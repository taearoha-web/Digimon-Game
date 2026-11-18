"""Bespoke boss models (team "bosses"): the four star-region kings, the party raid's blood
demon king and the dragon tomb's ancient bone dragon. Each takes a Quaternius rig for its
bones and clips, then is sculpted, painted and dressed into its own creature:

    /opt/bpy5/bin/python tools/blender/recipes_bosses.py [forest_king ...]

writes assets/models/monsters/boss/<Name>.glb (a model path of its own, "boss/<Name>",
used by StarMonsters / RaidData / DungeonData - the shared rigs are left alone). Clips the
game never asks for are dropped. Same materials as recipes_brutes (kit_brutes): Skin,
Detail, Glow, Ivory, IvoryGlow; the bosses are untinted, so every colour is final.
Budget: bosses may reach ~15k triangles.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import remaster_lib as L  # noqa: E402
import kit_brutes as K  # noqa: E402
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "models", "monsters")
OUT = os.path.join(SRC, "boss")

C = L.srgb
SKIN, DETAIL, GLOW, IVORY, IVORY_GLOW = K.SKIN, K.DETAIL, K.GLOW, K.IVORY, K.IVORY_GLOW
WHITE = C("ffffff")
GAME_CLIPS = ("Idle", "Flying_Idle", "Walk", "Run", "Fast_Flying", "Punch", "Headbutt", "HitReact", "Death")


# ---------------------------------------------------------------- shared helpers

def bone_weights(obj):
    """Per vertex: {bone: weight}."""
    names = [g.name for g in obj.vertex_groups]
    return [{names[g.group]: g.weight for g in v.groups if g.weight > 0.0} for v in obj.data.vertices]


def sculpt(obj, fn):
    """Moves every vertex: fn(co, weights) -> new co (weights {bone: w})."""
    ws = bone_weights(obj)
    for v, w in zip(obj.data.vertices, ws):
        v.co = fn(v.co.copy(), w)


def scale_about(co, pivot, s):
    d = co - pivot
    return pivot + Vector((d.x * s[0], d.y * s[1], d.z * s[2]))


def keep_clips(names, rename=None):
    """Drops the actions the game never plays; rename {old: new}."""
    for a in list(bpy.data.actions):
        if rename and a.name in rename:
            a.name = rename[a.name]
    for a in list(bpy.data.actions):
        if a.name not in names:
            bpy.data.actions.remove(a)


def leaf(parts, base, direction, length, width, root, tip_col, weights, up=None, curl=0.0, seg=6, rings=4):
    """A broad flat leaf (or petal, feather): a blob flattened across `up`."""
    d = direction.normalized()
    bend = (up.normalized() * curl * length) if (up is not None and curl) else None
    return parts.blob(base, (width, width * 0.22), d, length, None, weights=weights, seg=seg, rings=rings, tip=0.12,
                      bend=bend, up=up, color_fn=lambda t: L.mix(root, tip_col, L.smooth(0.0, 1.0, t)))


def flower(parts, center, normal, radius, petal, petal_tip, heart, weights, petals=5, seg=5):
    n = normal.normalized()
    t_, b_, _n = L.frame(n)
    for i in range(petals):
        a = 2.0 * math.pi * i / petals
        d = (t_ * math.cos(a) + b_ * math.sin(a) + n * 0.35).normalized()
        parts.blob(center, (radius * 0.55, radius * 0.16), d, radius * 1.15, None, weights=weights, seg=seg, rings=3,
                   tip=0.45, up=n, color_fn=lambda t: L.mix(petal, petal_tip, t))
    parts.ellipsoid(center + n * radius * 0.12, (radius * 0.32,) * 3, color=heart, weights=weights, seg=6, rings=4)


def branch(parts, base, direction, length, radius, weights, root, tip_col, rng, depth=2, tines=2, spread=0.55,
           tips=None, up=Vector((0, 0, 1))):
    """An antler: a curving main beam with tines that branch again; records tip points."""
    d = direction.normalized()
    bend = (up * 0.25 + d * 0.0) * length
    parts.blob(base, radius, d, length, None, weights=weights, seg=7, rings=5, tip=0.35, bend=bend,
               color_fn=lambda t: L.mix(root, tip_col, L.smooth(0.0, 1.0, t)))
    end = base + d * length + bend
    if tips is not None:
        tips.append((end, (d * length + bend).normalized()))
    if depth <= 0:
        return
    for k in range(tines):
        t = 0.45 + 0.4 * k / max(1, tines - 1)
        at = base + d * length * t + bend * t * t
        side = d.cross(up).normalized() * (1 if k % 2 == 0 else -1)
        nd = (d * 0.5 + up * 0.7 + side * spread * rng.uniform(0.6, 1.2)).normalized()
        branch(parts, at, nd, length * 0.5, radius * 0.6, weights, L.mix(root, tip_col, t), tip_col, rng, depth - 1,
               tines=1, spread=spread, tips=tips, up=up)


def crown(parts, center, axis, radius, height, points, gold, gold_dk, gem, weights, gem_mat=IVORY_GLOW, tilt=0.0):
    """A royal crown: a flared gold band with tall points, a gem set in front."""
    a = axis.normalized()
    with parts.on(IVORY):
        parts.frustum(center, a, radius, radius * 1.12, height * 0.45,
                      lambda t, side: L.mix(gold_dk, gold, t) if side else gold_dk, weights, seg=20)
        t_, b_, _n = L.frame(a)
        for i in range(points):
            ang = 2.0 * math.pi * i / points
            p = center + a * height * 0.35 + (t_ * math.cos(ang) + b_ * math.sin(ang)) * radius * 1.06
            out = (t_ * math.cos(ang) + b_ * math.sin(ang))
            tall = height * (1.0 if i % 2 == 0 else 0.7)
            parts.blob(p, (radius * 0.16, radius * 0.07), (a + out * 0.18).normalized(), tall, None, weights=weights,
                       seg=5, rings=3, tip=0.05, up=out, color_fn=lambda t: L.mix(gold_dk, gold, 0.4 + 0.6 * t))
    front = center + a * height * 0.22 - b_ * 0.0
    return front


def flat_islands(obj, mat_names):
    K.flat(obj, mat_names)


# ---------------------------------------------------------------- dawn_ancient_stag (big/Dino)

def forest_king(arm, body):
    """อรุณศิลา ราชันมังกรพฤกษา: an ancient forest dragon king grown out of stone and bark.
    The cute dino is sculpted into a heavy, small-headed dragon with a long snout; bark-brown
    hide with moss on every upward face, slabs of grey stone on the shoulders, forearms and
    spine, a crest of great leaves down the neck and back, branching antler-horns in flower,
    a gold crown with an emerald, amber eyes alight under stone brows, ivory fangs and claws,
    a long stone-plated tail."""
    keep_clips(("Idle", "Walk", "Run", "Punch", "HitReact", "Death"))
    L.delete_faces(body, ("Eye_White", "Eye_Black", "Dino_Tongue"))
    neck = Vector((0.0, -0.04, 2.0))

    def shape(co, w):
        hw = w.get("Head", 0.0) + 0.5 * w.get("Neck", 0.0)
        if hw > 0.0:
            # A smaller, longer head: shrunk about the neck, the snout drawn forward and
            # the crown flattened.
            s = scale_about(co, neck, (0.72, 0.8, 0.66))
            fwd = L.smooth(-0.2, -0.9, co.y)
            s.y -= 0.32 * fwd
            s.z -= 0.08 * fwd
            co = co.lerp(s, min(1.0, hw))
        # Broad shoulders and chest, heavy forearms, thick thighs.
        tw = w.get("Torso", 0.0) + w.get("Shoulder.L", 0.0) + w.get("Shoulder.R", 0.0)
        if tw > 0.0:
            co.x *= 1.0 + 0.25 * tw
            co.y -= 0.06 * tw * L.smooth(0.2, -0.2, co.y)
        aw = w.get("LowerArm.L", 0.0) + w.get("LowerArm.R", 0.0)
        if aw > 0.0:
            axis = Vector((math.copysign(1.0, co.x) * abs(co.x), 0.17, 1.83))
            r = co - axis
            r.x = 0.0
            co += r * 0.45 * aw
        lw = w.get("UpperLeg.L", 0.0) + w.get("UpperLeg.R", 0.0) + w.get("LowerLeg.L", 0.0) + w.get("LowerLeg.R", 0.0)
        if lw > 0.0:
            c = Vector((math.copysign(0.35, co.x), 0.22, co.z))
            co += (co - c) * 0.22 * lw
        return co

    sculpt(body, shape)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 6200)
    L.relax(body, 2, 0.35)

    bark, bark_dk, moss, moss_lt = C("b0804e"), C("6e4a30"), C("78bc44"), C("c4ec78")
    stone, stone_dk, belly = C("dcd6c2"), C("948e7e"), C("f2e8c4")

    def paint(name, co, n, info):
        if name == "Dino_Teeth":
            return L.mix(C("d8c8a0"), C("fffaf0"), 0.6), IVORY
        if name == "Dino_Tongue":
            return L.mix(C("5a1a1a"), C("b04a40"), L.smooth(-0.3, 0.6, n.z)), IVORY
        # Bark: vertical grain broken by noise, darker in the furrows.
        grain = K.fbm(Vector((co.x * 4.0, co.y * 4.0, co.z * 0.8)), 2.2, 4)
        c = L.mix(bark, bark_dk, L.smooth(0.42, 0.62, grain) * 0.8)
        c = L.mix(c, C("a07a50"), L.smooth(0.0, 0.05, info["bump"]) * 0.5)
        if name == "Dino_Secondary" and n.y < 0.2:
            # The belly: pale ribbed stone.
            v = abs(math.sin(co.z * math.pi / 0.16))
            c = L.mix(belly, stone_dk, L.smooth(0.3, 0.0, v) * 0.5)
            return c
        # Moss on every upward face and down the back.
        up = (L.smooth(0.25, 0.75, n.z) * 0.85 + L.smooth(0.3, 0.9, n.y) * 0.6) * L.smooth(1.55, 1.9, co.z) * L.smooth(1.15, 0.8, abs(co.x))
        m = L.mix(moss, moss_lt, K.fbm(co, 4.0, 2))
        c = L.mix(c, m, min(1.0, up) * L.smooth(0.35, 0.6, K.fbm(co, 2.5, 7) + 0.25))
        c = L.mix(c, C("2a1e18"), L.smooth(0.3, 0.05, co.z) * 0.5)
        return c

    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    rng = random.Random(3)
    head = {"Head": 1.0}

    # Eyes: amber, glowing, under heavy stone brows.
    for sx in (-1.0, 1.0):
        c = Vector((0.27 * sx, -0.5, 2.36))
        p, n = surf.toward(c + Vector((0.6 * sx, -0.9, 0.1)), c)
        if p is not None:
            c = p - n * 0.05
        gaze = Vector((0.5 * sx, -1.0, 0.05)).normalized()
        K.fierce_eye(parts, c, 0.085, gaze, sx, C("fff2a0"), C("ff9a20"), head, lid=bark_dk, open_=0.45,
                     glow_mat=IVORY_GLOW, slant=0.4)
        K.ridge(parts, c + Vector((0.11 * sx, 0.06, 0.08)), c + Vector((-0.08 * sx, -0.12, 0.06)), 0.06, stone_dk,
                head, bulge=Vector((0, -0.02, 0.04)), tip=0.7, mat=IVORY)
    # Fangs at the lip.
    for sx in (-1.0, 1.0):
        p, n = surf.toward(Vector((0.16 * sx, -3.0, 2.02)), Vector((0.16 * sx, 0.0, 2.02)))
        if p is not None:
            K.fang(parts, p + Vector((0, 0.02, 0.0)), Vector((0.05 * sx, -0.2, -1.0)), 0.14, 0.035, head)
    # Antler-horns: two great branching antlers, wood-dark at the root to pale tips, flowering.
    tips = []
    wood, wood_tip = C("3e2a1c"), C("c9ab7c")
    for sx in (-1.0, 1.0):
        p, n = surf.toward(Vector((0.25 * sx, -0.1, 4.0)), Vector((0.2 * sx, -0.25, 2.4)))
        if p is None:
            continue
        with parts.on(IVORY):
            branch(parts, p - n * 0.05, Vector((0.55 * sx, 0.45, 0.8)), 0.95, 0.105, head, wood, wood_tip, rng,
                   depth=2, tines=3, spread=0.6, tips=tips, up=Vector((0.2 * sx, 0.3, 1.0)).normalized())
    # Flowers on the antler tips and a few along the beams.
    with parts.on(IVORY):
        for i, (tp, td) in enumerate(tips):
            if i % 3 != 2:
                pink = (C("ff8fc0"), C("ffe6f2")) if i % 2 == 0 else (C("fff6f0"), C("ffb6d4"))
                flower(parts, tp, td, 0.15, pink[0], pink[1], C("ffd23a"), head)
        for (tp, td) in tips[1::2][:4]:
            for k in range(3):
                leaf(parts, tp, (td + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0.2))).normalized(), 0.13,
                     0.05, C("3f7a28"), C("a6dc60"), head, up=Vector((0, 0, 1)))
    # The crown: gold, seven points, an emerald in front.
    with parts.on(IVORY):
        cc = Vector((0.0, -0.22, 2.62))
        p, n = surf.toward(Vector((0.0, -0.22, 4.0)), Vector((0.0, -0.22, 2.2)))
        if p is not None:
            cc = p - Vector((0, 0, 0.1))
        front = crown(parts, cc, Vector((0, 0.15, 1.0)), 0.25, 0.34, 7, C("ffd560"), C("b07a1a"), C("2affa0"), head)
    with parts.on(IVORY_GLOW):
        parts.ellipsoid(cc + Vector((0, -0.21, 0.09)), (0.05, 0.03, 0.06), color=C("6affc0"), weights=head, seg=8,
                        rings=5)
    # Leaf crest from the crown down the neck and spine: great overlapping leaves.
    for k in range(9):
        z = 2.3 - k * 0.2
        y = 0.25 + k * 0.05
        p, n = surf.toward(Vector((0.0, 4.0, z + 0.3)), Vector((0.0, y - 0.2, z)))
        if p is None:
            continue
        s = 1.0 - abs(k - 3) * 0.08
        for sx in (-1.0, 1.0):
            d = (n + Vector((0.35 * sx, 0.3, 0.5))).normalized()
            leaf(parts, p - n * 0.04, d, 0.6 * s, 0.17 * s, C("3a7a2c"), C("b8e870"), p,
                 up=None)
    # Stone slabs: shoulders, forearms, the spine; mossy tops.
    def stone_col(u):
        return L.mix(stone_dk, stone, L.smooth(-0.6, 0.6, u.z)).lerp(moss, L.smooth(0.55, 0.95, u.z) * 0.8)

    for sx in (-1.0, 1.0):
        for k, (x, y, z, r) in enumerate(((0.62, 0.2, 2.02, 0.2), (0.85, 0.22, 1.98, 0.15), (0.45, 0.35, 2.12, 0.15))):
            p, n = surf.toward(Vector((x * sx, y, z + 2.0)), Vector((x * sx, y, z - 0.4)))
            if p is not None:
                K.rock(parts, p, r, stone_col, p, seed=k + (5 if sx > 0 else 0), squash=(1.2, 1.0, 0.6),
                       up=n)
        for k, x in enumerate((1.35, 1.55)):
            p, n = surf.toward(Vector((x * sx, 0.18, 3.5)), Vector((x * sx, 0.18, 1.6)))
            if p is not None:
                K.rock(parts, p, 0.12, stone_col, p, seed=20 + k + (5 if sx > 0 else 0), squash=(1.3, 1.0, 0.55),
                       up=n)
    # Claws: ivory hooks on the fingers and toes.
    for sx in (-1.0, 1.0):
        side = "L" if sx > 0 else "R"
        for fname in ("Index3", "Middle3", "Pinky3", "Thumb2"):
            b = arm.data.bones.get(fname + "." + side)
            if b is None:
                continue
            tip = b.tail_local
            d = (b.tail_local - b.head_local).normalized()
            K.fang(parts, tip - d * 0.03, (d + Vector((0, 0, -0.4))).normalized(), 0.13, 0.035,
                   {fname + "." + side: 1.0}, root=C("6a5a48"), tip_col=C("fff4dc"))
        for k in (-1, 0, 1):
            base = Vector((0.35 * sx + 0.09 * k, -0.17, 0.08))
            K.fang(parts, base, Vector((0.15 * k, -1.0, -0.25)).normalized(), 0.12, 0.04, {"Foot." + side: 1.0},
                   root=C("6a5a48"), tip_col=C("fff4dc"))
    # The tail: a long stone-plated sweep behind the hips, rigid on the hips.
    hips = {"Hips": 0.7, "Body": 0.3}
    pts = [Vector((0.0, 0.5 + 0.2 * i, 0.98 - 0.085 * i + 0.006 * i * i)) for i in range(10)]
    for i, p in enumerate(pts):
        r = 0.34 * (1.0 - i / 11.0)
        parts.ellipsoid(p, (r, r * 1.3, r * 0.9), color=None, weights=hips, seg=10, rings=7,
                        color_fn=lambda u: L.mix(bark_dk, bark, L.smooth(-0.6, 0.6, u.z)).lerp(moss, L.smooth(
                            0.5, 0.9, u.z) * 0.6))
        if i % 2 == 0 and i < 9:
            K.rock(parts, p + Vector((0, 0, r * 0.75)), r * 0.55, stone_col, hips, seed=40 + i, squash=(0.9, 1.1, 0.7))
    K.join_parts(body, parts.to_object())
    K.bake_ao(body, shade=Vector((0.5, 0.48, 0.42)))


# ---------------------------------------------------------------- crystal_horn_king (star/Bull)

CRYSTAL = "IvoryCrystal"  # faceted, flat-shaded, untinted


def shard(parts, base, direction, length, radius, weights, root, tip_col, sides=6):
    with parts.on(CRYSTAL):
        return parts.blob(base, radius, direction, length, None, weights=weights, seg=sides, rings=3, tip=0.02,
                          color_fn=lambda t: L.mix(root, tip_col, L.smooth(0.0, 1.0, t)))


def cluster(parts, base, normal, size, weights, root, tip_col, rng, n=3, lean=0.45):
    """A few crystals growing out of one spot, the tallest in the middle."""
    nn = normal.normalized()
    t_, b_, _n = L.frame(nn)
    shard(parts, base - nn * size * 0.1, nn, size, size * 0.27, weights, root, tip_col)
    for k in range(n - 1):
        a = 2.0 * math.pi * k / (n - 1) + rng.uniform(-0.4, 0.4)
        d = (nn + (t_ * math.cos(a) + b_ * math.sin(a)) * lean).normalized()
        shard(parts, base - nn * size * 0.08, d, size * rng.uniform(0.5, 0.7), size * 0.15, weights, root, tip_col,
              sides=5)


def crystal_king(arm, body):
    """ไครโอฮอร์น ราชันผลึกคราม: a king beast of the crystal valley. The bull is smoothed and
    raised into a heavy humped beast with a sapphire back fading to a frost-pale belly, a
    shaggy white frost mane, glowing ice eyes; two great crystal horns sweep forward from
    its brow, a crown of crystals stands between them, crystal spires run down its spine
    and armour its shoulders and shins, every crystal lit from within at the tip."""
    keep_clips(("Idle", "Walk", "Run", "Punch", "HitReact", "Death"))
    L.delete_faces(body, ("Eye_White", "Eye_Black", "Horns"))

    def shape(co, w):
        hump = w.get("Torso3", 0.0) + w.get("Neck1", 0.0) + 0.6 * w.get("Torso2", 0.0)
        if hump > 0.0:
            co.z += 0.45 * hump * L.smooth(3.4, 4.4, co.z)
            co.x *= 1.0 + 0.12 * hump
        hw = w.get("Head", 0.0)
        if hw > 0.0:
            co = co.lerp(scale_about(co, Vector((0.0, -4.0, 3.7)), (1.12, 1.0, 1.08)), hw)
        return co

    sculpt(body, shape)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 5600)
    L.relax(body, 2, 0.4)
    back, mid, belly, hoof = C("3a6cc4"), C("8cc0f0"), C("eef7ff"), C("2a3660")

    def paint(name, co, n, info):
        if name == "Hooves":
            return L.mix(hoof, C("6a7cb0"), L.smooth(0.0, 0.4, co.z)), IVORY
        if name == "Muzzle":
            return C("4a5a8a")
        up = L.smooth(-0.1, 0.8, n.z)
        c = L.mix(mid, back, up)
        c = L.mix(c, belly, L.smooth(-0.2, -0.8, n.z) * 0.85)
        c = L.mix(c, belly, L.smooth(1.4, 0.4, co.z) * 0.5)  # frosted legs
        c = L.mix(c, c * 0.78, L.smooth(0.5, 0.75, K.fbm(co, 3.5, 3)) * 0.6)  # fur clumps
        return c

    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    rng = random.Random(9)
    head = {"Head": 1.0}
    ice, ice_dk, ice_tip = C("6fb4ff"), C("2a58c0"), C("f0fdff")
    for sx in (-1.0, 1.0):
        c = Vector((0.6 * sx, -4.3, 3.86))
        gaze = Vector((0.7 * sx, -1.0, 0.0)).normalized()
        K.fierce_eye(parts, c, 0.13, gaze, sx, C("e8ffff"), C("2ad0ff"), head, lid=C("2e4c90"), open_=0.45,
                     glow_mat=IVORY_GLOW, slant=0.4)
        K.ridge(parts, c + Vector((0.12 * sx, 0.1, 0.12)), c + Vector((-0.1 * sx, -0.14, 0.1)), 0.08, C("3a5ca8"),
                head, bulge=Vector((0, -0.03, 0.05)), tip=0.7)
        # The great horns: forward and out, then up; a smaller tine behind each.
        hb = Vector((0.72 * sx, -3.95, 4.2))
        shard(parts, hb, Vector((0.9 * sx, -0.55, 0.55)), 2.7, 0.4, head, ice_dk, ice_tip, sides=7)
        shard(parts, hb + Vector((0.3 * sx, -0.25, 0.25)), Vector((0.5 * sx, -0.2, 1.0)), 1.3, 0.2, head, ice,
              ice_tip)
        shard(parts, hb + Vector((0.05 * sx, 0.25, 0.0)), Vector((0.8 * sx, 0.6, 0.3)), 1.1, 0.2, head, ice_dk,
              ice_tip)
    # The crown: a gold band set with a ring of crystals.
    cc = Vector((0.0, -4.05, 4.25))
    p, n = surf.toward(Vector((0.0, -4.05, 6.0)), Vector((0.0, -4.05, 3.5)))
    if p is not None:
        cc = p - Vector((0, 0, 0.12))
    with parts.on(IVORY):
        parts.frustum(cc, Vector((0, 0.1, 1.0)), 0.5, 0.56, 0.24,
                      lambda t, side: L.mix(C("b07a1a"), C("ffd560"), t) if side else C("b07a1a"), head, seg=20)
    for i in range(7):
        a = 2.0 * math.pi * i / 7 + math.pi * 0.5
        o = Vector((math.cos(a), math.sin(a) * 0.9, 0.0))
        tall = 1.3 if i == 0 else (0.95 if i in (1, 6) else 0.7)
        shard(parts, cc + o * 0.48 + Vector((0, 0, 0.12)), (Vector((0, 0, 1.0)) + o * 0.25).normalized(), tall, 0.16,
              head, ice, ice_tip, sides=5)
    # Spires down the spine: tallest over the shoulders.
    for k in range(9):
        y = -2.4 + k * 0.6
        p, n = surf.toward(Vector((0.0, y, 7.0)), Vector((0.0, y, 2.5)))
        if p is None:
            continue
        size = 1.7 * math.exp(-((k - 2.0) / 3.2) ** 2) + 0.5
        cluster(parts, p, (n + Vector((0, 0.35, 0.6))).normalized(), size, p, ice_dk, ice_tip, rng, n=3)
    # Shoulder armour and shin crystals.
    for sx in (-1.0, 1.0):
        for k, (y, z, d) in enumerate(((-1.75, 3.0, (0.9, -0.3, 0.6)), (-2.05, 2.55, (1.0, -0.5, 0.1)),
                                         (-1.4, 2.6, (1.0, 0.1, 0.3)))):
            p, n = surf.toward(Vector((3.0 * sx, y, z)), Vector((0.0, y, z)))
            if p is not None:
                cluster(parts, p, Vector((d[0] * sx, d[1], d[2])), 0.95 - 0.12 * k, p, ice_dk, ice_tip, rng, n=3)
        for y in (-1.85, 2.45):
            p, n = surf.toward(Vector((2.0 * sx, y, 0.8)), Vector((0.62 * sx if y < 0 else 0.55 * sx, y, 0.8)))
            if p is not None:
                shard(parts, p - n * 0.05, (n + Vector((0, 0.2, 0.7))).normalized(), 0.7, 0.14, p, ice_dk, ice_tip)
    # The frost mane: shaggy white fur around the neck and chest.
    dirs = [d for d in K.fibonacci(46) if d.y < 0.2]
    K.tufts(parts, surf, Vector((0.0, -2.4, 3.4)), dirs, 0.85, 0.24, C("cfe4ff"), C("ffffff"), seed=4, jitter=0.4, flat=0.45, tip=0.3,
            lift_out=0.5, droop=0.9, skip=lambda p, n: p.y < -3.4 or p.z < 2.3)
    # A crystal at the tail's end.
    tail = arm.data.bones.get("Tail7")
    if tail is not None:
        shard(parts, tail.head_local + Vector((0, 0, -0.1)), Vector((0, 0.2, -1.0)), 0.5, 0.12, {"Tail7": 1.0}, ice,
              ice_tip)
    K.join_parts(body, parts.to_object())
    K.flat(body, (CRYSTAL,))
    K.glow_tips(body, CRYSTAL, IVORY_GLOW, 0.14, C("bff4ff"), C("ffffff"))
    K.bake_ao(body, shade=Vector((0.5, 0.56, 0.72)))


# ---------------------------------------------------------------- sky_celestial_king (star/Horse_White)

def add_bones(arm, specs):
    """New deform bones [(name, head, tail, parent)] in the rig's rest pose."""
    with L._ctx(arm):
        bpy.ops.object.mode_set(mode="EDIT")
        eb = arm.data.edit_bones
        for name, head, tail, parent in specs:
            b = eb.new(name)
            b.head, b.tail = head, tail
            b.roll = 0.0
            b.parent = eb[parent]
            b.use_deform = True
        bpy.ops.object.mode_set(mode="OBJECT")


