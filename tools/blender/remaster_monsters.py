"""Remasters Quaternius monster rigs into smoother, cuter, hand-painted-looking models.

    /opt/bpy5/bin/python tools/blender/remaster_monsters.py [blob/PinkBlob ...]

Reads assets/models/monsters/<dir>/<Name>.gltf, writes
assets/models/monsters/remaster/<dir>/<Name>.glb, which MonsterVisual loads in its place
(same rig, bone names and clip names). With no arguments every recipe is rebuilt.
Built and checked with Blender 5.3 (bpy). Re-import in Godot afterwards.

A recipe is a function (arm, body) -> None that reshapes the body, paints it and adds
parts; the shared steps (load, AO, export, clip check) live in remaster_lib.

Adding a monster: write a recipe (usually: drop the old eye faces, clean, subdivide or
decimate to ~4-5k tris, paint_body with a gradient, sparkly_eye / cheek / smile_mouth on
the face bone, a few characterful parts, bake_ao), register it in RECIPES, run this
script, import twice in Godot, then compare with
    godot --rendering-driver opengl3 --path . res://tests/tools/remaster_review.tscn -- <outdir> orig|new <ids>
Keep each model under ~8k tris; MonsterData tints still multiply the painted colours.
"""
import math
import random
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import remaster_lib as L  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "models", "monsters")
OUT = os.path.join(SRC, "remaster")

C = L.srgb
WHITE = C("ffffff")
INK = C("2a1530")


# ---------------------------------------------------------------- shared face kit

def front_hit(surf, x, z, from_y=-6.0):
    """Where a ray from far in front (at x, z) meets the body: (point, normal)."""
    return surf.toward(Vector((x, from_y, z)), Vector((x, 0.0, z)))


def ellipse(rx, ry, n=20, rot=0.0):
    out = []
    for i in range(n):
        a = 2.0 * math.pi * i / n
        x, y = math.cos(a) * rx, math.sin(a) * ry
        out.append((x * math.cos(rot) - y * math.sin(rot), x * math.sin(rot) + y * math.cos(rot)))
    return out


def sparkly_eye(parts, center, radius, gaze, iris_top, iris_bottom, weights, iris=0.66, pupil=0.36,
                sclera=WHITE, sclera_shade=C("d9dcf2"), look_up=Vector((0, 0, 1)), oval=1.12, lid=None):
    """A glossy cartoon eyeball: white ball, big gradient iris, dark pupil, two glints.
    gaze: unit direction the iris faces. lid: optional colour for a soft upper lid."""
    small = radius < 0.25  # small eyes on big creatures need fewer sides
    parts.ellipsoid(center, (radius, radius, radius), color=None, weights=weights, seg=14 if small else 20,
                    rings=9 if small else 12,
                    color_fn=lambda u: L.mix(sclera, sclera_shade, L.smooth(0.2, -0.9, u.z) * 0.8))

    def iris_col(x, y):
        return L.mix(iris_bottom, iris_top, L.smooth(-0.9, 0.7, y))

    parts.sphere_cap(center, radius, gaze, (iris * 0.92, iris * oval), None, weights, lift=0.012, up=look_up,
                     color_fn=iris_col, seg=24, rings=4)
    dark = L.mix(iris_top, C("12081a"), 0.75)
    parts.sphere_cap(center, radius, gaze, (pupil * 0.9, pupil * oval), dark, weights, lift=0.024, up=look_up,
                     offset=(0.0, -0.04), seg=20, rings=2)
    # Iris ring glow along the bottom (reads as depth).
    parts.sphere_cap(center, radius, gaze, (iris * 0.42, iris * 0.18), L.mix(iris_bottom, WHITE, 0.35), weights,
                     lift=0.03, up=look_up, offset=(0.0, -iris * 0.62), seg=16, rings=2)
    parts.sphere_cap(center, radius, gaze, (iris * 0.30, iris * 0.30 * oval), WHITE, weights, lift=0.04,
                     up=look_up, offset=(-iris * 0.38, iris * 0.42), seg=16, rings=2)
    parts.sphere_cap(center, radius, gaze, (iris * 0.13, iris * 0.13), WHITE, weights, lift=0.04, up=look_up,
                     offset=(iris * 0.40, -iris * 0.22), seg=12, rings=1)
    if lid is not None:
        parts.sphere_cap(center, radius * 1.03, Vector((gaze.x, gaze.y, gaze.z + 1.6)).normalized(),
                         (1.05, 0.62), lid, weights, lift=0.02, up=look_up, seg=24, rings=5, detail=False)


