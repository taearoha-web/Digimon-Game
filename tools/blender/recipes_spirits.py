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


def F_ellipse(rx, ry, n=16):
    return [(math.cos(2 * math.pi * i / n) * rx, math.sin(2 * math.pi * i / n) * ry) for i in range(n)]


# ================================================================ registry / runner

RECIPES = {
    "flying/Ghost_abyss_ghost": abyss_ghost,
    "flying/Ghost_lotus_sprite": lotus_sprite,
}
SOURCE = {
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