def key_bones(arm, fn, step=2):
    """Keys extra bones into every clip: fn(clip, t 0..1) -> {bone: 3x3 rotation in the
    armature's rest frame}; looping clips should return the same at t 0 and 1."""
    if arm.animation_data is None:
        arm.animation_data_create()
    scene = bpy.context.scene
    for act in list(bpy.data.actions):
        arm.animation_data.action = act
        if hasattr(arm.animation_data, "action_slot") and act.slots:
            arm.animation_data.action_slot = act.slots[0]
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        frames = list(range(f0, f1, step)) + [f1]
        for f in frames:
            t = (f - f0) / max(1, f1 - f0)
            for name, rot in fn(act.name, t).items():
                pb = arm.pose.bones[name]
                bm = pb.bone.matrix_local.to_3x3()
                pb.rotation_mode = "QUATERNION"
                pb.rotation_quaternion = (bm.inverted() @ rot @ bm).to_quaternion()
                pb.keyframe_insert("rotation_quaternion", frame=f)
    arm.animation_data.action = None
    scene.frame_set(0)
    for p in arm.pose.bones:
        p.matrix_basis = Matrix.Identity(4)


def feather_wing(parts, root, span_dir, up, length, sx, weights_in, weights_out, white, gold, rng):
    """A great feathered wing from root along span_dir: rows of coverts, secondaries and long
    primaries fanning back and down, white to gold at the tips."""
    s = span_dir.normalized()
    back = Vector((0, 1.0, -0.15)).normalized()
    plane = s.cross(back).normalized()
    if plane.z < 0.0:
        plane = -plane
    for row, (count, ln, wd, z) in enumerate(((8, 0.6, 0.24, 0.0), (9, 1.1, 0.25, -0.1), (7, 1.75, 0.26, -0.18))):
        for i in range(count):
            t = (i + 0.5) / count
            if row == 2:
                t = 0.55 + 0.45 * t
            base = root + s * length * t + plane * (0.06 - 0.06 * row) + up * z
            fan = back.lerp(s, 0.15 + 0.75 * t ** 1.6).normalized()
            d = (fan + Vector((0, 0, -0.25 * (1.0 - t)))).normalized()
            w = weights_in if t < 0.45 else weights_out
            col_tip = gold if row == 2 else L.mix(white, gold, 0.45)
            leaf(parts, base, d, ln * (0.75 + 0.35 * t) * rng.uniform(0.92, 1.05), wd, white, col_tip, w,
                 up=plane, seg=6, rings=4)


