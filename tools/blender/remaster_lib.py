"""Shared helpers for remastering the Quaternius monster rigs (see remaster_monsters.py).

Everything runs on Blender's Python module (bpy 5.3, also 4.2), headless:
load a rig, smooth its body, add procedurally built parts skinned to its bones,
paint linear vertex colours with baked ambient occlusion, export a GLB that keeps
the rig and every animation clip.

Coordinates are Blender's after glTF import: Z up, the creature faces -Y, +X is its
left side. Two materials leave the file:
  Skin   - opaque, gets the game's ink outline (StorybookFinish)
  Detail - painted-on parts (pupils, glints, cheeks, mouths, spots); exported with
           alphaMode MASK so the game draws them without an outline ring.
"""
import json
import math
import random
import struct

import bpy  # noqa: F401  (bmesh and mathutils load with bpy)
import bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform, intersect_point_tri

SKIN = "Skin"
DETAIL = "Detail"


# ---------------------------------------------------------------- colours

def srgb(hex_or_tuple):
    """'ff88aa' or (r, g, b) in sRGB 0..1 -> linear (r, g, b)."""
    if isinstance(hex_or_tuple, str):
        h = hex_or_tuple.lstrip("#")
        c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    else:
        c = list(hex_or_tuple)
    return Vector([x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c])


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return a * (1.0 - t) + b * t


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------- scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _ctx(obj, selected=None):
    sel = selected or [obj]
    return bpy.context.temp_override(object=obj, active_object=obj, selected_objects=sel,
                                     selected_editable_objects=sel)


def load(path):
    """Imports a rig; returns (armature, body) with every skinned mesh joined into body."""
    bpy.ops.import_scene.gltf(filepath=path, disable_bone_shape=True)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm]
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o not in meshes:
            bpy.data.objects.remove(o)
    body = meshes[0]
    if len(meshes) > 1:
        with _ctx(body, meshes):
            bpy.ops.object.join()
    body.name = "Model"  # not "Body": Godot would rename the clashing bone
    return arm, body


def tri_count(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def mat_index(obj, name):
    for i, m in enumerate(obj.data.materials):
        if m and m.name == name:
            return i
    return -1


def dominant_groups(obj):
    """Per vertex: the name of the bone weighing on it most ('' when none)."""
    names = [g.name for g in obj.vertex_groups]
    out = []
    for v in obj.data.vertices:
        best = max(v.groups, key=lambda g: g.weight, default=None)
        out.append(names[best.group] if best is not None else "")
    return out


def delete_faces(obj, mat_names=(), where=None):
    """Removes faces by material name and/or a predicate where(face_center, material_name,
    bone) - bone is the dominant bone of the face's first vertex."""
    groups = dominant_groups(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    names = [m.name if m else "" for m in obj.data.materials]
    kill = []
    for f in bm.faces:
        n = names[f.material_index]
        if n in mat_names or (where and where(f.calc_center_median(), n, groups[f.verts[0].index])):
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


def delete_small_islands(obj, max_faces, mat_names):
    """Drops loose pieces of at most max_faces faces of the given materials (Quaternius
    builds spikes out of single loose triangles); run before clean() welds them."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    names = [m.name if m else "" for m in obj.data.materials]
    seen, kill = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, comp = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            comp.append(g)
            for v in g.verts:
                for h in v.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        if len(comp) <= max_faces and names[comp[0].material_index] in mat_names:
            kill += comp
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    return len(kill)


def clean(obj, quads=True, merge=1e-4, fill_holes=0):
    """Welds glTF's split vertices, makes quads where it can, drops custom normals;
    optionally caps holes of up to fill_holes sides (left where loose spikes sat)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=merge)
    if fill_holes:
        bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=fill_holes)
    if quads:
        bmesh.ops.join_triangles(bm, faces=bm.faces, angle_face_threshold=math.radians(40),
                                 angle_shape_threshold=math.radians(40), cmp_materials=True)
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(obj.data)
    bm.free()
    if obj.data.has_custom_normals:
        with _ctx(obj):
            bpy.ops.mesh.customdata_custom_splitnormals_clear()


