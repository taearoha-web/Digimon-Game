"""Helpers for the flying-monster remasters (recipes_flyers.py), on top of remaster_lib.

Adds what the eerie / fierce flyers need and the pilot kit lacks:
  * atlas_regions(): the Quaternius "Atlas" rigs colour faces through a 32 px palette
    texture; this gives every face a material named after its palette colour
    ("c_1e1f22") so a paint function can tell eyes, horns, cloth... apart.
  * Glow materials: emissive surfaces (eyes, runes, embers, magic). The game's
    monster tint multiplies albedo only, so emission keeps its colour under every tint
    (the fix for "tint colours the eye whites"). Exported alphaMode MASK so they draw
    without the ink outline.
  * FParts: Parts that can put geometry on a Glow material (detail="glow" / "glow2"),
    plus a few shapes: membrane (wing skin between points), horn, fang.
"""
import json
import math
import struct

import bpy
import bmesh
from mathutils import Vector

import remaster_lib as L

GLOW = "Glow"
GLOW2 = "Glow2"


# ---------------------------------------------------------------- atlas regions

def atlas_regions(body):
    """Replaces a textured 'Atlas' material by one material per palette colour."""
    me = body.data
    if not me.uv_layers:
        return {}
    uv = me.uv_layers.active.data
    imgs = {}
    for i, m in enumerate(me.materials):
        img = None
        if m and m.use_nodes:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image:
                    img = n.image
        imgs[i] = img
    cache = {}
    names = []
    face_name = []
    for poly in me.polygons:
        img = imgs.get(poly.material_index)
        if img is None:
            face_name.append(me.materials[poly.material_index].name)
            continue
        if img.name not in cache:
            w, h = img.size
            px = list(img.pixels)
            cache[img.name] = (w, h, px)
        w, h, px = cache[img.name]
        u = sum(uv[li].uv.x for li in poly.loop_indices) / poly.loop_total
        v = sum(uv[li].uv.y for li in poly.loop_indices) / poly.loop_total
        x = min(w - 1, max(0, int((u % 1.0) * w)))
        y = min(h - 1, max(0, int((v % 1.0) * h)))
        k = (y * w + x) * 4
        rgb = px[k:k + 3]
        # Blender stores sRGB images' pixels as sRGB floats.
        hx = "c_%02x%02x%02x" % tuple(int(round(c * 255)) for c in rgb)
        face_name.append(hx)
    counts = {}
    for n in face_name:
        counts[n] = counts.get(n, 0) + 1
        if n not in names:
            names.append(n)
    me.materials.clear()
    for n in names:
        m = bpy.data.materials.get(n) or bpy.data.materials.new(n)
        me.materials.append(m)
    for poly, n in zip(me.polygons, face_name):
        poly.material_index = names.index(n)
    return counts


# ---------------------------------------------------------------- painting

def paint_body_glow(obj, paint, glow=None):
    """Like remaster_lib.paint_body but glow(name, co, bone) -> 0 / 1 / 2 picks Skin-or-
    Detail / Glow / Glow2 per face (centre co, dominant bone of its first vertex)."""
    me = obj.data
    names = [m.name if m else "" for m in me.materials]
    groups = L.dominant_groups(obj)
    pick = []
    for poly in me.polygons:
        g = glow(names[poly.material_index], poly.center, groups[poly.vertices[0]]) if glow else 0
        pick.append(g)
    L.paint_body(obj, paint)
    _ensure_mats(obj)
    for poly, g in zip(me.polygons, pick):
        if g == 1:
            poly.material_index = 2
        elif g == 2:
            poly.material_index = 3


def _ensure_mats(obj):
    me = obj.data
    while len(me.materials) < 4:
        me.materials.append(L.material([L.SKIN, L.DETAIL, GLOW, GLOW2][len(me.materials)]))


# ---------------------------------------------------------------- parts