def sky_king(arm, body):
    """เอเธอเรียน ราชันปีกสวรรค์: the winged sun-horse king of the sky citadel. A pearl-white
    horse, its mane and tail flowing gold, gold armour (a face plate with a short sun-horn,
    a collar of gold plates, cuffs above golden hooves), great white-and-gold wings on bones
    of their own that beat in every clip, a crown of rays, and a sun halo carried behind the
    head by the withers (never in front of the face)."""
    keep_clips(("Idle", "Walk", "Run", "Punch", "HitReact", "Death"))
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    root_l, root_r = Vector((0.32, -0.7, 3.5)), Vector((-0.32, -0.7, 3.5))
    add_bones(arm, [
        ("Wing1.L", root_l, Vector((1.3, -0.35, 4.25)), "Torso3"),
        ("Wing2.L", Vector((1.3, -0.35, 4.25)), Vector((2.6, 0.2, 4.9)), "Wing1.L"),
        ("Wing1.R", root_r, Vector((-1.3, -0.35, 4.25)), "Torso3"),
        ("Wing2.R", Vector((-1.3, -0.35, 4.25)), Vector((-2.6, 0.2, 4.9)), "Wing1.R"),
    ])

    def flap(clip, t):
        # Raise angle (radians) of the wing: slow beats at rest, faster on the move, a
        # great upstroke then a downbeat in the attack, folded down in death.
        if clip == "Idle":
            a = 0.18 * math.sin(2 * math.pi * t * 2)
        elif clip == "Walk":
            a = 0.25 * math.sin(2 * math.pi * t * 2)
        elif clip == "Run":
            a = 0.45 * math.sin(2 * math.pi * t * 2)
        elif clip == "Punch":
            a = 0.7 * math.sin(math.pi * min(1.0, t / 0.45)) if t < 0.45 else -0.45 * math.sin(math.pi * (t - 0.45) / 0.55)
        elif clip == "HitReact":
            a = -0.25 * math.sin(math.pi * t)
        else:
            a = -0.7 * L.smooth(0.0, 0.8, t)
        out = {}
        for side, sgn in (("L", -1.0), ("R", 1.0)):
            out["Wing1." + side] = Matrix.Rotation(sgn * a, 3, "Y")
            out["Wing2." + side] = Matrix.Rotation(sgn * a * 0.6, 3, "Y")
        return out

    def shape(co, w):
        nw = w.get("Neck1", 0.0) + w.get("Neck2", 0.0) + w.get("Torso3", 0.0) * 0.6
        if nw > 0.0:
            co.x *= 1.0 + 0.12 * nw
        return co

    sculpt(body, shape)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 5000)
    L.relax(body, 2, 0.4, ("Main", "Main_Light"))
    pearl, cream, shadow = C("fffdf6"), C("f2e6cc"), C("d8cbe0")
    gold, gold_dk, gold_lt = C("ffcf4a"), C("c08418"), C("fff0b0")

    def paint(name, co, n, info):
        if name == "Hooves":
            return L.mix(gold_dk, gold, L.smooth(0.0, 0.3, co.z)), IVORY
        if name == "Hair":
            # Mane and tail: gold at the roots flowing to pale gold-white.
            t = L.smooth(-0.02, 0.1, info["bump"])
            return L.mix(C("ffb52a"), gold_lt, t * 0.7 + 0.3 * K.noise(co, 6.0, 1)), IVORY
        if name == "Muzzle":
            return C("e8c8c0")
        c = L.mix(cream, pearl, L.smooth(-0.3, 0.6, n.z))
        c = L.mix(c, shadow, L.smooth(-0.4, -0.9, n.z) * 0.5)
        return c

    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    rng = random.Random(5)
    head = {"Head": 1.0}
    for sx in (-1.0, 1.0):
        c = Vector((0.27 * sx, -2.92, 4.14))
        gaze = Vector((1.0 * sx, -0.5, 0.0)).normalized()
        K.fierce_eye(parts, c, 0.075, gaze, sx, C("fff6c0"), C("f0a020"), head, lid=cream, open_=0.6,
                     glow_mat=IVORY_GLOW, slant=0.2, pupil="dot")
    # Face plate: a gold shell down the forehead and nose, a short radiant horn on the brow.
    with parts.on(IVORY):
        for k in range(4):
            y = -2.75 - k * 0.17
            p, n = surf.toward(Vector((0.0, y - 0.6, 6.0)), Vector((0.0, y, 3.6)))
            if p is not None:
                parts.ellipsoid(p - n * 0.02, (0.17 - 0.015 * k, 0.12, 0.05), K.basis(n, Vector((0, -1, 0))),
                                color=None, weights=head, seg=10, rings=5,
                                color_fn=lambda u: L.mix(gold_dk, gold_lt, L.smooth(-0.6, 0.9, u.z)))
        p, n = surf.toward(Vector((0.0, -3.4, 6.0)), Vector((0.0, -2.75, 4.0)))
        if p is not None:
            K.horn(parts, p - n * 0.04, Vector((0.0, -0.7, 0.75)), 0.55, 0.075, head, gold_dk, gold_lt,
                   rings_col=C("fff8e0"), mat=IVORY, seg=8, rings=6, bands=5)
        # A crown of rays between the ears.
        cc = Vector((0.0, -2.55, 4.5))
        crown(parts, cc, Vector((0.0, 0.25, 1.0)), 0.16, 0.3, 7, gold, gold_dk, C("ffffff"), head)
        # The collar: gold plates round the base of the neck.
        for i in range(11):
            a = math.pi * (0.1 + 0.8 * i / 10.0)
            o = Vector((math.cos(a) * 0.6, -1.38 - math.sin(a) * 0.3, 3.0 - math.sin(a) * 0.38))
            p, n = surf.project(o, (o - Vector((0.0, -1.2, 3.1))).normalized(), 0.6)
            if p is not None:
                parts.ellipsoid(p + n * 0.02, (0.2, 0.15, 0.05), K.basis(n), color=None, weights=p, seg=8, rings=4,
                                color_fn=lambda u: L.mix(gold_dk, gold_lt, L.smooth(-0.5, 0.9, u.y)))
        # Cuffs above the hooves.
        for bone, y in (("FrontLowerLeg", -1.32), ("BackLowerLeg", 1.72)):
            for sx in (-1.0, 1.0):
                x = 0.4 * sx
                parts.frustum(Vector((x, y, 0.38)), Vector((0, 0, 1)), 0.13, 0.11, 0.16,
                              lambda t, side: L.mix(gold_dk, gold_lt, t) if side else gold_dk,
                              Vector((x, y, 0.45)), seg=12)
    # Flowing mane strands down the crest of the neck, tail plumes.
    for k in range(9):
        t = k / 8.0
        p = Vector((0.0, -2.45 + 1.15 * t, 4.45 - 1.05 * t))
        hit, n = surf.toward(p + Vector((0, 0.6, 1.2)), p - Vector((0, 0, 0.3)))
        if hit is None:
            continue
        for sx in (-1.0, 1.0):
            d = Vector((0.35 * sx, 0.8, -0.35)).normalized()
            with parts.on(IVORY):
                leaf(parts, hit - n * 0.03, d, 0.75 - 0.2 * t, 0.12, C("ffb52a"), gold_lt, hit,
                     up=Vector((sx, 0, 0.3)).normalized(), seg=6, rings=4)
    # Wings.
    white = C("ffffff")
    for sx, rt in ((1.0, root_l), (-1.0, root_r)):
        side = "L" if sx > 0 else "R"
        span = Vector((1.0 * sx, 0.2, 0.55))
        with parts.on(SKIN):
            parts.blob(rt, (0.22, 0.12), span, 1.35, None, weights={"Wing1." + side: 1.0}, seg=8, rings=5, tip=0.5,
                       color_fn=lambda t: L.mix(cream, pearl, t))
            parts.blob(rt + span.normalized() * 1.3, (0.14, 0.08), Vector((1.0 * sx, 0.4, 0.45)), 1.4, None,
                       weights={"Wing2." + side: 1.0}, seg=8, rings=5, tip=0.3,
                       color_fn=lambda t: L.mix(pearl, gold_lt, t))
            feather_wing(parts, rt, Vector((1.0 * sx, 0.3, 0.5)), Vector((0, 0, 1.0)), 2.6, sx,
                         {"Wing1." + side: 1.0}, {"Wing2." + side: 1.0}, white, gold, rng)
    # The sun halo: a ring of light and rays behind the head, carried by the withers so it
    # stays behind the head when the head dips (never in front of the face).
    neck = {"Torso3": 1.0}
    hc = Vector((0.0, -1.95, 4.9))
    axis = Vector((0.0, 1.0, 0.25)).normalized()
    with parts.on(IVORY_GLOW):
        t_, b_, _n = L.frame(axis)
        for i in range(24):
            a = 2.0 * math.pi * i / 24
            p = hc + (t_ * math.cos(a) + b_ * math.sin(a)) * 0.95
            q = hc + (t_ * math.cos(a + 0.27) + b_ * math.sin(a + 0.27)) * 0.95
            parts.blob(p, 0.075, q - p, (q - p).length * 1.05, None, weights=neck, seg=6, rings=3, tip=0.9,
                       color_fn=lambda t: gold_lt)
        for i in range(12):
            a = 2.0 * math.pi * (i + 0.5) / 12
            o = t_ * math.cos(a) + b_ * math.sin(a)
            parts.blob(hc + o * 1.02, (0.1, 0.035), o, 0.5 if i % 2 == 0 else 0.3, None, weights=neck, seg=4,
                       rings=2, tip=0.05, up=axis, color_fn=lambda t: L.mix(gold, gold_lt, t))
    K.join_parts(body, parts.to_object())
    K.bake_ao(body, shade=Vector((0.62, 0.58, 0.7)))
    key_bones(arm, flap)