def cheek(parts, point, normal, rx, ry, color, shine=True):
    parts.decal(point, normal, ellipse(rx, ry, 20), color, rings=3)
    if shine:
        parts.decal(point + Vector((0, 0, ry * 0.25)), normal, ellipse(rx * 0.28, ry * 0.22, 10),
                    L.mix(color, WHITE, 0.6), lift=0.02, rings=1)


def smile_mouth(parts, point, normal, w, h, lip, tongue, up=Vector((0, 0, 1))):
    """A happy open 'D' mouth: flat top, round bottom, with a tongue."""
    pts = []
    n = 18
    for i in range(n + 1):
        a = math.pi + math.pi * i / n  # bottom half, left to right
        pts.append((math.cos(a) * w, math.sin(a) * h))
    # gently curved top lip, right to left
    for i in range(1, 6):
        t = i / 6.0
        x = w * (1.0 - 2.0 * t)
        pts.append((x, h * 0.18 * (1.0 - (x / w) ** 2)))
    pts = [(x, y + h * 0.35) for x, y in pts]
    parts.decal(point, normal, pts, lip, rings=3, up=up)
    parts.decal(point + Vector((0, 0, -h * 0.28)), normal, ellipse(w * 0.55, h * 0.34, 16), tongue, lift=0.02,
                rings=2, up=up)


def gloss(parts, point, normal, size, color, up=Vector((0, 0, 1))):
    """A painted jelly highlight: a curved streak plus a dot."""
    path = [(math.cos(a) * size, math.sin(a) * size * 0.8) for a in
            [math.radians(d) for d in range(95, 185, 10)]]
    parts.stroke(point, normal, path, size * 0.32, color, up=up)
    parts.decal(point + Vector((0, 0, -size * 0.55)), normal, ellipse(size * 0.13, size * 0.13, 10), color,
                lift=0.016, rings=1, up=up)


def dir_hit(surf, center, direction):
    """Where a ray from far out along direction, aimed back at center, meets the body."""
    d = direction.normalized()
    return surf.toward(center + d * 8.0, center)


def bubbles(parts, surf, spots, base, size, center=Vector((0, 0, 0.9))):
    """Jelly bubbles: light rings with a glint. spots: [(direction, scale)]."""
    for (d, s) in spots:
        p, n = dir_hit(surf, center, d)
        if p is None:
            continue
        parts.decal(p, n, ellipse(size * s, size * s, 14), L.mix(base, WHITE, 0.38), rings=2)
        side = n.cross(Vector((0, 0, 1)))
        side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
        parts.decal(p + side * size * s * 0.25 + Vector((0, 0, size * s * 0.3)), n,
                    ellipse(size * s * 0.22, size * s * 0.22, 8), L.mix(base, WHITE, 0.85), lift=0.02, rings=1)


def fibonacci(n):
    out = []
    for i in range(n):
        z = 1.0 - 2.0 * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1.0 - z * z))
        a = i * math.pi * (3.0 - math.sqrt(5.0))
        out.append(Vector((r * math.cos(a), r * math.sin(a), z)))
    return out


def basis(z):
    t_, b_, n_ = L.frame(z)
    return Matrix((t_, b_, n_)).transposed()


