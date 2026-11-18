"""Helpers for team dawncrystal's recipes (recipes_dawncrystal.py): loading the FBX rigs,
faceted crystals, petals / leaves, vine tubes, a coiled hermit shell, head enlarging for
the realistic animal rigs. Built on kit_critters' material set (Skin, Detail, Keep,
KeepDetail, KeepGlow), so the output loads like every other remaster.
"""
import math
import os
import random

import bpy  # noqa: F401
import bmesh
from mathutils import Matrix, Vector

import remaster_lib as L
import kit_critters as K

C = L.srgb
V = Vector
WHITE = C("ffffff")


def D(hex_or_tuple, gamma=0.55):
    """A colour as it should show in game for muted tones (see recipes_critters.D)."""
    c = L.srgb(hex_or_tuple)
    return V((c.x ** gamma, c.y ** gamma, c.z ** gamma))


# ---------------------------------------------------------------- loading

def load(path):
    """(armature, body) for .gltf / .glb / .fbx. FBX rigs (dawn/Bat, dawn/Slime): only the
    main armature and its meshes are kept, mesh transforms are baked so mesh space equals
    armature space, and the clips are renamed to their short names ("Bat_Attack" from
    "BatArmature|BatArmature|Bat_Attack" -> "Attack") so MonsterVisual's aliases find them
    whatever the variant file is called."""
    if not path.endswith(".fbx"):
        return L.load(path)
    bpy.ops.import_scene.fbx(filepath=path)
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    arm = max(arms, key=lambda a: len(a.data.bones))
    base = os.path.splitext(os.path.basename(path))[0]
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm]
    for o in list(bpy.data.objects):
        if o != arm and o not in meshes:
            bpy.data.objects.remove(o)
    for o in meshes:
        o.data.transform(arm.matrix_world.inverted() @ o.matrix_world)
        o.matrix_parent_inverse = Matrix.Identity(4)
        o.matrix_basis = Matrix.Identity(4)
        o.parent = arm
    body = meshes[0]
    if len(meshes) > 1:
        with L._ctx(body, meshes):
            bpy.ops.object.join()
    body.name = "Model"
    for act in list(bpy.data.actions):
        short = act.name.split("|")[-1]
        if short.startswith(base + "_"):
            short = short[len(base) + 1:]
        act.name = short
    return arm, body


# ---------------------------------------------------------------- parts

class DParts(K.KParts):
    """KParts with a flat-shading switch (crystal facets): with parts.faceted(): ..."""

    def __init__(self, surface):
        super().__init__(surface)
        self.flat = False

    class _Flat:
        def __init__(self, parts):
            self.parts = parts

        def __enter__(self):
            self.prev = self.parts.flat
            self.parts.flat = True

        def __exit__(self, *a):
            self.parts.flat = self.prev

    def faceted(self):
        return DParts._Flat(self)

    def _add(self, cos, faces, color, weights, detail):
        verts = super()._add(cos, faces, color, weights, detail)
        if self.flat:
            for v in verts:
                for f in v.link_faces:
                    f.smooth = False
        return verts


def start(body):
    surf = L.Surface(body)
    return surf, DParts(surf)


def finish(body, parts, **ao):
    K.join_parts(body, parts.to_object())
    K.bake_ao(body, **ao)


# ---------------------------------------------------------------- sampling

def hit(surf, center, direction):
    """Where a ray from far out along direction, aimed back at center, meets the body."""
    d = direction.normalized()
    return surf.toward(center + d * 8.0, center)


def hash01(v, seed=0):
    x = math.sin(v.x * 127.1 + v.y * 311.7 + v.z * 74.7 + seed * 19.3) * 43758.5453
    return x - math.floor(x)


def noise(v, scale=1.0, seed=0):
    p = v * scale
    i = V((math.floor(p.x), math.floor(p.y), math.floor(p.z)))
    f = p - i
    u = V([t * t * (3.0 - 2.0 * t) for t in f])

    def h(dx, dy, dz):
        return hash01(V((i.x + dx, i.y + dy, i.z + dz)), seed)

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


# ---------------------------------------------------------------- shaping

def grow(obj, center, r_in, r_out, factor, squash=(1.0, 1.0, 1.0), pred=None):
    """Scales the vertices around center by factor (fully inside r_in, fading out to r_out):
    a cartoon head on a realistic animal. squash multiplies the factor per axis."""
    for v in obj.data.vertices:
        if pred and not pred(v.co):
            continue
        d = (v.co - center).length
        t = L.smooth(r_out, r_in, d)
        if t <= 0.0:
            continue
        f = V([1.0 + (factor * s - 1.0) * t for s in squash])
        off = v.co - center
        v.co = center + V((off.x * f.x, off.y * f.y, off.z * f.z))