class FParts(L.Parts):
    """Parts with Glow materials: pass detail="glow" or "glow2"."""

    def __init__(self, surface):
        super().__init__(surface)
        self.mats = [L.SKIN, L.DETAIL, GLOW, GLOW2]

    def _add(self, cos, faces, color, weights, detail):
        verts = [self.bm.verts.new(c) for c in cos]
        idx = 2 if detail == "glow" else 3 if detail == "glow2" else 1 if detail else 0
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

    def membrane(self, rows, color_fn, weights, detail=False, thick=0.02, normal_hint=None):
        """A thin two-sided skin over a grid of points rows[r][c] (wing membrane, cloth).
        color_fn(r_t, c_t) -> colour. Built as a closed slab so the outline works."""
        nr, nc = len(rows), len(rows[0])
        cos, uv = [], []
        # Per-point normal from the grid.
        norms = []
        for r in range(nr):
            for c in range(nc):
                a = rows[min(r + 1, nr - 1)][c] - rows[max(r - 1, 0)][c]
                b = rows[r][min(c + 1, nc - 1)] - rows[r][max(c - 1, 0)]
                n = a.cross(b)
                if normal_hint is not None and n.dot(normal_hint) < 0:
                    n = -n
                norms.append(n.normalized() if n.length > 1e-9 else Vector((0, 0, 1)))
        for side in (1.0, -1.0):
            for r in range(nr):
                for c in range(nc):
                    cos.append(rows[r][c] + norms[r * nc + c] * thick * 0.5 * side)
                    uv.append((r / (nr - 1), c / (nc - 1)))
        faces = []
        off = nr * nc
        for r in range(nr - 1):
            for c in range(nc - 1):
                a, b, cc, d = r * nc + c, r * nc + c + 1, (r + 1) * nc + c + 1, (r + 1) * nc + c
                faces.append((a, b, cc, d))
                faces.append((off + d, off + cc, off + b, off + a))
        # rims
        def ring(idx):
            for i in range(len(idx) - 1):
                p, q = idx[i], idx[i + 1]
                faces.append((p, off + p, off + q, q))
        ring([c for c in range(nc)][::-1])
        ring([(nr - 1) * nc + c for c in range(nc)])
        ring([r * nc for r in range(nr)])
        ring([r * nc + nc - 1 for r in range(nr)][::-1])
        return self._add(cos, faces, lambda i: color_fn(*uv[i]), weights, detail)

    def horn(self, base, direction, length, radius, color_fn, weights, curl=None, seg=10, rings=8,
             detail=False, tip=0.04):
        """A tapering curved horn / spike / fang: blob with a bend."""
        return self.blob(base, radius, direction, length, None, weights=weights, detail=detail, seg=seg,
                         rings=rings, tip=tip, color_fn=color_fn, bend=curl)


def join_parts(body, parts_obj):
    """remaster_lib.join_parts, keeping Glow / Glow2 apart."""
    with L._ctx(body, [body, parts_obj]):
        bpy.ops.object.join()
    me = body.data
    order = [L.SKIN, L.DETAIL, GLOW, GLOW2]

    def slot(m):
        n = m.name if m else L.SKIN
        for i in (3, 2, 1, 0):
            if n.startswith(order[i]):
                return i
        return 0

    remap = [slot(m) for m in me.materials]
    idx = [remap[p.material_index] for p in me.polygons]
    me.materials.clear()
    for n in order:
        me.materials.append(L.material(n))
    for poly, i in zip(me.polygons, idx):
        poly.material_index = i


# ---------------------------------------------------------------- export

def export(arm, body, path, clips, glow=(1.0, 0.8, 0.3), glow2=None, strength=1.6, strength2=1.6):
    """remaster_lib.export, then Glow materials get their emission (sRGB colour tuples)."""
    # Drop unused material slots so the GLB has no empty surfaces.
    me = body.data
    used = sorted({p.material_index for p in me.polygons})
    keep = [me.materials[i] for i in used]
    remap = {i: k for k, i in enumerate(used)}
    idx = [remap[p.material_index] for p in me.polygons]
    me.materials.clear()
    for m in keep:
        me.materials.append(m)
    for p, i in zip(me.polygons, idx):
        p.material_index = i
    L.export(arm, body, path, clips)
    data = open(path, "rb").read()
    jlen, _t = struct.unpack_from("<I4s", data, 12)
    doc = json.loads(data[20:20 + jlen])
    rest = data[20 + jlen:]
    for m in doc.get("materials", []):
        spec = {GLOW: (glow, strength), GLOW2: (glow2 or glow, strength2)}.get(m.get("name"))
        if spec is None:
            continue
        col, s = spec
        lin = list(L.srgb(col)) if isinstance(col, str) else list(col)
        m["emissiveFactor"] = [min(1.0, c) for c in lin]
        if s != 1.0:
            m.setdefault("extensions", {})["KHR_materials_emissive_strength"] = {"emissiveStrength": s}
            used_ext = doc.setdefault("extensionsUsed", [])
            if "KHR_materials_emissive_strength" not in used_ext:
                used_ext.append("KHR_materials_emissive_strength")
        m["alphaMode"] = "MASK"
        m["alphaCutoff"] = 0.5
    blob = json.dumps(doc, separators=(",", ":")).encode()
    blob += b" " * ((4 - len(blob) % 4) % 4)
    out = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(blob) + len(rest))
    out += struct.pack("<I4s", len(blob), b"JSON") + blob + rest
    open(path, "wb").write(out)


