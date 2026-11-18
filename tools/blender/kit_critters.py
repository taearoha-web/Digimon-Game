"""Team critters' additions to remaster_lib: untinted materials, texture sampling, fierce faces.

Materials leaving a critters model (MonsterVisual tints every material whose name does
not start with "Keep"):
  Skin        opaque, tinted, ink outline
  Detail      painted-on decals, tinted (alphaMode MASK: no outline)
  Keep        opaque, NOT tinted (eyeballs, teeth, claws that must stay white/black)
  KeepDetail  decals, NOT tinted (iris, pupil, glints, a belly that must stay cream)
  KeepGlow    unlit (KHR_materials_unlit), NOT tinted: glowing eyes, embers, runes, sparks
"""
import json
import math
import struct
from contextlib import contextmanager

import bpy
import bmesh
from mathutils import Vector

import remaster_lib as L

KEEP = "Keep"
KEEP_DETAIL = "KeepDetail"
GLOW = "KeepGlow"
MATS = [L.SKIN, L.DETAIL, KEEP, KEEP_DETAIL, GLOW]
MODES = {"skin": 0, "detail": 1, "keep": 2, "keepdetail": 3, "glow": 4}
WHITE = L.srgb("ffffff")


def _slot(name):
    """Material slot index from a (possibly '.001'-suffixed) material name."""
    base = name.split(".")[0] if name else L.SKIN
    return MATS.index(base) if base in MATS else 0


class KParts(L.Parts):
    """Parts with a current material mode: with parts.use("keep"): ... puts what follows
    on the untinted materials (detail pieces on KeepDetail), "glow" on KeepGlow."""

    def __init__(self, surface):
        super().__init__(surface)
        self.mats = list(MATS)
        self.mode = "skin"

    @contextmanager
    def use(self, mode):
        old = self.mode
        self.mode = mode
        try:
            yield self
        finally:
            self.mode = old

    def _add(self, cos, faces, color, weights, detail):
        verts = [self.bm.verts.new(c) for c in cos]
        if self.mode == "glow":
            index = 4
        else:
            index = (2 if self.mode == "keep" else 0) + (1 if detail else 0)
        for f in faces:
            try:
                face = self.bm.faces.new([verts[i] for i in f])
            except ValueError:
                continue
            face.material_index = index
            face.smooth = True
            self.colors[face] = [color(i) if callable(color) else color for i in f]
        self._weigh(verts, weights)
        return verts


def _set_mats(me, new_index):
    me.materials.clear()
    for m in MATS:
        me.materials.append(L.material(m))
    for poly, i in zip(me.polygons, new_index):
        poly.material_index = i


def tex_lookup(obj):
    """Per loop: the linear colour of the source texture under that corner (None when the
    model has no image). Run before reshaping steps that drop UVs."""
    img = next((i for i in bpy.data.images if i.size[0] > 0), None)
    me = obj.data
    if img is None or not me.uv_layers:
        return None
    w, h = img.size
    px = list(img.pixels[:])
    uv = me.uv_layers.active.data
    out = []
    for li in range(len(me.loops)):
        u, v = uv[li].uv
        x = min(w - 1, max(0, int((u % 1.0) * w)))
        y = min(h - 1, max(0, int((v % 1.0) * h)))
        k = (y * w + x) * 4
        out.append(L.srgb((px[k], px[k + 1], px[k + 2])))
    return out