def displace(obj, amount, fn):
    for v in obj.data.vertices:
        v.co += v.normal * amount * fn(v.co, v.normal)


def delete_mat_islands(obj, pred):
    """Deletes loose pieces where pred(material, centre, size, n_verts)."""
    kill = set()
    for vs, mat in L.islands(obj):
        lo, hi = L.bounds(obj, vs)
        if pred(mat, (lo + hi) * 0.5, hi - lo, len(vs)):
            kill |= vs
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in kill], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


# ---------------------------------------------------------------- pieces

def crystal(parts, base, direction, length, radius, weights, root, tip, sides=6, shoulder=0.72, mode="keep",
            twist=0.0, up=None):
    """A faceted gem prism: a ring at the base, a ring at `shoulder` of the length, a point."""
    d = direction.normalized()
    t_, b_, _n = L.frame(d, up or (V((0, 0, 1)) if abs(d.z) < 0.9 else V((0, -1, 0))))
    cos, cols = [], []
    for k, (h, r) in enumerate(((-0.08, radius * 0.85), (shoulder, radius))):
        for s in range(sides):
            a = twist + 2.0 * math.pi * s / sides
            cos.append(base + d * (h * length) + (t_ * math.cos(a) + b_ * math.sin(a)) * r)
            cols.append(L.mix(root, tip, max(0.0, h)) if s % 2 == 0 else L.mix(root, tip, max(0.0, h) * 0.8))
    cos.append(base + d * length)
    cols.append(tip)
    faces = []
    for s in range(sides):
        a, b = s, (s + 1) % sides
        faces.append((a, b, b + sides, a + sides))
        faces.append((a + sides, b + sides, 2 * sides))
    with parts.use(mode), parts.faceted():
        return parts._add(cos, faces, lambda i: cols[i], weights, False)


def cluster(parts, base, normal, size, weights, root, tip, count=5, seed=1, spread=0.55, mode="keep", sides=6):
    """A crystal druse: a tall middle gem and smaller ones leaning out around it."""
    rng = random.Random(seed)
    n = normal.normalized()
    t_, b_, _ = L.frame(n)
    crystal(parts, base - n * size * 0.1, n, size, size * 0.2, weights, root, tip, sides=sides, mode=mode,
            twist=rng.uniform(0, 1))
    for i in range(count - 1):
        a = 2.0 * math.pi * (i + rng.uniform(-0.2, 0.2)) / (count - 1)
        side = t_ * math.cos(a) + b_ * math.sin(a)
        d = (n + side * spread * rng.uniform(0.7, 1.3)).normalized()
        ln = size * rng.uniform(0.45, 0.75)
        crystal(parts, base + side * size * 0.16 - n * size * 0.08, d, ln, ln * 0.24, weights, root, tip,
                sides=sides, mode=mode, twist=rng.uniform(0, 1))


def petal(parts, base, direction, length, width, color_fn, weights, up, tip=0.55, cup=0.0, seg=10, rings=6):
    """A soft flat petal / leaf: width across, a quarter of that thick; cup bends the tip."""
    return parts.blob(base, (width, width * 0.22), direction, length, None, weights=weights, seg=seg, rings=rings,
                      tip=tip, up=up, color_fn=color_fn, bend=(up * cup) if cup else None)


def leaf(parts, base, direction, length, width, c0, c1, weights, up, cup=0.08):
    return petal(parts, base, direction, length, width, lambda t: L.mix(c0, c1, L.smooth(0.0, 0.9, t)), weights,
                 up, tip=0.06, cup=length * cup, seg=8, rings=6)


def blossom(parts, center, normal, size, petal_in, petal_out, middle, weights, petals=5, turn=0.0, lift=0.25):
    t_, b_, n_ = L.frame(normal)
    for i in range(petals):
        a = turn + 2.0 * math.pi * i / petals
        d = (t_ * math.cos(a) + b_ * math.sin(a) + n_ * lift).normalized()
        petal(parts, center, d, size, size * 0.5, lambda t: L.mix(petal_in, petal_out, L.smooth(0.0, 0.85, t)),
              weights, n_, tip=0.75, cup=size * 0.12)
    parts.ellipsoid(center + n_ * size * 0.1, (size * 0.28, size * 0.28, size * 0.18), basis(n_), color=None,
                    weights=weights, seg=10, rings=6,
                    color_fn=lambda u: L.mix(L.mix(middle, C("c8601a"), 0.45), middle, L.smooth(-0.2, 0.8, u.z)))