def flower(parts, center, normal, size, petal, middle, weights, petals=5, turn=0.0):
    """A five-petal flower facing along normal: soft petals pale at the heart, a domed middle."""
    t_, b_, n_ = L.frame(normal)
    for i in range(petals):
        a = turn + 2.0 * math.pi * i / petals
        d = (t_ * math.cos(a) + b_ * math.sin(a) + n_ * 0.2).normalized()
        parts.blob(center, (size * 0.42, size * 0.2), d, size, None, weights=weights, seg=10, rings=6, tip=0.8,
                   color_fn=lambda along: L.mix(L.mix(petal, WHITE, 0.55), petal, L.smooth(0.0, 0.7, along)),
                   up=n_)
    parts.ellipsoid(center + n_ * size * 0.12, (size * 0.32, size * 0.32, size * 0.2), basis(n_), color=None,
                    weights=weights, seg=12, rings=6,
                    color_fn=lambda u: L.mix(L.mix(middle, C("e0782a"), 0.5), middle, L.smooth(-0.2, 0.8, u.z)))


def jelly_paint(top, mid, bottom, glow, height, tip=None):
    """Jelly body: light crown, rich middle, warm glowing base (light passing through),
    lighter where it faces you; optional lighter colour on anything that sticks out."""

    def paint(name, co, n, info):
        h = co.z / height
        c = L.mix(mid, top, L.smooth(0.42, 0.95, h))
        c = L.mix(c, bottom, L.smooth(0.42, 0.08, h))
        c = L.mix(c, glow, L.smooth(0.25, 0.0, h) * 0.8)
        c = L.mix(c, glow, max(0.0, -n.y) * 0.15)
        if tip is not None:
            c = L.mix(c, tip, L.smooth(0.03, 0.14, info["bump"]))
        return c

    return paint


# ---------------------------------------------------------------- recipes

def pink_slime(arm, body):
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    L.clean(body)
    L.subdivide(body, 2)
    L.inflate(body, 0.035)
    lo, hi = L.bounds(body)
    height = hi.z - lo.z
    L.paint_body(body, jelly_paint(C("ffc9e3"), C("ff8cc0"), C("f2649f"), C("ffb3d8"), height))
    surf = L.Surface(body)
    parts = L.Parts(surf)
    for sx in (-1.0, 1.0):
        c = Vector((0.45 * sx, -0.6, 1.24))
        gaze = Vector((0.2 * sx, -1.0, -0.06)).normalized()
        sparkly_eye(parts, c, 0.31, gaze, C("4a1650"), C("e0559b"), {"Head2": 1.0})
        p, n = front_hit(surf, 0.6 * sx, 0.8)
        cheek(parts, p, n, 0.16, 0.095, C("ff4f86"))
    p, n = front_hit(surf, 0.0, 0.88)
    smile_mouth(parts, p, n, 0.19, 0.16, C("7a1640"), C("ff7da3"))
    p, n = front_hit(surf, -0.45, 1.6)
    gloss(parts, p, n, 0.26, C("fff0f7"))
    p, n = dir_hit(surf, Vector((0, 0, 0.9)), Vector((0.5, 0.7, 0.75)))
    gloss(parts, p, n, 0.24, C("fff0f7"))
    bubbles(parts, surf, [(Vector((0.75, -0.6, -0.45)), 1.0), (Vector((0.95, -0.2, -0.2)), 0.6),
                          (Vector((-0.8, -0.5, -0.55)), 0.75), (Vector((0.3, -0.9, -0.75)), 0.5),
                          (Vector((-0.6, 0.8, -0.3)), 0.9), (Vector((0.4, 0.9, -0.5)), 0.6),
                          (Vector((-0.2, 0.95, 0.2)), 0.5)], C("ff8cc0"), 0.085)
    L.join_parts(body, parts.to_object())
    L.bake_ao(body)


