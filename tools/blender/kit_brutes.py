"""Helpers for the fierce monsters (recipes_brutes.py): atlas sampling, extra materials,
fierce eyes, fangs, horns, glowing cracks, fur tufts.

Materials a brute model can carry (glTF material names; MonsterVisual reads the prefix):
  Skin       - opaque, tinted by MonsterData "tint", ink outline (the lib's default)
  Detail     - painted-on, tinted, no outline (alphaMode MASK)
  Glow       - unlit + MASK: emissive-looking markings / eyes; tinted, so a white-ish glow
               takes each variant's colour (thunder golem yellow, void golem violet)
  Ivory      - opaque, NOT tinted (bone, tusks, teeth, claws, metal that must keep its colour)
  IvoryGlow  - unlit, NOT tinted (an eye or ember that must keep its own colour)
  anything else (e.g. "Dino_Main") - opaque and tinted like Skin; kept by name so a
               template's "paint" {material: colour} can still repaint it.
"""
import json
import math
import random
import struct

import bpy  # noqa: F401
import bmesh
from mathutils import Matrix, Vector

import remaster_lib as L

C = L.srgb
SKIN, DETAIL, GLOW, IVORY, IVORY_GLOW = "Skin", "Detail", "Glow", "Ivory", "IvoryGlow"
WHITE = C("ffffff")


def balanced(tint):
    """MonsterVisual's StorybookFinish.balanced_tint (linear factors on the albedo)."""
    peak = max(tint)
    d = max(1.0, peak / 1.22)
    return Vector([t / d for t in tint])


def pre(color, tint):
    """The colour to paint so that, multiplied by a template's tint, it shows `color`."""
    b = balanced(tint)
    return Vector([min(1.0, c / max(t, 1e-3)) for c, t in zip(color, b)])


# ---------------------------------------------------------------- regions

def regions(obj):
    """Per polygon: its region key - the material name, or, for atlas-textured rigs, the
    sRGB hex of the texel under its first corner (Quaternius atlases are flat swatches)."""
    me = obj.data
    names = [m.name if m else "" for m in me.materials]
    img = None
    for m in me.materials:
        if m and m.use_nodes:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image is not None:
                    img = n.image
    if img is None or not me.uv_layers:
        return [names[p.material_index] for p in me.polygons]
    w, h = img.size
    px = img.pixels[:]
    uv = me.uv_layers.active.data

    def s(x):
        return int(255 * (x * 12.92 if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055) + 0.5)

    out = []
    for p in me.polygons:
        acc = Vector((0, 0, 0))
        for li in p.loop_indices:
            u, v = uv[li].uv
            x = min(w - 1, max(0, int((u % 1.0) * w)))
            y = min(h - 1, max(0, int((v % 1.0) * h)))
            i = (y * w + x) * 4
            acc += Vector(px[i:i + 3])
        acc /= len(p.loop_indices)
        out.append("%02x%02x%02x" % tuple(s(x) for x in acc))
    return out


def tag_regions(obj, keys=None):
    """Bakes the region of every polygon into its material slot (one slot per region), so
    the lib's per-material tools (delete_faces, islands, split_off) work on atlas rigs."""
    keys = keys or regions(obj)
    me = obj.data
    uniq = sorted(set(keys))
    me.materials.clear()
    for k in uniq:
        me.materials.append(L.material("R_" + k))
    idx = {k: i for i, k in enumerate(uniq)}
    for p, k in zip(me.polygons, keys):
        p.material_index = idx[k]


def nearest_region(hexes, palette):
    """Maps a sampled hex to the closest key of palette {hex: name}."""
    def rgb(h):
        return Vector([int(h[i:i + 2], 16) for i in (0, 2, 4)])
    out = {}
    for h in hexes:
        out[h] = min(palette, key=lambda k: (rgb(k) - rgb(h)).length)
    return {h: palette[k] for h, k in out.items()}