def paint_body(obj, paint, face_mode=None, tex=False):
    """Like remaster_lib.paint_body; info also carries "tex" (the source texture colour at
    that corner, when tex=True) and "mat" (the source material name). face_mode(name,
    center, normal, bone) -> one of MODES picks each face's material (default skin)."""
    me = obj.data
    names = [m.name if m else "" for m in me.materials]
    texcol = tex_lookup(obj) if tex else None
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    groups = L.dominant_groups(obj)
    bump = L.protrusion(obj)
    new_index = []
    for poly in me.polygons:
        n = names[poly.material_index]
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            v = me.vertices[vi]
            info = {"bone": groups[vi], "bump": bump[vi], "tex": texcol[li] if texcol else None, "mat": n}
            c = paint(n, v.co, v.normal, info)
            attr.data[li].color = (c[0], c[1], c[2], 1.0)
        mode = face_mode(n, poly.center, poly.normal, groups[poly.vertices[0]]) if face_mode else "skin"
        new_index.append(MODES[mode or "skin"])
    _set_mats(me, new_index)


def join_parts(body, parts_obj):
    with L._ctx(body, [body, parts_obj]):
        bpy.ops.object.join()
    me = body.data
    remap = [_slot(m.name if m else "") for m in me.materials]
    _set_mats(me, [remap[p.material_index] for p in me.polygons])


def bake_ao(obj, keep_modes=("glow",), **kw):
    """remaster_lib.bake_ao, leaving faces of keep_modes (glow by default) unshaded."""
    me = obj.data
    skip = {MODES[m] for m in keep_modes}
    attr = me.color_attributes["Col"]
    saved = {li: tuple(attr.data[li].color) for p in me.polygons if p.material_index in skip for li in p.loop_indices}
    L.bake_ao(obj, **kw)
    for li, c in saved.items():
        attr.data[li].color = c


def export(arm, body, path, clips):
    L.export(arm, body, path, clips)
    data = open(path, "rb").read()
    jlen, _t = struct.unpack_from("<I4s", data, 12)
    doc = json.loads(data[20:20 + jlen])
    rest = data[20 + jlen:]
    for m in doc.get("materials", []):
        if m.get("name") == KEEP_DETAIL:
            m["alphaMode"] = "MASK"
            m["alphaCutoff"] = 0.5
        if m.get("name") == GLOW:
            m.setdefault("extensions", {})["KHR_materials_unlit"] = {}
            used = doc.setdefault("extensionsUsed", [])
            if "KHR_materials_unlit" not in used:
                used.append("KHR_materials_unlit")
    blob = json.dumps(doc, separators=(",", ":")).encode()
    blob += b" " * ((4 - len(blob) % 4) % 4)
    out = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(blob) + len(rest))
    out += struct.pack("<I4s", len(blob), b"JSON") + blob + rest
    open(path, "wb").write(out)


# ---------------------------------------------------------------- shaping

def scale_region(obj, pred, center, factors, falloff=None):
    """Scales vertices where pred(co) about center by factors (x, y, z); falloff(co) -> 0..1
    blends the move (soft selection)."""
    for v in obj.data.vertices:
        if pred(v.co):
            t = falloff(v.co) if falloff else 1.0
            d = v.co - center
            target = center + Vector((d.x * factors[0], d.y * factors[1], d.z * factors[2]))
            v.co = L.mix(v.co, target, t)


def move_region(obj, pred, offset_fn):
    for v in obj.data.vertices:
        if pred(v.co):
            v.co = v.co + offset_fn(v.co)


# ---------------------------------------------------------------- faces