# ---------------------------------------------------------------- big/Demon: the two humanoid kings

DEMON_EYE, DEMON_PUPIL, DEMON_DARK = "c5c7d0", "606266", "666966"


def demon_base(arm, body, head_scale, keep_wings=False, keep_horns=False):
    """The Demon rig stripped to its body (no eyes, halo, trident; wings / horns kept on
    request), the head shrunk about the neck, the chest broadened; returns the region keys
    of the faces left."""
    keys = K.regions(body)
    K.tag_regions(body, keys)

    def kill(c, mat, bone):
        r = mat[2:]
        if r in (DEMON_EYE, DEMON_PUPIL):
            return True
        if r == DEMON_DARK:
            if bone == "Head" and keep_horns and c.z < 3.0:
                return False
            if bone == "Neck" and keep_wings:
                return False
            return True
        if bone == "Neck" and abs(c.x) > 0.3 and not keep_wings:
            return True  # the wing membranes
        return False

    L.delete_faces(body, where=kill)
    pivot = Vector((0.0, 0.08, 1.95))

    def shape(co, w):
        hw = w.get("Head", 0.0)
        if hw > 0.0:
            co = co.lerp(scale_about(co, pivot, head_scale), min(1.0, hw))
        tw = w.get("Torso", 0.0) + 0.7 * (w.get("Shoulder.L", 0.0) + w.get("Shoulder.R", 0.0))
        if tw > 0.0:
            co.x *= 1.0 + 0.2 * tw
            co.y -= 0.08 * tw * L.smooth(0.25, -0.15, co.y)
        return co

    sculpt(body, shape)
    return keys