def face_islands(obj, pred):
    """Connected groups of faces passing pred(poly) -> [(centre, half_size Vector, verts)]."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    ok = {p.index for p in me.polygons if pred(p)}
    seen = set()
    out = []
    for i in ok:
        if i in seen:
            continue
        stack, comp = [bm.faces[i]], []
        seen.add(i)
        while stack:
            f = stack.pop()
            comp.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index in ok and g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        vs = {v.index for f in comp for v in f.verts}
        lo, hi = L.bounds(obj, vs)
        out.append(((lo + hi) * 0.5, (hi - lo) * 0.5, vs))
    bm.free()
    return out


# ---------------------------------------------------------------- materials

class BParts(L.Parts):
    """Parts with more materials: `with parts.on(GLOW): ...` puts what is made inside on Glow."""

    def __init__(self, surface, mats=(SKIN, DETAIL, GLOW, IVORY, IVORY_GLOW)):
        super().__init__(surface)
        self.mats = list(mats)
        self.cur = None

    class _On:
        def __init__(self, parts, name):
            self.parts, self.name, self.prev = parts, name, None

        def __enter__(self):
            self.prev = self.parts.cur
            self.parts.cur = self.name
            return self.parts

        def __exit__(self, *a):
            self.parts.cur = self.prev

    def on(self, name):
        if name not in self.mats:
            self.mats.append(name)
        return BParts._On(self, name)

    def _add(self, cos, faces, color, weights, detail):
        verts = [self.bm.verts.new(c) for c in cos]
        idx = self.mats.index(self.cur) if self.cur else (1 if detail else 0)
        for f in faces:
            try:
                face = self.bm.faces.new([verts[i] for i in f])
            except ValueError:
                continue
            face.material_index = idx
            face.smooth = True
            self.colors[face] = [color(i) if callable(color) else color for i in f]
        self._weigh(verts, weights)
        return verts


def paint(obj, fn, keys=None):
    """fn(region, co, normal, info) -> colour or (colour, material name), for every corner;
    info = {"bone", "bump", "poly" (polygon centre)}. Faces take the material of their
    first corner. Material slots become the names used (Skin first)."""
    me = obj.data
    keys = keys or regions(obj)
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    groups = L.dominant_groups(obj)
    bump = L.protrusion(obj)
    names = [SKIN, DETAIL]
    face_mat = []
    for poly in me.polygons:
        k = keys[poly.index]
        mat = None
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            v = me.vertices[vi]
            r = fn(k, v.co, v.normal, {"bone": groups[vi], "bump": bump[vi], "poly": poly.center})
            if isinstance(r, tuple) and len(r) == 2 and isinstance(r[1], str):
                c, m = r
            else:
                c, m = r, SKIN
            mat = mat or m
            attr.data[li].color = (c[0], c[1], c[2], 1.0)
        if mat not in names:
            names.append(mat)
        face_mat.append(names.index(mat))
    me.materials.clear()
    for n in names:
        me.materials.append(L.material(n))
    for poly, i in zip(me.polygons, face_mat):
        poly.material_index = i


def join_parts(body, parts_obj):
    """Joins parts into body, folding material slots by name (Skin.001 -> Skin)."""
    with L._ctx(body, [body, parts_obj]):
        bpy.ops.object.join()
    me = body.data
    names = []
    remap = []
    for m in me.materials:
        n = m.name.split(".")[0] if m else SKIN
        if n not in names:
            names.append(n)
        remap.append(names.index(n))
    idx = [remap[p.material_index] for p in me.polygons]
    me.materials.clear()  # (resets every polygon's index)
    for n in names:
        me.materials.append(L.material(n))
    for poly, i in zip(me.polygons, idx):
        poly.material_index = i


_LIB_EXPORT = L.export


def export(arm, body, path, clips):
    """remaster_lib.export, plus: unused material slots dropped; Glow / IvoryGlow made
    unlit + MASK; body["base_colors"] (JSON {material: sRGB hex}) sets those materials'
    base colour factor (the hue of a rig a template may repaint by material name).
    recipes_brutes installs this as L.export, so remaster_monsters.build uses it too; it
    changes nothing for models without such materials."""
    me = body.data
    used = {p.material_index for p in me.polygons}
    keep = [i for i in range(len(me.materials)) if i in used]
    if len(keep) < len(me.materials):
        names = [me.materials[i].name for i in keep]
        remap = {old: new for new, old in enumerate(keep)}
        idx = [remap[p.material_index] for p in me.polygons]
        me.materials.clear()
        for n in names:
            me.materials.append(L.material(n))
        for p, i in zip(me.polygons, idx):
            p.material_index = i
    _LIB_EXPORT(arm, body, path, clips)
    base_colors = json.loads(body.get("base_colors", "{}"))
    data = open(path, "rb").read()
    jlen, _t = struct.unpack_from("<I4s", data, 12)
    doc = json.loads(data[20:20 + jlen])
    rest = data[20 + jlen:]
    used_ext = set(doc.get("extensionsUsed", []))
    for m in doc.get("materials", []):
        n = m.get("name", "")
        if n.endswith("Glow"):
            m.setdefault("extensions", {})["KHR_materials_unlit"] = {}
            m["alphaMode"] = "MASK"
            m["alphaCutoff"] = 0.5
            used_ext.add("KHR_materials_unlit")
        if n.endswith("Detail") and n != "Detail":
            m["alphaMode"] = "MASK"
            m["alphaCutoff"] = 0.5
        if n in base_colors:
            c = C(base_colors[n])
            m.setdefault("pbrMetallicRoughness", {})["baseColorFactor"] = [c[0], c[1], c[2], 1.0]
    if used_ext:
        doc["extensionsUsed"] = sorted(used_ext)
    blob = json.dumps(doc, separators=(",", ":")).encode()
    blob += b" " * ((4 - len(blob) % 4) % 4)
    out = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(blob) + len(rest))
    out += struct.pack("<I4s", len(blob), b"JSON") + blob + rest
    open(path, "wb").write(out)


# ---------------------------------------------------------------- geometry helpers

def front_hit(surf, x, z, from_y=-6.0):
    return surf.toward(Vector((x, from_y, z)), Vector((x, 0.0, z)))


def dir_hit(surf, center, direction):
    d = direction.normalized()
    return surf.toward(center + d * 8.0, center)


def ellipse(rx, ry, n=20, rot=0.0):
    out = []
    for i in range(n):
        a = 2.0 * math.pi * i / n
        x, y = math.cos(a) * rx, math.sin(a) * ry
        out.append((x * math.cos(rot) - y * math.sin(rot), x * math.sin(rot) + y * math.cos(rot)))
    return out


def fibonacci(n):
    out = []
    for i in range(n):
        z = 1.0 - 2.0 * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1.0 - z * z))
        a = i * math.pi * (3.0 - math.sqrt(5.0))
        out.append(Vector((r * math.cos(a), r * math.sin(a), z)))
    return out


def basis(z, up=Vector((0, 0, 1))):
    t_, b_, n_ = L.frame(z, up)
    return Matrix((t_, b_, n_)).transposed()


def rot_about(v, axis, ang):
    return Matrix.Rotation(ang, 3, axis.normalized()) @ v


# ---------------------------------------------------------------- features

def fierce_eye(parts, center, radius, gaze, sx, iris, iris_dark, weights, lid=None, socket=None,
               slant=0.35, open_=0.55, pupil="slit", glow_mat=GLOW, lid_mat=SKIN, oval=1.0):
    """An angry glowing eye: a glowing eyeball (bright core -> darker rim), a slit or dot
    pupil, and a heavy upper lid tilted down towards the nose (sx = +1 the creature's
    left eye, -1 its right). open_ 0..1 how much of the ball shows under the lid.
    socket: optional colour of a dark ring of shadow around the ball."""
    up = rot_about(Vector((0, 0, 1)), gaze, slant * sx)
    with parts.on(glow_mat):
        parts.ellipsoid(center, (radius * oval, radius, radius), basis(gaze, up), color=None, weights=weights,
                        seg=14, rings=8, color_fn=lambda u: L.mix(iris, iris_dark, L.smooth(0.5, -0.2, u.z) * 0.85))
        if pupil == "slit":
            parts.sphere_cap(center, radius, gaze, (0.1, 0.62), C("0d0610"), weights, lift=0.03, up=up, seg=12,
                             rings=2)
        elif pupil == "dot":
            parts.sphere_cap(center, radius, gaze, (0.22, 0.22), C("0d0610"), weights, lift=0.03, up=up, seg=12,
                             rings=2)
        # a hot glint
        parts.sphere_cap(center, radius, gaze, (0.14, 0.1), L.mix(iris, WHITE, 0.8), weights, lift=0.05, up=up,
                         offset=(-0.32 * sx, 0.25), seg=8, rings=1)
    if lid is not None:
        # Upper lid: a shell over the top of the ball whose lower edge sits open_ of the way
        # down, tilted with the slant; a thinner lower lid below.
        side = gaze.cross(up).normalized()
        h = 0.95
        edge = -0.15 + 0.75 * open_
        top = rot_about(gaze, side, edge + h)
        with parts.on(lid_mat):
            parts.sphere_cap(center, radius * 1.07, top, (1.5, h), lid, weights, lift=0.0, up=up, seg=18, rings=4,
                             detail=False)
            low = rot_about(gaze, side, -(0.5 + 0.55))
            parts.sphere_cap(center, radius * 1.06, low, (1.4, 0.55), lid, weights, lift=0.0, up=up, seg=16,
                             rings=3, detail=False)
    return up


def ridge(parts, a, b, radius, color, weights, bulge=None, tip=0.6, seg=10, rings=6, mat=SKIN, flat=0.6):
    """A brow ridge / plate: a stretched blob from a to b."""
    axis = b - a
    with parts.on(mat):
        return parts.blob(a, (radius, radius * flat), axis, axis.length, color if not callable(color) else None,
                          weights=weights, seg=seg, rings=rings, tip=tip,
                          color_fn=color if callable(color) else None, bend=bulge,
                          up=(bulge.normalized() if bulge is not None and bulge.length > 1e-6 else None))


def fang(parts, base, direction, length, radius, weights, root=C("e9dcc0"), tip_col=C("fffaf0"), mat=IVORY,
         bend=None, seg=8, rings=5, flat=1.0):
    with parts.on(mat):
        return parts.blob(base, (radius, radius * flat), direction, length, None, weights=weights, seg=seg,
                          rings=rings, tip=0.04, bend=bend,
                          color_fn=lambda t: L.mix(root, tip_col, L.smooth(0.0, 0.9, t)))


def horn(parts, base, direction, length, radius, weights, root, tip_col, bend=None, rings_col=None, mat=IVORY,
         seg=12, rings=9, tip=0.05, bands=4):
    """A tapering curved horn; rings_col paints growth bands along it."""

    def col(t):
        c = L.mix(root, tip_col, L.smooth(0.15, 1.0, t))
        if rings_col is not None and t < 0.8:
            c = L.mix(c, rings_col, L.smooth(0.6, 0.95, math.cos(t * bands * 2.0 * math.pi)) * 0.6 * (1.0 - t))
        return c

    with parts.on(mat):
        return parts.blob(base, radius, direction, length, None, weights=weights, seg=seg, rings=rings, tip=tip,
                          bend=bend, color_fn=col)


def glow_path(parts, point, normal, path, width, color, up=Vector((0, 0, 1)), mat=GLOW, lift=0.016, max_reach=0.6):
    with parts.on(mat):
        parts.stroke(point, normal, path, width, color, lift=lift, up=up, max_reach=max_reach)


def crack_path(rng, length, steps=6, wander=0.35, start=(0.0, 0.0), heading=None):
    """A jagged crack polyline in the surface plane."""
    a = heading if heading is not None else rng.uniform(0, 2 * math.pi)
    x, y = start
    pts = [(x, y)]
    seg = length / steps
    for _i in range(steps):
        a += rng.uniform(-wander, wander) * 2.0
        x += math.cos(a) * seg
        y += math.sin(a) * seg
        pts.append((x, y))
    return pts


def scatter_dirs(n, seed, cond=None, center=None):
    rng = random.Random(seed)
    out = []
    for d in fibonacci(n):
        if cond is None or cond(d):
            out.append(d)
    rng.shuffle(out)
    return out


def tufts(parts, surf, center, dirs, length, radius, root, tip_col, weights=None, jitter=0.35, seed=1, per=1,
          lift_out=0.6, droop=0.35, mat=SKIN, seg=6, rings=3, skip=None, flat=0.5, tip=0.08):
    """Fur / spike tufts over the body: rays from center along each of dirs hit the
    surface; at each hit `per` blobs lean outward and droop down."""
    rng = random.Random(seed)
    made = 0
    with parts.on(mat):
        for d in dirs:
            p, n = dir_hit(surf, center, d)
            if p is None or (skip and skip(p, n)):
                continue
            for _k in range(per):
                j = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * jitter
                dd = (n * lift_out + j + Vector((0, 0, -droop))).normalized()
                ln = length * rng.uniform(0.75, 1.2)
                parts.blob(p - n * radius * 0.5, (radius, radius * flat), dd, ln, None,
                           weights=weights if weights is not None else p, seg=seg, rings=rings, tip=tip,
                           color_fn=lambda t: L.mix(root, tip_col, L.smooth(0.0, 1.0, t)), up=n)
                made += 1
    return made


def split_where(obj, pred):
    """Moves the faces passing pred(polygon) into a copy of obj (to keep crisp parts, e.g.
    horns and blades, out of a subdivision); join it back with L.join()."""
    flags = [bool(pred(p)) for p in obj.data.polygons]
    other = obj.copy()
    other.data = obj.data.copy()
    bpy.context.scene.collection.objects.link(other)
    for target, keep in ((obj, False), (other, True)):
        bm = bmesh.new()
        bm.from_mesh(target.data)
        bm.faces.ensure_lookup_table()
        kill = [f for f in bm.faces if flags[f.index] != keep]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(target.data)
        bm.free()
    return other


def bake_ao(obj, keep_glow=True, **kw):
    """L.bake_ao, leaving glowing surfaces (unlit) as painted."""
    me = obj.data
    attr = me.color_attributes["Col"]
    glow = [i for i, m in enumerate(me.materials) if m and m.name.endswith("Glow")]
    saved = {}
    if keep_glow and glow:
        for p in me.polygons:
            if p.material_index in glow:
                for li in p.loop_indices:
                    saved[li] = tuple(attr.data[li].color)
    L.bake_ao(obj, **kw)
    for li, c in saved.items():
        attr.data[li].color = c


def body_dir_paint(co, center=Vector((0, 0, 1.4))):
    d = co - center
    return d.normalized() if d.length > 1e-6 else Vector((0, 0, 1))


def retag(obj, verts, name):
    """Moves the faces whose vertices are all in verts onto material slot `name`."""
    me = obj.data
    names = [m.name for m in me.materials]
    if name not in names:
        me.materials.append(L.material(name))
        names.append(name)
    i = names.index(name)
    for p in me.polygons:
        if all(v in verts for v in p.vertices):
            p.material_index = i


def hash01(v, seed=0):
    """A stable pseudo-random 0..1 from a position (per-facet colour jitter)."""
    x = math.sin(v.x * 127.1 + v.y * 311.7 + v.z * 74.7 + seed * 19.3) * 43758.5453
    return x - math.floor(x)


def flat(obj, mat_names):
    """Flat-shades the faces of the given materials (cut stone, crystal facets)."""
    names = [m.name for m in obj.data.materials]
    for p in obj.data.polygons:
        if names[p.material_index] in mat_names:
            p.use_smooth = False


def rock(parts, center, radius, color_fn, weights, seed=0, seg=7, rings=5, squash=(1.0, 1.0, 0.8), mat=IVORY,
         up=Vector((0, 0, 1))):
    """A faceted boulder (flat shade it with flat()): a low ellipsoid with jittered radii."""
    rng = random.Random(seed)
    radii = (radius * squash[0] * rng.uniform(0.85, 1.1), radius * squash[1] * rng.uniform(0.85, 1.1),
             radius * squash[2] * rng.uniform(0.85, 1.1))
    b = basis(up) @ Matrix.Rotation(rng.uniform(0, 6.28), 3, "Z")
    with parts.on(mat):
        vs = parts.ellipsoid(center, radii, b, color=None, weights=weights, seg=seg, rings=rings, color_fn=color_fn)
    for v in vs:
        v.co += (v.co - center) * rng.uniform(-0.12, 0.12)
    return vs


def crystal(parts, base, direction, length, radius, weights, root, tip_col, mat=SKIN, sides=5):
    with parts.on(mat):
        return parts.blob(base, radius, direction, length, None, weights=weights, seg=sides, rings=3, tip=0.02,
                          color_fn=lambda t: L.mix(root, tip_col, t))


def noise(v, scale=1.0, seed=0):
    """Smooth 3D value noise 0..1 (mottling, fur clumps, rock veins)."""
    p = v * scale
    i = Vector((math.floor(p.x), math.floor(p.y), math.floor(p.z)))
    f = p - i
    u = Vector([t * t * (3.0 - 2.0 * t) for t in f])

    def h(dx, dy, dz):
        return hash01(Vector((i.x + dx, i.y + dy, i.z + dz)), seed)

    x00 = h(0, 0, 0) * (1 - u.x) + h(1, 0, 0) * u.x
    x10 = h(0, 1, 0) * (1 - u.x) + h(1, 1, 0) * u.x
    x01 = h(0, 0, 1) * (1 - u.x) + h(1, 0, 1) * u.x
    x11 = h(0, 1, 1) * (1 - u.x) + h(1, 1, 1) * u.x
    y0 = x00 * (1 - u.y) + x10 * u.y
    y1 = x01 * (1 - u.y) + x11 * u.y
    return y0 * (1 - u.z) + y1 * u.z


def fbm(v, scale=1.0, seed=0, octaves=3):
    out, amp, tot = 0.0, 1.0, 0.0
    for o in range(octaves):
        out += noise(v, scale * (2 ** o), seed + o) * amp
        tot += amp
        amp *= 0.5
    return out / tot


def border_points(obj, inside, outside, spacing=0.12):
    """Points along the border where faces of material `inside` meet faces of `outside`:
    [(point, across, normal)] - across points from the inside face into the outside one."""
    me = obj.data
    names = [m.name for m in me.materials]
    bm = bmesh.new()
    bm.from_mesh(me)
    out = []
    for e in bm.edges:
        if len(e.link_faces) != 2:
            continue
        a, b = e.link_faces
        na, nb = names[a.material_index], names[b.material_index]
        if na == outside and nb == inside:
            a, b = b, a
        elif not (na == inside and nb == outside):
            continue
        mid = (e.verts[0].co + e.verts[1].co) * 0.5
        if any((mid - p).length < spacing for p, _a, _n in out):
            continue
        across = (b.calc_center_median() - a.calc_center_median()).normalized()
        out.append((mid.copy(), across, (a.normal + b.normal).normalized()))
    bm.free()
    return out


def displace(obj, amount, fn):
    """Pushes vertices along their normals by amount * fn(co, normal) (lumpy fur, rock)."""
    for v in obj.data.vertices:
        v.co += v.normal * amount * fn(v.co, v.normal)


def merge_materials(obj, mapping):
    """Folds material slots into others by name ({"Skin_Fur": "Skin"})."""
    me = obj.data
    old = [m.name for m in me.materials]
    names = []
    for n in old:
        t = mapping.get(n, n)
        if t not in names:
            names.append(t)
    idx = [names.index(mapping.get(old[p.material_index], old[p.material_index])) for p in me.polygons]
    me.materials.clear()
    for n in names:
        me.materials.append(L.material(n))
    for p, i in zip(me.polygons, idx):
        p.material_index = i