def basis(z, up=V((0, 0, 1))):
    t_, b_, n_ = L.frame(z, up)
    return Matrix((t_, b_, n_)).transposed()


def tube(parts, points, radius, color_fn, weights, seg=8, taper=None, cap=True):
    """A tube along a polyline (vines, roots, branches). radius(t) or a number; color_fn(t)."""
    n = len(points)
    cos, cols = [], []
    prev_t = None
    for i, p in enumerate(points):
        a = points[max(i - 1, 0)]
        b = points[min(i + 1, n - 1)]
        d = (b - a).normalized()
        if prev_t is None:
            t_, b_, _ = L.frame(d)
        else:
            b_ = d.cross(prev_t).normalized()
            t_ = b_.cross(d).normalized()
        prev_t = t_
        u = i / (n - 1)
        r = radius(u) if callable(radius) else radius * (1.0 - (taper or 0.0) * u)
        for s in range(seg):
            ang = 2.0 * math.pi * s / seg
            cos.append(p + (t_ * math.cos(ang) + b_ * math.sin(ang)) * r)
            cols.append(color_fn(u))
    faces = []
    for i in range(n - 1):
        for s in range(seg):
            a0, a1 = i * seg + s, i * seg + (s + 1) % seg
            faces.append((a0, a1, a1 + seg, a0 + seg))
    if cap:
        cos.append(points[0])
        cols.append(color_fn(0.0))
        cos.append(points[-1] + (points[-1] - points[-2]).normalized() * 0.001)
        cols.append(color_fn(1.0))
        s0, s1 = len(cos) - 2, len(cos) - 1
        last = (n - 1) * seg
        for s in range(seg):
            faces.append((s0, (s + 1) % seg, s))
            faces.append((s1, last + s, last + (s + 1) % seg))
    return parts._add(cos, faces, lambda i: cols[i], weights, False)


def thorn(parts, base, direction, length, radius, weights, c0, c1, bend=None):
    return parts.blob(base, radius, direction, length, None, weights=weights, seg=6, rings=4, tip=0.02, bend=bend,
                      color_fn=lambda t: L.mix(c0, c1, L.smooth(0.2, 1.0, t)))


def spiral_shell(parts, origin, axis, forward, radius, turns, color_fn, weights, steps=9, shrink=0.74,
                 rise=0.62):
    """A hermit crab's coiled shell: whorls (ellipsoids) shrinking along a rising spiral
    around axis, the widest at origin (the shell's mouth faces -forward)."""
    ax = axis.normalized()
    fw = (forward - ax * forward.dot(ax)).normalized()
    side = ax.cross(fw).normalized()
    r = radius
    centres = []
    for i in range(steps):
        a = turns * 2.0 * math.pi * i / steps
        dist = radius * 0.55 * (shrink ** i)
        h = sum(radius * rise * (shrink ** k) for k in range(i))
        c = origin + ax * h + (fw * math.cos(a) + side * math.sin(a)) * dist
        centres.append((c, r, i))
        r *= shrink
    made = []
    for c, rr, i in centres:
        b = basis((c - origin + ax * 0.01).normalized() if i else ax)
        made += parts.ellipsoid(c, (rr, rr, rr * 0.92), b, color=None, weights=weights, seg=12 if i < 3 else 8,
                                rings=8 if i < 3 else 6, color_fn=lambda u, i=i: color_fn(u, i))
    return centres


def coral(parts, base, direction, length, radius, weights, c0, c1, depth=2, seed=1, spread=0.7):
    """A branching coral: a stubby blob that forks into thinner ones."""
    rng = random.Random(seed)
    d = direction.normalized()
    parts.blob(base, radius, d, length, None, weights=weights, seg=6, rings=4, tip=0.55,
               color_fn=lambda t: L.mix(c0, c1, L.smooth(0.3, 1.0, t) * (0.5 if depth else 1.0)))
    if depth <= 0:
        parts.ellipsoid(base + d * length, (radius * 0.75,) * 3, color=c1, weights=weights, seg=6, rings=4)
        return
    tip = base + d * length * 0.92
    t_, b_, _ = L.frame(d)
    for k in range(2 if depth > 1 else rng.choice((2, 3))):
        a = rng.uniform(0, 2 * math.pi)
        dd = (d + (t_ * math.cos(a) + b_ * math.sin(a)) * spread).normalized()
        coral(parts, tip, dd, length * rng.uniform(0.6, 0.8), radius * 0.68, weights, L.mix(c0, c1, 0.4), c1,
              depth - 1, seed * 7 + k, spread)