def metal(dark, light, trim, edge=0.75):
    """Plate colour by the unit vector on an ellipsoid: dark steel lit from above, a trim
    band at the rim (|u.z| or the lower edge)."""
    def fn(u):
        c = L.mix(dark, light, L.smooth(-0.3, 0.9, u.z) * 0.8)
        return L.mix(c, trim, L.smooth(edge, edge + 0.08, -u.z))
    return fn


def shell(parts, center, radii, weights, color_fn, basis=Matrix.Identity(3), seg=14, rings=9):
    with parts.on(IVORY):
        return parts.ellipsoid(center, radii, basis, color=None, weights=weights, seg=seg, rings=rings,
                               color_fn=color_fn)


def eclipse_knight(arm, body):
    """น็อกซ์ออเรล ราชันสุริยคราส, the star story's final boss: a towering crowned eclipse
    knight. A small head in a black great-helm with a burning gold visor slit and a gold
    crown, layered black-and-gold pauldrons, breastplate with an eclipse sigil, a skirt of
    plates, heavy gauntlets and greaves, a violet-black cape with a gold hem, a great black
    sword with a glowing gold fuller in his hand (the rig's weapon swing is his attack), and
    the eclipse itself behind him: a black sun in a ring of gold fire."""
    keep_clips(("Idle", "Walk", "Run", "Weapon", "HitReact", "Death"))
    bpy.data.actions["Weapon"].name = "Punch"
    demon_base(arm, body, (0.62, 0.62, 0.62))
    L.clean(body)
    L.decimate_to(body, 3200)
    L.relax(body, 2, 0.4)

    under = C("3e3052")

    def paint(region, co, n, info):
        c = L.mix(under, C("4a3a5a"), L.smooth(-0.3, 0.9, n.z) * 0.6)
        return L.mix(c, c * 0.7, L.smooth(0.4, 0.6, math.sin(co.z * 40.0) * 0.5 + 0.5) * 0.3)

    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    steel, steel_lt, gold, gold_lt, gold_dk = C("3a3058"), C("9a8cc8"), C("f2b440"), C("ffe7a0"), C("9a6416")
    plate = metal(steel, steel_lt, gold, 0.62)
    head = {"Head": 1.0}
    lo, hi = L.bounds(body, [v.index for v, g in zip(body.data.vertices, L.dominant_groups(body)) if g == "Head"])
    hc = (lo + hi) * 0.5
    hr = (hi - lo) * 0.5
    # The great-helm, its visor slit alight, a crest and the crown.
    shell(parts, hc + Vector((0, -0.02, 0.02)), (hr.x * 1.12, hr.y * 1.15, hr.z * 1.12), head, plate, seg=16,
          rings=10)
    with parts.on(IVORY_GLOW):
        parts.ellipsoid(hc + Vector((0.0, -hr.y * 1.1, 0.02)), (hr.x * 0.8, 0.03, 0.035), color=gold_lt,
                        weights=head, seg=10, rings=4)
    with parts.on(IVORY):
        parts.blob(hc + Vector((0, -hr.y * 1.12, -0.05)), (0.035, 0.02), Vector((0, 0, -1.0)), hr.z * 0.8, None,
                   weights=head, seg=6, rings=3, tip=0.6, color_fn=lambda t: gold)
        crown(parts, hc + Vector((0, 0.0, hr.z * 0.8)), Vector((0, 0.1, 1.0)), hr.x * 0.95, hr.z * 0.9, 9,
              gold, gold_dk, gold_lt, head)
        for sx in (-1.0, 1.0):
            # swept wing-crests on the helm's sides
            for k in range(3):
                parts.blob(hc + Vector((hr.x * 1.05 * sx, 0.05 + 0.06 * k, 0.05 + 0.08 * k)), (0.08, 0.025),
                           Vector((0.45 * sx, 0.8, 0.5 + 0.25 * k)), 0.55 - 0.1 * k, None, weights=head, seg=6,
                           rings=4, tip=0.08, up=Vector((sx, 0, 0)),
                           color_fn=lambda t: L.mix(gold_dk, gold_lt, t))
    # Pauldrons: three layered shells on each shoulder.
    for sx in (-1.0, 1.0):
        side = "L" if sx > 0 else "R"
        for k in range(3):
            c = Vector((0.62 * sx + 0.1 * k * sx, 0.18, 2.0 - 0.13 * k))
            w = {"UpperArm." + side: 0.55 + 0.15 * k, "Shoulder." + side: 0.45 - 0.15 * k}
            b = K.basis(Vector((0.55 * sx, 0.0, 1.0)).normalized())
            shell(parts, c, (0.5 - 0.06 * k, 0.42 - 0.04 * k, 0.24), w, metal(steel, steel_lt, gold, 0.55), b)
        # a gold spike on top
        with parts.on(IVORY):
            parts.blob(Vector((0.7 * sx, 0.2, 2.18)), (0.07, 0.07), Vector((0.4 * sx, 0.1, 1.0)), 0.35, None,
                       weights={"UpperArm." + side: 0.5, "Shoulder." + side: 0.5}, seg=6, rings=3, tip=0.05,
                       color_fn=lambda t: L.mix(gold_dk, gold_lt, t))
        # Gauntlets and vambraces, greaves, sabatons.
        shell(parts, Vector((1.47 * sx, 0.18, 1.83)), (0.32, 0.24, 0.24), {"LowerArm." + side: 1.0},
              metal(steel, steel_lt, gold, 0.6), K.basis(Vector((1.0 * sx, 0, 0))))
        shell(parts, Vector((1.82 * sx, 0.16, 1.86)), (0.17, 0.19, 0.17), {"LowerArm." + side: 1.0}, plate)
        shell(parts, Vector((0.35 * sx, 0.18, 0.33)), (0.22, 0.24, 0.3), {"LowerLeg." + side: 1.0},
              metal(steel, steel_lt, gold, 0.7))
        shell(parts, Vector((0.36 * sx, 0.12, 0.6)), (0.15, 0.13, 0.12), {"LowerLeg." + side: 0.5,
                                                                         "UpperLeg." + side: 0.5}, plate)
        shell(parts, Vector((0.35 * sx, 0.06, 0.09)), (0.2, 0.32, 0.12), {"Foot." + side: 1.0},
              metal(steel, steel_lt, gold, 0.5))
    # Breastplate and the eclipse sigil on it.
    shell(parts, Vector((0.0, 0.08, 1.72)), (0.66, 0.5, 0.52), {"Torso": 0.85, "Abdomen": 0.15}, plate, seg=16,
          rings=10)
    with parts.on(IVORY_GLOW):
        sc = Vector((0.0, -0.43, 1.75))
        for i in range(16):
            a = 2.0 * math.pi * i / 16
            p = sc + Vector((math.cos(a) * 0.17, 0.0, math.sin(a) * 0.17))
            q = sc + Vector((math.cos(a + 0.42) * 0.17, 0.0, math.sin(a + 0.42) * 0.17))
            parts.blob(p, 0.03, q - p, (q - p).length * 1.1, None, weights={"Torso": 1.0}, seg=5, rings=2, tip=1.0,
                       color_fn=lambda t: gold_lt)
    # The skirt of plates.
    for i in range(10):
        a = math.pi * (-0.15 + 1.3 * i / 9.0)
        o = Vector((math.cos(a), -math.sin(a) * 0.85, 0.0))
        c = Vector((0.0, 0.2, 1.0)) + o * 0.5
        w = {"Body": 0.6, ("UpperLeg.L" if o.x > 0 else "UpperLeg.R"): 0.4}
        with parts.on(IVORY):
            parts.blob(c, (0.2, 0.05), (o * 0.35 + Vector((0, 0, -1.0))).normalized(), 0.55, None, weights=w,
                       seg=8, rings=4, tip=0.7, up=o, color_fn=lambda t: L.mix(steel_lt, gold, L.smooth(0.8, 0.95, t)))
    # The cape: from the shoulders down the back, gold hem.
    cape_w = {"Torso": 0.75, "Body": 0.25}
    with parts.on(SKIN):
        for k, sx in enumerate((-0.38, 0.0, 0.38)):
            parts.blob(Vector((sx, 0.5, 2.05)), (0.42, 0.07), Vector((sx * 0.5, 0.45, -1.0)).normalized(), 1.95,
                       None, weights=cape_w, seg=10, rings=7, tip=1.25, up=Vector((0, 1.0, 0.0)),
                       color_fn=lambda t: L.mix(C("3a1a5e"), C("1a0e2a"), t * 0.6) if t < 0.92 else gold)
    # The great sword in his hand: black blade, glowing gold fuller, gold guard, a gem pommel.
    hand = {"Middle1.L": 1.0}
    grip = Vector((1.9, 0.17, 1.86))
    fwd = Vector((0.0, -1.0, 0.0))
    with parts.on(IVORY):
        parts.blob(grip + Vector((0, 0.32, 0)), 0.05, fwd, 0.5, None, weights=hand, seg=6, rings=3, tip=1.0,
                   color_fn=lambda t: C("2a1a10"))
        parts.blob(grip + Vector((-0.34, -0.2, 0)), (0.06, 0.06), Vector((1.0, 0, 0)), 0.68, None, weights=hand,
                   seg=6, rings=3, tip=0.6, color_fn=lambda t: L.mix(gold_dk, gold_lt, abs(t - 0.5) * 2))
        parts.blob(grip + Vector((0, -0.18, 0)), (0.24, 0.05), fwd, 2.5, None, weights=hand, seg=8, rings=6,
                   tip=0.15, up=Vector((1.0, 0, 0)), color_fn=lambda t: L.mix(C("2a2438"), C("5a4e78"), t))
    with parts.on(IVORY_GLOW):
        parts.blob(grip + Vector((0, -0.25, 0)), (0.05, 0.06), fwd, 2.1, None, weights=hand, seg=6, rings=4,
                   tip=0.2, up=Vector((1.0, 0, 0)), color_fn=lambda t: L.mix(C("ffd070"), C("c890ff"), t))
        parts.ellipsoid(grip + Vector((0, 0.36, 0)), (0.07, 0.07, 0.07), color=C("b880ff"), weights=hand, seg=8,
                        rings=5)
    # The eclipse behind him: a black sun in a ring of gold fire, with long rays.
    ring_w = {"Torso": 1.0}
    ec = Vector((0.0, 0.85, 2.6))
    with parts.on(IVORY):
        parts.ellipsoid(ec, (0.78, 0.05, 0.78), color=None, weights=ring_w, seg=24, rings=6,
                        color_fn=lambda u: L.mix(C("140c24"), C("6a46a8"), L.smooth(0.55, 1.0, math.hypot(u.x, u.z))))
    with parts.on(IVORY_GLOW):
        for i in range(28):
            a = 2.0 * math.pi * i / 28
            p = ec + Vector((math.cos(a), -0.04, math.sin(a))) * 0.84
            q = ec + Vector((math.cos(a + 0.24), -0.04, math.sin(a + 0.24))) * 0.84
            parts.blob(p, 0.08, q - p, (q - p).length * 1.1, None, weights=ring_w, seg=6, rings=2, tip=1.0,
                       color_fn=lambda t: L.mix(C("ffb020"), C("fff0b0"), 0.5))
        for i in range(16):
            a = 2.0 * math.pi * (i + 0.5) / 16
            o = Vector((math.cos(a), 0.0, math.sin(a)))
            parts.blob(ec + o * 0.86 + Vector((0, 0.02, 0)), (0.09, 0.03), o, 0.6 if i % 2 == 0 else 0.32, None,
                       weights=ring_w, seg=4, rings=2, tip=0.05, up=Vector((0, 1.0, 0)),
                       color_fn=lambda t: L.mix(C("ffc040"), C("fff4c8"), t))
    K.join_parts(body, parts.to_object())
    K.bake_ao(body, shade=Vector((0.55, 0.5, 0.66)))