def green_slime(arm, body):
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 4200)
    L.inflate(body, 0.02)
    lo, hi = L.bounds(body)
    height = hi.z - lo.z
    L.paint_body(body, jelly_paint(C("d2f78a"), C("86dc5c"), C("4dab4f"), C("b9f58a"), height, tip=C("f4ffb0")))
    surf = L.Surface(body)
    parts = L.Parts(surf)
    sparkly_eye(parts, Vector((0.015, -0.74, 0.86)), 0.4, Vector((0.0, -1.0, -0.02)).normalized(), C("5a2a0a"),
                C("f6b032"), {"Head": 1.0}, iris=0.6, pupil=0.32)
    for sx in (-1.0, 1.0):
        p, n = front_hit(surf, 0.58 * sx, 0.52)
        cheek(parts, p, n, 0.14, 0.085, C("ff7a8a"))
    p, n = front_hit(surf, 0.0, 0.36)
    smile_mouth(parts, p, n, 0.19, 0.13, C("2f4a1a"), C("ff8a8a"))
    # A little fang on the lip.
    parts.decal(p + Vector((0.06, 0, 0.04)), n, [(-0.03, 0.0), (0.0, -0.05), (0.03, 0.0)], WHITE, lift=0.022,
                rings=1)
    p, n = front_hit(surf, -0.62, 1.0)
    gloss(parts, p, n, 0.22, C("f6ffe0"))
    bubbles(parts, surf, [(Vector((0.85, -0.5, -0.4)), 1.0), (Vector((-0.85, -0.45, -0.5)), 0.7),
                          (Vector((0.6, 0.8, -0.3)), 0.8), (Vector((-0.5, 0.85, -0.45)), 0.6)],
            C("86dc5c"), 0.07)
    L.join_parts(body, parts.to_object())
    L.bake_ao(body)


def wild_chicken(arm, body):
    L.delete_faces(body, ("Eye_White",), where=lambda c, n, g: n == "Eye_Black" and abs(c.x) > 0.36)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 5000)
    L.relax(body, 4, 0.5, ("Chicken_Main",))
    lo, hi = L.bounds(body)
    height = hi.z - lo.z
    cream_top, cream_low, shade = C("fffdf7"), C("f4e7d4"), C("e6d5c4")
    comb_top, comb_low = C("ff6a52"), C("d92a34")
    beak_top, beak_low = C("ffcb52"), C("f28a1e")

    def paint(name, co, n, info):
        if name == "Chicken_Main":
            if abs(co.x) > 0.66:  # wing feathers: creamy base to white tips
                return L.mix(shade, C("ffffff"), L.smooth(0.72, 1.1, abs(co.x)))
            c = L.mix(cream_low, cream_top, L.smooth(0.15, 0.95, co.z / height))
            return L.mix(c, C("ffffff"), max(0.0, -n.y) * 0.35)
        if name == "Chicken_Red":
            return L.mix(comb_low, comb_top, L.smooth(-0.02, 0.1, info["bump"]))
        if name == "Beak":
            return L.mix(beak_low, beak_top, L.smooth(0.3, 0.8, co.z))
        return C("5a2414")  # the line between the beak halves

    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = L.Parts(surf)
    for sx in (-1.0, 1.0):
        sparkly_eye(parts, Vector((0.5 * sx, -0.38, 0.77)), 0.34, Vector((0.5 * sx, -1.0, 0.06)).normalized(),
                    C("2e170c"), C("c46a1c"), {"Head": 1.0}, iris=0.58, pupil=0.32)
        # Cross brows: the field's "furious" wild chicken.
        p, n = front_hit(surf, 0.44 * sx, 1.17)
        parts.stroke(p, n, [(0.2 * sx, 0.07), (0.05 * sx, 0.02), (-0.1 * sx, -0.06)], 0.085, C("7a2c1c"),
                     lift=0.02)
        p, n = front_hit(surf, 0.6 * sx, 0.36)
        cheek(parts, p, n, 0.12, 0.075, C("ff8f8a"))
        # Feet: three round orange toes.
        foot = Vector((0.32 * sx, -0.42, 0.05))
        for k in (-1, 0, 1):
            d = Vector((0.35 * k + 0.12 * sx, -1.0, -0.05)).normalized()
            parts.blob(foot, (0.08, 0.06), d, 0.3, None, weights={"Body": 1.0}, seg=8, rings=5, tip=0.8,
                       color_fn=lambda along: L.mix(C("ff9a2a"), C("ffc35a"), along))
    # Tail tuft: three soft feathers on the back.
    for k in (-1, 0, 1):
        base = Vector((0.1 * k, 0.58, 1.02 - 0.05 * abs(k)))
        d = Vector((0.65 * k, 0.6, 1.0)).normalized()
        parts.blob(base, (0.2, 0.07), d, 0.85 - 0.12 * abs(k), None, weights=base, seg=12, rings=8, tip=0.6,
                   color_fn=lambda along: L.mix(C("eadccb"), C("ffffff"), L.smooth(0.35, 0.9, along)),
                   up=Vector((0, 1, 0)), bend=Vector((0.1 * k, 0.15, 0.0)))
    L.join_parts(body, parts.to_object())
    L.bake_ao(body, strength=0.38, shade=Vector((0.86, 0.66, 0.58)))  # warm shade on cream feathers


