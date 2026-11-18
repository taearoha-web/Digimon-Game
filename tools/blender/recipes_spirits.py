"""Team spirits: VARIANTS of the shared flying rigs, so every monster that used to share a
model with another one (differing only by its MonsterData tint) is its own creature.

    /opt/bpy5/bin/python tools/blender/recipes_spirits.py [flying/Ghost_lotus_sprite ...]

Same pipeline as recipes_flyers.py (kit_flyers' Glow materials keep eyes, runes and fire
their colour under every tint). Each variant is built from its source rig (SOURCE) with
the same bones and clips and written to remaster/<dir>/<Rig>_<monster_id>.glb; that
monster's "model" in its data file points at "remaster/<dir>/<Rig>_<monster_id>". The
first monster of each rig keeps recipes_flyers' model.

Variants differ by SHAPE and features (crowns, petals, horns, tentacles, halos, armour),
not only paint, and fit each monster's Thai name and role; bosses are the grandest.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import remaster_lib as L  # noqa: E402
import kit_flyers as K  # noqa: E402
import recipes_flyers as F  # noqa: E402
from mathutils import Vector  # noqa: E402

C = L.srgb
WHITE = C("ffffff")
UP = Vector((0, 0, 1))
front_hit = F.front_hit
dir_hit = F.dir_hit


# ---------------------------------------------------------------- shared shapes

def torus(parts, center, normal, R, r, color_fn, weights, seg=24, sides=8, detail=False, squash=1.0):
    """A ring (halo, shackle, chain link): color_fn(u around 0..1, v around the tube 0..1)."""
    t_, b_, n_ = L.frame(normal)
    cos, uv = [], []
    for i in range(seg):
        a = 2.0 * math.pi * i / seg
        d = t_ * math.cos(a) + b_ * math.sin(a)
        for j in range(sides):
            c = 2.0 * math.pi * j / sides
            cos.append(center + d * (R + r * math.cos(c)) + n_ * (r * squash * math.sin(c)))
            uv.append((i / seg, j / sides))
    faces = []
    for i in range(seg):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            c = ((i + 1) % seg) * sides + (j + 1) % sides
            d = ((i + 1) % seg) * sides + j
            faces.append((a, d, c, b))
    # Outward check on the first face.
    f = faces[0]
    nrm = (cos[f[1]] - cos[f[0]]).cross(cos[f[2]] - cos[f[0]])
    mid = (cos[f[0]] + cos[f[2]]) * 0.5
    ring_c = center + (t_ * 1.0) * R
    if nrm.dot(mid - ring_c) < 0:
        faces = [tuple(reversed(f)) for f in faces]
    return parts._add(cos, faces, lambda i: color_fn(*uv[i]), weights, detail)


def star_outline(r_out, r_in, points=5, rot=0.0):
    out = []
    for i in range(points * 2):
        a = rot + math.pi * 0.5 + math.pi * i / points
        r = r_out if i % 2 == 0 else r_in
        out.append((math.cos(a) * r, math.sin(a) * r))
    return out


def petal(parts, base, direction, length, width, col_fn, weights, up=None, cup=0.0, detail=False, seg=10, rings=7,
          tip=0.18, thin=0.32):
    """A lotus / flower petal: a flattened blob that cups (bends) towards `up`."""
    d = direction.normalized()
    bend = None
    if cup and up is not None:
        bend = up.normalized() * cup * length
    return parts.blob(base, (width, width * thin), d, length, None, weights=weights, detail=detail, seg=seg,
                      rings=rings, tip=tip, color_fn=col_fn, bend=bend, up=up)


def lotus(parts, center, axis, radius, petals, length, width, col_fn, weights, layers=2, open_=0.55, seed=1,
          detail=False, twist=0.0):
    """A lotus blossom: rings of cupped petals around axis (outer layer opens wider)."""
    t_, b_, n_ = L.frame(axis)
    for layer in range(layers):
        k = petals - layer * 2 if layer else petals
        op = open_ * (1.0 - 0.45 * layer)
        ln = length * (1.0 - 0.18 * layer)
        for i in range(k):
            a = 2.0 * math.pi * (i + 0.5 * layer) / k + twist
            out = t_ * math.cos(a) + b_ * math.sin(a)
            d = (out * math.sin(op * math.pi * 0.5) * 1.1 + n_ * math.cos(op * math.pi * 0.5)).normalized()
            base = center + out * radius * (1.0 - 0.4 * layer) + n_ * (0.02 * layer)
            petal(parts, base, d, ln, width * (1.0 - 0.15 * layer), col_fn, weights, up=-out, cup=0.22,
                  detail=detail, seg=8, rings=5)


def chain(parts, start, direction, links, size, col_fn, weights):
    """A hanging chain of alternating links."""
    d = direction.normalized()
    side = d.cross(Vector((1, 0, 0)))
    if side.length < 0.1:
        side = d.cross(Vector((0, 1, 0)))
    side.normalize()
    for i in range(links):
        c = start + d * (i * size * 1.55)
        nrm = side if i % 2 == 0 else d.cross(side).normalized()
        torus(parts, c, nrm, size, size * 0.28, col_fn, weights, seg=12, sides=6, squash=1.0)


def gentle_eye(parts, center, radius, gaze, weights, iris_top, iris_low, glint=WHITE, lid=None, star=True):
    """A soft, kind eye for the gentle spirits: a big deep iris filling the eye, a star
    glint (glow, so tints never dull it), a thin lash line."""
    gaze = gaze.normalized()
    parts.ellipsoid(center, (radius, radius, radius), color=None, weights=weights, seg=16, rings=10,
                    color_fn=lambda u: L.mix(iris_low, iris_top, L.smooth(-0.8, 0.8, u.z)))
    parts.sphere_cap(center, radius, gaze, (0.42, 0.5), L.mix(iris_top, C("08040e"), 0.6), weights, lift=0.015,
                     seg=16, rings=2, offset=(0.0, -0.05))
    # Lower iris shine.
    parts.sphere_cap(center, radius, gaze, (0.38, 0.16), L.mix(iris_low, WHITE, 0.45), weights, lift=0.022,
                     offset=(0.0, -0.42), seg=14, rings=2)
    if star:
        o = star_outline(0.3, 0.11, 4)
        t_, b_, n_ = L.frame(gaze)
        p = center + (gaze + t_ * -0.3 + b_ * 0.38).normalized() * radius * 1.03
        parts.decal(p, (p - center).normalized(), [(x * radius, y * radius) for x, y in o], glint, weights=weights,
                    lift=0.01, rings=1, detail="glow")
    parts.sphere_cap(center, radius, gaze, (0.1, 0.1), glint, weights, lift=0.03, offset=(0.3, -0.2), seg=8,
                     rings=1, detail="glow")
    if lid is not None:
        up = (UP - gaze * UP.dot(gaze)).normalized()
        parts.sphere_cap(center, radius * 1.05, (up * 1.0 + gaze * 0.25).normalized(), (1.0, 0.7), lid, weights,
                         lift=0.0, up=gaze, seg=22, rings=4, detail=False)


def flame(parts, base, direction, length, width, weights, hot=C("fff2b0"), mid=C("ff9a30"), cool=C("c82a10"),
          bend=None, detail="glow2"):
    """A licking flame tongue."""
    return parts.blob(base, (width, width * 0.6), direction, length, None, weights=weights, detail=detail, seg=8,
                      rings=7, tip=0.03, bend=bend,
                      color_fn=lambda t: L.mix(L.mix(hot, mid, L.smooth(0.0, 0.5, t)), cool, L.smooth(0.5, 1.0, t)))


# ================================================================ Ghost

def _ghost_prep(body, keep_grin=True, target=5200):
    eyes = [e for e in K.eye_balls(body, ("Eye_White",)) if e[0].z > 1.85]
    if keep_grin:
        L.delete_faces(body, where=lambda c, n, g: (n == "Eye_White" and c.z > 1.82) or
                       (n == "Eye_Black" and c.z > 2.0))
    else:
        L.delete_faces(body, ("Eye_White", "Eye_Black"))
    L.clean(body, fill_holes=40 if not keep_grin else 0)
    L.subdivide(body, 1)
    L.decimate_to(body, target)
    L.relax(body, 2, 0.35, ("Ghost_Main",))
    return eyes


def abyss_ghost(arm, body):
    """Ghost -> abyss_ghost (ผีนรกอเวจี): a damned soul of the deepest hell. The ghost's ears
    become curled obsidian horns, a crest of hellfire burns between them, the grin grows
    long fangs, molten cracks glow through ash-pale ectoplasm, the wrists drag broken
    shackles and chains, and the tatters below burn like flame."""
    eyes = _ghost_prep(body, target=4300)
    top, low, deep = C("ffe6d8"), C("b07a78"), C("3a1218")
    horn_a, horn_b = C("1a1014"), C("6a5a5e")

    def paint(name, co, n, info):
        if name == "Eye_White":
            return L.mix(C("d8c8a8"), C("fff4dc"), L.smooth(-0.01, 0.04, info["bump"]))
        if name == "Eye_Black":
            return C("1a0404")
        if co.z > 2.62 and abs(co.x) > 0.18:  # ears -> obsidian horns, ringed
            t = L.smooth(2.62, 3.3, co.z)
            c = L.mix(horn_a, horn_b, t)
            return L.mix(c, c * 0.5, L.smooth(0.55, 1.0, math.sin(co.z * 30.0)) * 0.6 * (1.0 - t))
        c = F._ghost_paint(top, low, deep, C("ffffff"), top_z=2.6, low_z=0.6)(name, co, n, info)
        # Scorch: soot rising from below and at the fingertips.
        return L.mix(c, C("2a0a0a"), L.smooth(0.9, 0.35, co.z) * 0.6)

    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    wh = {"Head": 1.0}
    for c, r in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        K.hollow_eye(parts, c, r * 1.05, Vector((0.3 * sx, -1.0, 0.0)), wh, lid_col=C("4a2026"), tilt=0.75,
                     open_=0.32, pupil=0.55, sink=0.3, ball=C("ffc040"))
    # Two long fangs at the grin's corners.
    for sx in (-1.0, 1.0):
        p, n = front_hit(surf, 0.24 * sx, 1.62)
        if p is not None:
            K.fang(parts, p - n * 0.02, Vector((0.1 * sx, -0.35, -1.0)), 0.3, 0.06, wh)
    # Curled horn tips (the ears end in hooks) and a crown of hellfire between them.
    for sx in (-1.0, 1.0):
        p, n = dir_hit(surf, Vector((0.32 * sx, 0.0, 2.6)), Vector((0.55 * sx, 0.0, 0.6)))
        if p is not None:
            parts.horn(p - n * 0.05, Vector((0.9 * sx, 0.1, 0.5)), 0.55, 0.11,
                       lambda t: L.mix(horn_a, horn_b, t), wh, curl=Vector((-0.25 * sx, 0.0, 0.35)))
    rng = random.Random(5)
    for k in range(7):
        x = -0.24 + 0.08 * k
        p, n = dir_hit(surf, Vector((x, 0.0, 2.4)), Vector((x * 0.6, 0.05, 1.0)))
        if p is None:
            continue
        ln = 0.6 + 0.45 * (1.0 - abs(x) / 0.3) + rng.uniform(-0.08, 0.08)
        flame(parts, p - n * 0.08, Vector((x * 1.4, 0.2, 1.0)), ln, 0.12, wh, hot=C("ffd070"), mid=C("ff5a10"),
              cool=C("a01008"), bend=Vector((rng.uniform(-0.15, 0.15), 0.18, 0.05)))
    # Molten cracks over the body.
    for k in range(18):
        a = rng.uniform(0, 2 * math.pi)
        z = rng.uniform(0.6, 2.4)
        d = Vector((math.cos(a), math.sin(a), 0.0))
        p, n = surf.toward(Vector((0, 0.25, z)) + d * 5.0, Vector((0, 0.25, z)))
        if p is None or any((p - e[0]).length < e[1] * 1.7 for e in eyes) or (abs(p.x) < 0.4 and p.y < 0 and
                                                                             1.4 < p.z < 2.0):
            continue
        path = [(0.0, 0.0)]
        ang = rng.uniform(0, math.pi)
        for i in range(5):
            ang += rng.uniform(-0.8, 0.8)
            x, y = path[-1]
            path.append((x + math.cos(ang) * 0.07, y + math.sin(ang) * 0.07))
        parts.stroke(p, n, path, 0.035, C("ffa040"), detail="glow2", lift=0.01)
    # Broken shackles on the wrists, each dragging a short chain.
    iron = lambda u, v: L.mix(C("2a2426"), C("8a7a7a"), 0.5 + 0.5 * math.sin(v * 6.283))
    for side, sx in (("L", 1.0), ("R", -1.0)):
        b = arm.data.bones["LowerArm." + side]
        c = b.head_local.lerp(b.tail_local, 0.75)
        w = {"LowerArm." + side: 1.0}
        torus(parts, c, Vector((1.0, 0.0, 0.0)), 0.2, 0.06, iron, w, seg=16, sides=6)
        chain(parts, c + Vector((0.0, 0.0, -0.24)), Vector((0.0, 0.15, -1.0)), 3, 0.08, iron, w)
    # Burning tatters below.
    rng2 = random.Random(9)
    for k in range(6):
        a = math.pi * 2.0 * k / 6 + rng2.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a) * 0.8 + 0.25, -0.4))
        p, n = dir_hit(surf, Vector((0.0, 0.25, 0.8)), d)
        if p is None:
            continue
        axis = (n * 0.35 + Vector((0, 0.35, -1.0))).normalized()
        parts.blob(p - n * 0.05, (0.1, 0.06), axis, 0.6 * rng2.uniform(0.8, 1.15), None, weights=p, seg=8, rings=6,
                   tip=0.04, bend=Vector((math.cos(a) * 0.15, 0.2, 0.0)),
                   color_fn=lambda t: L.mix(C("5a1a1a"), C("ff7a20"), L.smooth(0.55, 1.0, t)))
    K.join_parts(body, parts.to_object())
    L.bake_ao(body, strength=0.45, shade=Vector((0.6, 0.42, 0.45)))
    return {"glow": "ffa030", "strength": 1.6, "glow2": "ff4a10", "strength2": 1.3}


def lotus_sprite(arm, body):
    """Ghost -> lotus_sprite (ภูตบัวประกายดาว): a gentle sprite born from a lotus under the
    stars, not a ghost. Pearl-white body blushing to lotus pink, the pointed ears are
    softened into two great petals, a lotus blossom crowns the head with a glowing star
    seed, a skirt of downward petals replaces the ragged tatters, big kind star-glint
    eyes and a small smile (no grin, no fangs), star sparkles over the skin."""
    eyes = _ghost_prep(body, keep_grin=False, target=4000)
    # Soften the ear spikes: shorter and rounder, like petals.
    for v in body.data.vertices:
        if v.co.z > 2.5 and abs(v.co.x) > 0.1:
            # Ears -> petals drooping outward: shorter, swung out about their root.
            t = L.smooth(2.5, 3.35, v.co.z)
            sx = 1.0 if v.co.x > 0 else -1.0
            h = (v.co.z - 2.5) * (1.0 - 0.3 * t)
            ang = 0.75 * t
            r = abs(v.co.x) - 0.1
            v.co.x = sx * (0.1 + r * math.cos(ang) + h * math.sin(ang) * 1.1)
            v.co.z = 2.5 + h * math.cos(ang) - r * math.sin(ang) * 0.3
    top, low, pink, lav = C("fffaf6"), C("ffd6e8"), C("ff9cc8"), C("c8a8f0")

    def paint(name, co, n, info):
        if co.z > 2.45 and abs(co.x) > 0.35:  # ear petals: white base, pink tip, veins
            t = L.smooth(0.4, 1.0, abs(co.x))
            c = L.mix(top, pink, t)
            vein = abs(math.sin(co.x * 28.0))
            return L.mix(c, L.mix(c, pink, 0.6), L.smooth(0.12, 0.0, vein) * 0.5 * t)
        c = L.mix(low, top, L.smooth(0.8, 2.4, co.z))
        c = L.mix(c, lav, L.smooth(0.9, 0.3, co.z) * 0.8)
        # Hands blush to petal pink at the fingertips.
        c = L.mix(c, pink, L.smooth(1.9, 2.7, abs(co.x)) * 0.7)
        sp = K.fbm(co, 0.07, 1)
        return L.mix(c, WHITE, L.smooth(0.45, 0.6, sp) * 0.8)

    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    wh = {"Head": 1.0}
    for c, r in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        gentle_eye(parts, c + Vector((0.0, 0.02, -0.04)), r * 1.0, Vector((0.25 * sx, -1.0, 0.05)), wh,
                   C("5a3ac8"), C("ff9ad8"))
        p, n = front_hit(surf, c.x + 0.02 * sx, c.z + r * 0.92)
        if p is not None:  # a soft lash line over the upper rim
            arc = [(-0.17, -0.03), (-0.08, 0.025), (0.0, 0.035), (0.08, 0.025), (0.17, -0.03)]
            parts.stroke(p, n, arc if sx > 0 else arc[::-1], 0.035, C("4a2050"))
        p, n = front_hit(surf, 0.5 * sx, 1.78)
        if p is not None:
            parts.decal(p, n, F_ellipse(0.11, 0.06), C("ffaacc"), rings=2)
    p, n = front_hit(surf, 0.0, 1.72)
    if p is not None:
        parts.stroke(p, n, [(-0.1, 0.03), (-0.05, -0.02), (0.0, -0.03), (0.05, -0.02), (0.1, 0.03)], 0.03,
                     C("a0406a"))
    # The lotus crown with a glowing star seed.
    petal_col = lambda t: L.mix(C("fff4f8"), C("ff7ab8"), L.smooth(0.25, 1.0, t))
    apex, an = dir_hit(surf, Vector((0.0, 0.0, 2.6)), UP)
    if apex is not None:
        base = apex - Vector((0, 0, 0.06))
        lotus(parts, base, Vector((0.0, 0.1, 1.0)), 0.22, 9, 0.62, 0.2, petal_col, wh, layers=2, open_=0.55)
        parts.ellipsoid(base + Vector((0, 0, 0.12)), (0.13, 0.13, 0.09), color=None, weights=wh, detail="glow",
                        color_fn=lambda u: L.mix(C("fff6b0"), C("ffd060"), L.smooth(0.5, -0.5, u.z)))
        o = star_outline(0.22, 0.08, 4)
        parts.decal(base + Vector((0, -0.02, 0.21)), Vector((0, -1, 0.15)).normalized(), o, C("fff8c8"),
                    weights=wh, lift=0.0, rings=1, detail="glow")
    # A skirt of downward lotus petals with green sepals.
    for k in range(10):
        a = 2.0 * math.pi * k / 10
        d = Vector((math.cos(a), math.sin(a) * 0.9 + 0.2, -0.15))
        p, n = dir_hit(surf, Vector((0.0, 0.3, 0.9)), d)
        if p is None:
            continue
        out = Vector((n.x, n.y, 0.0)).normalized()
        petal(parts, p - n * 0.04, (out * 1.3 + Vector((0, 0, -1.0))).normalized(), 0.62, 0.27,
              lambda t: L.mix(C("fff0f6"), C("ff7ab8"), L.smooth(0.3, 1.0, t)), p, up=out, cup=0.35, seg=8, rings=5)
    for k in range(5):
        a = 2.0 * math.pi * (k + 0.5) / 5
        d = Vector((math.cos(a), math.sin(a) * 0.9 + 0.2, -0.1))
        p, n = dir_hit(surf, Vector((0.0, 0.3, 1.05)), d)
        if p is not None:
            out = Vector((n.x, n.y, 0.0)).normalized()
            petal(parts, p - n * 0.05, (out * 0.8 + Vector((0, 0, -0.6))).normalized(), 0.32, 0.12,
                  lambda t: L.mix(C("4aa860"), C("9ae0a0"), t), p, up=out, cup=0.2)
    # Star sparkles on the skin.
    rng = random.Random(4)
    for k in range(10):
        a = rng.uniform(0, 2 * math.pi)
        z = rng.uniform(1.0, 2.5)
        d = Vector((math.cos(a), math.sin(a), 0.0))
        p, n = surf.toward(Vector((0, 0.2, z)) + d * 5.0, Vector((0, 0.2, z)))
        if p is None or any((p - e[0]).length < e[1] * 1.8 for e in eyes):
            continue
        s = rng.uniform(0.05, 0.09)
        parts.decal(p, n, star_outline(s, s * 0.35, 4, rng.uniform(0, 1)), C("fff6c0"), lift=0.012, rings=1,
                    detail="glow")
    K.join_parts(body, parts.to_object())
    L.bake_ao(body, strength=0.35, shade=Vector((0.8, 0.62, 0.78)))
    return {"glow": "fff0b0", "strength": 1.5, "glow2": "ffd0e8", "strength2": 1.3}



# ================================================================ Ghost_Skull

def _skull_prep(body, target=4000):
    L.clean(body)
    skull = L.split_off(body, ("Head",))
    L.subdivide(body, 1)
    L.decimate_to(body, target)
    L.relax(body, 2, 0.35)
    L.clean(skull, quads=False)
    L.join(body, skull)


def _tatters(parts, surf, col_fn, count=6, length=0.55, seed=9):
    F._wisps(parts, surf, 0.5, col_fn, count=count, length=length, seed=seed)


def star_wraith(arm, body):
    """Ghost_Skull -> star_wraith (วิญญาณดาวดับ): the ghost of a dead star. The skull is
    dark meteoric stone split by white-hot star-fire cracks, a star burns in each socket,
    a broken corona of crystal star-shards stands behind the head, and the shadow body is
    a night sky drawn with glowing constellations."""
    _skull_prep(body)
    stone_top, stone_low = C("f0f0ff"), C("8a88a8")
    sky_top, sky_low = C("6a6aa0"), C("1a1838")

    def paint(name, co, n, info):
        if name == "c_a58c72":
            c = L.mix(stone_low, stone_top, L.smooth(1.4, 2.5, co.z))
            c = L.mix(c, c * 0.6, max(0.0, K.fbm(co, 0.09, 2)) * 0.9)
            d0, d1 = K.cells(co, 0.16)
            seam = 1.0 - L.smooth(0.0, 0.05, d1 - d0)
            return L.mix(c, C("2a2440"), seam * 0.8 * L.smooth(1.5, 2.3, co.z))
        c = L.mix(sky_low, sky_top, L.smooth(0.4, 2.6, co.z))
        neb = max(0.0, K.fbm(co + Vector((3, 1, 0)), 0.35, 3))
        c = L.mix(c, C("7a5ac8"), neb * 0.7)
        star = K.fbm(co, 0.05, 1)
        return L.mix(c, C("ffffff"), L.smooth(0.5, 0.6, star))

    K.paint_body_glow(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    wh = {"Head": 1.0}
    for sx in (-1.0, 1.0):
        p, n = surf.toward(Vector((0.27 * sx, -5.0, 1.95)), Vector((0.27 * sx, -0.3, 1.95)))
        if p is None:
            continue
        parts.ellipsoid(p + Vector((0, 0.02, 0)), (0.12, 0.05, 0.11), color=None, weights=wh, seg=10, rings=6,
                        color_fn=lambda u: C("0a0818"))
        # A small star burning in the socket: a glowing core and four twinkle rays.
        g = p + Vector((0, -0.04, 0))
        parts.ellipsoid(g, (0.085, 0.05, 0.085), color=None, weights=wh, detail="glow", seg=8, rings=5,
                        color_fn=lambda u: C("f8fbff"))
        for a in range(4):
            d = Vector((math.cos(a * math.pi / 2), 0.0, math.sin(a * math.pi / 2)))
            parts.blob(g, (0.03, 0.015), d, 0.17 if a % 2 else 0.24, None, weights=wh, detail="glow", seg=5,
                       rings=3, tip=0.05, color_fn=lambda t: C("f8fbff"), up=Vector((0, -1, 0)))
        # A heavy stone brow.
        p3, n3 = front_hit(surf, 0.27 * sx, 2.12)
        if p3 is not None:
            parts.stroke(p3, n3, [(0.18 * sx, 0.06), (0.05 * sx, 0.0), (-0.1 * sx, -0.08)], 0.07, C("141226"),
                         lift=0.012)
    # Star-fire cracks running over the cranium.
    rng = random.Random(14)
    for k in range(7):
        a = rng.uniform(-2.4, 2.4)
        d = Vector((math.sin(a), -math.cos(a) * 0.6 + 0.3, 0.9))
        p, n = dir_hit(surf, Vector((0, -0.15, 2.0)), d)
        if p is None or p.z < 2.15:
            continue
        path = [(0.0, 0.0)]
        ang = rng.uniform(0, math.pi * 2)
        for i in range(4):
            ang += rng.uniform(-0.9, 0.9)
            x, y = path[-1]
            path.append((x + math.cos(ang) * 0.08, y + math.sin(ang) * 0.08))
        parts.stroke(p, n, path, 0.03, C("e8f4ff"), weights=wh, detail="glow", lift=0.01)
    # A broken corona of crystal star shards behind the head.
    centre = Vector((0.0, 0.45, 2.45))
    for k in range(9):
        a = math.pi * 0.5 + 2.0 * math.pi * k / 9 + (0.12 if k % 2 else 0.0)
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        if out.z < -0.55:
            continue
        ln = 0.5 if k % 2 == 0 else 0.32
        base = centre + out * 0.72
        parts.blob(base, (0.15, 0.07), out + Vector((0, 0.15, 0)), ln, None, weights=wh, seg=6, rings=4, tip=0.05,
                   color_fn=lambda t: L.mix(C("8a8ac8"), C("f4f8ff"), L.smooth(0.1, 0.9, t)), up=Vector((0, 1, 0)))
        parts.ellipsoid(base + out * ln * 0.92, (0.05, 0.05, 0.05), color=None, weights=wh, detail="glow", seg=6,
                        rings=4, color_fn=lambda u: C("f8fbff"))
    torus(parts, centre, Vector((0, 1, 0)), 0.74, 0.05, lambda u, v: C("c8d0ff"), wh, seg=28, sides=6,
          detail="glow2")
    # Constellations on the shadow body: glowing stars joined by thin lines.
    for k, (sx, z0) in enumerate(((1.0, 1.2), (-1.0, 1.0), (1.0, 0.75))):
        pts = []
        for i in range(4):
            a = sx * (0.6 + 0.35 * i) + rng.uniform(-0.15, 0.15)
            z = z0 + rng.uniform(-0.15, 0.25) - 0.08 * i
            d = Vector((math.sin(a), -math.cos(a), 0.0))
            p, n = surf.toward(Vector((0, 0.3, z)) + d * 5.0, Vector((0, 0.3, z)))
            if p is not None:
                pts.append((p, n))
        for i, (p, n) in enumerate(pts):
            parts.decal(p, n, star_outline(0.1, 0.035, 4), C("ffffff"), lift=0.014, rings=1, detail="glow")
            if i:
                q, _m = pts[i - 1]
                pm, nm = surf.project((p + q) * 0.5, n, 0.6)
                if pm is None:
                    continue
                t_, b_, n_ = L.frame(nm)
                a2, b2 = p - pm, q - pm
                parts.stroke(pm, nm, [(a2.dot(t_), a2.dot(b_)), (b2.dot(t_), b2.dot(b_))], 0.016, C("c8d8ff"),
                             lift=0.012, detail="glow2", taper=False)
    _tatters(parts, surf, lambda t: L.mix(C("2a2a5a"), C("08061a"), t), count=7, length=0.62, seed=4)
    K.join_parts(body, parts.to_object())
    L.bake_ao(body, strength=0.45, shade=Vector((0.5, 0.5, 0.75)))
    return {"glow": "e8f4ff", "strength": 1.8, "glow2": "a8b8ff", "strength2": 1.3}


def eclipse_wraith(arm, body):
    """Ghost_Skull -> eclipse_wraith (วิญญาณกะโหลกคราส): a skull in eclipse. Half the skull is
    bone, half swallowed by black shadow along a curved terminator; a black sun with a
    burning corona hangs behind the head, a crescent moon glows on the brow, one socket
    holds an eclipse ring of light, and a ragged mantle of dusk cloth wraps the shoulders."""
    import kit_critters as KC
    _skull_prep(body)
    bone_top, bone_low, night = C("fbf2e2"), C("cbbca4"), C("161020")
    shade_top, shade_low = C("6a4a7a"), C("1a1022")

    def eclipse_side(co):
        # Shadow over the creature's right half, along a curved limb like the moon's.
        return L.smooth(0.04, -0.04, co.x - 0.18 * math.cos((co.z - 1.95) * 2.2) + 0.1)

    def paint(name, co, n, info):
        if name == "c_a58c72":
            c = L.mix(bone_low, bone_top, L.smooth(1.5, 2.5, co.z))
            c = L.mix(c, C("2a1a2c"), L.smooth(-0.01, -0.06, info["bump"]) * 0.85)
            return L.mix(c, night, eclipse_side(co))
        h = L.smooth(0.4, 2.4, co.z)
        c = L.mix(shade_low, shade_top, h)
        return L.mix(c, shade_low * 0.6, L.smooth(1.3, 2.6, abs(co.x)) * 0.6)

    K.paint_body_glow(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    wh = {"Head": 1.0}
    for sx in (-1.0, 1.0):
        p, n = surf.toward(Vector((0.27 * sx, -5.0, 1.95)), Vector((0.27 * sx, -0.3, 1.95)))
        if p is None:
            continue
        if sx > 0:  # bone side: an ember in the socket
            parts.ellipsoid(p + Vector((0.0, -0.02, -0.01)), (0.1, 0.045, 0.09), color=None, weights=wh,
                            detail="glow", seg=10, rings=6, color_fn=lambda u: C("ffe8b0"))
        else:  # shadow side: a thin ring of light, the eclipse in the eye
            torus(parts, p + Vector((0, -0.02, 0)), Vector((0, -1, 0)), 0.085, 0.022, lambda u, v: C("ffd890"), wh,
                  seg=16, sides=5, detail="glow2")
    # A crescent moon on the brow.
    p, n = front_hit(surf, 0.0, 2.32)
    if p is not None:
        arc = [(math.cos(a) * 0.12 - 0.02, math.sin(a) * 0.12) for a in [math.radians(d) for d in range(-120, 121, 20)]]
        parts.stroke(p, n, arc, 0.06, C("fff0c0"), weights=wh, detail="glow2", lift=0.012)
    # The black sun behind the head, with its corona.
    centre = Vector((0.0, 0.5, 2.4))
    R = 0.88
    parts.ellipsoid(centre, (R, 0.06, R), color=None, weights=wh, seg=24, rings=8,
                    color_fn=lambda u: C("0c0812"))
    torus(parts, centre + Vector((0, -0.02, 0)), Vector((0, 1, 0)), R + 0.02, 0.06, lambda u, v: C("fff0c0"), wh,
          seg=32, sides=6, detail="glow2")
    rng = random.Random(3)
    for k in range(14):
        a = 2.0 * math.pi * k / 14 + rng.uniform(-0.08, 0.08)
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        if out.z < -0.6:
            continue
        ln = rng.uniform(0.18, 0.42) * (1.4 if k % 3 == 0 else 1.0)
        flame(parts, centre + out * R + Vector((0, -0.01, 0)), out, ln * 1.2, 0.08, wh, hot=C("fff6d0"),
              mid=C("ffc060"), cool=C("ff7a30"), bend=Vector((math.cos(a + 1.5), 0, math.sin(a + 1.5))) * 0.06)

    # A ragged mantle of dusk cloth round the shoulders, hanging at the back.
    def cloth(u, v, outside):
        c = L.mix(C("3a2a4a"), C("150c1c"), v)
        c = L.mix(c, c * 0.7, L.smooth(0.7, 1.0, abs(math.sin(u * 9.0))) * 0.5)
        return c if outside else c * 0.6
    KC.cape(parts, Vector((0.0, 0.05, 0.0)), 1.72, 0.85, 0.42, 0.7, 3.6, cloth, {"Torso": 0.6, "Body1": 0.4},
            rows=6, cols=14, flare=0.2)
    _tatters(parts, surf, lambda t: L.mix(C("3a2a4a"), C("100a16"), t), count=6, length=0.55, seed=9)
    K.join_parts(body, parts.to_object())
    L.bake_ao(body, strength=0.45, shade=Vector((0.5, 0.45, 0.65)))
    return {"glow": "ffe0a0", "strength": 1.6, "glow2": "ffd070", "strength2": 1.7}



# ================================================================ Glub_Evolved

def drown_jelly(arm, body):
    """Glub_Evolved -> drown_jelly (แมงกะพรุนวิญญาณจมน้ำ): the spirit of a drowned jellyfish.
    The head's tip is pressed down under a wide glassy bell with a scalloped glowing rim
    and radial canals; long trailing tentacles and frilly oral arms hang from it round the
    pale body column; three drowned-soul eyes glow sea-green; the wings become fin-lobes
    dotted with bioluminescence; little air bubbles cling to the skin. No lava, no cracks."""
    eyes = [e for e in K.eye_balls(body, ("c_8f92a0",)) if e[0].z < 2.8]
    L.delete_faces(body, ("c_8f92a0", "c_1e1f22"))
    L.clean(body)
    # Press the head's horn-tip down into the bell.
    for v in body.data.vertices:
        if v.co.z > 2.95:
            v.co.z = 2.95 + (v.co.z - 2.95) * 0.35
            v.co.y *= 0.6
    L.subdivide(body, 1)
    L.decimate_to(body, 3000)
    L.relax(body, 2, 0.3, ("c_403a5a",))
    top, low, deep = C("f4f0ff"), C("b8c8f0"), C("4a5aa0")

    def paint(name, co, n, info):
        if name == "c_818181":  # fin lobes: pale membrane, deeper root, glowing dots
            t = L.smooth(0.4, 2.0, abs(co.x))
            c = L.mix(C("6a7ab8"), C("f0f4ff"), t)
            d0, _d1 = K.cells(co, 0.2)
            return L.mix(c, C("ffffff"), L.smooth(0.12, 0.05, d0) * 0.7)
        c = L.mix(deep, low, L.smooth(0.5, 1.6, co.z))
        c = L.mix(c, top, L.smooth(1.6, 2.6, co.z))
        # Gentle vertical canals down the column.
        canal = abs(math.sin(math.atan2(co.x, co.y) * 6.0))
        c = L.mix(c, c * 0.8, L.smooth(0.2, 0.0, canal) * 0.6)
        return L.mix(c, c * 1.2, max(0.0, -n.y) * 0.2)

    K.paint_body_glow(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    for c, r in eyes:
        sx = 0.0 if abs(c.x) < 0.05 else (1.0 if c.x > 0 else -1.0)
        K.hollow_eye(parts, c, r * 0.95, Vector((0.3 * sx, -1.0, 0.0)), {"Head": 1.0}, lid_col=C("c8d4f4"),
                     tilt=0.35 if sx else 0.0, open_=0.45, pupil=0.5, sink=0.3, ball=C("d8fff0"))
    # The bell.
    apex, _an = dir_hit(surf, Vector((0.0, 0.0, 2.8)), UP)
    anchor = apex if apex is not None else Vector((0, 0, 3.1))
    bc = Vector((0.0, 0.05, anchor.z + 0.02))
    R = 1.05

    def bell_col(u):
        c = L.mix(C("dcd8ff"), C("ffffff"), L.smooth(-0.2, 0.9, u.z))
        rad = abs(math.sin(math.atan2(u.y, u.x) * 8.0))
        c = L.mix(c, C("a8b8ff"), L.smooth(0.25, 0.0, rad) * L.smooth(0.95, 0.2, u.z) * 0.6)
        return L.mix(c, C("8a9ae0"), L.smooth(0.25, -0.2, u.z) * 0.5)
    parts.ellipsoid(bc, (R, R * 0.95, 0.72), color=None, weights=anchor, seg=28, rings=12, squash_bottom=0.72,
                    color_fn=bell_col)
    # Scalloped glowing rim.
    for k in range(16):
        a = 2.0 * math.pi * k / 16
        d = Vector((math.cos(a), math.sin(a) * 0.95, 0.0))
        parts.ellipsoid(bc + d * R * 0.97 + Vector((0, 0, -0.14)), (0.14, 0.14, 0.09), K.basis(d), color=None,
                        weights=anchor, seg=7, rings=4, detail="glow2" if k % 2 == 0 else False,
                        color_fn=lambda u: L.mix(C("b8fff0"), C("e8fff8"), L.smooth(-0.5, 0.8, u.z)))
    # Glowing spots on the bell's crown.
    for k in range(7):
        a = 2.0 * math.pi * k / 7 + 0.3
        p = bc + Vector((math.cos(a) * 0.45, math.sin(a) * 0.43, 0.62))
        parts.ellipsoid(p, (0.07, 0.07, 0.04), color=None, weights=anchor, detail="glow", seg=8, rings=4,
                        color_fn=lambda u: C("d0fff4"))
    # Long trailing tentacles from under the rim.
    rng = random.Random(8)
    for k in range(12):
        a = 2.0 * math.pi * (k + 0.5) / 12
        out = Vector((math.cos(a), math.sin(a), 0.0))
        base = bc + out * R * 0.8 + Vector((0, 0, -0.2))
        ln = rng.uniform(1.6, 2.3)
        parts.blob(base, 0.05, Vector((out.x * 0.12, out.y * 0.12 + 0.12, -1.0)), ln, None, weights=anchor, seg=6,
                   rings=8, tip=0.25, bend=Vector((out.x * 0.3 + rng.uniform(-0.15, 0.15), 0.3, 0.0)),
                   color_fn=lambda t: L.mix(C("c8d0ff"), C("e8fff8"), t))
    # Frilly oral arms hugging the column.
    for k in range(4):
        a = 2.0 * math.pi * (k + 0.5) / 4
        out = Vector((math.cos(a), math.sin(a), 0.0))
        p, n = dir_hit(surf, Vector((0, 0.0, 2.6)), out + Vector((0, 0, 0.2)))
        if p is None:
            continue
        parts.blob(p + n * 0.02, (0.14, 0.05), Vector((out.x * 0.25, out.y * 0.25, -1.0)), 1.5, None, weights=anchor,
                   seg=8, rings=8, tip=0.3, up=out, bend=Vector((out.x * 0.25, out.y * 0.25 + 0.15, 0)),
                   color_fn=lambda t: L.mix(C("ffe8f8"), C("e8c8ff"), t))
    # Air bubbles on the skin.
    for k in range(9):
        a = rng.uniform(0, 2 * math.pi)
        z = rng.uniform(0.9, 2.6)
        d = Vector((math.cos(a), math.sin(a), 0.0))
        p, n = surf.toward(Vector((0, 0.0, z)) + d * 5.0, Vector((0, 0.0, z)))
        if p is None or any((p - e[0]).length < e[1] * 1.6 for e in eyes):
            continue
        s = rng.uniform(0.04, 0.08)
        parts.ellipsoid(p + n * s * 0.7, (s, s, s), color=None, weights=p, seg=8, rings=5,
                        color_fn=lambda u: L.mix(C("a8c0ff"), WHITE, L.smooth(-0.2, 0.9, u.z)))
    K.join_parts(body, parts.to_object())
    L.bake_ao(body, strength=0.35, shade=Vector((0.55, 0.62, 0.8)))
    return {"glow": "b8fff0", "strength": 1.6, "glow2": "8affe0", "strength2": 1.2}


# ================================================================ Squidle

def tide_squid(arm, body):
    """Squidle -> tide_squid (หมึกเงาคลื่นคลั่ง): a shadow squid of the raging tide. The bone
    horns are gone; a tall finned mantle sweeps up and back from the head, the hanging
    tongue becomes a beak ringed by curling tentacles, the arms are tentacles with sucker
    rows beneath, the wings are wave-striped fins, big squid eyes with bar pupils, and
    photophores glow cyan along mantle and arms over chromatophore-spotted skin."""
    eyes = K.eye_balls(body, ("c_8f92a0",))
    L.delete_faces(body, ("c_8f92a0", "c_1e1f22", "c_a58c72"))
    L.clean(body, fill_holes=30)
    L.decimate_to(body, 4200)
    skin_top, skin_low, belly, spot = C("8a7ad8"), C("2a2060"), C("e8e0ff"), C("c84a8a")

    def paint(name, co, n, info):
        bone = info["bone"]
        if name == "c_2a6f8b":  # fins with wave stripes
            t = L.smooth(0.5, 1.9, abs(co.x))
            c = L.mix(C("3a3a90"), C("a8c8ff"), t)
            wave = math.sin(abs(co.x) * 9.0 + math.sin(co.y * 6.0) * 1.5)
            return L.mix(c, C("f0f8ff"), L.smooth(0.75, 0.95, wave) * 0.8)
        if name == "c_5b354a":  # beak / mouth
            return L.mix(C("1a1028"), C("4a3a5a"), L.smooth(1.2, 1.8, co.z))
        c = L.mix(skin_low, skin_top, L.smooth(1.2, 2.5, co.z))
        on_arm = bone.startswith(("UpperArm", "LowerArm", "Middle", "Index", "Pinky", "Thumb"))
        if on_arm and n.z < -0.2:
            # Sucker rows under the tentacle-arms: pale rings.
            c = L.mix(c, belly, 0.6)
            d0, _d1 = K.cells(Vector((co.x * 1.0, co.y * 2.5, co.z * 2.5)), 0.12)
            return L.mix(c, C("b8a0d0"), L.smooth(0.1, 0.05, d0))
        c = L.mix(c, belly, L.smooth(-0.3, -0.85, n.y) * L.smooth(2.1, 1.5, co.z) * 0.7)
        # Chromatophores.
        d0, _d1 = K.cells(co, 0.14)
        return L.mix(c, spot, L.smooth(0.08, 0.03, d0) * 0.55)

    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    wh = {"Head": 1.0}
    for c, r in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        K.fierce_eye(parts, c, r * 1.0, Vector((0.45 * sx, -1.0, 0.0)), wh, skin_top * 0.9, lid_dark=skin_low,
                     ball=C("ffc838"), slit=None, tilt=0.1, open_=0.62, lower_lid=0.8, brow=skin_low)
        # The cephalopod's bar pupil, bent into a shallow W.
        g = Vector((0.3 * sx, -1.0, 0.0)).normalized()
        for k, (ox, oy) in enumerate(((-0.32, 0.05), (0.0, -0.04), (0.32, 0.05))):
            parts.sphere_cap(c, r * 1.0, g, (0.24, 0.12), C("0a0610"), wh, lift=0.04, offset=(ox, oy), seg=12,
                             rings=1, detail=False)
    # The mantle: a tall cone sweeping up and back, with two fins at its tip.
    apex, _n = dir_hit(surf, Vector((0.0, 0.1, 2.2)), Vector((0.0, 0.3, 1.0)))
    base = (apex if apex is not None else Vector((0, 0.15, 2.55))) - Vector((0, 0, 0.25))
    axis = Vector((0.0, 0.55, 1.0)).normalized()
    mantle = lambda t: L.mix(skin_top, L.mix(skin_top, C("d8d0ff"), 0.5), t)
    parts.blob(base, (0.48, 0.42), axis, 1.25, None, weights=wh, seg=14, rings=10, tip=0.12, color_fn=mantle,
               up=Vector((0, -1, 0)))
    tip = base + axis * 1.0
    for sx in (-1.0, 1.0):
        parts.blob(tip - axis * 0.15, (0.42, 0.06), Vector((sx, 0.35, -0.1)), 0.75, None, weights=wh, seg=10, rings=6,
                   tip=0.1, up=Vector((0, 0, 1)), bend=axis * 0.2,
                   color_fn=lambda t: L.mix(skin_top, C("b8d0ff"), t))
    # Photophores along the mantle and on the brow.
    for k in range(6):
        p = base + axis * (0.25 + 0.14 * k)
        for sx in (-1.0, 1.0):
            side = Vector((sx, -0.25, 0)).normalized()
            rr = 0.46 * (1.0 - 0.75 * (0.25 + 0.14 * k) / 1.25)
            parts.ellipsoid(p + side * rr, (0.045, 0.045, 0.045), color=None, weights=wh, detail="glow2", seg=6,
                            rings=4, color_fn=lambda u: C("a8fff8"))
    # Beak tentacles: a ring of curling short tentacles round the mouth.
    p0, _n0 = front_hit(surf, 0.0, 1.55)
    mc = (p0 if p0 is not None else Vector((0, -0.5, 1.55))) + Vector((0, 0.15, 0))
    for k in range(6):
        a = math.pi * (0.15 + 0.7 * k / 5)
        d = Vector((math.cos(a) * 0.9, -0.35, -0.6 - 0.3 * math.sin(a))).normalized()
        parts.blob(mc + Vector((math.cos(a) * 0.22, 0.0, -0.05)), 0.075, d, 0.75, None, weights=wh, seg=8, rings=7,
                   tip=0.2, bend=Vector((-math.cos(a) * 0.25, -0.12, 0.18)),
                   color_fn=lambda t: L.mix(skin_top, C("e8d8ff"), L.smooth(0.4, 1.0, t)))
    # Photophores on the tentacle-arms.
    for side in ("L", "R"):
        for bn, f in (("UpperArm." + side, 0.5), ("LowerArm." + side, 0.3), ("LowerArm." + side, 0.85)):
            b = arm.data.bones[bn]
            c = b.head_local.lerp(b.tail_local, f)
            p, n = surf.toward(c + Vector((0, 0, 2.0)), c)
            if p is not None:
                parts.ellipsoid(p + n * 0.02, (0.05, 0.05, 0.04), K.basis(n), color=None, weights={bn: 1.0},
                                detail="glow2", seg=6, rings=4, color_fn=lambda u: C("a8fff8"))
    K.join_parts(body, parts.to_object())
    L.bake_ao(body, strength=0.45, shade=Vector((0.5, 0.5, 0.75)))
    return {"glow": "ffb820", "strength": 1.5, "glow2": "6afff0", "strength2": 1.5}


# ================================================================ Hywirl

def sky_wind_spirit(arm, body):
    """Hywirl -> sky_wind_spirit (ภูตวายุนภา): a spirit of the high wind. Cloud-white body
    fading to sky blue, painted wind swirls, the jagged crest swept back into two long
    streaming plumes, the tail wrapped in a puffy cloud, long sky ribbons trailing from
    the wrists, a glowing spiral on the chest and calm narrow cyan eyes. No lava, no fangs."""
    eyes = K.eye_balls(body, ("c_8f92a0",))
    L.delete_faces(body, ("c_8f92a0", "c_1e1f22"))
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 3300)
    L.relax(body, 3, 0.4)
    top, low, sky = C("ffffff"), C("a8d0ff"), C("5a9aff")

    def paint(name, co, n, info):
        c = L.mix(low, top, L.smooth(1.2, 2.5, co.z))
        c = L.mix(c, sky, L.smooth(1.4, 2.7, abs(co.x)) * 0.7)
        # Wind streaks: long curved bands round the body.
        sw = math.sin(math.atan2(co.x, co.y) * 2.0 + co.z * 5.0)
        c = L.mix(c, C("dff0ff"), L.smooth(0.85, 1.0, sw) * 0.7)
        return L.mix(c, c * 0.85, L.smooth(1.0, 0.2, co.z) * 0.4)

    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    wh = {"Head": 1.0}
    for c, r in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        K.fierce_eye(parts, c, r * 0.85, Vector((0.4 * sx, -1.0, 0.0)), wh, C("e8f4ff"), lid_dark=C("7aa8e0"),
                     ball=C("c8fbff"), slit=None, tilt=0.3, open_=0.3, lower_lid=0.6, ring=C("2ab8e8"))
    # Two long plumes streaming back from the crest.
    for sx in (-1.0, 1.0):
        p, n = dir_hit(surf, Vector((0.0, 0.0, 2.3)), Vector((0.35 * sx, 0.2, 1.0)))
        if p is None:
            continue
        for k, (ln, wd, lift) in enumerate(((1.35, 0.26, 0.05), (0.95, 0.19, 0.25))):
            parts.blob(p - n * 0.05, (wd, wd * 0.22), Vector((0.35 * sx, 1.0, lift)), ln, None, weights=wh, seg=8,
                       rings=8, tip=0.3, up=Vector((0, 0, 1)), bend=Vector((0.2 * sx, 0.1, 0.25 - 0.15 * k)),
                       color_fn=lambda t: L.mix(C("ffffff"), C("9ad4ff"), L.smooth(0.45, 1.0, t)))
    # Cloud puffs round the tail and on the shoulders.
    rng = random.Random(6)
    for k in range(9):
        z = 0.2 + 0.12 * k
        a = rng.uniform(0, 2 * math.pi)
        c = Vector((math.cos(a) * 0.25, 0.45 + math.sin(a) * 0.25, z))
        s = 0.3 - 0.015 * k
        parts.ellipsoid(c, (s, s, s * 0.8), color=None, weights=c, seg=10, rings=7,
                        color_fn=lambda u: L.mix(C("c8dcf8"), C("ffffff"), L.smooth(-0.6, 0.6, u.z)))
    for sx in (-1.0, 1.0):
        c = Vector((0.5 * sx, 0.15, 1.9))
        for k in range(3):
            q = c + Vector((0.15 * k * sx, rng.uniform(-0.08, 0.08), 0.05 * (1 - k)))
            s = 0.2 - 0.03 * k
            parts.ellipsoid(q, (s, s, s * 0.8), color=None, weights=q, seg=10, rings=7,
                            color_fn=lambda u: L.mix(C("c8dcf8"), C("ffffff"), L.smooth(-0.6, 0.6, u.z)))
    # Sky ribbons trailing from the wrists.
    for side, sx in (("L", 1.0), ("R", -1.0)):
        b = arm.data.bones["LowerArm." + side]
        c = b.head_local.lerp(b.tail_local, 0.7)
        w = {"LowerArm." + side: 1.0}
        torus(parts, c, Vector((1, 0, 0)), 0.17, 0.045, lambda u, v: C("ffe9a8"), w, seg=14, sides=5)
        parts.blob(c + Vector((0, 0.1, -0.05)), (0.2, 0.03), Vector((0.1 * sx, 1.0, -0.5)), 1.15, None, weights=w,
                   seg=8, rings=8, tip=0.55, up=Vector((1, 0, 0)), bend=Vector((0.2 * sx, 0.1, 0.35)),
                   color_fn=lambda t: L.mix(C("8ad0ff"), C("e8f8ff"), t))
    # Glowing wind spiral on the chest and swirl runes on the arms.
    p, n = front_hit(surf, 0.0, 1.55)
    if p is not None:
        spiral = [(math.cos(t * 4.0) * 0.02 * t * 3.0, math.sin(t * 4.0) * 0.02 * t * 3.0)
                  for t in [i * 0.25 for i in range(15)]]
        parts.stroke(p, n, spiral, 0.035, C("c8faff"), detail="glow2", taper=False, lift=0.014)
    for side, sx in (("L", 1.0), ("R", -1.0)):
        b = arm.data.bones["UpperArm." + side]
        c = b.head_local.lerp(b.tail_local, 0.55)
        q, n = surf.toward(c + Vector((0, -2.0, 0.6)), c)
        if q is not None:
            arc = [(math.cos(a) * 0.12 * (1 - a / 9), math.sin(a) * 0.12 * (1 - a / 9)) for a in
                   [i * 0.5 for i in range(11)]]
            parts.stroke(q, n, arc, 0.03, C("c8faff"), detail="glow2", taper=False, lift=0.012)
    K.join_parts(body, parts.to_object())
    L.bake_ao(body, strength=0.35, shade=Vector((0.6, 0.7, 0.9)))
    return {"glow": "c8fbff", "strength": 1.5, "glow2": "a8f0ff", "strength2": 1.3}


def F_ellipse(rx, ry, n=16):
    return [(math.cos(2 * math.pi * i / n) * rx, math.sin(2 * math.pi * i / n) * ry) for i in range(n)]


# ================================================================ registry / runner

RECIPES = {
    "flying/Hywirl_sky_wind_spirit": sky_wind_spirit,
    "flying/Squidle_tide_squid": tide_squid,
    "flying/Glub_Evolved_drown_jelly": drown_jelly,
    "flying/Ghost_Skull_eclipse_wraith": eclipse_wraith,
    "flying/Ghost_Skull_star_wraith": star_wraith,
    "flying/Ghost_abyss_ghost": abyss_ghost,
    "flying/Ghost_lotus_sprite": lotus_sprite,
}
SOURCE = {
    "flying/Hywirl_sky_wind_spirit": "flying/Hywirl",
    "flying/Squidle_tide_squid": "flying/Squidle",
    "flying/Glub_Evolved_drown_jelly": "flying/Glub_Evolved",
    "flying/Ghost_Skull_eclipse_wraith": "flying/Ghost_Skull",
    "flying/Ghost_Skull_star_wraith": "flying/Ghost_Skull",
    "flying/Ghost_abyss_ghost": "flying/Ghost",
    "flying/Ghost_lotus_sprite": "flying/Ghost",
}


def build(name):
    import bpy
    L.reset()
    arm, body = L.load(os.path.join(F.SRC, SOURCE[name] + ".gltf"))
    K.atlas_regions(body)
    clips = sorted(a.name for a in bpy.data.actions)
    before = L.tri_count(body)
    opts = RECIPES[name](arm, body) or {}
    out = os.path.join(F.OUT, name + ".glb")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    K.export(arm, body, out, clips, glow=opts.get("glow", "ffc040"), glow2=opts.get("glow2"),
             strength=opts.get("strength", 1.6), strength2=opts.get("strength2", 1.6))
    print("REMASTER %s tris %d -> %d, %d bytes, clips %s" % (name, before, L.tri_count(body), os.path.getsize(out),
                                                          ",".join(clips)))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    for name in (args or list(RECIPES)):
        build(name)
