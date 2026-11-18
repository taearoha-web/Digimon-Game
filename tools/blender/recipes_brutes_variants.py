"""Team brutes: VARIANT models, so monsters that shared one rig no longer look alike.

    /opt/bpy5/bin/python tools/blender/recipes_brutes_variants.py [big/Yeti_yeti_king ...]

Each variant is built from the same source rig (SOURCE) through its base recipe in
recipes_brutes.py with a variant spec (reshaping, a new paint, features left out, new
parts), and written to assets/models/monsters/remaster/<dir>/<Name>_<monster_id>.glb;
that monster's "model" points at "remaster/<dir>/<Name>_<monster_id>". The first monster
of each group keeps the shared model (recipes_brutes.py). Bosses get the grander kit:
crowns, mantles, armour, bigger horns. Rig and every clip are kept.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402,F401  (bmesh loads with bpy)
import bmesh  # noqa: E402
import remaster_lib as L  # noqa: E402
import kit_brutes as K  # noqa: E402
import recipes_brutes as B  # noqa: E402
from mathutils import Vector  # noqa: E402

V = Vector
C = L.srgb
SRC, OUT = B.SRC, B.OUT
SKIN, DETAIL, GLOW, IVORY, IVORY_GLOW = K.SKIN, K.DETAIL, K.GLOW, K.IVORY, K.IVORY_GLOW
WHITE = C("ffffff")
HEAD = {"Head": 1.0}
TORSO = {"Torso": 1.0}


def mat_of(r):
    return r[1] if isinstance(r, tuple) else SKIN


def col_of(r):
    return r[0] if isinstance(r, tuple) else r


# ================================================================ big/Yeti

def yeti_king(arm, body):
    """yeti_king (icy blue boss): the yeti made a king - broader shoulders and chest, a
    crown of glowing ice spikes on a frosted silver band, huge curling ram horns, a
    long frost beard, a royal-blue mantle with a white fur collar down its back, great ice
    crystal pauldrons, a glowing frost rune on the chest."""
    ice, ice_core = C("aee8ff"), C("f4fdff")

    def shape(body):
        # broad shoulders and a deeper chest (a boss's mass)
        K.scale_region(body, lambda c: 1.2 < c.z < 2.3 and abs(c.x) < 1.3, V((0, 0.2, 1.7)), (1.16, 1.14, 1.04),
                       lambda c: L.smooth(1.2, 1.6, c.z) * L.smooth(2.35, 2.0, c.z) * L.smooth(1.3, 0.8, abs(c.x)))

    def extra(arm, body, surf, parts):
        # huge ram horns: from the crown, curling back, down and forward
        for sx in (-1.0, 1.0):
            K.horn(parts, V((0.36 * sx, -0.1, 2.62)), V((0.9 * sx, 0.35, 0.5)).normalized(), 0.95, 0.19, HEAD,
                   C("3e3438"), C("f2e8d4"), bend=V((0.25 * sx, -0.2, -0.8)), rings_col=C("2a2224"), bands=7,
                   seg=10, rings=10)
        # crown: a frosted silver band with glowing ice spikes, the tallest in front
        apex, _n = K.dir_hit(surf, V((0, -0.05, 2.3)), V((0, -0.05, 1)))
        base = apex - V((0, 0, 0.1))
        K.ring_band(parts, base, V((0, -0.05, 1)), 0.38, 0.14,
                    lambda t, side: L.mix(C("6a88a8"), C("eaf6ff"), t * 0.8 + 0.1), HEAD, seg=16, flare=1.12)
        sizes = [1.6, 0.8, 1.15, 0.8, 1.0, 0.8, 1.15, 0.8]
        K.spike_ring(parts, base + V((0, 0, 0.1)), V((0, -0.05, 1)), 0.4, 8, 0.5, 0.085, HEAD, ice, ice_core,
                     mat=IVORY_GLOW, tilt=0.25, phase=-math.pi / 2, sizes=sizes, seg=5)
        # frost beard hanging from the chin
        with parts.on(DETAIL):
            for k in range(7):
                x = (k - 3) * 0.075
                p, n = K.front_hit(surf, x, 1.86)
                if p is None:
                    continue
                parts.blob(p - n * 0.04, (0.07, 0.035), V((x * 0.6, -0.35, -1.0)).normalized(),
                           0.42 - 0.04 * abs(k - 3), None, weights=HEAD, seg=6, rings=4, tip=0.15, up=n,
                           color_fn=lambda t: L.mix(C("dfe8f2"), WHITE, t))
        # royal mantle down the back, fur collar on top
        def mantle_w(u, t):
            return {"Torso": 1.0 - 0.5 * t, "Hips": 0.5 * t}

        K.cloth(parts, V((-0.62, 0.42, 2.12)), V((0.62, 0.42, 2.12)), V((0, 0.32, -1)), 1.75, mantle_w,
                lambda u, t: L.mix(C("1e2a6a"), C("3a58b8"), 0.3 + 0.5 * math.sin(u * math.pi) - 0.3 * t)
                if t < 0.93 else C("e8eef6"),
                cols=8, rows=7, thick=0.04, bulge=lambda u, t: V(((u - 0.5) * 0.35 * t, 0.12 * math.sin(u * math.pi),
                                                                  0)),
                ragged=0.0)
        collar = V((0, 0.2, 2.06))
        for i in range(13):
            a = math.pi * (0.05 + 0.9 * i / 12)
            d = V((math.cos(a), 0.55 * math.sin(a) + 0.2, 0.15))
            p, n = K.dir_hit(surf, collar, d)
            if p is None:
                continue
            parts.ellipsoid(p + n * 0.06, (0.16, 0.13, 0.12), color=None, weights=TORSO, seg=6, rings=4,
                            color_fn=lambda u: L.mix(C("c8d2e0"), WHITE, L.smooth(-0.6, 0.7, u.z)))
        # great ice pauldrons
        for sx in (-1.0, 1.0):
            q, m = K.dir_hit(surf, V((0.72 * sx, 0.18, 1.95)), V((0.25 * sx, 0.3, 1.0)))
            if q is None:
                continue
            for k in range(5):
                a = (k - 2) * 0.42
                dd = (m + V((0.55 * sx * math.sin(a), 0.35 * math.cos(a) - 0.1, 0.35))).normalized()
                K.crystal(parts, q - m * 0.02 + V((0.09 * sx * (k - 2), 0.04 * (k % 2), 0)), dd,
                          0.58 - 0.1 * abs(k - 2), 0.1, q, C("9ad4ff"), C("f4fcff"), mat="Skin_Crystal")
        # frost rune on the chest
        p, n = K.front_hit(surf, 0.0, 1.5)
        if p is not None:
            rune = [(-0.12, 0.14), (0.0, -0.02), (0.12, 0.14)]
            K.glow_path(parts, p, n, rune, 0.04, ice_core, mat=IVORY_GLOW)
            K.glow_path(parts, p, n, [(0.0, 0.18), (0.0, -0.2)], 0.04, ice_core, mat=IVORY_GLOW)

    def post(body):
        K.flat(body, ("Skin_Crystal",))
        K.merge_materials(body, {"Skin_Crystal": SKIN})

    B.yeti(arm, body, {"shape": shape, "extra": extra, "post": post, "skip": {"horns", "crystals"}, "tris": 3000})


def crystal_yeti(arm, body):
    """crystal_yeti: a yeti of the crystal valley, half grown into crystal - a geode ridge
    of faceted crystals down its spine, crystal horns, crystal-armoured forearms, frosted
    lilac fur with glassy facets, deep violet hide and pink-violet glowing eyes."""
    hide_v = C("4a3a78")

    def paint(base):
        def fn(name, co, n, info):
            r = base(name, co, n, info)
            c, m = col_of(r), mat_of(r)
            if m == "Skin_Hide":
                c = L.mix(hide_v, C("8a78c8"), max(0.0, n.z) * 0.5 + 0.15)
            elif m == "Skin_Fur":
                c = L.mix(c, C("efe6ff"), 0.35)
                # glassy facets breaking through the fur
                f = K.noise(co, 4.0, 21)
                c = L.mix(c, C("c8f0ff"), L.smooth(0.62, 0.68, f) * 0.8)
            return c, m
        return fn

    def extra(arm, body, surf, parts):
        crys, crys_hi = C("a8e4ff"), C("f6fdff")
        # crystal horns: two big faceted shards
        for sx in (-1.0, 1.0):
            K.crystal(parts, V((0.3 * sx, -0.15, 2.6)), V((0.45 * sx, 0.15, 1.0)).normalized(), 0.7, 0.13, HEAD,
                      crys, crys_hi, mat="Skin_Crystal", sides=5)
            K.crystal(parts, V((0.42 * sx, -0.05, 2.5)), V((0.9 * sx, 0.3, 0.55)).normalized(), 0.38, 0.08, HEAD,
                      crys, crys_hi, mat="Skin_Crystal", sides=5)
        # a geode ridge down the spine
        rng = random.Random(5)
        for k, z in enumerate((2.55, 2.3, 2.05, 1.8, 1.55, 1.3)):
            for j in (-1, 0, 1):
                if j and k % 2:
                    continue
                q, m = K.dir_hit(surf, V((0.0, 0.1, z)), V((0.35 * j, 1.0, 0.2)))
                if q is None:
                    continue
                ln = (0.7 - 0.07 * k) * (0.65 if j else 1.0) * rng.uniform(0.85, 1.1)
                K.crystal(parts, q - m * 0.05, (m + V((0.25 * j, 0, 0.55))).normalized(), ln, 0.11 - 0.008 * k, q,
                          crys, crys_hi, mat="Skin_Crystal", sides=5)
        # crystal-armoured forearms
        for sx in (-1.0, 1.0):
            for k, x in enumerate((1.3, 1.45, 1.6)):
                for a in (-0.6, 0.4, 1.4):
                    d = V((0, -math.sin(a), math.cos(a)))
                    q, m = K.dir_hit(surf, V((x * sx, 0.17, 1.84)), d)
                    if q is None:
                        continue
                    K.crystal(parts, q - m * 0.03, (m + V((0.4 * sx, 0, 0))).normalized(), 0.26 - 0.03 * k, 0.07,
                              q, crys, crys_hi, mat="Skin_Crystal", sides=4)
        # crystals on the shoulders
        for sx in (-1.0, 1.0):
            q, m = K.dir_hit(surf, V((0.7 * sx, 0.2, 1.9)), V((0.2 * sx, 0.4, 1.0)))
            if q is not None:
                for k in range(4):
                    dd = (m + V((0.45 * sx * (k - 1.5), 0.25, 0.3))).normalized()
                    K.crystal(parts, q - m * 0.02 + V((0.07 * sx * (k - 1.5), 0.05 * k, 0)), dd,
                              0.42 - 0.06 * abs(k - 1.5), 0.085, q, crys, crys_hi, mat="Skin_Crystal")

    def post(body):
        K.flat(body, ("Skin_Crystal",))
        K.merge_materials(body, {"Skin_Crystal": SKIN})

    B.yeti(arm, body, {"paint": paint, "extra": extra, "post": post, "skip": {"horns", "crystals"},
                       "eye": (C("ffe8ff"), C("c040e0"))})


# ================================================================ big/BlueDemon

def void_golem(arm, body):
    """void_golem (violet): a golem of obsidian from the void - near-black basalt instead
    of slate, huge crushing fists, twisted obsidian horns, jagged obsidian shards bursting
    from the shoulders and back with glowing tips, a broken halo of floating shards behind
    its head and a black-hole core ringed by a glowing accretion disc."""
    shard_mat = "Ivory_Shard"

    def shape(body):
        # close the old eye holes (the rig's eye whites were cut out) as deep black sockets
        me = body.data
        bm = bmesh.new()
        bm.from_mesh(me)
        made = bmesh.ops.holes_fill(bm, edges=bm.edges[:], sides=48)["faces"]
        names = [m.name for m in me.materials]
        if "R_socket" not in names:
            me.materials.append(L.material("R_socket"))
            names.append("R_socket")
        for f in made:
            c = f.calc_center_median()
            if c.z > 2.05 and c.y < -0.2:
                f.material_index = names.index("R_socket")
            else:
                f.material_index = names.index("R_79a6b7")
        bm.to_mesh(me)
        bm.free()
        groups = L.dominant_groups(body)
        hands = [V((1.95 * sx, 0.17, 1.85)) for sx in (-1.0, 1.0)]
        for v, g in zip(body.data.vertices, groups):
            if g == "Middle1.L" and (v.co.y < -0.3 or v.co.y > 0.45):
                continue  # the club
            for h in hands:
                d = v.co - h
                if d.length < 0.55 and abs(v.co.x) > 1.45:
                    t = L.smooth(0.55, 0.3, d.length) * L.smooth(1.45, 1.65, abs(v.co.x))
                    v.co = h + d * (1.0 + 0.38 * t)
        body.data.update()

    def paint(base):
        def fn(region, co, n, info):
            r = base(region, co, n, info)
            c = col_of(r)
            if region == "R_socket":
                return C("08060c"), IVORY  # deep eye sockets behind the glowing slits
            # slate -> obsidian basalt with a violet sheen on top faces
            c = V((c.x * 0.52, c.y * 0.46, c.z * 0.66))
            c = L.mix(c, C("54447a"), max(0.0, n.z) * 0.3)
            return c, mat_of(r)
        return fn

    def extra(arm, body, surf, parts):
        dark, sheen = C("120e1a"), C("4a3a66")
        # twisted obsidian horns
        for sx in (-1.0, 1.0):
            K.horn(parts, V((0.32 * sx, -0.25, 2.66)), V((0.35 * sx, 0.15, 1.0)).normalized(), 0.75, 0.12, HEAD,
                   dark, sheen, bend=V((0.2 * sx, 0.25, 0.0)), mat=shard_mat, seg=6, rings=6)
        # obsidian shards bursting from the shoulders and the back
        rng = random.Random(3)
        for sx in (-1.0, 1.0):
            q, m = K.dir_hit(surf, V((0.75 * sx, 0.15, 1.8)), V((0.3 * sx, 0.15, 1.0)))
            if q is None:
                continue
            for k in range(4):
                dd = (m + V((0.4 * sx * (k - 1.5), 0.3 + 0.1 * k, 0.45))).normalized()
                K.crystal(parts, q - m * 0.05 + V((0.08 * sx * (k - 1.5), 0.06 * k, 0)), dd,
                          (0.7 - 0.12 * abs(k - 1.5)) * rng.uniform(0.85, 1.1), 0.11, q, dark, sheen, mat=shard_mat,
                          sides=4)
        for k, (x, z) in enumerate(((0.28, 2.05), (-0.3, 1.9), (0.05, 1.6), (-0.15, 1.3), (0.22, 1.35))):
            q, m = K.dir_hit(surf, V((x, 0.0, z)), V((x * 0.6, 1.0, 0.2)))
            if q is not None:
                K.crystal(parts, q - m * 0.05, (m + V((0, 0.0, 0.5))).normalized(), 0.75 - 0.07 * k, 0.12, q,
                          dark, sheen, mat=shard_mat, sides=4)
        # a broken halo of floating shards behind the head
        ctr, ax = V((0, 0.75, 2.45)), V((0, 1, 0.15))
        t_, b_, n_ = L.frame(ax)
        for i in range(11):
            a = 2.0 * math.pi * i / 11 + 0.3
            if 0.38 < (a % (2 * math.pi)) / (2 * math.pi) < 0.47:
                continue  # the break
            d = t_ * math.cos(a) + b_ * math.sin(a)
            K.crystal(parts, ctr + d * 0.78, d, 0.3 + 0.08 * (i % 2), 0.075, TORSO, dark, sheen, mat=shard_mat,
                      sides=4)
        K.ring_of(parts, ctr, ax, 0.74, 30, 0.022, TORSO, C("f0e0ff"), gap=0.1, phase=0.3 + 2 * math.pi * 0.38)
        # accretion disc around the core
        p, n = K.front_hit(surf, 0.0, 1.45)
        if p is not None:
            K.ring_of(parts, p + n * 0.04, (n + V((0, 0, 0.6))).normalized(), 0.27, 22, 0.03, p, WHITE)
            with parts.on(IVORY):
                parts.ellipsoid(p + n * 0.02, (0.13, 0.13, 0.08), K.basis(n), color=C("05030a"), weights=p, seg=10,
                                rings=6)

    def post(body):
        # the base recipe's slate brow slabs, turned to obsidian like the rest
        me = body.data
        attr = me.color_attributes["Col"]
        ivory = [m.name for m in me.materials].index(IVORY)
        for p in me.polygons:
            c = p.center
            if p.material_index == ivory and c.z > 2.25 and c.y < -0.25 and 0.05 < abs(c.x) < 0.7:
                for li in p.loop_indices:
                    k = attr.data[li].color
                    if k[0] + k[1] + k[2] > 0.25:
                        attr.data[li].color = (k[0] * 0.52, k[1] * 0.46, k[2] * 0.66, 1.0)
        K.glow_tips(body, shard_mat, GLOW, 0.14, C("e8d8ff"), WHITE)
        K.flat(body, (shard_mat,))
        K.merge_materials(body, {shard_mat: IVORY})

    B.stone_golem(arm, body, {"shape": shape, "paint": paint, "extra": extra, "post": post, "skip": {"crystals"}})


# ================================================================ big/Demon

def void_emperor(arm, body):
    """void_emperor (violet boss): the demon crowned emperor of the void - a skin of night
    scattered with glowing stars, a tall gold crown set with void gems, a second pair of
    great swept-back horns, gold-trimmed black pauldrons, a royal mantle with a gold hem,
    a glowing third eye."""

    def paint(base):
        def fn(region, co, n, info):
            r = base(region, co, n, info)
            c, m = col_of(r), mat_of(r)
            if m == SKIN:
                lum = (c.x + c.y + c.z) / 3.0
                c = L.mix(C("1c1826"), C("8c84a8"), min(1.0, lum * 1.6))
            return c, m
        return fn

    def extra(arm, body, surf, parts):
        gold, gold_hi, iron = C("b07a1a"), C("ffe48a"), C("1a1622")
        apex, _n = surf.hit(V((0, -0.12, 3.6)), V((0, 0, -1)))  # from above, through the halo's hole
        base = apex - V((0, 0, 0.12))
        K.ring_band(parts, base, V((0, -0.1, 1)), 0.36, 0.16, lambda t, side: L.mix(gold, gold_hi, t * 0.7 + 0.2),
                    HEAD, seg=18, flare=1.14)
        K.spike_ring(parts, base + V((0, 0, 0.12)), V((0, -0.1, 1)), 0.39, 7, 0.42, 0.075, HEAD, gold, gold_hi,
                     tilt=0.18, phase=-math.pi / 2, sizes=[1.5, 0.75, 1.0, 0.75, 0.75, 1.0, 0.75], seg=5)
        for i in range(7):
            a = -math.pi / 2 + 2 * math.pi * i / 7
            d = V((math.cos(a), math.sin(a), 0))
            K.gem(parts, base + d * 0.4 + V((0, 0, 0.08)), d, 0.055, C("f4e8ff"), HEAD)
        # great swept-back horns
        for sx in (-1.0, 1.0):
            K.horn(parts, V((0.42 * sx, -0.05, 2.5)), V((0.55 * sx, 0.75, 0.35)).normalized(), 0.95, 0.12, HEAD,
                   C("140f1a"), gold_hi, bend=V((0.05 * sx, 0.1, 0.45)), rings_col=C("2a2040"), bands=6, seg=8,
                   rings=8)
        # third eye
        p, n = K.front_hit(surf, 0.0, 2.5)
        if p is not None:
            K.fierce_eye(parts, p - n * 0.05, 0.075, (n + V((0, -0.3, 0))).normalized(), 1.0, WHITE,
                         C("c080ff"), HEAD, lid=C("3a3448"), open_=0.6, slant=0.0, glow_mat=GLOW)
        # gold-trimmed black pauldrons with spikes
        for sx in (-1.0, 1.0):
            q, m = K.dir_hit(surf, V((0.72 * sx, 0.15, 1.85)), V((0.3 * sx, 0.05, 1.0)))
            if q is None:
                continue
            with parts.on(IVORY):
                parts.ellipsoid(q + m * 0.04, (0.32, 0.27, 0.13), K.basis(m), color=None, weights=q, seg=10, rings=6,
                                color_fn=lambda u: gold_hi if u.z < 0.25 else L.mix(iron, C("4a3e66"), u.z))
            for k in range(3):
                K.horn(parts, q + m * 0.12 + V((0.1 * sx * (k - 1), 0.06 * k, 0)),
                       (m + V((0.35 * sx, 0.15 * k, 0.15))).normalized(), 0.32 - 0.06 * abs(k - 1), 0.055, q,
                       iron, gold_hi, seg=6, rings=4)

        # the royal mantle (under the wings)
        def mw(u, t):
            return {"Torso": 1.0 - 0.6 * t, "Hips": 0.6 * t}

        K.cloth(parts, V((-0.6, 0.38, 1.82)), V((0.6, 0.38, 1.82)), V((0, 0.3, -1)), 1.55, mw,
                lambda u, t: gold_hi if t > 0.92 or u < 0.04 or u > 0.96 else
                L.mix(C("0e0818"), C("3a1a6a"), 0.3 + 0.6 * math.sin(u * math.pi) - 0.3 * t),
                cols=8, rows=6, thick=0.04, bulge=lambda u, t: V(((u - 0.5) * 0.45 * t, 0.12 * math.sin(u * math.pi),
                                                                  0)))
        # stars over the body
        rng = random.Random(17)
        for d in K.fibonacci(110):
            p, nn = K.dir_hit(surf, V((0, 0.1, 1.4)), d)
            if p is None or p.z < 0.4 or p.z > 2.0 or rng.random() < 0.45:
                continue
            s_ = rng.uniform(0.018, 0.034)
            with parts.on(GLOW):
                parts.decal(p, nn, K.ellipse(s_, s_, 6), WHITE, rings=1, lift=0.012)
        for sx in (-1.0, 1.0):
            for k in range(6):
                x = 0.7 + 0.2 * k
                p, nn = K.dir_hit(surf, V((x * sx, 0.18, 1.85)), V((0, -0.4 + 0.3 * (k % 3), 1.0)))
                if p is not None:
                    with parts.on(GLOW):
                        parts.decal(p, nn, K.ellipse(0.022, 0.022, 6), WHITE, rings=1, lift=0.012)

    B.demon(arm, body, {"paint": paint, "extra": extra, "skip": {"embers", "shoulder_spikes", "spines"}, "tris": 2900,
                        "eye": (WHITE, C("b070ff")), "lid": C("4a4258")})


# ================================================================ big/Dino

def jade_drake(arm, body):
    """jade_drake (sky isle; its template repaints Dino_Main / Dino_Secondary by name): a
    celestial drake - scaled hide instead of tiger bands, a row of polished jade plates
    down the spine, golden antlers, long golden whiskers, small jade-ribbed wings and
    jade-gold eyes."""
    jade, jade_hi, gold, gold_hi = C("0e6a46"), C("b8f8d8"), C("d8a830"), C("fff6c0")

    def shape(body):
        body["base_colors"] = '{"Dino_Main": "2fb48a", "Dino_Secondary": "eaf4c4"}'

    def paint(base):
        def fn(name, co, n, info):
            r = base(name, co, n, info)
            c, m = col_of(r), mat_of(r)
            if m == "Dino_Main":
                c = L.mix(WHITE, C("cfd8d0"), L.smooth(-0.3, 0.6, n.y))
                throat = L.smooth(-0.3, -0.85, n.y) * L.smooth(2.4, 1.6, co.z) * L.smooth(0.9, 1.3, co.z)
                c = L.mix(c, C("fffbea"), throat)
                # overlapping scales
                sc = abs(math.sin(co.z * 24.0 + math.sin(co.x * 24.0) * 1.3)) * abs(math.sin(co.x * 24.0 + 0.7))
                c = L.mix(c, C("8aa496"), L.smooth(0.55, 0.95, sc) * 0.4 * L.smooth(-0.2, 0.4, n.y + 0.3))
                c = L.mix(c, C("70887a"), L.smooth(0.35, 0.05, co.z) * 0.5)
            return c, m
        return fn

    def extra(arm, body, surf, parts):
        # golden antlers with forward tines
        for sx in (-1.0, 1.0):
            root = V((0.28 * sx, -0.18, 2.78))
            K.horn(parts, root, V((0.35 * sx, 0.55, 1.0)).normalized(), 0.75, 0.065, HEAD, gold, gold_hi,
                   bend=V((0.1 * sx, 0.25, 0.05)), seg=7, rings=7)
            K.horn(parts, root + V((0.08 * sx, 0.12, 0.3)), V((0.5 * sx, -0.3, 0.8)).normalized(), 0.3, 0.04, HEAD,
                   gold, gold_hi, seg=6, rings=4)
            K.horn(parts, root + V((0.14 * sx, 0.3, 0.55)), V((0.7 * sx, 0.1, 0.6)).normalized(), 0.22, 0.035,
                   HEAD, gold, gold_hi, seg=6, rings=4)
        # long whiskers from the snout
        for sx in (-1.0, 1.0):
            p, n = K.front_hit(surf, 0.17 * sx, 2.42)
            if p is None:
                continue
            K.horn(parts, p - n * 0.02, V((1.0 * sx, -0.15, -0.3)).normalized(), 0.75, 0.026, HEAD, gold, gold_hi,
                   bend=V((0.1 * sx, 0.15, -0.3)), seg=5, rings=7, tip=0.2)
        # jade plates down the spine
        for k, z in enumerate((2.25, 2.04, 1.83, 1.62, 1.41, 1.2, 0.99)):
            q, m = K.dir_hit(surf, V((0, 0.0, z)), V((0, 1.0, 0.05)))
            if q is None:
                continue
            s_ = 1.0 - 0.07 * abs(k - 2)
            with parts.on(IVORY):
                parts.blob(q - m * 0.06, (0.2 * s_, 0.05), (m + V((0, 0.5, 0.35))).normalized(), 0.55 * s_, None,
                           weights=q, seg=8, rings=5, tip=0.12, up=V((1, 0, 0)),
                           color_fn=lambda t: L.mix(jade, C("3cc890"), L.smooth(0.0, 0.8, t)) if t < 0.85 else jade_hi)
        # small wings: golden ribs, jade membrane
        for sx in (-1.0, 1.0):
            sh = V((0.32 * sx, 0.5, 1.98))
            ribs = [V((1.05 * sx, 0.75, 2.55)), V((1.15 * sx, 0.95, 2.15)), V((0.95 * sx, 1.0, 1.75)),
                    V((0.6 * sx, 0.9, 1.55))]
            bases = [sh + V((0.06 * sx * i, 0.04 * i, -0.05 * i)) for i in range(4)]
            K.fin(parts, bases, ribs, TORSO, lambda u, t: L.mix(C("1a8a60"), C("8ee8c0"), t * 0.7 + 0.15 * u),
                  mat=IVORY, thick=0.03, spines=(gold, gold_hi), spine_r=0.03)

    B.sand_raptor(arm, body, {"shape": shape, "paint": paint, "extra": extra,
                              "eye": (C("f6ffb0"), C("20a060"))})


# ================================================================ big/Ninja

NINJA_STEEL = ("Eye_White", "Birb_Secondary", "Gold")


def rift_stalker(arm, body):
    """rift_stalker (cyan): a hunter from between dimensions - a single vertical rift eye
    splitting the mask, katanas turned to blades of rift light, swept-back hood horns, a
    broken ring of glowing shards floating at its back and rift cracks over the limbs."""

    def paint(base):
        def fn(name, co, n, info):
            r = base(name, co, n, info)
            c, m = col_of(r), mat_of(r)
            if name in ("Eye_White", "Birb_Secondary"):  # energy blades
                return L.mix(C("bfefff"), WHITE, L.smooth(-0.01, 0.03, info["bump"])), GLOW
            if name == "Gold":
                return L.mix(C("1a2228"), C("5a6a78"), max(0.0, n.z)), IVORY
            if name == "Belt" and co.z > 0.5:
                return L.mix(C("0a1418"), C("1e3a44"), max(0.0, -n.y) * 0.6 + 0.2), IVORY
            if name == "Ninja_Secondary" and info["bone"] != "Head":
                u = co.x * 9.0 + co.z * 14.0 if abs(co.x) > 1.0 else co.z * 22.0 + co.y * 6.0
                return L.mix(C("1a2026"), C("3e4a56"), L.smooth(0.7, 0.95, math.sin(u))), IVORY
            return c, m
        return fn

    def extra(arm, body, surf, parts):
        # the rift eye: a tall glowing slit down the mask, cracks running out of it
        p, n = K.front_hit(surf, 0.0, 2.3)
        if p is not None:
            eye = [(0.02 * math.sin(i * 1.3), -0.17 + 0.34 * i / 8.0) for i in range(9)]
            with parts.on(DETAIL):
                parts.stroke(p, n, eye, 0.13, C("06080c"), lift=0.014, weights=HEAD)
            with parts.on(GLOW):
                parts.stroke(p, n, eye, 0.06, WHITE, lift=0.03, weights=HEAD)
            rng = random.Random(8)
            for a in (0.4, 2.7, -0.5, 3.6):
                start = (0.0, 0.12 if a in (0.4, 2.7) else -0.12)
                K.glow_path(parts, p, n, K.crack_path(rng, 0.2, 4, 0.3, start=start, heading=a), 0.022, C("e0faff"),
                            lift=0.025)
        # swept-back hood horns
        for sx in (-1.0, 1.0):
            with parts.on(SKIN):
                parts.blob(V((0.22 * sx, 0.0, 2.6)), (0.12, 0.05), V((0.35 * sx, 0.85, 0.55)).normalized(), 0.95,
                           None, weights=HEAD, seg=8, rings=7, tip=0.08, up=V((0, -0.5, 1)),
                           bend=V((0.05 * sx, 0.1, 0.3)), color_fn=lambda t: L.mix(C("34344a"), C("7070a0"), t))
        # a broken ring of rift shards at its back
        ctr, ax = V((0, 0.95, 2.05)), V((0, 1, 0))
        t_, b_, n_ = L.frame(ax)
        for i in range(12):
            if i in (4, 5):
                continue
            a = 2.0 * math.pi * i / 12
            d = t_ * math.cos(a) + b_ * math.sin(a)
            K.crystal(parts, ctr + d * 0.85, (d + n_ * 0.2).normalized(), 0.28 + 0.1 * (i % 3 == 0), 0.06, TORSO,
                      C("a8f0ff"), WHITE, mat=GLOW, sides=4)
        # rift cracks over the arms and legs
        rng = random.Random(2)
        for (c, d, h, ln) in ((V((0.9, 0.15, 1.82)), V((0, -0.3, 1)), 0.0, 0.45),
                              (V((-0.9, 0.15, 1.82)), V((0, -0.3, 1)), math.pi, 0.45),
                              (V((0.4, 0.15, 0.7)), V((0.3, -1, 0)), 1.5, 0.35),
                              (V((-0.4, 0.15, 0.7)), V((-0.3, -1, 0)), 1.6, 0.35),
                              (V((0.0, 0.1, 1.45)), V((0.25, -1, 0.1)), -1.2, 0.4)):
            q, m = K.dir_hit(surf, c, d)
            if q is not None:
                path = K.crack_path(rng, ln, 5, 0.3, heading=h)
                with parts.on(DETAIL):
                    parts.stroke(q, m, path, 0.06, C("06080c"), lift=0.01)
                K.glow_path(parts, q, m, path, 0.025, C("e0faff"))

    B.shadow_ninja(arm, body, {"paint": paint, "extra": extra, "skip": {"eyes", "scarf"}})


def abyss_merman(arm, body):
    """abyss_merman (teal): a warrior of the drowned abyss - the katanas gone, a barbed
    trident in its hand, scaled hide with a pale belly, a spined dorsal fin over the
    head, ear fins, fins on the forearms and calves, round glowing deep-sea eyes, gill
    slits and a fanged scowl, a kelp belt with shells."""

    def shape(body):
        L.delete_faces(body, where=lambda c, n, g: n in NINJA_STEEL or
                       (g == "Middle1.L" and (c.y < -0.12 or c.y > 0.42 or n == "Ninja_Main")) or
                       (n == "Ninja_Main" and c.y > 0.4 and c.z > 2.25))
        L.clean(body)

    def paint(base):
        def fn(name, co, n, info):
            r = base(name, co, n, info)
            c, m = col_of(r), mat_of(r)
            bone = info["bone"]
            if name == "Belt" and co.z > 0.5:  # kelp belt
                return L.mix(C("3a6a28"), C("9ac050"), L.smooth(0.6, 0.9, math.sin(co.x * 30.0)) * 0.6 + 0.2), IVORY
            if name == "Ninja_Secondary":
                if bone == "Head":  # the face: paler scaled skin
                    return L.mix(C("a8b4c0"), C("e0e8ee"), max(0.0, n.z) * 0.5 + max(0.0, -n.y) * 0.3)
                return L.mix(C("4a5a6a"), C("8a9aaa"), max(0.0, n.z))  # webbed hands and feet
            if m == SKIN:
                c = L.mix(C("5a6a80"), C("aab8c8"), L.smooth(-0.2, 0.7, n.z) * 0.5 + L.smooth(0.3, -0.6, n.y) * 0.4)
                belly = L.smooth(-0.4, -0.85, n.y) * L.smooth(0.8, 1.2, co.z) * L.smooth(1.85, 1.6, co.z)
                c = L.mix(c, C("e8ecf0"), belly * 0.7)
                sc = abs(math.sin(co.z * 28.0 + math.sin(co.x * 28.0) * 1.4)) * abs(math.sin(co.x * 28.0 + 0.5))
                c = L.mix(c, C("2e3a4c"), L.smooth(0.55, 0.95, sc) * 0.45)
            return c, m
        return fn

    def extra(arm, body, surf, parts):
        def fin_col(u, t):
            return L.mix(C("4a6a80"), C("dff2ff"), t * 0.8)

        spine = (C("34465a"), C("f0f8ff"))
        # round glowing deep-sea eyes and a fanged scowl
        for sx in (-1.0, 1.0):
            p, n = K.front_hit(surf, 0.24 * sx, 2.3)
            if p is None:
                continue
            gaze = (n + V((0.2 * sx, -0.4, 0))).normalized()
            K.fierce_eye(parts, p - n * 0.06, 0.11, gaze, sx, C("f4ffc0"), C("30c0a0"), HEAD, lid=C("5a6a80"),
                         open_=0.62, pupil="dot", slant=0.3, glow_mat=IVORY_GLOW)
        p, n = K.front_hit(surf, 0.0, 2.05)
        if p is not None:
            mouth = [(x / 8.0 * 0.26, -0.03 * (1 - (x / 8.0) ** 2) - 0.03 * abs(x / 8.0)) for x in range(-8, 9)]
            with parts.on(DETAIL):
                parts.stroke(p, n, mouth, 0.05, C("101822"), lift=0.012, weights=HEAD)
            for x in (-0.15, -0.07, 0.07, 0.15):
                q, m = K.front_hit(surf, x, 2.05)
                if q is not None:
                    K.fang(parts, q, (m * 0.3 + V((0, 0, -1))).normalized(), 0.08, 0.022, HEAD, seg=5, rings=3)
        # gill slits on the neck
        for sx in (-1.0, 1.0):
            for k in range(3):
                q, m = K.dir_hit(surf, V((0, -0.1, 2.0 - 0.05 * k)), V((sx, -0.3, -0.15)))
                if q is not None:
                    with parts.on(DETAIL):
                        parts.stroke(q, m, [(0.0, 0.07), (0.015, 0.0), (0.0, -0.07)], 0.025, C("1a2430"),
                                     lift=0.012)
        # spined dorsal fin over the head and down the nape
        bases, tips = [], []
        for i in range(9):
            a = math.radians(-35 + 125 * i / 8)  # from the brow over the crown to the nape
            d = V((0, -math.cos(a) * 0.45 + math.sin(a) * 0.9, math.cos(a)))
            q, m = K.dir_hit(surf, V((0, -0.15, 2.3)), d)
            if q is None:
                continue
            h = 0.12 + 0.4 * math.sin(math.pi * min(1.0, (i + 1) / 7.5)) ** 0.8
            bases.append(q - m * 0.03)
            tips.append(q + (m + V((0, 0.8, 0.4))).normalized() * h)
        K.fin(parts, bases, tips, HEAD, fin_col, mat=SKIN, spines=spine)
        # ear fins
        for sx in (-1.0, 1.0):
            q, m = K.dir_hit(surf, V((0, -0.15, 2.3)), V((sx, 0.1, 0.05)))
            if q is None:
                continue
            bs = [q + V((0, 0.08 * k - 0.1, -0.06 * k + 0.08)) for k in range(4)]
            ts = [b + V((0.3 * sx, 0.25 + 0.05 * k, 0.18 - 0.1 * k)) for k, b in enumerate(bs)]
            K.fin(parts, bs, ts, HEAD, fin_col, mat=SKIN, spines=spine, spine_r=0.018)
        # forearm and calf fins
        for sx in (-1.0, 1.0):
            side = "L" if sx > 0 else "R"
            bs = [V((x * sx, 0.3, 1.88)) for x in (1.2, 1.35, 1.5, 1.65)]
            ts = [b + V((0.08 * sx, 0.3 - 0.05 * k, 0.12)) for k, b in enumerate(bs)]
            K.fin(parts, bs, ts, {"LowerArm." + side: 1.0}, fin_col, mat=SKIN, spines=spine, spine_r=0.018)
            bs = [V((0.35 * sx, 0.36, z)) for z in (0.5, 0.38, 0.26, 0.14)]
            ts = [b + V((0.05 * sx, 0.28 - 0.04 * k, -0.05)) for k, b in enumerate(bs)]
            K.fin(parts, bs, ts, {"LowerLeg." + side: 1.0}, fin_col, mat=SKIN, spines=spine, spine_r=0.016)
        # the trident (left hand, where the katana was)
        w = {"Middle1.L": 1.0}
        bronze, verd, steel = C("3a3020"), C("6aa890"), C("e8f0f4")
        with parts.on(IVORY):
            parts.frustum(V((1.93, 0.75, 1.86)), V((0, -1, 0)), 0.04, 0.035, 2.55,
                          lambda t, side_: L.mix(bronze, verd, 0.3 + 0.4 * t), w, seg=8)
            parts.ellipsoid(V((1.93, -1.8, 1.86)), (0.3, 0.05, 0.06), color=None, weights=w, seg=8, rings=4,
                            color_fn=lambda u: L.mix(verd, C("c8f0e0"), max(0.0, u.z)))
        for dx in (-0.26, 0.0, 0.26):
            K.fang(parts, V((1.93 + dx, -1.8, 1.86)), V((dx * 0.25, -1, 0)), 0.6 if dx == 0 else 0.48, 0.05, w,
                   root=verd, tip_col=steel, seg=6, rings=4)
            barb = V((0.3 if dx >= 0 else -0.3, 0.8, 0)).normalized()
            K.fang(parts, V((1.93 + dx * 1.1, -2.2 if dx == 0 else -2.08, 1.86)), barb, 0.12, 0.024, w, root=steel,
                   tip_col=steel, seg=4, rings=2)
        # shells on the belt
        for x in (-0.28, 0.0, 0.28):
            q, m = K.front_hit(surf, x, 1.02)
            if q is not None:
                with parts.on(IVORY):
                    parts.ellipsoid(q + m * 0.02, (0.06, 0.06, 0.025), K.basis(m), color=None, weights=q, seg=8,
                                    rings=4, color_fn=lambda u: L.mix(C("e8b8a0"), C("fff4ec"), u.z))

    B.shadow_ninja(arm, body, {"shape": shape, "paint": paint, "extra": extra, "skip": {"eyes", "scarf"}})


# ================================================================ big/Orc_Skull

def bone_lord(arm, body):
    """bone_lord (blood-red boss): the skull orc made lord of bones - a crown of
    blood-stained bone spikes set with ruby embers, great spiralling horns, a ribcage
    breastplate, skull pauldrons with burning eyes, a tattered blood-red cape, corpse-grey
    hide (the mohawk gone under the crown)."""

    def shape(body):
        L.delete_faces(body, where=lambda c, n, g: n == "Orc_Mouth" and c.z > 2.5)
        L.clean(body)

    def paint(base):
        def fn(name, co, n, info):
            r = base(name, co, n, info)
            c, m = col_of(r), mat_of(r)
            if m == SKIN:
                c = L.mix(c, C("6a6660"), 0.55)
            if name == "MushroomKing_Main" and m == IVORY and c.x > 0.1:  # blood on the skull
                c = L.mix(c, C("6a1010"), L.smooth(0.62, 0.78, K.fbm(co, 3.0, 9)) * 0.6)
            return c, m
        return fn

    def extra(arm, body, surf, parts):
        bone_lo, bone_hi, blood = C("8a7458"), C("fff6e4"), C("7a1010")
        ruby = C("ff4020")
        apex, _n = K.dir_hit(surf, V((0, -0.25, 2.4)), V((0, -0.05, 1)))
        base = apex - V((0, 0, 0.14))
        K.ring_band(parts, base, V((0, 0, 1)), 0.4, 0.13, lambda t, side: L.mix(C("2a2224"), C("6a5a5a"), t), HEAD,
                    seg=18, flare=1.1)
        K.spike_ring(parts, base + V((0, 0, 0.1)), V((0, 0, 1)), 0.42, 9, 0.48, 0.08, HEAD, blood, bone_hi,
                     tilt=0.2, phase=-math.pi / 2, sizes=[1.5, 0.7, 1.05, 0.7, 0.85, 0.85, 0.7, 1.05, 0.7], seg=6)
        for i in (0, 2, 7):
            a = -math.pi / 2 + 2 * math.pi * i / 9
            d = V((math.cos(a), math.sin(a), 0))
            K.gem(parts, base + d * 0.44 + V((0, 0, 0.065)), d, 0.05, ruby, HEAD, mat=IVORY_GLOW)
        # great spiralling horns
        for sx in (-1.0, 1.0):
            K.horn(parts, V((0.44 * sx, -0.3, 2.5)), V((0.85 * sx, 0.15, 0.45)).normalized(), 0.95, 0.15, HEAD,
                   C("3a1a14"), bone_hi, bend=V((0.05 * sx, 0.35, 0.55)), rings_col=C("5a2a20"), bands=7, seg=10,
                   rings=9)
        # ribcage breastplate: a sternum and five pairs of ribs
        p, n = K.front_hit(surf, 0.0, 1.6)
        if p is not None:
            with parts.on(IVORY):
                parts.blob(p + V((0, 0, 0.3)), (0.06, 0.035), V((0, -0.12, -1)), 0.62, None, weights=TORSO, seg=8,
                           rings=6, tip=0.6, up=n, color_fn=lambda t: L.mix(bone_lo, bone_hi, 0.6))
        for k, z in enumerate((1.88, 1.74, 1.6, 1.46, 1.33)):
            for sx in (-1.0, 1.0):
                q, m = K.front_hit(surf, 0.05 * sx, z)
                if q is None:
                    continue
                K.fang(parts, q + m * 0.02, V((sx, 0.55, -0.12)), 0.5 - 0.04 * k, 0.05, TORSO, root=bone_hi,
                       tip_col=bone_lo, bend=V((0, 0.35, -0.05)), seg=6, rings=6, flat=0.7)
        # skull pauldrons with burning eyes
        for sx in (-1.0, 1.0):
            q, m = K.dir_hit(surf, V((0.75 * sx, 0.15, 1.9)), V((0.3 * sx, 0.0, 1.0)))
            if q is None:
                continue
            c0 = q + m * 0.12
            face = V((0.35 * sx, -1, 0.15)).normalized()
            side = face.cross(V((0, 0, 1))).normalized()
            with parts.on(IVORY):
                parts.ellipsoid(c0, (0.19, 0.17, 0.17), color=None, weights=q, seg=10, rings=7,
                                color_fn=lambda u: L.mix(bone_lo, bone_hi, L.smooth(-0.6, 0.8, u.z)))
                parts.ellipsoid(c0 + face * 0.12 + V((0, 0, -0.1)), (0.11, 0.08, 0.06), color=None, weights=q, seg=8,
                                rings=5, color_fn=lambda u: L.mix(bone_lo, bone_hi, 0.5))
                for ex in (-1.0, 1.0):
                    dd = (face + side * 0.45 * ex + V((0, 0, 0.1))).normalized()
                    parts.sphere_cap(c0, 0.19, dd, (0.3, 0.26), C("120808"), q, lift=0.02, detail=False)
            with parts.on(IVORY_GLOW):
                for ex in (-1.0, 1.0):
                    dd = (face + side * 0.45 * ex + V((0, 0, 0.1))).normalized()
                    parts.ellipsoid(c0 + dd * 0.17, (0.03, 0.03, 0.03), color=ruby, weights=q, seg=6, rings=4)
            K.horn(parts, c0 + V((0, 0, 0.12)), V((0.3 * sx, 0.2, 1)).normalized(), 0.3, 0.05, q, blood, bone_hi,
                   seg=6, rings=4)

        # tattered blood-red cape
        def cw(u, t):
            return {"Torso": 1.0 - 0.6 * t, "Hips": 0.6 * t}

        K.cloth(parts, V((-0.6, 0.38, 2.12)), V((0.6, 0.38, 2.12)), V((0, 0.3, -1)), 1.7, cw,
                lambda u, t: L.mix(C("5a0810"), C("b01a28"), 0.25 + 0.55 * math.sin(u * math.pi) - 0.25 * t),
                cols=10, rows=6, thick=0.04, ragged=0.35, seed=4,
                bulge=lambda u, t: V(((u - 0.5) * 0.4 * t, 0.14 * math.sin(u * math.pi), 0)))

    B.skull_orc(arm, body, {"shape": shape, "paint": paint, "extra": extra, "skip": {"horns"}, "tris": 3800})


# ================================================================ big/Tribal

def demon_ninja(arm, body):
    """demon_ninja (red): a warrior of the demon tribe - the bone mask recut as a lacquered
    oni mask with gold carving and tusks, great curved demon horns, the feather crown
    turned into a crown of hellfire, glowing war-paint, a black mane, lacquered shoulder
    plates (sode) with gold rims, black talons."""
    MASK, MARK, PALE = "6ea86c", "d2be5d", "c5c7d0"

    def paint(base):
        def fn(region, co, n, info):
            r = base(region, co, n, info)
            c, m = col_of(r), mat_of(r)
            rr = region[2:]
            mask = info["bone"] == "Head" and co.y < -0.2 and 1.55 < co.z < 3.0 and abs(co.x) < 0.66
            if rr == PALE:
                if co.z < 2.6 and abs(co.x) < 0.55:
                    return C("fff0d0"), IVORY_GLOW  # eyes burn inside the mask
                t = L.smooth(2.85, 3.85, co.z)  # feathers -> hellfire
                return L.mix(L.mix(C("5a0806"), C("ff4a10"), L.smooth(0.0, 0.5, t)), C("ffe070"),
                             L.smooth(0.55, 1.0, t)), IVORY_GLOW
            if mask:
                if rr == MASK:
                    return L.mix(C("6a0a10"), C("d42a30"), max(0.0, -n.y) * 0.7 + max(0.0, n.z) * 0.3), IVORY
                if rr == MARK:
                    return C("fff4e0"), IVORY  # the teeth
                if m == IVORY:
                    return L.mix(C("b07818"), C("ffd860"), max(0.0, -n.y)), IVORY  # gold carving
            if rr == MARK:  # body bands -> glowing war-paint
                return C("ffd8b0"), GLOW
            if m == SKIN:
                c = c * 0.7
            return c, m
        return fn

    def extra(arm, body, surf, parts):
        # great curved demon horns from the brow of the mask
        for sx in (-1.0, 1.0):
            K.horn(parts, V((0.5 * sx, -0.3, 2.62)), V((1.0 * sx, 0.05, 0.3)).normalized(), 1.0, 0.15, HEAD,
                   C("140c0e"), C("e8402a"), bend=V((-0.1 * sx, 0.0, 0.6)), rings_col=C("2a1416"), bands=5, seg=9,
                   rings=8)
            # tusks jutting up from the mask's jaw
            q, m = K.front_hit(surf, 0.3 * sx, 1.9)
            if q is not None:
                K.fang(parts, q, V((0.25 * sx, -0.35, 1.0)), 0.3, 0.06, HEAD, root=C("d8c8a0"),
                       bend=V((0.03 * sx, -0.05, 0)))
        # a black mane down the back of the head
        dirs = [d for d in K.fibonacci(60) if d.y > 0.25 and d.z > -0.2]
        K.tufts(parts, surf, V((0, -0.1, 2.5)), dirs, 0.42, 0.08, C("1a1414"), C("3a2a2a"), weights=HEAD, seed=6,
                per=1, droop=1.1, lift_out=0.45, seg=6, rings=4, flat=0.45, tip=0.2, mat=IVORY,
                skip=lambda p, n: p.y < 0.0)
        # lacquered shoulder plates with gold rims
        for sx in (-1.0, 1.0):
            q, m = K.dir_hit(surf, V((0.75 * sx, 0.15, 1.85)), V((0.25 * sx, 0.0, 1.0)))
            if q is None:
                continue
            for k in range(3):
                c0 = q + m * (0.06 - 0.02 * k) + V((0.1 * sx * k, 0.0, -0.13 * k))
                b = K.basis((m + V((0.5 * sx * k, 0, 0))).normalized())
                with parts.on(IVORY):
                    parts.ellipsoid(c0, (0.32 - 0.02 * k, 0.28, 0.07), b, color=None, weights=q, seg=10, rings=5,
                                    color_fn=lambda u: C("e0b040") if abs(u.z) < 0.35 else
                                    L.mix(C("5a0a10"), C("b8202a"), max(0.0, u.z)))
        # black talons
        for side in ("L", "R"):
            B.claws(parts, arm, side, length=0.15, root=C("1a1010"), tip_col=C("6a4a4a"))

    B.bone_mask_warrior(arm, body, {"paint": paint, "extra": extra, "skip": {"pauldrons"}, "tris": 3400})


# ================================================================ cute/Cthulhu

def hell_wizard(arm, body):
    """hell_wizard (red): a tentacle demon of hell - great curved obsidian horns, a
    floating crown of hellfire, lava cracks over the dome instead of veins, tentacle tips
    smouldering like embers, charred wings with burning edges, fiery eyes."""

    def paint(base):
        def fn(name, co, n, info):
            r = base(name, co, n, info)
            c, m = col_of(r), mat_of(r)
            bone = info["bone"]
            if bone.startswith("Wing"):
                d = abs(co.x) - 0.5
                if d > 0.98:
                    return L.mix(C("ff8a30"), C("ffe0a0"), L.smooth(0.98, 1.1, d)), IVORY_GLOW
                return L.mix(C("2a2024"), C("0e0a0c"), L.smooth(0.2, 1.0, d)), IVORY
            if co.y < -0.3 and co.z < 0.13:  # smouldering tentacle tips
                return L.mix(C("ff5010"), C("ffd080"), L.smooth(0.13, 0.0, co.z)), IVORY_GLOW
            return c, m
        return fn

    def extra(arm, body, surf, parts):
        for sx in (-1.0, 1.0):
            q, m = K.dir_hit(surf, V((0, 0, 0.9)), V((0.75 * sx, 0.05, 0.75)))
            if q is None:
                continue
            K.horn(parts, q - m * 0.05, V((0.75 * sx, 0.1, 0.55)).normalized(), 0.75, 0.12, HEAD,
                   C("120a0c"), C("ff5a30"), bend=V((-0.1 * sx, 0.05, 0.45)), rings_col=C("2a1a1a"), bands=5,
                   seg=10, rings=9)
        # a floating crown of hellfire above the dome
        apex, _n = K.dir_hit(surf, V((0, -0.1, 0.9)), V((0, 0, 1)))
        ctr = apex + V((0, 0, 0.12))
        K.spike_ring(parts, ctr, V((0, -0.15, 1)), 0.32, 7, 0.32, 0.07, {"Head2": 1.0}, C("ff3a10"), C("ffe680"),
                     mat=IVORY_GLOW, tilt=0.3, sizes=[1.4, 0.8, 1.0, 0.8, 1.0, 0.8, 1.0], phase=-math.pi / 2, seg=5)
        K.ring_of(parts, ctr, V((0, -0.15, 1)), 0.32, 18, 0.03, {"Head2": 1.0}, C("ff7a20"), mat=IVORY_GLOW)
        # lava cracks over the dome
        rng = random.Random(23)
        for d in (V((0.6, 0.3, 0.8)), V((-0.6, 0.3, 0.8)), V((0.2, 0.9, 0.5)), V((-0.3, 0.9, 0.3)),
                  V((0.8, -0.1, 0.4)), V((-0.8, -0.1, 0.4)), V((0.0, 0.7, 0.75)), V((0.5, 0.8, -0.1)),
                  V((-0.5, 0.8, -0.1))):
            q, m = K.dir_hit(surf, V((0, 0, 0.8)), d)
            if q is not None:
                path = K.crack_path(rng, 0.42, 6, 0.4)
                with parts.on(DETAIL):
                    parts.stroke(q, m, path, 0.07, C("1a0808"), lift=0.01)
                K.glow_path(parts, q, m, path, 0.03, C("ff8a30"), mat=IVORY_GLOW, lift=0.02)

    B.tentacle_horror(arm, body, {"paint": paint, "extra": extra, "skip": {"veins"},
                                  "eye": (C("fff0b0"), C("e02a10")), "lid": C("5a3a3a")})


def trench_horror(arm, body):
    """trench_horror (teal, elite): a horror of the deep trench - an angler's glowing lure
    on a stalk over the brow, a spined crest fin, rows of bioluminescent spots, barnacle
    crusts, finned wings with rays, pale milky deep-sea eyes."""

    def paint(base):
        def fn(name, co, n, info):
            r = base(name, co, n, info)
            c, m = col_of(r), mat_of(r)
            if info["bone"].startswith("Wing"):
                a = math.atan2(co.z - 0.7, abs(co.x) - 0.45)
                ray = L.smooth(0.75, 0.95, abs(math.sin(a * 9.0)))
                return L.mix(L.mix(C("4a5e6a"), C("1a242c"), L.smooth(0.2, 1.0, abs(co.x) - 0.5)), C("a8c8d0"),
                             ray * 0.5), m
            return c, m
        return fn

    def extra(arm, body, surf, parts):
        head3 = {"Head3": 1.0}
        apex, _n = K.dir_hit(surf, V((0, -0.2, 0.9)), V((0, -0.25, 1)))
        # the lure: a stalk arching up and over the brow, a glowing bulb
        stalk = V((0, -0.55, 1)).normalized()
        K.horn(parts, apex - V((0, 0, 0.03)), stalk, 0.7, 0.055, head3, C("2a3a40"), C("6a8a90"),
               bend=V((0, -0.45, -0.45)), seg=6, rings=8, tip=0.5)
        tip = apex + stalk * 0.7 + V((0, -0.45, -0.45))
        with parts.on(IVORY_GLOW):
            parts.ellipsoid(tip + V((0, -0.05, -0.08)), (0.14, 0.14, 0.16), color=None, weights=head3, seg=10, rings=6,
                            color_fn=lambda u: L.mix(C("6af0e0"), WHITE, L.smooth(-0.4, 0.8, -u.y)))
        # spined crest fin along the dome
        bases, tips = [], []
        for i in range(7):
            a = math.radians(10 + 120 * i / 6)
            d = V((0, -math.cos(a) * 0.3 + math.sin(a) * 1.0, math.cos(a) + 0.2))
            q, m = K.dir_hit(surf, V((0, 0.0, 0.8)), d)
            if q is None:
                continue
            h = 0.1 + 0.22 * math.sin(math.pi * (i + 0.5) / 7)
            bases.append(q - m * 0.02)
            tips.append(q + (m + V((0, 0.7, 0.3))).normalized() * h)
        K.fin(parts, bases, tips, "surface", lambda u, t: L.mix(C("4a6a78"), C("c8f0ff"), t * 0.8), mat=SKIN,
              spines=(C("2a3a44"), C("e8f8ff")), spine_r=0.018)
        # bioluminescent spots
        rng = random.Random(31)
        for d in K.fibonacci(70):
            if d.z < -0.1 or (d.y < -0.55 and abs(d.x) < 0.5 and d.z < 0.6) or rng.random() < 0.35:
                continue
            q, m = K.dir_hit(surf, V((0, 0, 0.75)), d)
            if q is None or q.z < 0.35:
                continue
            s_ = rng.uniform(0.022, 0.04)
            with parts.on(GLOW):
                parts.decal(q, m, K.ellipse(s_, s_, 8), WHITE, rings=1, lift=0.012)
        # barnacle crusts on the back of the dome
        for d in K.fibonacci(40):
            if d.y < 0.15 or d.z < -0.2 or rng.random() < 0.5:
                continue
            q, m = K.dir_hit(surf, V((0, 0, 0.75)), d)
            if q is None:
                continue
            s_ = rng.uniform(0.04, 0.07)
            with parts.on(IVORY):
                parts.frustum(q - m * 0.01, m, s_, s_ * 0.55, s_ * 0.9,
                              lambda t, side: L.mix(C("8a8478"), C("e0dccc"), t) if side or t < 0.5 else C("1a1a1a"),
                              q, seg=7)

    B.tentacle_horror(arm, body, {"paint": paint, "extra": extra, "eye": (C("d8fff4"), C("0a9a88")),
                                  "lid": C("3a4a54")})


# ================================================================ registry / runner

RECIPES = {
    "big/BlueDemon_void_golem": void_golem,
    "big/Demon_void_emperor": void_emperor,
    "big/Dino_jade_drake": jade_drake,
    "big/Ninja_rift_stalker": rift_stalker,
    "big/Ninja_abyss_merman": abyss_merman,
    "big/Orc_Skull_bone_lord": bone_lord,
    "big/Tribal_demon_ninja": demon_ninja,
    "big/Yeti_yeti_king": yeti_king,
    "big/Yeti_crystal_yeti": crystal_yeti,
    "cute/Cthulhu_hell_wizard": hell_wizard,
    "cute/Cthulhu_trench_horror": trench_horror,
}
# the shared rig each variant is built from: "<dir>/<Name>_<monster_id>" -> "<dir>/<Name>"
SOURCE = {name: name[:name.index("_" + mid)] for name, mid in (
    (n, f.__name__) for n, f in RECIPES.items())}


def build(name):
    import bpy
    L.reset()
    arm, body = L.load(os.path.join(SRC, SOURCE[name] + ".gltf"))
    clips = sorted(a.name for a in bpy.data.actions)
    before = L.tri_count(body)
    RECIPES[name](arm, body)
    out = os.path.join(OUT, name + ".glb")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    K.export(arm, body, out, clips)
    print("VARIANT %s tris %d -> %d, %d bytes, mats %s" % (name, before, L.tri_count(body), os.path.getsize(out),
                                                        ",".join(m.name for m in body.data.materials)))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    for name in (args or list(RECIPES)):
        build(name)
