"""Team dawncrystal's remasters (see remaster_monsters.py for the pipeline):

    /opt/bpy5/bin/python tools/blender/recipes_dawncrystal.py [dawn/Crab ...]

The dawn forest (star 1) cast, the crystal valley animals (star 50) and the abyss's coral
hermit crab. Output names are remaster/<dir>/<Name>.glb; a name with a monster id suffix
("star/Wolf_crystal_fang") is that monster's own VARIANT of the shared rig, and its data
"model" points at "remaster/<dir>/<Name>" directly. SOURCE maps every output to its rig.
Every model here is painted in its monster's own palette (their data carries no tint),
with eyes, teeth and glows on the untinted Keep* materials.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import remaster_lib as L  # noqa: E402
import kit_critters as K  # noqa: E402
import kit_dawncrystal as Q  # noqa: E402
import remaster_monsters as M  # noqa: E402
from mathutils import Vector  # noqa: E402

V = Vector
C = L.srgb
D = Q.D
WHITE = C("ffffff")


def cute_eye(parts, *a, **kw):
    with parts.use("keep"):
        M.sparkly_eye(parts, *a, **kw)


def eye_at(surf, center, direction, radius, sink=0.45):
    """An eyeball centre sunk into the surface hit along direction from center."""
    p, n = Q.hit(surf, center, direction)
    if p is None:
        return center + direction.normalized() * radius, direction.normalized()
    return p - n * radius * sink, n


# ================================================================ dawn/Crab  dawn_fox (petal crab)

def _crab_base(body, claw_scale=1.0):
    """Drops the big black eye discs; welds; optionally enlarges the claws."""
    Q.delete_mat_islands(body, lambda m, c, s, n: m == "Black" and s.x > 0.3)
    L.clean(body)
    if claw_scale != 1.0:
        for sx in (-1.0, 1.0):
            root = V((0.72 * sx, -0.12, 0.8))
            K.scale_region(body, lambda c, sx=sx: c.x * sx > 0.62 and c.z > 0.5, root, (claw_scale,) * 3,
                           lambda c, sx=sx: L.smooth(0.62, 0.8, c.x * sx))
    L.subdivide(body, 1)
    L.decimate_to(body, 4000 if claw_scale == 1.0 else 2800)
    L.relax(body, 2, 0.3, ("Main",))


def petal_crab(arm, body):
    """ปูกลีบอรุณ dawn_fox: a round dawn-coloured crab - rosy coral below warming to peach
    and gold on top, cream underside, a five-petal sunrise blossom crowning its shell with
    rows of petal scales down its back, petal tufts on the claws, big sparkly eyes."""
    _crab_base(body)
    coral, peach, gold, cream = D("ff6a8a"), D("ffa894"), D("ffd890"), D("fff2e4")

    def paint(name, co, n, info):
        if name == "White":
            return WHITE
        if name == "Black":
            return C("5a1a32")
        if name == "Main_Dark":
            if co.z > 1.25:
                return D("ffd890")  # the crown nub: a bud under the blossom
            return D("b8405a")  # brows
        c = L.mix(coral, peach, L.smooth(0.15, 0.9, co.z))
        c = L.mix(c, gold, L.smooth(0.9, 1.45, co.z) * 0.8)
        c = L.mix(c, cream, max(0.0, -n.z) * 0.7)
        if abs(co.x) > 0.8 and co.z > 0.6:
            c = L.mix(D("ff6a80"), D("ffd0b0"), L.smooth(0.95, 1.3, abs(co.x)))  # claws: pale tips
        return c

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name in ("White", "Black") else "skin")
    surf, parts = Q.start(body)
    for sx in (-1.0, 1.0):
        c, n = eye_at(surf, V((0.34 * sx, 0.0, 0.8)), V((0.3 * sx, -1.0, 0.05)), 0.25)
        cute_eye(parts, c, 0.25, V((0.22 * sx, -1.0, 0.05)).normalized(), C("4a1a3a"), C("ff9a5a"), c,
                 iris=0.66, pupil=0.34, oval=1.2)
        p, n = M.front_hit(surf, 0.62 * sx, 0.5)
        if p is not None:
            M.cheek(parts, p, n, 0.1, 0.06, C("ff7a9a"))
    # Sunrise blossom on the crown of the shell.
    p, n = Q.hit(surf, V((0, 0.05, 0.8)), V((0, 0.15, 1)))
    pin, pout = D("fff4f0"), D("ff8ab8")
    t_, b_, n_ = L.frame(V((0, 0.12, 1)).normalized())
    for i in range(6):
        a = 2.0 * math.pi * (i + 0.5) / 6
        d = (t_ * math.cos(a) + b_ * math.sin(a) + n_ * 0.55).normalized()
        Q.petal(parts, p - n * 0.06, d, 0.62, 0.3, lambda t: L.mix(pin, pout, L.smooth(0.1, 0.9, t)), p, n_,
                tip=0.7, cup=0.08, seg=8, rings=5)
    for i in range(5):
        a = 2.0 * math.pi * i / 5
        d = (t_ * math.cos(a) + b_ * math.sin(a) + n_ * 1.3).normalized()
        Q.petal(parts, p, d, 0.4, 0.2, lambda t: L.mix(D("fff8e8"), D("ffb8d0"), t), p, n_, tip=0.7, seg=8,
                rings=5)
    parts.ellipsoid(p + n * 0.14, (0.16, 0.16, 0.11), color=None, weights=p, seg=12, rings=7,
                    color_fn=lambda u: L.mix(C("ff9a2a"), C("ffe066"), L.smooth(-0.3, 0.8, u.z)))
    # Petal scales down the back, three rows, overlapping like shingles.
    for row, (el, count, size) in enumerate(((55, 4, 0.42), (30, 5, 0.4), (5, 6, 0.36))):
        for k in range(count):
            ang = math.radians(-75 + 150 * k / (count - 1))
            e = math.radians(el)
            dirv = V((math.sin(ang) * math.cos(e), math.cos(ang) * math.cos(e), math.sin(e)))
            q, m = Q.hit(surf, V((0, 0, 0.8)), dirv)
            if q is None:
                continue
            down = (m * 0.25 + V((0, 0, -1)) + dirv * 0.35).normalized()
            Q.petal(parts, q + m * 0.02, down, size, size * 0.55,
                    lambda t: L.mix(D("ffe4ea"), D("ff86ac"), L.smooth(0.0, 1.0, t)), q, m, tip=0.75,
                    cup=-0.04, seg=8, rings=5)
    # A petal tuft on each claw.
    for sx in (-1.0, 1.0):
        q, m = Q.hit(surf, V((1.0 * sx, -0.1, 0.9)), V((0.3 * sx, 0, 1)))
        if q is not None:
            for k in range(3):
                d = (m + V((0.5 * sx * (k - 1), 0.2, 0.3))).normalized()
                Q.petal(parts, q - m * 0.02, d, 0.24, 0.12, lambda t: L.mix(pin, pout, t), q, m, tip=0.7, seg=8,
                        rings=4)
    Q.finish(body, parts)


# ================================================================ dawn/Crab variant  reef_crab

def coral_hermit(arm, body):
    """ปูเกราะปะการังโลหิต reef_crab: a hermit crab of the drowned abyss - deep crimson
    body, oversized blood-red claws with black-tipped pincers, glaring gold eyes, and a huge
    coiled bone-white shell on its back overgrown with branching blood coral and barnacles."""
    _crab_base(body, claw_scale=1.35)
    crimson, scarlet, belly = C("8a1020"), C("d0303a"), C("f0b0a0")

    def paint(name, co, n, info):
        if name == "White":
            return C("fff2e0")
        if name == "Black":
            return C("1a0408")
        if name == "Main_Dark":
            return D("8a1020") if co.z > 1.25 else D("5a0812")
        if abs(co.x) > 0.75 and co.z > 0.55:
            c = L.mix(C("b00818"), C("ff3a30"), max(0.0, n.z) * 0.6 + 0.2)  # glossy blood claws
            return L.mix(c, C("1a0406"), L.smooth(1.15, 1.45, abs(co.x)))
        c = L.mix(crimson, scarlet, L.smooth(0.1, 1.3, co.z) * 0.8)
        c = L.mix(c, belly, max(0.0, -n.z) * 0.6)
        return L.mix(c, C("5a0410"), L.smooth(0.55, 0.8, Q.noise(co, 6.0, 3)) * 0.35)

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name in ("White", "Black") else "skin")
    surf, parts = Q.start(body)
    for sx in (-1.0, 1.0):
        c, n = eye_at(surf, V((0.4 * sx, 0.0, 0.85)), V((0.4 * sx, -1.0, 0.12)), 0.17)
        K.fierce_eye(parts, c, 0.17, V((0.35 * sx, -1.0, 0.0)).normalized(), C("ffe070"), C("ff8a10"), c,
                     lid=C("6a0a18"), slant=0.45, side=sx, slit=True, iris=0.9, lid_drop=1.6)
    # Spikes along the claw tops.
    for sx in (-1.0, 1.0):
        for k in range(4):
            q, m = Q.hit(surf, V((0.95 * sx, -0.1, 0.85)), V((0.2 * sx + 0.25 * (k - 1.5), -0.2, 1)))
            if q is not None:
                Q.thorn(parts, q - m * 0.02, m, 0.13, 0.04, q, C("6a0410"), C("ffd0c0"))
    # The coiled shell, sitting on the back, its spire rising back and up.
    shell_lo, shell_hi, band = D("d8a090"), D("ffe4d4"), D("a83a30")

    def shell_col(u, i):
        c = L.mix(shell_lo, shell_hi, L.smooth(-0.6, 0.8, u.z))
        stripe = L.smooth(0.5, 0.75, math.sin(math.atan2(u.y, u.x) * 4.0 + i * 1.3) * 0.5 + 0.5)
        return L.mix(c, band, stripe * 0.85)

    origin = V((0, 0.8, 0.88))
    centres = Q.spiral_shell(parts, origin, V((0, 0.9, 1)), V((0, -1, 0.5)), 0.62, 1.7, shell_col, origin,
                             steps=7, shrink=0.7, rise=0.6)
    # a flared lip of the shell's mouth behind the head
    lip_c = origin + V((0, -0.32, -0.12))
    parts.ellipsoid(lip_c, (0.6, 0.14, 0.42), Q.basis(V((0, -1, 0.35)).normalized()), color=None, weights=origin,
                    seg=16, rings=8, color_fn=lambda u: L.mix(D("f4c8b8"), D("ff9a8a"), L.smooth(0.0, -0.9, u.z)))
    # Blood coral branches and barnacles on the shell.
    rng = random.Random(9)
    for k, (c, r, i) in enumerate(centres[:4]):
        for j in range(2 if i == 0 else (1 if i < 3 else 0)):
            a = rng.uniform(0, 2 * math.pi)
            d = V((math.cos(a) * 0.9, math.sin(a) * 0.6 + 0.35, 0.8)).normalized()
            Q.coral(parts, c + d * r * 0.8, d, 0.5 * (1.0 - 0.15 * i), 0.085, origin, C("8a0612"), C("ff3a2a"),
                    depth=2, seed=31 + k * 5 + j, spread=0.7)
        for j in range(4 if i < 3 else 2):
            a = 2.0 * math.pi * j / 4 + i
            d = V((math.cos(a), math.sin(a), 0.25)).normalized()
            Q.thorn(parts, c + d * r * 0.9, (d + V((0, 0, 0.3))).normalized(), r * 0.5, r * 0.16, origin,
                    D("c86a5a"), D("fff0e4"))
        for j in range(2):
            a = rng.uniform(0, 2 * math.pi)
            d = V((math.cos(a), math.sin(a), rng.uniform(-0.2, 0.8))).normalized()
            parts.ellipsoid(c + d * r * 0.97, (0.07, 0.07, 0.05), Q.basis(d), color=None, weights=origin, seg=8,
                            rings=5, color_fn=lambda u: L.mix(C("9a8a80"), C("f0e8dc"), L.smooth(-0.2, 0.9, u.z)))
    Q.finish(body, parts)


# ================================================================ dawn/Enemy  dawn_deer (leaf goblin)

def leaf_spirit(arm, body):
    """ภูตเขาใบไม้ dawn_deer: a mischievous little forest spirit - fresh leaf-green body
    shading to moss below, its stubby horns turned into knotted twig antlers, a crown of
    big leaves sprouting from its head, leafy ears, cheeky amber eyes under green lids."""
    Q.delete_mat_islands(body, lambda m, c, s, n: m == "Eyes")
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 4200)
    L.relax(body, 2, 0.3, ("Main",))
    moss, leafc, lime = D("3a8a40"), D("6ccc58"), D("ccf080")

    def paint(name, co, n, info):
        if name == "Teeth":
            return WHITE
        if name == "Tongue":
            return C("c84a5a")
        if name == "Horns":
            return L.mix(C("6a4426"), C("c8a060"), L.smooth(1.0, 1.55, co.z))
        if name == "Main_Dark":
            return C("1e5a28")
        c = L.mix(moss, leafc, L.smooth(0.0, 0.9, co.z))
        c = L.mix(c, lime, L.smooth(0.9, 1.5, co.z) * 0.8)
        c = L.mix(c, C("e8f8b0"), max(0.0, -n.y) * L.smooth(0.2, 0.7, co.z) * 0.15)
        return L.mix(c, C("1e5a28"), L.smooth(0.62, 0.85, Q.noise(co, 5.0, 2)) * 0.25)

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name in ("Teeth", "Tongue") else "skin")
    surf, parts = Q.start(body)
    for sx in (-1.0, 1.0):
        c, n = eye_at(surf, V((0.42 * sx, 0.0, 0.8)), V((0.42 * sx, -1.0, 0.0)), 0.2)
        K.fierce_eye(parts, c, 0.2, V((0.3 * sx, -1.0, 0.02)).normalized(), C("ffe27a"), C("e8901a"), c,
                     lid=D("4aaa48"), slant=0.3, side=sx, slit=False, iris=0.78, lid_drop=2.3)
        p, n = M.front_hit(surf, 0.6 * sx, 0.55)
        if p is not None:
            M.cheek(parts, p, n, 0.09, 0.05, C("ffa07a"))
        # twig tines on the horns
        q = V((0.95 * sx, 0.0, 1.45))
        for k, d in enumerate((V((0.2 * sx, -0.3, 1)), V((0.6 * sx, 0.3, 0.6)))):
            parts.blob(q - V((0.12 * sx, 0, 0.1)) * k, 0.045, d.normalized(), 0.28, None, weights=q, seg=6,
                       rings=4, tip=0.3, color_fn=lambda t: L.mix(C("6a4426"), C("c8a060"), t))
        Q.leaf(parts, q + V((0.05 * sx, 0, 0.18)), V((0.5 * sx, -0.4, 0.8)), 0.42, 0.17, D("4aa040"), D("c0ee70"),
               q, V((0, -1, 0.3)).normalized())
    # A crown of leaves.
    p, n = Q.hit(surf, V((0, 0, 0.8)), V((0, 0.1, 1)))
    rng = random.Random(4)
    for i in range(7):
        a = math.radians(-80 + 160 * i / 6)
        d = V((math.sin(a) * 0.75, 0.25 + math.cos(a) * 0.15, 1.0)).normalized()
        ln = 0.8 if i == 3 else rng.uniform(0.52, 0.66)
        Q.leaf(parts, p - n * 0.05 + V((math.sin(a) * 0.12, 0.05, 0)), d, ln, ln * 0.4,
               D("3aa040") if i % 2 else D("2a9050"), D("d0f47a") if i % 2 else D("a0e888"), p,
               V((0, -1, 0.2)).normalized(), cup=0.12)
    parts.blob(p + V((0, -0.05, 0)), 0.035, V((0.0, -0.3, 1.0)), 0.3, None, weights=p, seg=6, rings=5, tip=0.5,
               bend=V((0, -0.15, -0.02)), color_fn=lambda t: L.mix(C("4a9a3a"), C("9ad860"), t))
    Q.finish(body, parts)


# ================================================================ dawn/Bee  dawn_alpaca (pollen bee)

def pollen_bee(arm, body):
    """ผึ้งเกสรอรุณ dawn_alpaca (light polish): a plump honey-gold bee blushing peach
    underneath, soft cocoa stripes, rosy pollen pom antennae, glassy sunrise wings and big
    sparkly eyes."""
    Q.delete_mat_islands(body, lambda m, c, s, n: m == "Eyes")
    L.clean(body)
    L.decimate_to(body, 4800)
    gold, honey, peach, cocoa = D("ffe066"), D("ffc63a"), D("ffa880"), D("5a3020")

    def paint(name, co, n, info):
        if name == "Teeth":
            return WHITE
        if name == "Tongue":
            return C("e85a7a")
        if name == "Wings":
            return L.mix(C("bfeaff"), C("ffd4ec"), L.smooth(0.6, 1.4, abs(co.x)))
        if name == "Main_2":
            if co.z > 1.2:
                return C("6a3a2a")  # antenna stalks
            if co.y < -0.45 and co.z < 0.75:
                return C("5a1a2a")  # mouth
            return L.mix(cocoa, C("8a5a3a"), max(0.0, n.z) * 0.5)
        c = L.mix(honey, gold, L.smooth(0.2, 1.1, co.z))
        c = L.mix(c, D("fff4b8"), L.smooth(1.1, 1.5, co.z) * 0.6)
        return L.mix(c, peach, max(0.0, -n.z) * 0.6)

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name in ("Teeth", "Tongue") else
                 ("detail" if name == "Wings" else "skin"))
    surf, parts = Q.start(body)
    for sx in (-1.0, 1.0):
        c, n = eye_at(surf, V((0.43 * sx, 0.0, 0.85)), V((0.43 * sx, -1.0, 0.05)), 0.22)
        cute_eye(parts, c, 0.22, V((0.3 * sx, -1.0, 0.05)).normalized(), C("3a1a10"), C("ffa83a"), c, iris=0.66,
                 pupil=0.34, oval=1.15)
        p, n = M.front_hit(surf, 0.62 * sx, 0.55)
        if p is not None:
            M.cheek(parts, p, n, 0.1, 0.06, C("ff8a8a"))
        # rosy pollen pom on each antenna tip
        tip = V((0.42 * sx, -0.52, 1.6))
        parts.ellipsoid(tip, (0.13, 0.13, 0.13), color=None, weights=tip, seg=10, rings=7,
                        color_fn=lambda u: L.mix(C("ff7aa0"), C("ffd0e0"), L.smooth(-0.5, 0.8, u.z)))
    Q.finish(body, parts)


# ================================================================ dawn/Bunny  dawn_bunny (boxing bunny)

def boxer_bunny(arm, body):
    """กระต่ายหมัดอรุณ dawn_bunny (light polish): morning-sky blue fur with a peach face mask
    and belly, red boxing gloves with white cuffs, determined sparkly eyes under little
    brows, a pink nose and a tuft on the crown."""
    Q.delete_mat_islands(body, lambda m, c, s, n: m in ("Black", "EyeColor", "White"))
    L.clean(body)
    L.decimate_to(body, 5200)
    L.relax(body, 1, 0.3, ("Main",))
    sky, sky_hi, peach = C("5ab0ff"), C("a8dcff"), C("ffe0c0")

    def paint(name, co, n, info):
        if name == "Main_Light":
            if abs(co.x) > 1.15 and co.z > 1.0:
                if abs(co.x) < 1.3:
                    return WHITE  # glove cuff
                return L.mix(C("c8141e"), C("ff5a4a"), max(0.0, n.z) * 0.6 + 0.2)
            if co.z < 0.3:
                return L.mix(C("ffd8b8"), WHITE, 0.4)  # feet
            return L.mix(peach, C("fff4e6"), L.smooth(1.8, 2.5, co.z))
        if name == "Main2":
            return L.mix(peach, C("fff2e0"), L.smooth(0.6, 1.4, co.z))
        c = L.mix(sky, sky_hi, L.smooth(0.3, 3.2, co.z) * 0.8 + max(0.0, n.z) * 0.2)
        if co.z > 2.6 and co.y < 0.25 and abs(co.x) > 0.5:
            c = L.mix(c, C("ffb8c8"), max(0.0, -n.y) * 0.8)  # inner ears
        return c

    K.paint_body(body, paint)
    surf, parts = Q.start(body)
    for sx in (-1.0, 1.0):
        c, n = eye_at(surf, V((0.4 * sx, -0.2, 2.3)), V((0.38 * sx, -1.0, 0.05)), 0.25, sink=0.55)
        cute_eye(parts, c, 0.25, V((0.25 * sx, -1.0, 0.05)).normalized(), C("1a2a5a"), C("ffb04a"), {"Head": 1.0},
                 iris=0.66, pupil=0.36, oval=1.3)
        p, n = M.front_hit(surf, 0.42 * sx, 2.66)
        if p is not None:
            parts.stroke(p, n, [(0.13 * sx, 0.04), (0.0, 0.02), (-0.12 * sx, -0.03)], 0.05, C("2a4a8a"),
                         lift=0.02)
        p, n = M.front_hit(surf, 0.72 * sx, 2.0)
        if p is not None:
            M.cheek(parts, p, n, 0.1, 0.06, C("ff8a9a"))
    p, n = M.front_hit(surf, 0.0, 2.08)
    if p is not None:
        parts.ellipsoid(p + n * 0.02, (0.09, 0.06, 0.065), color=None, weights={"Head": 1.0}, seg=10, rings=6,
                        color_fn=lambda u: L.mix(C("ff7090"), C("ffc0d0"), L.smooth(-0.3, 0.9, u.z)))
    p, n = Q.hit(surf, V((0, 0, 2.6)), V((0, -0.2, 1)))
    if p is not None:
        for k in range(3):
            d = V((0.35 * (k - 1), -0.3, 1.0)).normalized()
            parts.blob(p - n * 0.04, (0.07, 0.04), d, 0.24, None, weights={"Head": 1.0}, seg=6, rings=4, tip=0.15,
                       bend=V((0, -0.08, -0.05)), up=V((0, -1, 0)),
                       color_fn=lambda t: L.mix(sky, sky_hi, t))
    Q.finish(body, parts)


# ================================================================ dawn/Bat  dawn_stag (dawn bat)

def dawn_bat(arm, body):
    """ค้างคาวรุ่งอรุณ dawn_stag: a bat of the first light - warm rose-peach fur with a
    lavender back, a fluffy gold chest ruff, sunrise wings (gold by the arm, rose, then
    violet at the trailing edge) on plum finger bones, a bigger head with huge ears lined
    peach, bright amber eyes, little fangs and a golden sun crest between the ears."""
    L.clean(body)
    Q.grow(body, V((0, -0.75, 3.0)), 0.45, 0.95, 1.3, pred=lambda c: c.z > 2.35)
    L.subdivide(body, 1)
    L.decimate_to(body, 4200)
    rose, peach, lav, gold = D("ff9a8a"), D("ffc8a0"), D("b89ad8"), D("ffd070")
    sh = {s_: arm.data.bones["Shoulder." + s_].head_local for s_ in ("L", "R")}

    def paint(name, co, n, info):
        bone = info["bone"]
        if name == "Nose":
            return L.mix(D("ffb0a0"), D("8a3050"), L.smooth(-1.45, -1.62, co.y))
        if name == "Belly":
            return L.mix(gold, D("fff0c0"), L.smooth(1.0, 2.4, co.z))
        if bone.startswith("Wing") or (bone.startswith("Shoulder") and abs(co.x) > 0.45):
            side = "L" if co.x > 0 else "R"
            t = (co - sh[side]).length / 2.6
            if name == "Black":
                return L.mix(D("6a3a6a"), D("9a5a7a"), t)  # finger bones
            c = L.mix(D("ffb24a"), D("ff7a8a"), L.smooth(0.15, 0.55, t))
            return L.mix(c, D("8a5ac8"), L.smooth(0.55, 0.95, t))
        if name == "Black":
            return D("5a2a4a")
        c = L.mix(rose, peach, L.smooth(1.0, 3.0, co.z) * 0.6 + max(0.0, -n.y) * 0.4)
        c = L.mix(c, lav, max(0.0, n.y) * 0.75)
        if co.z > 3.3:
            c = L.mix(c, D("ffd8c0"), max(0.0, -n.y) * 0.9)  # inner ears
        return c

    K.paint_body(body, paint)
    surf, parts = Q.start(body)
    head = {"Head": 1.0}
    for sx in (-1.0, 1.0):
        c, n = eye_at(surf, V((0.3 * sx, -0.4, 3.08)), V((0.45 * sx, -1.0, 0.15)), 0.23, sink=0.35)
        K.fierce_eye(parts, c, 0.23, V((0.3 * sx, -1.0, 0.05)).normalized(), D("ffe27a"), D("ff8a1a"), head,
                     lid=D("e88a8a"), slant=0.3, side=sx, slit=False, iris=0.8, lid_drop=3.2, lid_size=0.9)
        K.fang(parts, V((0.08 * sx, -1.22, 2.72)), V((0, -0.2, -1)), 0.14, 0.035, {"Nose": 1.0})
    # Golden sun crest between the ears.
    p, n = Q.hit(surf, V((0, -0.6, 3.0)), V((0, -0.1, 1)))
    if p is not None:
        with parts.use("glow"):
            for k in range(5):
                a = math.radians(-60 + 30 * k)
                d = V((math.sin(a), -0.15, math.cos(a))).normalized()
                parts.blob(p - n * 0.05, (0.08, 0.04), d, 0.4 if k % 2 == 0 else 0.28, None, weights=head, seg=6,
                           rings=4, tip=0.1, up=V((0, -1, 0)),
                           color_fn=lambda t: L.mix(D("ffb030"), D("fff2b0"), t))
    Q.finish(body, parts)


# ================================================================ dawn/Skull  dawn_thornhart (elite)

def thorn_skull(arm, body):
    """กะโหลกหนามพฤกษา dawn_thornhart (elite): an old beast skull the forest took back -
    weathered bone mossed over on the crown, embers of green-gold light deep in the
    sockets, thorny bramble vines wrapped around it, great thorny branch antlers with
    leaves and two wild roses, and a beard of roots reaching down to the ground."""
    Q.delete_mat_islands(body, lambda m, c, s, n: m == "Main_Light" and n > 60)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 2200)
    bone_hi, bone_lo, moss = D("f4ead0"), D("c8b088"), D("6aa040")

    def paint(name, co, n, info):
        if name == "Main_Light":
            return L.mix(D("e8dcb8"), D("fff8e8"), 0.5)  # teeth
        c = L.mix(bone_lo, bone_hi, L.smooth(-0.6, 0.7, n.z) * 0.6 + L.smooth(0.2, 1.2, co.z) * 0.4)
        c = L.mix(c, D("8a7050"), L.smooth(0.65, 0.85, Q.noise(co, 7.0, 1)) * 0.35)  # stains
        m = L.smooth(0.25, 0.7, n.z) * L.smooth(0.4, 0.62, Q.fbm(co, 3.0, 5))
        return L.mix(c, L.mix(moss, D("a8d060"), Q.noise(co, 12.0, 2)), m)

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name == "Main_Light" else "skin")
    surf, parts = Q.start(body)
    head = {"Head2": 1.0}
    wood, wood_hi = D("5a3a22"), D("a07a4a")
    vine, vine_hi = D("2e5a2a"), D("6a9a3a")
    rng = random.Random(12)
    # Ember eyes deep in the sockets.
    for sx in (-1.0, 1.0):
        sc = V((0.42 * sx, -0.22, 0.86))
        parts.ellipsoid(sc, (0.2, 0.14, 0.27), color=D("1a1008"), weights=head, seg=12, rings=8)
        with parts.use("glow"):
            parts.ellipsoid(sc + V((-0.02 * sx, -0.13, -0.04)), (0.075, 0.04, 0.05), Q.basis(V((0, -1, 0)),
                            V((0.5 * sx, 0, 1)).normalized()), color=None, weights=head, seg=10, rings=6,
                            color_fn=lambda u: L.mix(C("b8ff3a"), C("fffbd0"), L.smooth(-0.2, 0.9, -u.y)))
        # a heavy thorned brow of bark slanting down to the nose
        a_, b_ = V((0.68 * sx, -0.5, 1.22)), V((0.12 * sx, -0.66, 1.0))
        Q.tube(parts, [a_, (a_ + b_) * 0.5 + V((0, -0.05, 0.04)), b_], lambda t: 0.075 * (1.0 - 0.4 * t),
               lambda t: L.mix(wood, wood_hi, 0.3 + 0.4 * t), head, seg=7)
        for k in range(3):
            q = a_.lerp(b_, 0.2 + 0.3 * k)
            Q.thorn(parts, q, V((0.2 * sx, -0.5, 1)).normalized(), 0.13, 0.03, head, D("6a3020"), D("f0d8b0"))
    # Thorny branch antlers.
    for sx in (-1.0, 1.0):
        root = V((0.4 * sx, 0.05, 1.28))
        pts = [root + V((0.25 * sx * t + 0.35 * sx * t * t, 0.15 * t, 0.9 * t - 0.15 * t * t)) for t in
               [i / 6 for i in range(7)]]
        Q.tube(parts, pts, lambda t: 0.1 * (1.0 - 0.75 * t), lambda t: L.mix(wood, wood_hi, t), head, seg=8)
        for k, (at, d, ln) in enumerate(((2, V((-0.2 * sx, -0.3, 1)), 0.45), (4, V((0.8 * sx, -0.2, 0.7)), 0.4),
                                         (3, V((0.3 * sx, 0.6, 0.8)), 0.35))):
            q = pts[at]
            tip = q + d.normalized() * ln
            Q.tube(parts, [q, (q + tip) * 0.5 + V((0, 0, 0.05)), tip], lambda t: 0.06 * (1.0 - 0.8 * t),
                   lambda t: L.mix(wood, wood_hi, t), head, seg=6)
        for k in range(7):
            q = pts[1 + k % 5] + V((rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04), 0))
            d = V((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.3, 1))).normalized()
            Q.thorn(parts, q, d, 0.14, 0.03, head, D("6a3020"), D("f0d8b0"))
        for k in range(3):
            q = pts[min(2 + k * 2, 6)]
            Q.leaf(parts, q, V((sx * 0.6, rng.uniform(-0.6, 0.3), 0.4)), 0.32, 0.13, D("3a8a30"), D("b8e060"),
                   head, V((0, -1, 0.3)).normalized())
        Q.blossom(parts, pts[3] + V((0, -0.08, 0.02)), V((0.3 * sx, -1, 0.4)), 0.13, D("fff0f0"), D("ff6a8a"),
                  D("ffd040"), head, petals=5)
    # Bramble vines wrapped around the cranium, studded with thorns and a few leaves.
    centre = V((0, 0.0, 0.8))
    for w, (tilt, phase) in enumerate(((0.5, 0.0), (-0.45, 1.6), (0.15, 3.3))):
        pts = []
        for i in range(19):
            a = phase + 2.2 * math.pi * i / 18
            d = V((math.cos(a), math.sin(a) * 0.9 + 0.25, tilt + 0.35 * math.sin(a * 1.5)))
            q, m = Q.hit(surf, centre, d)
            if q is None or (q.y < -0.35 and 0.45 < q.z < 1.15 and abs(q.x) > 0.2):
                continue  # keep clear of the eye sockets
            pts.append(q + m * 0.05)
        if len(pts) < 4:
            continue
        Q.tube(parts, pts, 0.045, lambda t: L.mix(vine, vine_hi, 0.5 + 0.5 * math.sin(t * 20)), "surface", seg=6)
        for i, q in enumerate(pts):
            m = (q - centre).normalized()
            if i % 3 == 0:
                d = (m + V((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), rng.uniform(-0.3, 0.6)))).normalized()
                Q.thorn(parts, q, d, 0.12, 0.028, q, D("6a3020"), D("f0d8b0"))
            elif i % 5 == 1:
                Q.leaf(parts, q, (m + V((0, 0, 0.3))).normalized(), 0.22, 0.09, D("3a8a30"), D("a8d850"), q,
                       V((0, 0, 1)) if abs(m.z) < 0.8 else V((0, -1, 0)))
    # A beard of roots from under the jaw down to the ground.
    for k in range(5):
        a = math.radians(-150 + 300 * k / 4)
        top = V((math.sin(a) * 0.4, -0.05 - math.cos(a) * 0.25, 0.08))
        out = V((math.sin(a), -math.cos(a) * 0.6 + 0.25, 0)).normalized()
        pts = [top + out * (0.45 * t) + V((0, 0, -0.16 * t + 0.08 * math.sin(t * 3.1))) for t in
               [i / 5 for i in range(6)]]
        Q.tube(parts, pts, lambda t: 0.07 * (1.0 - 0.7 * t), lambda t: L.mix(D("4a3020"), D("8a6a40"), t),
               {"Body": 1.0}, seg=6)
    Q.finish(body, parts)


# ================================================================ dawn/Slime  dawn_spirit_fox (elite)

def spirit_slime(arm, body):
    """สไลม์วิญญาณอรุณ dawn_spirit_fox (elite): a slime of living dawnfire - deep amber at
    the base glowing up through orange to a pale gold crown, a sun emblem burning on its
    chest, fox-fire flames for ears and a curling flame tail, slanted glowing spirit eyes
    and a sly grin; small sparks float at its sides. (This rig faces +X.)"""
    Q.delete_mat_islands(body, lambda m, c, s, n: m == "Eyes")
    L.clean(body)
    L.subdivide(body, 2)
    L.decimate_to(body, 4200)
    L.relax(body, 2, 0.4)
    amber, orange, gold, cream = D("e8601a"), D("ff9a2a"), D("ffd060"), D("fff4c8")

    def paint(name, co, n, info):
        c = L.mix(amber, orange, L.smooth(0.0, 0.8, co.z))
        c = L.mix(c, gold, L.smooth(0.8, 1.6, co.z))
        c = L.mix(c, cream, L.smooth(1.5, 1.95, co.z) * 0.8)
        return L.mix(c, cream, max(0.0, n.x) * 0.25)

    K.paint_body(body, paint)
    surf, parts = Q.start(body)
    centre = V((0, 0, 0.9))
    # Spirit eyes: dark almond sockets with a glowing core and a glint.
    for sy in (-1.0, 1.0):
        p, n = Q.hit(surf, centre, V((1.0, 0.42 * sy, 0.55)))
        tilt = 0.35 * sy
        with parts.use("keepdetail"):
            parts.decal(p, n, M.ellipse(0.36, 0.2, 24, tilt), D("3a1004"), rings=2, lift=0.012)
        with parts.use("glow"):
            parts.decal(p, n, M.ellipse(0.29, 0.14, 22, tilt), None, rings=3, lift=0.02,
                        color_fn=lambda x, y, k: L.mix(C("fffbe8"), C("ffb020"), k ** 1.5))
        with parts.use("keepdetail"):
            parts.decal(p, n, M.ellipse(0.04, 0.12, 12), D("3a1004"), rings=1, lift=0.026)
            parts.decal(p + V((0, 0.07 * sy, 0.05)), n, M.ellipse(0.04, 0.04, 10), WHITE, rings=1, lift=0.03)
    p, n = Q.hit(surf, centre, V((1.0, 0.0, 0.05)))
    if p is not None:
        with parts.use("keepdetail"):
            parts.stroke(p, n, [(-0.2, 0.06), (-0.1, -0.02), (0.0, 0.02), (0.1, -0.02), (0.2, 0.06)], 0.045,
                         D("5a2008"), lift=0.016)
    # Sun emblem on the chest.
    p, n = Q.hit(surf, centre, V((1.0, 0.0, -0.45)))
    if p is not None:
        with parts.use("glow"):
            parts.decal(p, n, M.ellipse(0.1, 0.1, 16), C("fff6c0"), rings=2, lift=0.016)
            for k in range(8):
                a = 2.0 * math.pi * k / 8
                parts.stroke(p, n, [(math.cos(a) * 0.14, math.sin(a) * 0.14),
                                    (math.cos(a) * 0.24, math.sin(a) * 0.24)], 0.045, C("ffd060"), lift=0.016)

    def flame(base, direction, length, width, bend, weights):
        with parts.use("glow"):
            parts.blob(base, (width, width * 0.6), direction, length, None, weights=weights, seg=8, rings=7,
                       tip=0.04, bend=bend, up=V((1, 0, 0)) if abs(direction.x) < 0.8 else V((0, 0, 1)),
                       color_fn=lambda t: L.mix(C("ff7a1a"), C("fff6c0"), L.smooth(0.0, 0.9, t)))

    # Fox-fire ears and a crown flame.
    for sy in (-1.0, 1.0):
        q, m = Q.hit(surf, centre, V((0.1, 0.55 * sy, 1.0)))
        flame(q - m * 0.12, V((0.1, 0.4 * sy, 1.0)).normalized(), 1.35, 0.3, V((-0.2, 0.12 * sy, 0)), q)
        flame(q - m * 0.1 + V((-0.12, -0.1 * sy, 0)), V((-0.1, 0.55 * sy, 0.8)).normalized(), 0.55, 0.15,
              V((-0.08, 0, 0.1)), q)
    q, m = Q.hit(surf, centre, V((-0.25, 0.0, 1.0)))
    flame(q - m * 0.1, V((-0.3, 0, 1)).normalized(), 0.85, 0.22, V((-0.2, 0, 0)), q)
    # A big curling flame tail behind, split in three tongues.
    q, m = Q.hit(surf, centre, V((-1.0, 0.0, -0.1)))
    flame(q - m * 0.15, V((-0.7, 0, 1)).normalized(), 1.7, 0.38, V((-0.35, 0, 0.1)), q)
    for sy in (-1.0, 1.0):
        flame(q - m * 0.1 + V((0, 0.25 * sy, 0.05)), V((-0.8, 0.5 * sy, 0.9)).normalized(), 1.0, 0.22,
              V((-0.2, 0.1 * sy, 0.1)), q)
    p, n = Q.hit(surf, centre, V((0.6, -0.3, 1.0)))
    if p is not None:
        with parts.use("keepdetail"):
            M.gloss(parts, p, n, 0.22, C("fff8e0"))
    # Glowing dawn streaks swirling up its sides.
    for sy in (-1.0, 1.0):
        for k in range(3):
            p, n = Q.hit(surf, centre, V((0.2 - 0.5 * k, 1.0 * sy, -0.1 + 0.25 * k)))
            if p is not None:
                with parts.use("glow"):
                    parts.stroke(p, n, [(0.18 * math.cos(a), 0.1 * math.sin(a) + a * 0.04) for a in
                                        [i * 0.6 for i in range(8)]], 0.05, C("ffe6a0"), lift=0.014)
    # Floating sparks at its sides (on the hands).
    for sy, b in ((1.0, "Hand.L"), (-1.0, "Hand.R")):
        h = arm.data.bones[b].tail_local
        with parts.use("glow"):
            parts.ellipsoid(h + V((0.05, 0.12 * sy, 0.12)), (0.09, 0.09, 0.12), color=None, weights={b: 1.0}, seg=8,
                            rings=6, color_fn=lambda u: L.mix(C("ff9a2a"), C("fff6c0"), L.smooth(-0.6, 0.8, u.z)))
    Q.finish(body, parts)


# ================================================================ star animals (crystal valley)

LEGS = {"FrontUpperLeg.L", "FrontLowerLeg.L", "FrontUpperLeg.R", "FrontLowerLeg.R", "BackUpperLeg.L",
        "BackLowerLeg.L", "BackUpperLeg.R", "BackLowerLeg.R", "BackLeg.L", "BackLeg.R"}


def _animal(arm, body, drop, head_c, r_in, r_out, grow, tris, legs=1.15):
    """The realistic Quaternius animal made cartoon: eye faces dropped, welded smooth, a
    bigger head, sturdier legs, subdivided and brought back to `tris`."""
    L.delete_faces(body, drop)
    L.clean(body)
    Q.grow(body, head_c, r_in, r_out, grow)
    if legs != 1.0:
        K.thicken(body, arm, LEGS, legs)
    L.subdivide(body, 1)
    L.decimate_to(body, tris)
    L.relax(body, 2, 0.35)


def tufts(parts, surf, center, dirs, length, width, c0, c1, droop=0.6, weights=None, seed=1, mode="skin"):
    """Pointed fur clumps where rays from center along dirs meet the body."""
    rng = random.Random(seed)
    with parts.use(mode):
        for d in dirs:
            q, m = Q.hit(surf, center, d)
            if q is None:
                continue
            j = V((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.25
            dd = (m + j + V((0, 0, -droop))).normalized()
            parts.blob(q - m * width * 0.5, (width, width * 0.5), dd, length * rng.uniform(0.8, 1.15), None,
                       weights=weights or q, seg=6, rings=4, tip=0.08, up=m,
                       color_fn=lambda t: L.mix(c0, c1, L.smooth(0.0, 1.0, t)))


def spine_crystals(parts, surf, y0, y1, z_from, count, size0, size1, root, tip, seed=3, lean=0.25, sides=6):
    """A ridge of crystal druses along the back from y0 (front) to y1."""
    rng = random.Random(seed)
    for k in range(count):
        t = k / max(count - 1, 1)
        y = y0 + (y1 - y0) * t
        q, m = Q.hit(surf, V((0, y, z_from * 0.6)), V((0, 0, 1)))
        if q is None:
            continue
        size = size0 + (size1 - size0) * math.sin(math.pi * t)
        Q.cluster(parts, q - m * 0.04, (m + V((0, lean, 0))).normalized(), size, q, root, tip, count=3 + k % 2,
                  seed=seed + k, spread=0.5, sides=sides)


def snow_husky(arm, body):
    """ฮัสกี้ผลึกหิมะ crystal_husky: a chibi husky - big round head, slate-blue saddle and
    mask over snow-white fur, icy sparkly eyes with the husky's pale brows, fluffy cheeks,
    chest ruff and a curled plume tail, frost crystals growing on its shoulders."""
    _animal(arm, body, ("Material.002", "Material.003"), V((0, -1.95, 2.75)), 0.45, 0.85, 1.32, 5000)
    coat, coat_hi, snow = D("4e5e84"), D("7c8cb0"), D("f6f9ff")

    def paint(name, co, n, info):
        if name == "Material.006":
            return D("262838")
        if name == "Material":
            c = L.mix(coat, coat_hi, max(0.0, -n.z) * 0.5 + L.smooth(2.6, 3.1, co.z) * 0.3)
            return L.mix(c, snow, L.smooth(0.35, 0.0, n.z) * L.smooth(-1.7, -2.2, co.y) * 0.6)
        return L.mix(D("d8e0f0"), snow, L.smooth(0.3, 1.6, co.z) * 0.5 + max(0.0, n.z) * 0.5)

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name == "Material.006" else "skin")
    surf, parts = Q.start(body)
    head = {"Head": 1.0}
    hc = V((0, -1.95, 2.75))
    for sx in (-1.0, 1.0):
        c, n = eye_at(surf, hc, V((0.5 * sx, -1.0, 0.1)), 0.15, sink=0.4)
        cute_eye(parts, c, 0.15, V((0.4 * sx, -1.0, 0.0)).normalized(), C("1a3a6a"), C("8ae0ff"), head,
                 iris=0.66, pupil=0.3, oval=1.15)
        p, m = Q.hit(surf, hc, V((0.4 * sx, -1.0, 0.55)))
        if p is not None:
            parts.decal(p, m, M.ellipse(0.06, 0.04, 12), D("f6f9ff"), rings=1)  # husky brow spot
        tufts(parts, surf, hc, [V((sx, -0.3, -0.4)), V((sx, 0.1, -0.2))], 0.26, 0.1, D("e0e8f4"), WHITE,
              weights=head, seed=2 + int(sx))
        # frost crystals on the shoulders
        q, m = Q.hit(surf, V((0.0, -0.9, 1.7)), V((0.6 * sx, -0.1, 1.0)))
        if q is not None:
            Q.cluster(parts, q - m * 0.03, (m + V((0.3 * sx, 0.2, 0.3))).normalized(), 0.34, q, D("7ac8ff"),
                      D("f4fcff"), count=4, seed=5 + int(sx))
    tufts(parts, surf, V((0, -1.2, 1.7)), [V((x, -1.0, -0.3)) for x in (-0.5, 0.0, 0.5)], 0.32, 0.12, D("e8eef8"),
          WHITE, weights={"Neck1": 1.0}, seed=7)
    p, m = Q.hit(surf, V((0, -2.2, 2.45)), V((0, -1, 0.3)))
    if p is not None:
        parts.ellipsoid(p + m * 0.02, (0.09, 0.06, 0.06), color=D("1a1a28"), weights=head, seg=10, rings=6)
    Q.finish(body, parts)


def _wolf(arm, body, elite):
    grow = 1.42 if elite else 1.38
    hc = V((0, -2.05, 2.2))
    _animal(arm, body, ("Eyes_Black",), hc, 0.42, 0.8, grow, 4600 if elite else 4800, legs=1.2 if elite else 1.12)
    if elite:
        Q.grow(body, V((0, -0.9, 1.9)), 0.5, 1.0, 1.15)  # broad shoulders
    top, side, belly = (D("26305e"), D("40508e"), D("b8c4e8")) if elite else (D("3a4a8e"), D("6274b8"),
                                                                            D("d4def6"))

    def paint(name, co, n, info):
        if name == "Nose":
            return D("161828")
        if name == "Main_Light" and not (co.y < -1.6 and co.z > 2.12):
            return L.mix(belly, WHITE, L.smooth(1.5, 2.4, co.z) * 0.3)
        c = L.mix(side, top, L.smooth(-0.2, 0.7, n.z))
        return L.mix(c, belly, L.smooth(-0.2, -0.7, n.z) * 0.6)

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name == "Nose" else "skin")
    surf, parts = Q.start(body)
    head = {"Head": 1.0}
    glow_hi, glow_lo = (C("e8ffff"), C("2ad8ff")) if elite else (C("d8f4ff"), C("4a9aff"))
    for sx in (-1.0, 1.0):
        c, n = eye_at(surf, hc, V((0.55 * sx, -1.0, 0.25)), 0.13, sink=0.45)
        K.fierce_eye(parts, c, 0.13, V((0.45 * sx, -1.0, 0.05)).normalized(), glow_hi, glow_lo, head,
                     lid=top, slant=0.5, side=sx, slit=True, iris=0.95, glow=True, lid_drop=1.5,
                     sclera=C("1a2040"))
        # crystal fangs (indigo, or diamond sabres on the pack leader)
        q, m = Q.hit(surf, hc + V((0.1 * sx, -0.3, -0.1)), V((0.15 * sx, -1.0, -0.4)))
        if q is not None:
            ln = 0.42 if elite else 0.24
            Q.crystal(parts, q - m * 0.03, V((0.05 * sx, -0.25, -1.0)), ln, 0.055 if elite else 0.04, head,
                      D("5a7ae8") if not elite else D("a8e8ff"), WHITE, sides=5)
        tufts(parts, surf, hc, [V((sx, 0.0, -0.4)), V((sx, 0.3, -0.1))], 0.3, 0.1, side, belly, weights=head,
              seed=11 + int(sx))
        if elite:
            p, m = Q.hit(surf, hc, V((0.45 * sx, -1.0, 0.45)))
            if p is not None and sx > 0:
                with parts.use("keepdetail"):
                    parts.stroke(p, m, [(-0.06, 0.2), (0.0, 0.05), (0.04, -0.12), (0.08, -0.22)], 0.04,
                                 D("c8d0e8"), lift=0.02)  # an old scar across the left eye
    # neck mane
    dirs = []
    for k in range(14 if elite else 8):
        a = math.radians(-120 + 240 * k / ((14 if elite else 8) - 1))
        dirs.append(V((math.sin(a), math.cos(a) * 0.7 - 0.2, 0.5 + 0.4 * math.cos(a))))
    mane0, mane1 = (D("c8d4ec"), WHITE) if elite else (side, belly)
    tufts(parts, surf, V((0, -1.3, 1.95)), dirs, 0.5 if elite else 0.34, 0.15 if elite else 0.11, mane0, mane1,
          droop=0.2, seed=21)
    # crystals: a ridge down the back; the leader adds a crown between the ears
    root, tip = (D("3a9ae8"), D("f0fcff")) if elite else (D("4a6ae0"), D("d8eaff"))
    spine_crystals(parts, surf, -0.9, 0.7, 2.0, 6 if elite else 4, 0.5 if elite else 0.26, 0.85 if elite else 0.4,
                   root, tip, seed=31, lean=0.45)
    if elite:
        q, m = Q.hit(surf, hc, V((0, 0.2, 1)))
        if q is not None:
            Q.cluster(parts, q - m * 0.04, (m + V((0, 0.4, 0))).normalized(), 0.55, head, root, tip, count=5,
                      seed=41, spread=0.6)
    p, m = Q.hit(surf, V((0, 1.5, 1.9)), V((0, 1, 0.3)))
    Q.finish(body, parts)


def frost_wolf(arm, body):
    """หมาป่าเขี้ยวคราม crystal_wolf (also the summoned spirit wolf): a lean cartoon wolf in
    deep indigo-blue fur with a pale belly, a bigger head with narrowed glowing blue eyes,
    indigo crystal fangs, a shaggy neck ruff and a short ridge of indigo crystals down its
    spine."""
    _wolf(arm, body, False)


def diamond_fang(arm, body):
    """จ่าฝูงเขี้ยวเพชร crystal_fang (elite variant): the pack leader - broader, near-black
    navy fur under a great silver-white mane, cyan eyes blazing, long diamond sabre fangs,
    an old scar over one eye, a crown of diamonds between the ears and tall diamond
    druses all along the back."""
    _wolf(arm, body, True)


def _bull(arm, body, elite):
    hc = V((0, -4.3, 3.85))
    _animal(arm, body, ("Eye_Black", "Eye_White"), hc, 0.6, 1.2, 1.25 if elite else 1.22, 4400 if elite else 4800,
            legs=1.18 if elite else 1.1)
    top, side, belly = (D("2a1e50"), D("4a3a80"), D("8a7ac0")) if elite else (D("4a5a8c"), D("7484b0"),
                                                                            D("b4c0dc"))
    ice0, ice1 = (D("8a6ae8"), D("f4eaff")) if elite else (D("6ab8f0"), D("f0faff"))

    def paint(name, co, n, info):
        if name == "Horns":
            return L.mix(ice0, ice1, L.smooth(0.0, 0.9, (co - hc).length - 0.4))
        if name == "Hooves":
            return L.mix(D("2a2e48"), ice0, 0.3)
        if name == "Muzzle":
            return D("c8b4c4") if not elite else D("a898c0")
        if name == "Main_Light" and co.z < 3.0:
            return belly
        c = L.mix(side, top, L.smooth(-0.2, 0.8, n.z))
        return L.mix(c, belly, L.smooth(-0.2, -0.8, n.z) * 0.5)

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name == "Horns" else "skin")
    surf, parts = Q.start(body)
    head = {"Head": 1.0}
    for sx in (-1.0, 1.0):
        c, n = eye_at(surf, hc, V((0.75 * sx, -1.0, 0.2)), 0.17, sink=0.4)
        K.fierce_eye(parts, c, 0.17, V((0.55 * sx, -1.0, 0.0)).normalized(),
                     C("f4e8ff") if elite else C("e0f8ff"), C("b04aff") if elite else C("3aa8ff"), head,
                     lid=top, slant=0.55, side=sx, slit=False, iris=0.9, glow=True, lid_drop=1.4,
                     sclera=C("1a1a30"))
        # crystal pauldrons on the shoulders
        q, m = Q.hit(surf, V((0, -1.9, 2.9)), V((0.7 * sx, -0.1, 1.0)))
        if q is not None:
            Q.cluster(parts, q - m * 0.05, (m + V((0.2 * sx, 0.1, 0.4))).normalized(), 1.0 if elite else 0.7, q,
                      ice0, ice1, count=5, seed=50 + int(sx))
        if elite:
            # the behemoth's great crystal horns: a long curved spear of crystal and its side shards
            base = hc + V((0.75 * sx, 0.15, 0.45))
            d1 = V((0.9 * sx, 0.1, 0.55)).normalized()
            Q.crystal(parts, base, d1, 1.2, 0.22, head, ice0, L.mix(ice0, ice1, 0.6), sides=6)
            d2 = V((0.35 * sx, -0.25, 1.0)).normalized()
            Q.crystal(parts, base + d1 * 1.05, d2, 0.9, 0.16, head, L.mix(ice0, ice1, 0.5), ice1, sides=6)
            for k in range(2):
                Q.crystal(parts, base + d1 * (0.3 + 0.35 * k), (d1 + V((0, -0.4, 0.8))).normalized(), 0.45, 0.08,
                          head, ice0, ice1, sides=5)
        else:
            base = hc + V((0.75 * sx, 0.15, 0.45))
            Q.crystal(parts, base, V((0.7 * sx, -0.1, 0.8)).normalized(), 0.55, 0.11, head, ice0, ice1, sides=6)
    # forehead tuft
    tufts(parts, surf, hc, [V((x, -0.5, 1.0)) for x in (-0.25, 0.0, 0.25)], 0.4, 0.13, side, belly, droop=0.3,
          weights=head, seed=61)
    spine_crystals(parts, surf, -1.6, 2.0, 4.0, 6 if elite else 4, 0.9 if elite else 0.55, 1.6 if elite else 0.8,
                   ice0, ice1, seed=71, lean=0.35)
    if elite:
        q, m = Q.hit(surf, V((0, -2.0, 2.4)), V((0, -1, -0.3)))
        if q is not None:
            Q.cluster(parts, q - m * 0.05, (m + V((0, 0, -0.3))).normalized(), 0.8, q, ice0, ice1, count=5, seed=81)
    Q.finish(body, parts)


def crystal_bull(arm, body):
    """กระทิงเกราะผลึก crystal_bull (the base bull): a stocky cartoon gaur in steel-blue
    hide, glaring ice-blue eyes, ice-crystal horns, crystal pauldrons on its shoulders and a
    row of crystal plates over the hump."""
    _bull(arm, body, False)


def crystal_behemoth(arm, body):
    """เบฮีมอธเขาผลึก crystal_behemoth (elite variant): a hulking violet-hided brute -
    enormous forked amethyst crystal horns, blazing violet eyes, huge druses on the
    shoulders and chest and tall crystal spires along its whole back."""
    _bull(arm, body, True)


def _alpaca(arm, body, glass):
    hc = V((0.02, -1.9, 4.55))
    L.delete_faces(body, ("Eyes_Black", "Eyes_White"))
    L.clean(body)
    Q.grow(body, hc, 0.4, 0.8, 1.35)
    L.subdivide(body, 1)
    L.decimate_to(body, 3800 if glass else 4600)
    L.relax(body, 2, 0.35)
    names = [m.name for m in body.data.materials]
    wool_v = {v for p in body.data.polygons if names[p.material_index] == "Main" for v in p.vertices}
    for i in wool_v:
        v = body.data.vertices[i]
        v.co += v.normal * 0.09 * L.smooth(0.35, 0.75, Q.fbm(v.co, 4.0, 3))
    if glass:
        wool, wool_lo, face, muzzle = D("f2f6ff"), D("b4c4ec"), D("c4d4f0"), D("e8eefc")
    else:
        wool, wool_lo, face, muzzle = D("fbf0dc"), D("dcc0a0"), D("c8966a"), D("f2dcc8")

    def paint(name, co, n, info):
        if name == "Hooves":
            return D("4a3a40") if not glass else D("6a7aa8")
        if name == "Muzzle":
            return muzzle
        if name == "Main_Dark":
            return L.mix(face, L.mix(face, WHITE, 0.3), max(0.0, n.z))
        c = L.mix(wool_lo, wool, L.smooth(0.3, 0.75, Q.fbm(co, 4.0, 3)) * 0.6 + max(0.0, n.z) * 0.4)
        if glass:
            c = L.mix(c, D("d8f0ff"), max(0.0, -n.y) * 0.3)
        return c

    K.paint_body(body, paint)
    surf, parts = Q.start(body)
    head = {"Head": 1.0}
    for sx in (-1.0, 1.0):
        c, n = eye_at(surf, hc, V((0.6 * sx, -1.0, 0.1)), 0.14, sink=0.4)
        cute_eye(parts, c, 0.14, V((0.5 * sx, -1.0, 0.0)).normalized(), C("1a2a5a") if glass else C("2a1408"),
                 C("8ad8ff") if glass else C("c88a4a"), head, iris=0.7, pupil=0.36, oval=1.15)
        p, m = Q.hit(surf, hc, V((0.6 * sx, -1.0, 0.45)))
        if p is not None:
            with parts.use("keepdetail"):
                parts.stroke(p, m, [(0.0, 0.0), (0.06 * sx, 0.04), (0.12 * sx, 0.1)], 0.03, D("3a2a2a"), lift=0.02)
    p, m = Q.hit(surf, hc + V((0, -0.3, -0.2)), V((0, -1, -0.3)))
    if p is not None:
        with parts.use("keepdetail"):
            parts.stroke(p, m, [(x / 6.0 * 0.12, -0.03 * (1 - (x / 6.0) ** 2)) for x in range(-6, 7)], 0.025,
                         D("5a3a3a"), lift=0.016)
    # a fluffy topknot
    q, m = Q.hit(surf, hc, V((0, 0.1, 1)))
    rng = random.Random(5)
    for k in range(7):
        off = V((rng.uniform(-0.15, 0.15), rng.uniform(-0.2, 0.12), rng.uniform(0.0, 0.15)))
        s_ = rng.uniform(0.14, 0.19)
        parts.ellipsoid(q + off + m * 0.06, (s_, s_, s_ * 0.9), color=None, weights=head, seg=10, rings=6,
                        color_fn=lambda u: L.mix(wool_lo, wool, L.smooth(-0.8, 0.6, u.z)))
    if glass:
        # glass mist: pale puffs drifting at the neck, chest and ankles, glass shards in the fleece,
        # a crystal tiara and twinkles of light
        for k in range(9):
            a = 2.0 * math.pi * k / 9 + rng.uniform(-0.2, 0.2)
            q, m = Q.hit(surf, V((0.03, -1.4, 2.9 + rng.uniform(-0.25, 0.35))),
                         V((math.cos(a), math.sin(a) * 0.8, rng.uniform(-0.3, 0.3))))
            if q is not None:
                s_ = rng.uniform(0.13, 0.26)
                parts.ellipsoid(q + m * rng.uniform(0.02, 0.12), (s_ * 1.3, s_, s_ * 0.8), Q.basis(m), color=None,
                                weights=q, seg=10, rings=6,
                                color_fn=lambda u: L.mix(D("a8d4ff"), D("f0f8ff"), L.smooth(-0.7, 0.8, u.z)))
        for b in ("FrontLowerLeg.L", "FrontLowerLeg.R", "BackLowerLeg.L", "BackLowerLeg.R"):
            t = arm.data.bones[b].tail_local
            for k in range(3):
                a = 2.0 * math.pi * k / 3
                with parts.use("glow"):
                    parts.ellipsoid(t + V((math.cos(a) * 0.14, math.sin(a) * 0.14, 0.05)), (0.12, 0.12, 0.09),
                                    color=None, weights={b: 1.0}, seg=8, rings=5,
                                    color_fn=lambda u: L.mix(C("bfe8ff"), C("f4fbff"), L.smooth(-0.6, 0.6, u.z)))
        for k in range(6):
            q, m = Q.hit(surf, V((0.04, 0.0, 1.6)), V((rng.uniform(-0.8, 0.8), rng.uniform(-0.6, 0.9), 1.0)))
            if q is not None:
                Q.cluster(parts, q - m * 0.05, m, rng.uniform(0.3, 0.45), q, D("9ad0ff"), D("f8fdff"), count=3,
                          seed=90 + k, spread=0.5)
        q, m = Q.hit(surf, hc, V((0, -0.35, 1)))
        if q is not None:
            Q.cluster(parts, q - m * 0.02 + V((0, -0.1, 0.1)), (m + V((0, -0.2, 0.3))).normalized(), 0.42, head,
                      D("8ac8ff"), WHITE, count=5, seed=99, spread=0.55)
        for k in range(9):
            q, m = Q.hit(surf, V((0.04, 0.0, 2.2)), V((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.3, 1))))
            if q is not None:
                with parts.use("glow"):
                    parts.decal(q, m, [(math.cos(a) * (0.09 if i % 2 == 0 else 0.03),
                                        math.sin(a) * (0.09 if i % 2 == 0 else 0.03))
                                       for i, a in enumerate([j * math.pi / 4 for j in range(8)])],
                                C("f4fcff"), rings=1, lift=0.03)
    Q.finish(body, parts)


def fleece_alpaca(arm, body):
    """The base alpaca (star/Alpaca): a fluffy cartoon alpaca - lumpy cream fleece, fawn face
    and legs, a big woolly topknot, sweet brown eyes with lashes and a little smile."""
    _alpaca(arm, body, False)


def glass_alpaca(arm, body):
    """อัลปาก้าหมอกแก้ว crystal_alpaca (variant): an alpaca of frost and glass - pale
    lilac-white fleece, blue-grey face, a tiara of glass crystals, glass shards growing from
    its fleece, glowing mist puffs at the ankles, cool puffs at the neck, twinkling motes."""
    _alpaca(arm, body, True)


# ================================================================ registry / runner

RECIPES = {
    "dawn/Crab": petal_crab,
    "dawn/Crab_reef_crab": coral_hermit,
    "dawn/Enemy": leaf_spirit,
    "dawn/Bee": pollen_bee,
    "dawn/Bunny": boxer_bunny,
    "dawn/Bat": dawn_bat,
    "dawn/Skull": thorn_skull,
    "dawn/Slime": spirit_slime,
    "star/Husky": snow_husky,
    "star/Wolf": frost_wolf,
    "star/Wolf_crystal_fang": diamond_fang,
    "star/Bull": crystal_bull,
    "star/Bull_crystal_behemoth": crystal_behemoth,
    "star/Alpaca": fleece_alpaca,
    "star/Alpaca_crystal_alpaca": glass_alpaca,
}
SOURCE = {"dawn/Crab_reef_crab": "dawn/Crab.gltf", "star/Wolf_crystal_fang": "star/Wolf.glb",
          "star/Bull_crystal_behemoth": "star/Bull.glb", "star/Alpaca_crystal_alpaca": "star/Alpaca.glb"}


def source_path(name):
    if name in SOURCE:
        return os.path.join(M.SRC, SOURCE[name])
    for ext in (".gltf", ".glb", ".fbx"):
        p = os.path.join(M.SRC, name + ext)
        if os.path.exists(p):
            return p
    raise FileNotFoundError(name)


def build(name):
    import bpy
    L.reset()
    arm, body = Q.load(source_path(name))
    clips = sorted(a.name for a in bpy.data.actions)
    before = L.tri_count(body)
    RECIPES[name](arm, body)
    out = os.path.join(M.OUT, name + ".glb")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    K.export(arm, body, out, clips)
    print("REMASTER %s tris %d -> %d, %d bytes, clips %s" % (name, before, L.tri_count(body), os.path.getsize(out),
                                                          ",".join(clips)))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    for name in (args or list(RECIPES)):
        build(name)