def apply_modifier(obj, mod):
    with _ctx(obj):
        bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
        bpy.ops.object.modifier_apply(modifier=mod.name)


def subdivide(obj, levels=1):
    mod = obj.modifiers.new("Subdiv", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    mod.uv_smooth = "NONE"
    apply_modifier(obj, mod)


def decimate_to(obj, target_tris):
    tris = tri_count(obj)
    if tris <= target_tris:
        return
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = target_tris / tris
    mod.use_collapse_triangulate = False
    apply_modifier(obj, mod)


def relax(obj, iterations=3, factor=0.5, mat_names=None):
    """Evens out the surface (decimation leaves long thin triangles that shade in streaks);
    only faces of mat_names move when given. Open borders stay put."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    names = [m.name if m else "" for m in obj.data.materials]
    verts = [v for v in bm.verts if not v.is_boundary and
             (mat_names is None or all(names[f.material_index] in mat_names for f in v.link_faces))]
    for _i in range(iterations):
        bmesh.ops.smooth_vert(bm, verts=verts, factor=factor, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(obj.data)
    bm.free()


def inflate(obj, amount, where=None):
    """Pushes vertices out along their normals (CC subdivision shrinks low-poly blobs)."""
    me = obj.data
    for v in me.vertices:
        if where is None or where(v.co):
            v.co += v.normal * amount


def islands(obj):
    """[(set_of_vertex_indices, material_name)] of connected pieces."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    names = [m.name if m else "" for m in obj.data.materials]
    seen = set()
    out = []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, comp = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            comp.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        out.append(({v.index for g in comp for v in g.verts}, names[comp[0].material_index]))
    bm.free()
    return out


def bounds(obj, verts=None):
    cos = [obj.data.vertices[i].co for i in verts] if verts is not None else [v.co for v in obj.data.vertices]
    lo = Vector((min(c.x for c in cos), min(c.y for c in cos), min(c.z for c in cos)))
    hi = Vector((max(c.x for c in cos), max(c.y for c in cos), max(c.z for c in cos)))
    return lo, hi


# ---------------------------------------------------------------- body sampling

class Surface:
    """Ray casts and skin-weight lookups against the body as it is now."""

    def __init__(self, obj):
        self.obj = obj
        me = obj.data
        self.verts = [v.co.copy() for v in me.vertices]
        self.polys = [list(p.vertices) for p in me.polygons]
        self.bvh = BVHTree.FromPolygons(self.verts, self.polys)
        names = [g.name for g in obj.vertex_groups]
        self.weights = [{names[g.group]: g.weight for g in v.groups if g.weight > 0.0} for v in me.vertices]

    def hit(self, origin, direction, dist=10.0):
        loc, nor, idx, _d = self.bvh.ray_cast(origin, direction.normalized(), dist)
        return (loc, nor) if loc is not None else (None, None)

    def project(self, point, normal, reach=0.6):
        """The body surface under point, looking down -normal from outside."""
        loc, nor = self.hit(point + normal * reach, -normal, reach * 3.0)
        if loc is None:
            loc, nor, _i, _d = self.bvh.find_nearest(point)
        return loc, nor

    def toward(self, origin, target):
        """First hit casting from origin towards target (e.g. from far in front onto the face)."""
        return self.hit(origin, target - origin, 50.0)

    def weights_at(self, p):
        loc, _n, idx, _d = self.bvh.find_nearest(p)
        poly = self.polys[idx]
        best = None
        # Interpolate over the polygon's triangles (fan).
        for k in range(1, len(poly) - 1):
            a, b, c = self.verts[poly[0]], self.verts[poly[k]], self.verts[poly[k + 1]]
            if intersect_point_tri(loc, a, b, c) or best is None:
                bc = barycentric_transform(loc, a, b, c, Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
                best = ((poly[0], bc.x), (poly[k], bc.y), (poly[k + 1], bc.z))
        out = {}
        for vi, f in best:
            f = max(0.0, f)
            for g, w in self.weights[vi].items():
                out[g] = out.get(g, 0.0) + w * f
        total = sum(out.values()) or 1.0
        return {g: w / total for g, w in out.items() if w / total > 0.01}


# ---------------------------------------------------------------- parts

def frame(normal, up=Vector((0, 0, 1))):
    """Orthonormal (tangent, bitangent, normal): tangent ~ creature's right-to-left, bitangent ~ up."""
    n = normal.normalized()
    if abs(n.dot(up)) > 0.98:
        up = Vector((0, -1, 0))
    t = up.cross(n).normalized()
    b = n.cross(t).normalized()
    return t, b, n


class Parts:
    """Accumulates new geometry with its colours, material and skin weights."""

    def __init__(self, surface):
        self.surface = surface
        self.bm = bmesh.new()
        self.deform = self.bm.verts.layers.deform.new()
        self.groups = {}
        self.colors = {}  # face index -> [linear colour per loop]
        self.mats = [SKIN, DETAIL]

    def _group(self, name):
        if name not in self.groups:
            self.groups[name] = len(self.groups)
        return self.groups[name]

    def _weigh(self, verts, weights):
        """weights: {'Bone': 1.0} fixed, 'surface' per-vertex from the body, or a Vector
        anchor whose body weights the whole part shares (rigid on the skin)."""
        fixed = None
        if isinstance(weights, Vector):
            fixed = self.surface.weights_at(weights)
        elif isinstance(weights, dict):
            fixed = weights
        for v in verts:
            w = fixed if fixed is not None else self.surface.weights_at(v.co)
            for g, x in w.items():
                v[self.deform][self._group(g)] = x

    def _add(self, cos, faces, color, weights, detail):
        """color: Vector, or f(index_of_vertex) -> Vector."""
        verts = [self.bm.verts.new(c) for c in cos]
        made = []
        for f in faces:
            try:
                face = self.bm.faces.new([verts[i] for i in f])
            except ValueError:
                continue
            face.material_index = 1 if detail else 0
            face.smooth = True
            made.append(face)
            cols = [color(i) if callable(color) else color for i in f]
            self.colors[face] = cols
        self._weigh(verts, weights)
        return verts

    # -- solids
    def _lathe(self, rings, seg, point, color, weights, detail):
        """A closed surface of revolution: point(theta 0..pi, phi) -> (position, colour)."""
        cos, cols = [], []
        p, c = point(0.0, 0.0)
        cos.append(p)
        cols.append(c)
        for r in range(1, rings):
            th = math.pi * r / rings
            for s in range(seg):
                p, c = point(th, 2.0 * math.pi * s / seg)
                cos.append(p)
                cols.append(c)
        p, c = point(math.pi, 0.0)
        cos.append(p)
        cols.append(c)
        last = len(cos) - 1
        faces = [(0, 1 + (s + 1) % seg, 1 + s) for s in range(seg)]
        for r in range(rings - 2):
            base = 1 + r * seg
            for s in range(seg):
                a, b = base + s, base + (s + 1) % seg
                faces.append((a, b, b + seg, a + seg))
        base = 1 + (rings - 2) * seg
        faces += [(base + s, base + (s + 1) % seg, last) for s in range(seg)]
        faces = [tuple(reversed(f)) for f in faces]  # outward
        col = (lambda i: cols[i]) if color is None else color
        return self._add(cos, faces, col, weights, detail)

    def ellipsoid(self, center, radii, basis=Matrix.Identity(3), color=Vector((1, 1, 1)), weights=None,
                  detail=False, seg=16, rings=10, squash_bottom=0.0, color_fn=None):
        """basis columns are the local x, y, z axes; color_fn(local unit vector) -> colour."""

        def point(th, ph):
            u = Vector((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)))
            if squash_bottom and u.z < 0.0:
                u = Vector((u.x, u.y, u.z * (1.0 - squash_bottom)))
            pos = center + basis @ Vector((u.x * radii[0], u.y * radii[1], u.z * radii[2]))
            return pos, (color_fn(u) if color_fn else color)

        return self._lathe(rings, seg, point, None, weights if weights is not None else center, detail)

    def blob(self, center, radius, axis, length, color, weights=None, detail=False, seg=12, rings=8, tip=0.25,
             color_fn=None, bend=None, up=None):
        """A soft spike / feather / petal: a sphere stretched from center along axis to
        `length`, narrowing to `tip` of its radius at the far end. radius may be (across,
        flat) for a flattened feather; color_fn(along 0..1) ; bend: Vector added at the tip."""
        axis = axis.normalized()
        t_, b_, n_ = frame(axis, up or (Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((0, -1, 0))))
        if isinstance(radius, (int, float)):
            radius = (radius, radius)

        def point(th, ph):
            along = (math.cos(th) + 1.0) * 0.5  # 1 at the tip, 0 at the base
            width = math.sin(th) * mix(1.0, tip, along ** 1.2)
            pos = center + axis * (along * length) + t_ * (math.cos(ph) * width * radius[0]) + \
                b_ * (math.sin(ph) * width * radius[1])
            if bend is not None:
                pos = pos + bend * (along ** 2)
            return pos, (color_fn(along) if color_fn else color)

        return self._lathe(rings, seg, point, None, weights if weights is not None else center, detail)

    def frustum(self, center, axis, r_bottom, r_top, height, color_fn, weights, seg=24, detail=False):
        """A capped, possibly flared band (crown, hat band): color_fn(t 0 bottom..1 top, side)."""
        t_, b_, n_ = frame(axis)
        cos, cols = [], []
        for k, (r, h) in enumerate(((r_bottom, 0.0), (r_top, height))):
            for s in range(seg):
                a = 2.0 * math.pi * s / seg
                cos.append(center + n_ * h + (t_ * math.cos(a) + b_ * math.sin(a)) * r)
                cols.append(color_fn(float(k), True))
        cos.append(center)
        cols.append(color_fn(0.0, False))
        cos.append(center + n_ * height)
        cols.append(color_fn(1.0, False))
        bot, top = 2 * seg, 2 * seg + 1
        faces = []
        for s in range(seg):
            a, b = s, (s + 1) % seg
            faces.append((a, b, b + seg, a + seg))
            faces.append((bot, b, a))
            faces.append((top, a + seg, b + seg))
        return self._add(cos, faces, lambda i: cols[i], weights, detail)

    # -- painted-on pieces
    def sphere_cap(self, center, radius, axis, half_angles, color, weights, lift=0.012, up=Vector((0, 0, 1)),
                   offset=(0.0, 0.0), seg=20, rings=5, color_fn=None, detail=True):
        """An elliptic patch lying on a sphere (iris, pupil, glint on an eyeball).
        half_angles (x, y) in radians; offset shifts the patch centre (radians) along
        the eye's own right / up."""
        t_, b_, n_ = frame(axis, up)
        cos, uv = [], []
        for r in range(rings + 1):
            k = r / rings
            for s in range(seg if r else 1):
                ph = 2.0 * math.pi * s / seg
                ax = offset[0] + math.cos(ph) * half_angles[0] * k
                ay = offset[1] + math.sin(ph) * half_angles[1] * k
                d = (n_ * math.cos(math.hypot(ax, ay)) +
                     (t_ * ax + b_ * ay).normalized() * math.sin(math.hypot(ax, ay))) if (ax or ay) else n_
                cos.append(center + d.normalized() * radius * (1.0 + lift))
                uv.append((math.cos(ph) * k, math.sin(ph) * k))
        faces = []
        for s in range(seg):
            faces.append((0, 1 + s, 1 + (s + 1) % seg))
        for r in range(1, rings):
            base = 1 + (r - 1) * seg
            for s in range(seg):
                a, b = base + s, base + (s + 1) % seg
                faces.append((a, a + seg, b + seg, b))
        col = (lambda i: color_fn(*uv[i])) if color_fn else color
        return self._add(cos, faces, col, weights, detail)

    def decal(self, point, normal, outline, color, weights="surface", lift=0.012, up=Vector((0, 0, 1)),
              rings=4, color_fn=None, detail=True, max_reach=0.6):
        """A flat painted shape draped over the body. outline: closed list of (x, y) in the
        surface plane (x towards the creature's left, y up), convex or star-shaped about 0."""
        t_, b_, n_ = frame(normal, up)
        surf = self.surface
        cos, uv = [], []
        segs = len(outline)

        def place(x, y):
            p = point + t_ * x + b_ * y
            loc, nor = surf.project(p, n_, max_reach)
            if loc is None:
                return p
            return loc + nor * lift

        cos.append(place(0.0, 0.0))
        uv.append((0.0, 0.0, 0.0))
        for r in range(1, rings + 1):
            k = r / rings
            for (x, y) in outline:
                cos.append(place(x * k, y * k))
                uv.append((x * k, y * k, k))
        faces = [(0, 1 + s, 1 + (s + 1) % segs) for s in range(segs)]
        for r in range(1, rings):
            base = 1 + (r - 1) * segs
            for s in range(segs):
                a, b = base + s, base + (s + 1) % segs
                faces.append((a, a + segs, b + segs, b))
        col = (lambda i: color_fn(*uv[i])) if color_fn else color
        return self._add(cos, faces, col, weights, detail)

    def stroke(self, point, normal, path, width, color, weights="surface", lift=0.014, up=Vector((0, 0, 1)),
               detail=True, taper=True, max_reach=0.6):
        """A painted line (mouth, brow, stripe) following path [(x, y)] in the surface plane."""
        t_, b_, n_ = frame(normal, up)
        surf = self.surface
        cos = []
        n = len(path)
        for i, (x, y) in enumerate(path):
            a = Vector(path[max(i - 1, 0)])
            b = Vector(path[min(i + 1, n - 1)])
            d = (b - a).normalized()
            side = Vector((-d.y, d.x))
            w = width * (math.sin(math.pi * (0.15 + 0.7 * i / (n - 1))) if taper else 1.0)
            for sgn in (-1.0, 1.0):
                q = Vector((x, y)) + side * w * 0.5 * sgn
                p = point + t_ * q.x + b_ * q.y
                loc, nor = surf.project(p, n_, max_reach)
                cos.append((loc + nor * lift) if loc is not None else p)
        faces = [(2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1) for i in range(n - 1)]
        return self._add(cos, faces, color, weights, detail)

    # -- finish
    def to_object(self, name="Parts"):
        me = bpy.data.meshes.new(name)
        self.bm.faces.index_update()
        face_cols = [(f.index, self.colors.get(f)) for f in self.bm.faces]
        self.bm.to_mesh(me)
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        for g, i in sorted(self.groups.items(), key=lambda kv: kv[1]):
            obj.vertex_groups.new(name=g)
        attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        cols = {}
        for idx, c in face_cols:
            cols[idx] = c
        for poly in me.polygons:
            c = cols.get(poly.index)
            for k, li in enumerate(poly.loop_indices):
                v = c[k] if c else Vector((1, 0, 1))
                attr.data[li].color = (v[0], v[1], v[2], 1.0)
        for m in self.mats:
            me.materials.append(material(m))
        self.bm.free()
        return obj


# ---------------------------------------------------------------- materials / paint

def material(name):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    va = nt.nodes.new("ShaderNodeVertexColor")
    va.layer_name = "Col"
    nt.links.new(va.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.5
    bsdf.inputs["Metallic"].default_value = 0.0
    return m


def paint_body(obj, paint):
    """paint(material_name, co, normal, info) -> linear colour, for every corner of the body,
    info = {"bone": dominant bone, "bump": protrusion (see protrusion())};
    afterwards every original material becomes Skin (or Detail when paint marks the
    material name in paint.detail)."""
    me = obj.data
    names = [m.name if m else "" for m in me.materials]
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    groups = dominant_groups(obj)
    bump = protrusion(obj)
    for poly in me.polygons:
        n = names[poly.material_index]
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            v = me.vertices[vi]
            c = paint(n, v.co, v.normal, {"bone": groups[vi], "bump": bump[vi]})
            attr.data[li].color = (c[0], c[1], c[2], 1.0)
    detail = getattr(paint, "detail", ())
    new_index = [1 if n in detail else 0 for n in names]
    me.materials.clear()
    me.materials.append(material(SKIN))
    me.materials.append(material(DETAIL))
    for poly in me.polygons:
        poly.material_index = new_index[poly.material_index] if poly.material_index < len(new_index) else 0


def protrusion(obj, iterations=25):
    """Per vertex: how far it stands out of a heavily smoothed copy of the mesh, along its
    normal (spike tips and ridges > 0, creases < 0), in mesh units."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for _i in range(iterations):
        bmesh.ops.smooth_vert(bm, verts=bm.verts, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.verts.ensure_lookup_table()
    out = [(v.co - bm.verts[v.index].co).dot(v.normal) for v in obj.data.vertices]
    bm.free()
    return out


def pose_matrix(arm, bone, action="Idle", frame=None):
    """Rest-space -> posed-space matrix of a bone in a clip's frame (its first by default):
    lets a recipe place things relative to how a part is actually held in game."""
    act = bpy.data.actions[action]
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    if hasattr(arm.animation_data, "action_slot") and act.slots:
        arm.animation_data.action_slot = act.slots[0]
    f = frame if frame is not None else int(act.frame_range[0])
    bpy.context.scene.frame_set(f)
    bpy.context.view_layer.update()
    pb = arm.pose.bones[bone]
    m = pb.matrix @ pb.bone.matrix_local.inverted()
    arm.animation_data.action = None
    bpy.context.scene.frame_set(0)
    for p in arm.pose.bones:
        p.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    return m


def split_off(obj, bones):
    """Moves the faces mostly driven by `bones` into a copy of obj (e.g. a hat that must
    keep its crisp shape while the body is subdivided); join() it back afterwards."""
    groups = dominant_groups(obj)
    other = obj.copy()
    other.data = obj.data.copy()
    bpy.context.scene.collection.objects.link(other)
    for target, keep in ((obj, False), (other, True)):
        bm = bmesh.new()
        bm.from_mesh(target.data)
        kill = [f for f in bm.faces if (sum(groups[v.index] in bones for v in f.verts) * 2 > len(f.verts)) != keep]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(target.data)
        bm.free()
    return other


def join(body, other):
    with _ctx(body, [body, other]):
        bpy.ops.object.join()


def join_parts(body, parts_obj):
    with _ctx(body, [body, parts_obj]):
        bpy.ops.object.join()
    # Joining appends material slots per source; fold duplicates back to Skin / Detail.
    me = body.data
    remap = [0 if (m and m.name.startswith(SKIN)) else 1 for m in me.materials]
    for poly in me.polygons:
        poly.material_index = remap[poly.material_index]
    while len(me.materials) > 2:
        me.materials.pop()


def bake_ao(obj, rays=48, reach=0.4, strength=0.45, floor=True, seed=7, shade=Vector((0.56, 0.53, 0.65))):
    """Ambient occlusion from the rest pose into the corner colours: occluded corners
    darken towards a cool tint (not grey), so creases read as soft painted shade."""
    me = obj.data
    verts = [v.co.copy() for v in me.vertices]
    polys = [list(p.vertices) for p in me.polygons]
    lo, _hi = bounds(obj)
    if floor:
        # A ground plane under the feet, as in the game.
        base = len(verts)
        s = 20.0
        verts += [Vector((-s, -s, lo.z - 0.01)), Vector((s, -s, lo.z - 0.01)), Vector((s, s, lo.z - 0.01)),
                  Vector((-s, s, lo.z - 0.01))]
        polys.append([base, base + 1, base + 2, base + 3])
    bvh = BVHTree.FromPolygons(verts, polys)
    rng = random.Random(seed)
    dirs = []
    for i in range(rays):
        # Cosine-weighted hemisphere (stratified).
        u = (i + rng.random()) / rays
        ph = 2.0 * math.pi * ((i * 0.618034) % 1.0)
        r = math.sqrt(u)
        dirs.append(Vector((r * math.cos(ph), r * math.sin(ph), math.sqrt(max(0.0, 1.0 - u)))))
    occl = []
    for v in me.vertices:
        n = v.normal
        t_, b_, n_ = frame(n)
        o = v.co + n * 0.004
        hit = 0.0
        for d in dirs:
            w = t_ * d.x + b_ * d.y + n_ * d.z
            loc, _nor, _i, dist = bvh.ray_cast(o, w, reach)
            if loc is not None:
                hit += 1.0 - (dist / reach) ** 2
        occl.append(hit / rays)
    attr = me.color_attributes["Col"]
    for li, loop in enumerate(me.loops):
        a = occl[loop.vertex_index] * strength
        c = Vector(attr.data[li].color[:3])
        shaded = Vector((c.x * shade.x, c.y * shade.y, c.z * shade.z))
        attr.data[li].color = (*mix(c, shaded, a), 1.0)


# ---------------------------------------------------------------- export

def export(arm, body, path, clips):
    for o in list(bpy.data.objects):
        o.select_set(o in (arm, body))
    bpy.context.view_layer.objects.active = arm
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_animations=True,
              export_animation_mode="ACTIONS", export_force_sampling=True, export_def_bones=False,
              export_optimize_animation_size=True, export_texcoords=False, export_tangents=False,
              export_materials="EXPORT", export_yup=True, export_apply=False, export_image_format="NONE")
    props = bpy.ops.export_scene.gltf.get_rna_type().properties
    if "export_vertex_color" in props.keys():
        kw["export_vertex_color"] = "ACTIVE"
    else:
        kw["export_colors"] = True
    bpy.ops.export_scene.gltf(**kw)
    _patch_glb(path, clips)


def _patch_glb(path, clips):
    """Detail -> alphaMode MASK (no outline in the game); checks every clip is present."""
    data = open(path, "rb").read()
    magic, version, _length = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF"
    jlen, jtype = struct.unpack_from("<I4s", data, 12)
    doc = json.loads(data[20:20 + jlen])
    rest = data[20 + jlen:]
    for m in doc.get("materials", []):
        m.pop("doubleSided", None)
        if m.get("name") == DETAIL:
            m["alphaMode"] = "MASK"
            m["alphaCutoff"] = 0.5
        pbr = m.setdefault("pbrMetallicRoughness", {})
        pbr["metallicFactor"] = 0.0
        pbr["roughnessFactor"] = 0.6
    names = sorted(a["name"] for a in doc.get("animations", []))
    missing = [c for c in clips if c not in names]
    assert not missing, "missing clips %s (have %s)" % (missing, names)
    blob = json.dumps(doc, separators=(",", ":")).encode()
    blob += b" " * ((4 - len(blob) % 4) % 4)
    out = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(blob) + len(rest))
    out += struct.pack("<I4s", len(blob), b"JSON") + blob + rest
    open(path, "wb").write(out)
    return names