# ---------------------------------------------------------------- probes

def describe(arm, body):
    """Prints regions (material -> faces, bounds, bones) to design a recipe from."""
    me = body.data
    groups = L.dominant_groups(body)
    names = [m.name if m else "" for m in me.materials]
    info = {}
    for p in me.polygons:
        n = names[p.material_index]
        d = info.setdefault(n, {"n": 0, "lo": Vector((9, 9, 9)), "hi": Vector((-9, -9, -9)), "bones": {}})
        d["n"] += 1
        c = p.center
        d["lo"] = Vector(map(min, d["lo"], c))
        d["hi"] = Vector(map(max, d["hi"], c))
        b = groups[p.vertices[0]]
        d["bones"][b] = d["bones"].get(b, 0) + 1
    lo, hi = L.bounds(body)
    print("BOUNDS", tuple(round(x, 2) for x in lo), tuple(round(x, 2) for x in hi), "tris", L.tri_count(body))
    for n, d in sorted(info.items(), key=lambda kv: -kv[1]["n"]):
        bones = sorted(d["bones"].items(), key=lambda kv: -kv[1])[:6]
        print("  %-20s %4d  lo %s hi %s  %s" % (n, d["n"], tuple(round(x, 2) for x in d["lo"]),
                                               tuple(round(x, 2) for x in d["hi"]), bones))
    for b in arm.data.bones:
        print("  bone %-12s head %s tail %s" % (b.name, tuple(round(x, 2) for x in b.head_local),
                                                tuple(round(x, 2) for x in b.tail_local)))


# ---------------------------------------------------------------- shared look kit

C = L.srgb
WHITE = C("ffffff")


def eye_balls(body, mat_names):
    """[(centre, radius)] of each eyeball island of the given materials (rest pose),
    sorted by x."""
    out = []
    for verts, name in L.islands(body):
        if name not in mat_names or len(verts) < 12:
            continue
        cos = [body.data.vertices[i].co for i in verts]
        c = sum(cos, Vector()) / len(cos)
        r = sum((v - c).length for v in cos) / len(cos)
        out.append((c, r))
    return sorted(out, key=lambda e: e[0].x)


def rot_about(v, axis, ang):
    from mathutils import Matrix
    return Matrix.Rotation(ang, 3, axis.normalized()) @ v


def fierce_eye(parts, center, radius, gaze, weights, lid_col, lid_dark=None, glow="glow", ball=None,
               slit=(0.1, 0.5), tilt=0.45, open_=0.32, pupil=C("12060a"), brow=None, brow_size=1.0,
               up=Vector((0, 0, 1)), lower_lid=0.0, ring=None):
    """A menacing eye: emissive ball (untinted glow), slit pupil, a heavy upper lid
    slanting down to the nose (tilt, radians) leaving `open_` rad above the centre, an
    optional brow ridge, optional lower lid. ball: vertex colour of the ball (dimmer
    than the glow)."""
    gaze = gaze.normalized()
    inward = Vector((-1.0 if center.x > 0 else 1.0, 0, 0))
    inward = (inward - gaze * inward.dot(gaze)).normalized()
    upv = (up - gaze * up.dot(gaze)).normalized()
    ball_col = ball or C("ffd890")
    parts.ellipsoid(center, (radius, radius, radius), color=None, weights=weights, detail=glow, seg=16, rings=10,
                    color_fn=lambda u: L.mix(ball_col, ball_col * 0.55, L.smooth(0.3, -0.9, u.z)))
    if ring is not None:
        parts.sphere_cap(center, radius, gaze, (0.62, 0.62), ring, weights, lift=0.01, seg=20, rings=2,
                         color_fn=lambda x, y: L.mix(ring, ball_col, L.smooth(0.55, 1.0, math.hypot(x, y))),
                         detail=glow)
    if slit:
        parts.sphere_cap(center, radius, gaze, slit, pupil, weights, lift=0.03, up=up, seg=14, rings=2)
    # Upper lid: a cap whose axis is "up" tilted towards the nose; it covers all but open_.
    ax = (upv * math.cos(tilt) + inward * math.sin(tilt)).normalized()
    half = math.pi * 0.5 - open_
    dark = lid_dark or lid_col * 0.55
    parts.sphere_cap(center, radius * 1.07, ax, (half, half), None, weights, lift=0.0, up=gaze, seg=24, rings=6,
                     detail=False, color_fn=lambda x, y: L.mix(lid_col, dark, L.smooth(0.6, 1.0, math.hypot(x, y))))
    if lower_lid:
        lax = (-upv * math.cos(tilt * 0.3) + inward * math.sin(tilt * 0.3)).normalized()
        lh = math.pi * 0.5 - lower_lid
        parts.sphere_cap(center, radius * 1.06, lax, (lh, lh), lid_col, weights, lift=0.0, up=gaze, seg=20,
                         rings=4, detail=False)
    if brow is not None:
        # A ridge along the lid's top edge: from above the outer corner down to the inner.
        outer = -inward
        a = center + (upv * 0.95 + outer * 0.75 + gaze * 0.35).normalized() * radius * 1.12
        b = center + (upv * 0.35 - outer * 1.0 + gaze * 0.45).normalized() * radius * 1.15
        parts.blob(a, (radius * 0.32 * brow_size, radius * 0.22 * brow_size), b - a, (b - a).length * 1.25, None,
                   weights=weights, seg=10, rings=7, tip=0.55, up=gaze,
                   color_fn=lambda t: L.mix(brow, brow * 0.7, t))