def fierce_eye(parts, center, radius, gaze, iris_top, iris_bottom, weights, lid, slant=0.35, side=1.0,
               slit=True, pupil_w=0.12, iris=0.62, glow=False, sclera=None, lid_drop=1.45, up=Vector((0, 0, 1)),
               lid_size=1.0):
    """A narrow, determined eye: (optional) sclera, big iris, a slit or round pupil, one
    small glint, and a heavy slanted upper lid in the creature's own colour cutting across
    it. side: +1 for the creature's left eye (lid inner corner points down to the nose).
    glow: iris drawn on the unlit material (embers / magic)."""
    sclera = sclera if sclera is not None else L.srgb("f4efe0")
    with parts.use("keep"):
        parts.ellipsoid(center, (radius, radius, radius), color=None, weights=weights, seg=16, rings=10,
                        color_fn=lambda u: L.mix(sclera, L.mix(sclera, L.srgb("8a7a6a"), 0.5),
                                                 L.smooth(0.2, -0.9, u.z) * 0.6))

    def iris_col(x, y):
        return L.mix(iris_bottom, iris_top, L.smooth(-0.9, 0.8, y))

    with parts.use("glow" if glow else "keep"):
        parts.sphere_cap(center, radius, gaze, (iris * 0.95, iris * 0.95), None, weights, lift=0.012, up=up,
                         color_fn=iris_col, seg=20, rings=3)
    with parts.use("keep"):
        dark = L.srgb("120808")
        if slit:
            parts.sphere_cap(center, radius, gaze, (pupil_w, iris * 0.85), dark, weights, lift=0.024, up=up,
                             seg=14, rings=1)
        else:
            parts.sphere_cap(center, radius, gaze, (iris * 0.4, iris * 0.4), dark, weights, lift=0.024, up=up,
                             seg=14, rings=1)
        parts.sphere_cap(center, radius, gaze, (iris * 0.16, iris * 0.16), WHITE, weights, lift=0.036, up=up,
                         offset=(-iris * 0.35 * side, iris * 0.35), seg=10, rings=1)
    # Slanted lid: a cap whose centre leans towards the nose, so its edge runs diagonally
    # down to the inner corner (a glare), over a darker rim that reads as the lash line.
    inner = Vector((-side, 0.0, 0.0))
    lean = (up + inner * slant * 2.6).normalized()
    lid_axis = (gaze + lean * lid_drop).normalized()
    rim = L.mix(lid, L.srgb("1a1010"), 0.75)
    parts.sphere_cap(center, radius * 1.05, lid_axis, (1.34 * lid_size, 1.04 * lid_size), rim, weights, lift=0.0, up=up, seg=22,
                     rings=3, detail=True, offset=(0.0, -0.12))
    parts.sphere_cap(center, radius * 1.075, lid_axis, (1.25 * lid_size, 0.95 * lid_size), lid, weights, lift=0.0, up=up, seg=22,
                     rings=4, detail=True, offset=(0.0, -0.12))


def fang(parts, base, direction, length, width, weights, color=None, up=None):
    color = color or L.srgb("fffaf0")
    with parts.use("keep"):
        parts.blob(base, (width, width * 0.7), direction, length, None, weights=weights, seg=8, rings=5, tip=0.08,
                   color_fn=lambda a: L.mix(L.srgb("e8dcc0"), color, L.smooth(0.0, 0.6, a)), up=up)


def horn(parts, base, direction, length, radius, weights, c0, c1, bend=None, mode="skin", seg=10, up=None):
    with parts.use(mode):
        parts.blob(base, radius, direction, length, None, weights=weights, seg=seg, rings=8, tip=0.12, bend=bend,
                   color_fn=lambda a: L.mix(c0, c1, L.smooth(0.0, 1.0, a)), up=up)


def zigzag(parts, point, normal, size, color, up=Vector((0, 0, 1)), mode="glow", turn=0.0):
    """A painted lightning bolt decal (star-shaped polygon about its centre)."""
    pts = [(-0.18, 0.5), (0.22, 0.5), (0.04, 0.12), (0.26, 0.12), (-0.16, -0.55), (-0.02, -0.06), (-0.22, -0.06)]
    c, s = math.cos(turn), math.sin(turn)
    pts = [((x * c - y * s) * size, (x * s + y * c) * size) for x, y in pts]
    with parts.use(mode):
        # Not star-shaped about 0 for decal rings: draw it as two quads-ish strokes instead.
        parts.stroke(point, normal, [pts[0], pts[2], pts[4]], size * 0.26, color, up=up, taper=True, lift=0.018)
        parts.stroke(point, normal, [pts[1], pts[3], pts[4]], size * 0.18, color, up=up, taper=True, lift=0.02)