def yellow_frog(arm, body):
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    L.clean(body)
    yellow_top, yellow_low, belly, spot = C("ffe14d"), C("ffc233"), C("fff2b8"), C("2a2350")
    groups = L.dominant_groups(body)

    def is_belly(co):
        return abs(co.x) < 0.45 and co.z < 2.2 and co.y < 0.0

    def paint(name, co, n, info):
        if name == "Frog_Secondary":
            return L.mix(belly, C("fffbe6"), L.smooth(1.0, 1.8, co.z)) if is_belly(co) else spot
        c = L.mix(yellow_low, yellow_top, L.smooth(0.5, 2.5, co.z))
        c = L.mix(c, C("ff9a1e"), max(0.0, n.y) * 0.25)  # warmer back
        return L.mix(c, C("fff3a0"), max(0.0, -n.z) * 0.4)  # pale underside

    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = L.Parts(surf)
    for sx in (-1.0, 1.0):
        side = "L" if sx > 0 else "R"
        sparkly_eye(parts, Vector((0.31 * sx, -0.43, 2.46)), 0.205, Vector((0.35 * sx, -1.0, 0.12)).normalized(),
                    C("2a1606"), C("e89a14"), {"Head": 1.0}, iris=0.62, pupil=0.36)
        p, n = front_hit(surf, 0.37 * sx, 2.22)
        cheek(parts, p, n, 0.075, 0.045, C("ff9a78"))
        # Toe pads on every finger tip...
        for f in ("Index3", "Middle3", "Pinky3", "Thumb2"):
            b = arm.data.bones["%s.%s" % (f, side)]
            parts.ellipsoid(b.tail_local, (0.065, 0.065, 0.055), color=None, weights={b.name: 1.0}, seg=8, rings=5,
                            color_fn=lambda u: L.mix(C("ffd36a"), C("fff4b0"), L.smooth(-0.5, 0.8, u.z)))
        # ... and three along each foot's front edge.
        foot = [body.data.vertices[i].co for i, g in enumerate(groups) if g == "Foot." + side]
        if foot:
            fy = min(v.y for v in foot)
            fz = min(v.z for v in foot)
            cx = sum(v.x for v in foot) / len(foot)
            for k in (-1, 0, 1):
                parts.ellipsoid(Vector((cx + 0.13 * k, fy + 0.05 + 0.03 * abs(k), fz + 0.05)), (0.07, 0.07, 0.05),
                                color=None, weights={"Foot." + side: 1.0}, seg=8, rings=5,
                                color_fn=lambda u: L.mix(C("ffc84a"), C("fff0a0"), L.smooth(-0.5, 0.8, u.z)))
    p, n = front_hit(surf, 0.0, 2.2)
    smile = [(x / 10.0 * 0.2, -0.06 * (1.0 - (x / 10.0) ** 2)) for x in range(-10, 11)]
    parts.stroke(p, n, smile, 0.04, C("7a3410"), lift=0.012)
    # More poison-frog spots: back, crown and thighs.
    for d, s in [(Vector((0.35, 1.0, 0.3)), 0.11), (Vector((-0.4, 1.0, -0.2)), 0.09), (Vector((0.1, 1.0, -0.6)), 0.08),
                 (Vector((-0.2, 1.0, 0.8)), 0.07), (Vector((0.6, 0.6, -0.4)), 0.06), (Vector((-0.75, 0.3, 0.1)), 0.06)]:
        p, n = dir_hit(surf, Vector((0, 0.1, 1.6)), d)
        if p is not None:
            parts.decal(p, n, ellipse(s, s * 0.85, 16, rot=0.4), spot, rings=2)
    for sx in (-1.0, 1.0):
        p, n = dir_hit(surf, Vector((0.35 * sx, 0.2, 0.75)), Vector((0.8 * sx, 0.3, 0.2)))
        if p is not None:
            parts.decal(p, n, ellipse(0.07, 0.06, 14), spot, rings=2)
    L.join_parts(body, parts.to_object())
    L.bake_ao(body)