def blood_king(arm, body):
    """ราชันอสูรโลหิต, the party raid's boss: a blood demon king. Deep crimson hide going
    black at the hands and feet, glowing blood veins over chest and arms, great black ram
    horns curling from a smaller head, an iron crown of spikes set with a blood gem, burning
    eyes, tusks; skull pauldrons, a skull-buckled belt over a tattered blood-red loincloth,
    huge torn bat wings, a mane of black-red flame down the back, and a jagged bone-and-iron
    cleaver with a glowing edge (the rig's weapon swing is his attack)."""
    keep_clips(("Idle", "Walk", "Run", "Weapon", "HitReact", "Death"))
    bpy.data.actions["Weapon"].name = "Punch"
    keys = demon_base(arm, body, (0.8, 0.8, 0.8), keep_wings=True)
    wing_pivot = Vector((0.0, 0.5, 1.95))

    def wings(co, w):
        ww = w.get("Neck", 0.0)
        if ww > 0.5 and abs(co.x) > 0.25:
            co = scale_about(co, wing_pivot, (1.75, 1.3, 1.65))
        return co

    sculpt(body, wings)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 5200)
    L.relax(body, 2, 0.35)
    hide, hide_dk, burnt, chest = C("c42234"), C("6a0e1c"), C("1c0c12"), C("e85a5a")

    def paint(region, co, n, info):
        bone = info["bone"]
        if region[2:] == DEMON_DARK:
            # the wing frame: black bone
            return L.mix(C("1a1014"), C("4a3034"), L.smooth(1.8, 2.8, co.z)), IVORY
        if bone == "Neck" and abs(co.x) > 0.25:
            # membrane: dark red, torn-looking blotches, darker at the edge
            d = (co - wing_pivot).length
            c = L.mix(C("8a1a26"), C("2a0810"), L.smooth(0.5, 2.0, d))
            return L.mix(c, C("12060a"), L.smooth(0.62, 0.7, K.noise(co, 3.0, 8)) * 0.8)
        c = L.mix(hide_dk, hide, L.smooth(-0.5, 0.4, -n.y + n.z * 0.5))
        c = L.mix(c, chest, L.smooth(-0.4, -0.9, n.y) * L.smooth(1.2, 1.6, co.z) * L.smooth(2.3, 2.0, co.z) * 0.5)
        ext = max(L.smooth(1.3, 1.75, abs(co.x)), L.smooth(0.5, 0.15, co.z))
        return L.mix(c, burnt, ext * 0.9)

    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    rng = random.Random(21)
    head = {"Head": 1.0}
    lo, hi = L.bounds(body, [v.index for v, g in zip(body.data.vertices, L.dominant_groups(body)) if g == "Head"])
    hc, hr = (lo + hi) * 0.5, (hi - lo) * 0.5
    bone_c, bone_tip = C("2a1a1a"), C("f2e2c4")
    for sx in (-1.0, 1.0):
        c = Vector((hr.x * 0.42 * sx, hc.y - hr.y * 0.78, hc.z + hr.z * 0.1))
        p, n = surf.toward(c + Vector((0.3 * sx, -2.0, 0.0)), c + Vector((0, 0.3, 0)))
        if p is not None:
            c = p - n * 0.06
        gaze = Vector((0.3 * sx, -1.0, 0.0)).normalized()
        K.fierce_eye(parts, c, 0.1, gaze, sx, C("fff2a0"), C("ff2a10"), head, lid=hide_dk, open_=0.45,
                     glow_mat=IVORY_GLOW, slant=0.45)
        K.ridge(parts, c + Vector((0.13 * sx, 0.05, 0.1)), c + Vector((-0.1 * sx, -0.1, 0.07)), 0.06, burnt, head,
                bulge=Vector((0, -0.03, 0.05)), tip=0.7)
        # Ram horns: out, back and curling forward.
        hb = hc + Vector((hr.x * 0.75 * sx, 0.0, hr.z * 0.55))
        K.horn(parts, hb, Vector((0.9 * sx, 0.3, 0.55)), 1.05, 0.13, head, C("140a0c"), C("e8d6b8"),
               bend=Vector((0.1 * sx, -0.55, -0.45)), rings_col=C("3a2a2a"), seg=10, rings=9, bands=6)
        # tusks
        K.fang(parts, Vector((0.17 * sx, hc.y - hr.y * 0.9, hc.z - hr.z * 0.55)), Vector((0.15 * sx, -0.3, 1.0)),
               0.24, 0.05, head)
    # The iron crown of spikes with a blood gem.
    with parts.on(IVORY):
        cc = hc + Vector((0, 0.02, hr.z * 0.75))
        crown(parts, cc, Vector((0, 0.15, 1.0)), hr.x * 0.7, hr.z * 0.7, 9, C("6a5a60"), C("1e1418"), C("ff2030"),
              head)
    with parts.on(IVORY_GLOW):
        parts.ellipsoid(cc + Vector((0, -hr.x * 0.72, hr.z * 0.25)), (0.07, 0.04, 0.09), color=C("ff3040"),
                        weights=head, seg=8, rings=5)
    # Skull pauldrons.
    for sx in (-1.0, 1.0):
        side = "L" if sx > 0 else "R"
        w = {"UpperArm." + side: 0.6, "Shoulder." + side: 0.4}
        sk = Vector((0.68 * sx, 0.12, 2.05))
        with parts.on(IVORY):
            parts.ellipsoid(sk, (0.3, 0.3, 0.26), color=None, weights=w, seg=12, rings=8,
                            color_fn=lambda u: L.mix(C("b8a888"), C("f4ead2"), L.smooth(-0.5, 0.8, u.z)))
            parts.ellipsoid(sk + Vector((0, -0.18, -0.12)), (0.2, 0.16, 0.12), color=None, weights=w, seg=10,
                            rings=6, color_fn=lambda u: L.mix(C("b8a888"), C("e8dcc0"), L.smooth(-0.5, 0.8, u.z)))
            for ex in (-1.0, 1.0):
                parts.ellipsoid(sk + Vector((0.1 * ex, -0.27, 0.02)), (0.07, 0.03, 0.06), color=C("1a0a0c"),
                                weights=w, seg=8, rings=4)
            K.horn(parts, sk + Vector((0.15 * sx, 0.0, 0.2)), Vector((0.5 * sx, 0.1, 1.0)), 0.4, 0.07, w, bone_c,
                   bone_tip, seg=7, rings=4)
        with parts.on(IVORY_GLOW):
            for ex in (-1.0, 1.0):
                parts.ellipsoid(sk + Vector((0.1 * ex, -0.29, 0.02)), (0.03, 0.02, 0.03), color=C("ff4030"),
                                weights=w, seg=6, rings=3)
    # Belt with a skull buckle, tattered loincloth.
    with parts.on(IVORY):
        parts.frustum(Vector((0.0, 0.2, 1.02)), Vector((0, 0, 1.0)), 0.6, 0.62, 0.16,
                      lambda t, side: C("2a1a14") if side else C("1a100c"), {"Body": 0.7, "Hips": 0.3}, seg=20)
        parts.ellipsoid(Vector((0.0, -0.38, 1.1)), (0.14, 0.08, 0.15), color=None, weights={"Body": 1.0}, seg=10,
                        rings=6, color_fn=lambda u: L.mix(C("b8a888"), C("f4ead2"), L.smooth(-0.5, 0.8, u.z)))
    with parts.on(SKIN):
        for k, x in enumerate((-0.2, 0.0, 0.2)):
            parts.blob(Vector((x, -0.36, 1.0)), (0.13, 0.03), Vector((x * 0.3, -0.15, -1.0)), 0.6 + 0.08 * (k % 2),
                       None, weights={"Body": 1.0}, seg=8, rings=4, tip=0.6, up=Vector((0, -1, 0)),
                       color_fn=lambda t: L.mix(C("7a0c18"), C("3a0610"), t))
    # Glowing blood veins over the chest and arms.
    ember = C("ff4a3a")
    for (x, z, ha, ln) in ((0.25, 1.6, -1.9, 0.5), (-0.28, 1.5, -1.2, 0.5), (0.05, 1.3, -1.6, 0.45),
                           (0.38, 1.35, -2.2, 0.35), (-0.15, 1.8, -0.6, 0.35)):
        p, n = K.front_hit(surf, x, z)
        if p is not None:
            K.glow_path(parts, p, n, K.crack_path(rng, ln, 6, 0.3, heading=ha), 0.05, ember, mat=IVORY_GLOW)
    for sx in (-1.0, 1.0):
        for k in range(2):
            p, n = K.dir_hit(surf, Vector((0.85 * sx + 0.3 * k * sx, 0.18, 1.82)), Vector((0, -0.3, 1.0)))
            if p is not None:
                K.glow_path(parts, p, n, K.crack_path(rng, 0.35, 5, 0.25, heading=0.0 if sx > 0 else math.pi),
                            0.035, ember, up=Vector((0, -1, 0)), mat=IVORY_GLOW)
    # A mane of black-red flame down the back.
    dirs = [d for d in K.fibonacci(60) if d.y > 0.25 and d.z > -0.2]
    with parts.on(IVORY_GLOW):
        for d in dirs[:16]:
            p, n = K.dir_hit(surf, Vector((0.0, 0.2, 1.85)), d)
            if p is None or abs(p.x) > 0.5:
                continue
            parts.blob(p - n * 0.04, (0.08, 0.05), (n + Vector((0, 0.3, 0.9))).normalized(), rng.uniform(0.35, 0.6),
                       None, weights=p, seg=6, rings=3, tip=0.05,
                       color_fn=lambda t: L.mix(C("5a0810"), C("ff6040"), t))
    # The cleaver: an iron-and-bone blade with a glowing edge.
    hand = {"Middle1.L": 1.0}
    grip = Vector((1.9, 0.17, 1.86))
    fwd = Vector((0.0, -1.0, 0.0))
    with parts.on(IVORY):
        parts.blob(grip + Vector((0, 0.35, 0)), 0.055, fwd, 0.6, None, weights=hand, seg=6, rings=3, tip=1.0,
                   color_fn=lambda t: L.mix(C("e8dcc0"), C("8a7a60"), t))
        parts.blob(grip + Vector((0, -0.2, 0.0)), (0.32, 0.06), fwd, 1.9, None, weights=hand, seg=8, rings=6,
                   tip=0.75, up=Vector((1.0, 0, 0)), bend=Vector((0, 0, -0.15)),
                   color_fn=lambda t: L.mix(C("2a2228"), C("5a4a50"), t))
        for k in range(4):
            parts.blob(grip + Vector((0, -0.55 - 0.38 * k, -0.27)), (0.06, 0.03), Vector((0, -0.4, -1.0)), 0.22,
                       None, weights=hand, seg=5, rings=2, tip=0.05, up=Vector((1, 0, 0)),
                       color_fn=lambda t: L.mix(bone_c, bone_tip, t))
    with parts.on(IVORY_GLOW):
        parts.blob(grip + Vector((0, -0.25, 0.28)), (0.03, 0.065), fwd, 1.75, None, weights=hand, seg=6, rings=4,
                   tip=0.6, up=Vector((1.0, 0, 0)), bend=Vector((0, 0, -0.12)),
                   color_fn=lambda t: L.mix(C("ff3020"), C("ffb080"), t))
    K.join_parts(body, parts.to_object())
    K.bake_ao(body, shade=Vector((0.6, 0.45, 0.5)))