def thicken(obj, arm, bones, factor, along=None):
    """Pushes the vertices driven mostly by `bones` away from (factor > 1) or towards their
    bone's axis: chunkier limbs on a lanky rig. along(t 0 head..1 tail) -> extra factor."""
    groups = L.dominant_groups(obj)
    for v in obj.data.vertices:
        b = groups[v.index]
        if b not in bones:
            continue
        bone = arm.data.bones[b]
        h, t = bone.head_local, bone.tail_local
        axis = t - h
        k = max(0.0, min(1.0, (v.co - h).dot(axis) / max(axis.length_squared, 1e-8)))
        foot = h + axis * k
        f = factor * (along(k) if along else 1.0)
        v.co = foot + (v.co - foot) * f


def cape(parts, center, z_top, z_bot, r_top, r_bot, arc, color_fn, weights, rows=8, cols=14, flare=0.0,
         thick=0.03):
    """A curved two-sided sheet hanging behind a creature (cape, mantle, leaf skirt): a part
    of a cone around the vertical through center, spanning `arc` radians centred on +Y
    (the back). color_fn(u across -1..1, v top 0..1, outside) -> colour."""
    cos, faces, cols_ = [], [], []
    for side in (1, 0):
        base = len(cos)
        for r in range(rows + 1):
            v = r / rows
            z = z_top + (z_bot - z_top) * v
            rad = r_top + (r_bot - r_top) * v + (thick if side else 0.0)
            for c in range(cols + 1):
                u = c / cols * 2.0 - 1.0
                a = math.pi * 0.5 + u * arc * 0.5 * (1.0 + flare * v)
                cos.append(Vector((center.x + math.cos(a) * rad, center.y + math.sin(a) * rad, z)))
                cols_.append(color_fn(u, v, bool(side)))
        for r in range(rows):
            for c in range(cols):
                a_ = base + r * (cols + 1) + c
                quad = (a_, a_ + 1, a_ + cols + 2, a_ + cols + 1)
                faces.append(tuple(reversed(quad)) if side else quad)
    return parts._add(cos, faces, lambda i: cols_[i], weights, False)


def island_info(obj):
    """[(vertex_set, centre, size, mean texture colour)] of the body's loose pieces."""
    tex = tex_lookup(obj)
    me = obj.data
    vcol = {}
    for li, l in enumerate(me.loops):
        vcol.setdefault(l.vertex_index, tex[li] if tex else Vector((1, 1, 1)))
    out = []
    for vs, _mat in L.islands(obj):
        c = sum((me.vertices[i].co for i in vs), Vector()) / len(vs)
        lo, hi = L.bounds(obj, vs)
        col = sum((vcol[i] for i in vs), Vector()) / len(vs)
        out.append((vs, c, hi - lo, col))
    return out


def delete_islands(obj, pred):
    """Deletes loose pieces where pred(centre, size, colour, n_verts) (texture-atlas eyes)."""
    kill = set()
    for vs, c, size, col in island_info(obj):
        if pred(c, size, col, len(vs)):
            kill |= vs
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in kill], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    return len(kill)


def is_grey(col, ref, tol=0.06):
    return (col - ref).length < tol


ATLAS_LID = L.srgb("8d909e")
ATLAS_PUPIL = L.srgb("232426")


def atlas_eye(c, size, col, n):
    """The Quaternius atlas eyeball (grey lid ball) and its pupil bar."""
    return is_grey(col, ATLAS_LID) or is_grey(col, ATLAS_PUPIL, 0.03)


def mat_islands(obj, mat_name):
    """[(centre, radius)] of loose pieces of one material (where the source's eyes sat)."""
    out = []
    me = obj.data
    for vs, mat in L.islands(obj):
        if mat != mat_name:
            continue
        lo, hi = L.bounds(obj, vs)
        out.append(((lo + hi) * 0.5, max(hi - lo) * 0.5))
    return out