def cactus_hat(arm, body):
    L.delete_small_islands(body, 3, ("Cactoro_Secondary",))
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    hat = L.split_off(body, ("Head3",))
    L.clean(body, fill_holes=8)
    L.subdivide(body, 1)
    L.decimate_to(body, 3000)
    L.clean(hat, quads=False)
    L.join(body, hat)
    green_top, green_low, rib = C("b4e870"), C("4fae4a"), C("d8f59a")
    straw_top, straw_low = C("ffd27a"), C("d98b38")

    def paint(name, co, n, info):
        if info["bone"] == "Head3":
            if name == "Cactoro_Red":
                return C("ef4b4b")
            if name == "Cactoro_Main":
                return C("42c46a")
            return L.mix(straw_low, straw_top, max(0.0, n.z) * 0.8 + 0.2)
        c = L.mix(green_low, green_top, L.smooth(0.0, 1.9, co.z))
        if abs(co.x) < 0.95:  # painted ribs around the trunk
            a = math.atan2(co.y, co.x)
            c = L.mix(c, rib, L.smooth(0.82, 0.98, math.cos(a * 7.0)) * 0.75)
        return c

    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = L.Parts(surf)
    groups = L.dominant_groups(body)
    sparkly_eye(parts, Vector((0.01, -0.72, 1.12)), 0.39, Vector((0.0, -1.0, -0.05)).normalized(), C("10204a"),
                C("3d9be8"), {"Head": 1.0}, iris=0.6, pupil=0.32)
    p, n = front_hit(surf, 0.0, 0.55)
    smile_mouth(parts, p, n, 0.16, 0.12, C("3a2a12"), C("ff7f86"))
    for sx in (-1.0, 1.0):
        p, n = front_hit(surf, 0.5 * sx, 0.68)
        cheek(parts, p, n, 0.12, 0.075, C("ff8a80"))
    # Spine tufts all over the trunk and arms, keeping the face clear.
    rng = random.Random(5)
    for d in fibonacci(70):
        if d.z < -0.3:
            continue
        p, n = dir_hit(surf, Vector((0, 0, 1.0)), d)
        if p is None or p.z > 1.9 or p.z < 0.15:
            continue
        if p.y < -0.2 and abs(p.x) < 0.62 and 0.3 < p.z < 1.62:
            continue
        for _k in range(3):
            jitter = Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(-0.3, 0.5)))
            dd = (n + jitter * 0.7).normalized()
            parts.blob(p - n * 0.01, 0.028, dd, 0.17, None, weights=p, detail=True, seg=4, rings=2, tip=0.05,
                       color_fn=lambda along: L.mix(C("e9dcb0"), C("ffffff"), along))
    # Arm-tip flowers.
    for sx, petal, middle in ((-1.0, C("ff7ab6"), C("ffe066")), (1.0, C("ffd84a"), C("ff9a3a"))):
        side = [v.co for v in body.data.vertices if v.co.x * sx > 0.5 and groups[v.index] != "Head3"]
        tip = max(side, key=lambda v: v.z + abs(v.x) * 0.6)
        p, n = dir_hit(surf, tip - Vector((0.25 * sx, 0, 0.25)), Vector((0.4 * sx, -0.3, 1.0)))
        if p is not None:
            flower(parts, p, (n + Vector((0, -0.4, 0.3))).normalized(), 0.2, petal, middle, weights=p)
    # A big flower tucked into the hat band, front-left of how the hat sits in game.
    hat = [v.co for v in body.data.vertices if groups[v.index] == "Head3"]
    hat_center = sum(hat, Vector()) / len(hat)
    pose = L.pose_matrix(arm, "Head3")
    want = pose.inverted() @ (pose @ hat_center + Vector((-0.45, -0.8, 0.55)))
    p, n = surf.toward(want + (want - hat_center).normalized() * 2.0, hat_center)
    if p is not None:
        flower(parts, p, n, 0.3, C("ff5fa2"), C("ffe066"), weights={"Head3": 1.0}, turn=0.3)
    L.join_parts(body, parts.to_object())
    L.bake_ao(body)