def scales(co, size, n=None):
    """0..1 groove factor of a Voronoi scale pattern (1 on the seams)."""
    from mathutils import noise
    p = co / size
    d, _pts = noise.voronoi(p, distance_metric="DISTANCE")
    edge = d[1] - d[0]
    return 1.0 - L.smooth(0.0, 0.28, edge)


def fbm(co, size, octaves=3):
    from mathutils import noise
    return noise.fractal(co / size, 0.5, 2.0, octaves, noise_basis="PERLIN_ORIGINAL")


def cells(co, size):
    """(distance to nearest cell point, second) for cracks / plates."""
    from mathutils import noise
    d, _pts = noise.voronoi(co / size, distance_metric="DISTANCE")
    return d[0], d[1]


def fang(parts, base, direction, length, width, weights, col_root=C("e8dcc0"), col_tip=WHITE, up=None):
    parts.blob(base, (width, width * 0.7), direction, length, None, weights=weights, seg=8, rings=5, tip=0.05,
               color_fn=lambda t: L.mix(col_root, col_tip, t), up=up)


def ridge(parts, surf, center, dirs, length, width, color_fn, weights=None, out=0.0, tilt=Vector((0, 0, 0)),
          detail=False, seg=8, rings=5):
    """Spikes / plates along rays from center along each dir, pointing out of the
    surface (bent by tilt). dirs: [(direction, scale)]."""
    made = []
    for d, s in dirs:
        p, n = surf.toward(center + d.normalized() * 8.0, center)
        if p is None:
            continue
        axis = (n + tilt).normalized()
        parts.blob(p - n * (0.04 * s + out), (width * s, width * s * 0.45), axis, length * s, None,
                   weights=weights if weights is not None else p, seg=seg, rings=rings, tip=0.05,
                   color_fn=color_fn, detail=detail, up=Vector((1, 0, 0)))
        made.append((p, n))
    return made


def hollow_eye(parts, center, radius, gaze, weights, socket=C("12061c"), lid_col=None, tilt=0.5, open_=0.35,
               pupil=0.34, glow="glow", ball=C("e8f8ff"), up=Vector((0, 0, 1)), sink=0.35, pupil_y=0.0):
    """An empty dark socket with a burning pinpoint: no white, no iris."""
    gaze = gaze.normalized()
    c = center - gaze * radius * sink
    parts.ellipsoid(c, (radius, radius, radius * 1.1), color=None, weights=weights, seg=14, rings=9,
                    color_fn=lambda u: L.mix(socket, socket * 0.4, L.smooth(0.0, 1.0, -u.y)))
    p = c + gaze * radius * 0.78 + up * radius * pupil_y
    parts.ellipsoid(p, (radius * pupil * 0.8, radius * pupil * 0.6, radius * pupil * 1.05), color=None,
                    weights=weights, detail=glow, seg=10, rings=6,
                    color_fn=lambda u: L.mix(ball, ball * 0.6, L.smooth(0.2, -0.8, u.z)))
    if lid_col is not None:
        inward = Vector((-1.0 if center.x > 0 else 1.0, 0, 0))
        inward = (inward - gaze * inward.dot(gaze)).normalized()
        upv = (up - gaze * up.dot(gaze)).normalized()
        ax = (upv * math.cos(tilt) + inward * math.sin(tilt)).normalized()
        half = math.pi * 0.5 - open_
        parts.sphere_cap(c, radius * 1.06, ax, (half, half), lid_col, weights, lift=0.0, up=gaze, seg=22, rings=5,
                         detail=False)