# ---------------------------------------------------------------- tomb_boss (flying/Dragon_Evolved)

def bone_dragon(arm, body):
    """ราชันมังกรโบราณ, the dragon tomb's boss: an ancient dragon king of bone and fossil. The
    head is sculpted into a long horned skull with hollow sockets where green soul-fire burns;
    the hide is aged ivory bone cracked with dark seams; ribs stand out along the flanks with
    the soul-fire glowing between them; a row of vertebra spines runs from skull to tail;
    the wings are torn, ghost-green membranes on bone fingers; a crown of patinated bronze
    with a jade gem sits between the great swept horns."""
    keep_clips(("Flying_Idle", "Fast_Flying", "Headbutt", "Punch", "HitReact", "Death"))
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    neck = Vector((0.0, 0.1, 1.95))
    wing_root = Vector((0.0, 0.3, 2.0))

    def shape(co, w):
        hw = w.get("Head", 0.0)
        if hw > 0.0:
            s = scale_about(co, neck, (0.74, 0.86, 0.72))
            fwd = L.smooth(-0.1, -0.85, co.y)
            s.y -= 0.35 * fwd
            s.z -= 0.06 * fwd
            co = co.lerp(s, min(1.0, hw))
        ww = sum(w.get("Wing%d.%s" % (i, s_), 0.0) for i in (2, 3, 4) for s_ in "LR")
        if ww > 0.0:
            co = co.lerp(scale_about(co, wing_root, (1.3, 1.25, 1.25)), min(1.0, ww))
        tw = w.get("Torso", 0.0) + w.get("Body1", 0.0)
        if tw > 0.0:
            co.x *= 1.0 - 0.1 * tw
        return co

    sculpt(body, shape)
    L.clean(body)
    L.decimate_to(body, 6000)
    L.relax(body, 2, 0.35, ("Dragon_Main",))
    bone, bone_dk, crack = C("efe4c8"), C("c2aa7c"), C("4a3c2c")
    soul, soul_hot = C("3cf080"), C("d8ffe0")

    def paint(name, co, n, info):
        b = info["bone"]
        on_wing = b.startswith(("Wing2", "Wing3", "Wing4"))
        if name == "Dragon_Horn":
            t = L.smooth(-0.02, 0.12, info["bump"])
            return L.mix(C("1e1a18"), C("8a8070"), t), IVORY
        if name == "Dragon_Secondary" and on_wing:
            c = L.mix(C("8ac0a0"), C("2e5a46"), L.smooth(0.5, 1.6, co.y))
            hole = L.smooth(0.64, 0.7, K.noise(co, 2.6, 3))
            return L.mix(c, C("0c1410"), hole * 0.9), SKIN
        if name == "Dragon_Secondary" and b in ("Torso", "Body1", "Body2", "Body3", "Neck"):
            # The belly: between the ribs the soul-fire shows.
            gap = abs(math.sin(co.z * math.pi / 0.13))
            if gap < 0.35:
                return L.mix(soul_hot, soul, gap / 0.35), IVORY_GLOW
            return L.mix(bone_dk, bone, 0.6), IVORY
        c = L.mix(bone_dk, bone, L.smooth(-0.4, 0.7, n.z))
        cr = abs(K.fbm(co, 5.0, 6) - 0.5)
        c = L.mix(c, crack, L.smooth(0.035, 0.0, cr) * 0.4)
        c = L.mix(c, C("b8a47c"), L.smooth(0.03, -0.04, info["bump"]) * 0.25)
        return c, IVORY

    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    head = {"Head": 1.0}
    groups = L.dominant_groups(body)
    lo, hi = L.bounds(body, [v.index for v, g in zip(body.data.vertices, groups) if g == "Head"])
    hc, hr = (lo + hi) * 0.5, (hi - lo) * 0.5
    # Hollow sockets with soul-fire eyes.
    for sx in (-1.0, 1.0):
        c = Vector((hr.x * 0.5 * sx, hc.y - hr.y * 0.35, hc.z + hr.z * 0.15))
        p, n = surf.toward(c + Vector((0.8 * sx, -2.0, 0.3)), c)
        if p is None:
            continue
        with parts.on(IVORY):
            parts.ellipsoid(p - n * 0.02, (0.17, 0.17, 0.12), K.basis(n), color=C("0e0c0a"), weights=head, seg=10,
                            rings=6)
        with parts.on(IVORY_GLOW):
            parts.ellipsoid(p + n * 0.035, (0.09, 0.09, 0.07), K.basis(n), color=None, weights=head, seg=8, rings=5,
                            color_fn=lambda u: L.mix(soul, soul_hot, L.smooth(-0.2, 0.9, u.z)))
            parts.blob(p + n * 0.05, (0.04, 0.02), (n + Vector((0, 0.6, 1.0))).normalized(), 0.22, None,
                       weights=head, seg=5, rings=3, tip=0.05, color_fn=lambda t: L.mix(soul_hot, soul, t))
        K.ridge(parts, p + Vector((0.14 * sx, 0.06, 0.12)), p + Vector((-0.12 * sx, -0.14, 0.1)), 0.07, bone_dk,
                head, bulge=Vector((0, -0.03, 0.05)), tip=0.7, mat=IVORY)
    # Rows of fangs along the jaw.
    for sx in (-1.0, 1.0):
        for k in range(4):
            y = hc.y - hr.y * (0.95 - 0.16 * k)
            p, n = surf.toward(Vector((sx * 2.0, y, hc.z - hr.z * 0.45)), Vector((0.0, y, hc.z - hr.z * 0.45)))
            if p is not None:
                K.fang(parts, p - n * 0.02, Vector((0.1 * sx, -0.1, -1.0)), 0.16 - 0.02 * k, 0.035, head)
    # Ribs along the flanks.
    for k in range(5):
        z = 1.85 - k * 0.19
        ctr = Vector((0.0, 0.3, z))
        for sx in (-1.0, 1.0):
            arc = []
            for j in range(6):
                a = math.radians(25.0 + 26.0 * j)
                d = Vector((math.sin(a) * sx, math.cos(a), -0.12 * j / 5.0))
                p, n = surf.toward(ctr + d * 2.5, ctr)
                if p is not None:
                    arc.append((p + n * 0.035, p))
            for (a0, w0), (a1, _w1) in zip(arc, arc[1:]):
                if (a1 - a0).length > 0.4:
                    continue
                K.ridge(parts, a0, a1, 0.045, bone, w0, tip=0.9, mat=IVORY, seg=6, rings=3)
    # Vertebra spines from the skull down the neck, back and tail.
    spine = [(Vector((0.0, 0.35, 2.55)), Vector((0, 0.5, 1.0))), (Vector((0.0, 0.5, 2.2)), Vector((0, 0.7, 1.0))),
             (Vector((0.0, 0.62, 1.85)), Vector((0, 1.0, 0.6))), (Vector((0.0, 0.66, 1.5)), Vector((0, 1.0, 0.3))),
             (Vector((0.0, 0.6, 1.15)), Vector((0, 1.0, 0.0))), (Vector((0.0, 0.52, 0.85)), Vector((0, 1.0, -0.3))),
             (Vector((0.05, 0.47, 0.6)), Vector((0, 1.0, -0.5)))]
    for k, (c, d) in enumerate(spine):
        p, n = surf.toward(c + d.normalized() * 2.0, c - d.normalized() * 0.3)
        if p is not None:
            K.horn(parts, p - n * 0.03, (n + Vector((0, 0.3, 0.4))).normalized(), 0.42 - 0.035 * k, 0.07 - 0.005 * k,
                   p, bone_dk, bone, seg=6, rings=4)
    # The bronze crown with its jade gem, and two great swept horns.
    bronze, bronze_dk = C("6aa088"), C("2a4a3a")
    with parts.on(IVORY):
        cc = Vector((0.0, hc.y + hr.y * 0.15, hc.z + hr.z * 0.72))
        p, n = surf.toward(cc + Vector((0, 0, 3.0)), cc - Vector((0, 0, 0.5)))
        if p is not None:
            cc = p - Vector((0, 0, 0.05))
        crown(parts, cc, Vector((0, 0.25, 1.0)), hr.x * 0.42, hr.z * 0.55, 7, bronze, bronze_dk, soul, head)
        for sx in (-1.0, 1.0):
            K.horn(parts, cc + Vector((hr.x * 0.5 * sx, 0.1, -0.05)), Vector((0.5 * sx, 1.0, 0.45)), 1.1, 0.12,
                   head, C("1e1a18"), C("cfc4aa"), bend=Vector((0.15 * sx, 0.1, 0.35)), rings_col=C("3a3028"))
    with parts.on(IVORY_GLOW):
        parts.ellipsoid(cc + Vector((0, -hr.x * 0.44, hr.z * 0.18)), (0.06, 0.035, 0.07), color=soul, weights=head,
                        seg=8, rings=5)
    K.join_parts(body, parts.to_object())
    K.bake_ao(body, shade=Vector((0.55, 0.6, 0.55)))