def cap_spots(parts, surf, center, count, size, color, min_z=0.25, seed=3, skip=None):
    """White toadstool spots scattered over a cap (rays from its centre)."""
    rng = random.Random(seed)
    placed = []
    for d in fibonacci(count * 4):
        if d.z < min_z or len(placed) >= count:
            continue
        p, n = dir_hit(surf, center, d)
        if p is None or any((p - q).length < size * 2.6 for q in placed) or (skip and skip(p)):
            continue
        placed.append(p)
        s = size * rng.uniform(0.7, 1.15)
        parts.decal(p, n, ellipse(s, s * rng.uniform(0.8, 1.0), 18, rot=rng.uniform(0, 3.1)), color, rings=3)


def mush_baby(arm, body):
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    L.clean(body)
    L.subdivide(body, 2)
    L.decimate_to(body, 4200)
    L.relax(body, 2, 0.4)
    L.inflate(body, 0.02)
    cap_top, cap_rim, gill = C("8fdcff"), C("3a8fd8"), C("fff1d9")
    skin_top, skin_low = C("fff4e3"), C("f0c99c")

    def paint(name, co, n, info):
        if name == "MushroomKing_Secondary":
            c = L.mix(cap_rim, cap_top, L.smooth(2.0, 3.1, co.z))
            return L.mix(c, gill, L.smooth(-0.1, -0.6, n.z))
        c = L.mix(skin_low, skin_top, L.smooth(0.0, 1.6, co.z))
        return L.mix(c, C("ffffff"), max(0.0, -n.y) * 0.2)

    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = L.Parts(surf)
    for sx in (-1.0, 1.0):
        sparkly_eye(parts, Vector((0.455 * sx, -0.57, 1.27)), 0.31, Vector((0.22 * sx, -1.0, -0.06)).normalized(),
                    C("3a1a0c"), C("c8742a"), {"Head": 1.0}, iris=0.62, pupil=0.34)
        p, n = front_hit(surf, 0.62 * sx, 0.86)
        cheek(parts, p, n, 0.14, 0.085, C("ff8f8f"))
    p, n = front_hit(surf, 0.0, 0.86)
    smile_mouth(parts, p, n, 0.17, 0.14, C("6a2a1a"), C("ff8a8a"))
    cap_spots(parts, surf, Vector((0, -0.2, 2.2)), 8, 0.19, C("ffffff"), min_z=0.05)
    L.join_parts(body, parts.to_object())
    L.bake_ao(body)