RECIPES = {
    "forest_king": ("big/Dino.gltf", "ForestDragonKing", forest_king),
    "crystal_king": ("star/Bull.glb", "CrystalHornKing", crystal_king),
    "sky_king": ("star/Horse_White.glb", "SunWingKing", sky_king),
    "eclipse_knight": ("big/Demon.gltf", "EclipseKnightKing", eclipse_knight),
    "blood_king": ("big/Demon.gltf", "BloodDemonKing", blood_king),
    "bone_dragon": ("flying/Dragon_Evolved.gltf", "BoneDragonKing", bone_dragon),
}
RECIPES_BY_NAME = {k: v[2] for k, v in RECIPES.items()}

L.export = K.export


def build(key):
    src, name, fn = RECIPES[key]
    L.reset()
    arm, body = L.load(os.path.join(SRC, src))
    before = L.tri_count(body)
    fn(arm, body)
    clips = sorted(a.name for a in bpy.data.actions)
    out = os.path.join(OUT, name + ".glb")
    os.makedirs(OUT, exist_ok=True)
    K.export(arm, body, out, clips)
    print("BOSS %s (%s) tris %d -> %d, %d bytes, clips %s, mats %s" % (
        key, name, before, L.tri_count(body), os.path.getsize(out), ",".join(clips),
        ",".join(m.name for m in body.data.materials)))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    for k in (args or list(RECIPES)):
        build(k)