def mush_king(arm, body):
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    L.clean(body)
    L.decimate_to(body, 4600)
    cap_top, cap_rim, gill = C("8fdcff"), C("3a8fd8"), C("fff1d9")
    skin_top, skin_low = C("fff1de"), C("e9bf8e")
    leaf_top, leaf_low = C("a6e35a"), C("4f9e3a")

    def paint(name, co, n, info):
        bone = info["bone"]
        held = bone.startswith(("Middle", "Index", "Pinky", "Thumb")) and co.x > 1.35
        if name == "Orc_Main":
            return L.mix(leaf_low, leaf_top, L.smooth(0.42, 0.86, co.z))
        if name == "MushroomKing_Secondary":
            if bone in ("Head", "Neck"):
                c = L.mix(cap_rim, cap_top, L.smooth(2.7, 3.5, co.z))
                return L.mix(c, gill, L.smooth(-0.1, -0.6, n.z))
            # little mushrooms growing on the arms and the one in hand: blue, pale tips
            return L.mix(cap_rim, C("bfe9ff"), L.smooth(0.0, 0.08, info["bump"]))
        if held:
            return C("f8e3c4")
        c = L.mix(skin_low, skin_top, L.smooth(0.3, 2.4, co.z))
        return L.mix(c, C("fff8ee"), max(0.0, -n.y) * 0.25)

    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = L.Parts(surf)
    for sx in (-1.0, 1.0):
        sparkly_eye(parts, Vector((0.335 * sx, -0.36, 2.29)), 0.19, Vector((0.3 * sx, -1.0, -0.02)).normalized(),
                    C("3a0e0e"), C("e04a2a"), {"Head": 1.0}, iris=0.6, pupil=0.32)
        # Stern royal brows.
        p, n = front_hit(surf, 0.33 * sx, 2.53)
        parts.stroke(p, n, [(0.17 * sx, 0.05), (0.04 * sx, 0.0), (-0.09 * sx, -0.05)], 0.06, C("6a3a1a"), lift=0.02)
        p, n = front_hit(surf, 0.42 * sx, 2.08)
        cheek(parts, p, n, 0.08, 0.05, C("ff9a80"))
    p, n = front_hit(surf, 0.0, 2.04)
    smile_mouth(parts, p, n, 0.13, 0.1, C("5a1e10"), C("ff7f7a"))
    cap_spots(parts, surf, Vector((0, -0.15, 2.9)), 9, 0.15, C("ffffff"), min_z=0.0)
    # The king's golden crown on top of the cap, with a ruby on the front.
    apex, _an = dir_hit(surf, Vector((0, -0.15, 3.0)), Vector((0, 0, 1)))
    gold, gold_dark = C("ffd84a"), C("e39a1c")
    base = apex - Vector((0, 0, 0.12))
    w = {"Head": 1.0}
    parts.frustum(base, Vector((0, 0, 1)), 0.42, 0.5, 0.32,
                  lambda t, side: L.mix(gold_dark, gold, 0.35 + 0.65 * t) if side else gold, w, seg=28)
    for i in range(5):
        a = math.pi * 0.5 + 2.0 * math.pi * i / 5
        rim = base + Vector((math.cos(a) * 0.46, math.sin(a) * 0.46, 0.27))
        d = Vector((math.cos(a) * 0.25, math.sin(a) * 0.25, 1.0)).normalized()
        parts.blob(rim, (0.1, 0.06), d, 0.3, None, weights=w, seg=8, rings=5, tip=0.25,
                   color_fn=lambda along: L.mix(gold_dark, C("fff2a0"), along),
                   up=Vector((math.cos(a), math.sin(a), 0)))
        parts.ellipsoid(rim + d * 0.3, (0.06, 0.06, 0.06), color=None, weights=w, seg=8, rings=5,
                        color_fn=lambda u: L.mix(C("ff3b6b"), C("ffc2d4"), L.smooth(0.0, 1.0, u.z)))
    gem = base + Vector((0, -0.47, 0.16))
    parts.ellipsoid(gem, (0.1, 0.05, 0.11), color=None, weights=w, seg=12, rings=8,
                    color_fn=lambda u: L.mix(C("c4103c"), C("ff8aa8"), L.smooth(-0.3, 1.0, u.z)))
    L.join_parts(body, parts.to_object())
    L.bake_ao(body)


RECIPES = {
    "blob/PinkBlob": pink_slime,
    "blob/GreenBlob": green_slime,
    "blob/Chicken": wild_chicken,
    "big/Frog": yellow_frog,
    "blob/Cactoro": cactus_hat,
    "blob/Mushnub": mush_baby,
    "big/MushroomKing": mush_king,
}
RECIPES.update(__import__("recipes_brutes").RECIPES)  # the fierce monsters (team brutes)


def build(name):
    import bpy
    L.reset()
    arm, body = L.load(os.path.join(SRC, name + ".gltf"))
    clips = sorted(a.name for a in bpy.data.actions)
    before = L.tri_count(body)
    RECIPES[name](arm, body)
    out = os.path.join(OUT, name + ".glb")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    L.export(arm, body, out, clips)
    print("REMASTER %s tris %d -> %d, %d bytes, clips %s" % (name, before, L.tri_count(body), os.path.getsize(out),
                                                          ",".join(clips)))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    for name in (args or list(RECIPES)):
        build(name)
