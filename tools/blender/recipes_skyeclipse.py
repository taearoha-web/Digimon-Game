"""Team skyeclipse's recipes: the sky citadel (star 100) and eclipse realm (star 150) monsters.

    /opt/bpy5/bin/python tools/blender/recipes_skyeclipse.py [star/Skeleton_Warrior_sky_warden ...]

Every output is a per-monster VARIANT (the shared rigs star/Skeleton_Warrior, Skeleton_Mage
and Horse_White also carry the region bosses, which keep their own models):
remaster/<dir>/<Rig>_<monster_id>.glb, and that monster's "model" in data/star_monsters.gd
points at "remaster/<dir>/<Rig>_<monster_id>". The halos, wings, mantles and crowns that
StarMonsterArt used to hang on these monsters at run time are sculpted into the models
(their "decor" is "baked": StarMonsterArt then only mounts the WeaponKit weapon).
Materials: kit_critters' set (Keep* untinted, KeepGlow unlit).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import remaster_lib as L  # noqa: E402
import kit_critters as K  # noqa: E402
import kit_skyeclipse as S  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "models", "monsters")
OUT = os.path.join(SRC, "remaster")

C = L.srgb
D = S.D
V = Vector
WHITE = C("ffffff")
HEAD = {"head": 1.0}
CHEST = {"chest": 1.0}


def start(body):
    surf = L.Surface(body)
    return surf, K.KParts(surf)


def finish(body, parts, **ao):
    K.join_parts(body, parts.to_object())
    K.bake_ao(body, **ao)


def shade(base, val, ref, lo=0.55, hi=1.25):
    """The atlas' painted light and shade carried onto a new base colour."""
    return base * max(lo, min(hi, val / ref))


def eyes_mode(name, center, normal, bone):
    return "glow" if name == "Eyes" else "skin"


# ================================================================ knights (Skeleton_Warrior)

def knight_paint(body, pal, part_override=None):
    """Repaints the warrior's body by atlas class: pal = {class: (colour, ref value)}."""

    def paint(name, co, n, info):
        if part_override:
            c = part_override(name, co, n, info)
            if c is not None:
                return c
        kind, val = S.tex_class(info["tex"])
        if name == "Cloak":
            kind = "cloak"
        base, ref = pal[kind]
        return shade(base, val, ref)

    K.paint_body(body, paint, face_mode=eyes_mode, tex=True)


def helm(parts, pal_top, pal_low, center=V((0, -0.01, 1.74)), radii=(0.47, 0.5, 0.47), seg=22, rings=14):
    """A rounded closed helm over the chibi skull (head bone)."""
    parts.ellipsoid(center, radii, color=None, weights=HEAD, seg=seg, rings=rings,
                    color_fn=lambda u: L.mix(pal_low, pal_top, L.smooth(-0.7, 0.8, u.z)))


def visor(parts, surf, z, color, half=0.24, width=0.07, nose=False):
    """A glowing eye slit (and nose bar) across the helm's front."""
    p, n = surf.toward(V((0, -6, z)), V((0, 0, z)))
    with parts.use("glow"):
        parts.stroke(p, n, [(-half, 0.0), (-half * 0.4, -0.012), (0.0, -0.02), (half * 0.4, -0.012), (half, 0.0)],
                     width, color, weights=HEAD, lift=0.02, taper=False)
    if nose:
        p2, n2 = surf.toward(V((0, -6, z - 0.1)), V((0, 0, z - 0.1)))
        parts.stroke(p2, n2, [(0, 0.06), (0, -0.16)], 0.06, C("2a2030"), weights=HEAD,
                     lift=0.022, taper=False)


def pauldron(parts, side, colour_fn, scale=1.0, weights=None, spikes=0, spike_col=None):
    c = V((0.3 * side, 0.0, 1.19))
    w = weights or {"upperarm.l" if side > 0 else "upperarm.r": 1.0}
    parts.ellipsoid(c, (0.2 * scale, 0.2 * scale, 0.15 * scale), color=None, weights=w, seg=14, rings=8,
                    color_fn=colour_fn, squash_bottom=0.5)
    for i in range(spikes):
        a = (i - (spikes - 1) / 2) * 0.45
        d = V((side * 0.55, math.sin(a) * 0.6, 1.0)).normalized()
        base = c + V((side * 0.04, math.sin(a) * 0.1, 0.08 * scale))
        K.horn(parts, base, d, 0.24 * scale, 0.055 * scale, w, spike_col[0], spike_col[1], mode="keep", seg=8)


HELM_C = V((0, -0.01, 1.74))
HELM_R = (0.47, 0.5, 0.47)


def knight_helm(parts, top, low, face, face_lo=None, faceplate=0.35, radii=HELM_R, center=HELM_C, peak=0.0):
    """A closed helm: crown colour top->low, a faceplate (front, below the brow) in `face`."""
    face_lo = face_lo if face_lo is not None else face

    def col(u):
        c = L.mix(low, top, L.smooth(-0.7, 0.8, u.z))
        f = L.smooth(-faceplate + 0.05, -faceplate - 0.05, u.y) * L.smooth(0.32, 0.22, u.z)
        return L.mix(c, L.mix(face_lo, face, L.smooth(-0.8, 0.2, u.z)), f)

    verts = parts.ellipsoid(center, radii, color=None, weights=HEAD, seg=24, rings=14, color_fn=col)
    if peak:
        for v in verts:
            t = (v.co.z - center.z) / radii[2]
            if t > 0:
                v.co.z += peak * t ** 4
                v.co.y += peak * 0.25 * t ** 4


def crest(parts, c0, c1, height=0.2, n=9, start=-55, end=95, width=0.07, center=HELM_C, r=0.46):
    """A ridge crest over the helm from brow to nape (overlapping flattened ellipsoids)."""
    for i in range(n):
        t = i / (n - 1)
        a = math.radians(start + (end - start) * t)
        d = V((0, math.sin(a), math.cos(a)))
        h = height * (0.6 + 0.4 * math.sin(math.pi * min(1.0, t * 1.3)))
        parts.ellipsoid(center + d * (r + h * 0.35), (width, 0.1, h), basis=_basis_z(d), color=None,
                        weights=HEAD, seg=8, rings=5,
                        color_fn=lambda u: L.mix(c0, c1, L.smooth(-0.5, 0.9, u.z)))


def _basis_z(z, x=V((1, 0, 0))):
    z = z.normalized()
    y = z.cross(x).normalized()
    x = y.cross(z).normalized()
    return Matrix((x, y, z)).transposed()


def helm_wings(parts, c_root, c_tip, size=1.0, center=HELM_C, n=4):
    """Small swept feathered wings on the helm's sides (a winged temple helm)."""
    for sx in (-1, 1):
        root = center + V((0.44 * sx, 0.06, 0.04))
        for i in range(n):
            t = i / max(1, n - 1)
            d = V((sx * (0.55 - 0.25 * t), 0.35 + 0.5 * t, 0.85 - 0.5 * t)).normalized()
            S.feather(parts, root + V((0, 0.05 * i, -0.03 * i)), d, (0.42 - 0.07 * i) * size, 0.07 * size, HEAD,
                      c_root, c_tip, up=V((sx, 0, 0)), tip=0.3, thick=0.3, bend=V((0, 0.08, -0.04)) * size)


def sky_warden(arm, body):
    """ผู้พิทักษ์วิหารฟ้า: a pearl-white and gold temple guard: a closed round helm with a
    gold faceplate, a glowing sky-blue eye slit, small white wings and a gold crest, and a
    floating golden halo above it."""
    L.delete_faces(body, ("Helmet", "Jaw", "Head", "Eyes"))
    L.clean(body, quads=False, merge=1e-5)
    pearl, gold, sky = D("fbf8f2"), D("ffd768"), D("6cbcff")
    pal = {"metal": (pearl, 0.55), "leather": (gold, 0.5), "cloth": (sky, 0.6), "bone": (D("e7eefb"), 0.9),
           "dark": (D("4a5c80"), 0.2), "cloak": (sky, 0.62)}
    knight_paint(body, pal)
    surf, parts = start(body)
    knight_helm(parts, D("ffffff"), D("dde3f0"), D("fff1c8"), D("f0c860"))
    crest(parts, D("e8a83a"), D("fff0b0"))
    helm_wings(parts, D("f4f6ff"), D("ffffff"))
    K.join_parts(body, parts.to_object())
    surf, parts = start(body)
    visor(parts, surf, 1.68, C("7fe0ff"), half=0.3, width=0.1)
    with parts.use("glow"):
        S.ring(parts, V((0, 0.08, 2.48)), V((0, 0.25, 1)), 0.33, 0.035, None, HEAD, flat=0.6,
               color_fn=lambda t, s: L.mix(C("ffc83a"), C("fff2c0"), 0.5 + 0.5 * s))
    finish(body, parts)


def eye_slits(parts, surf, z, color, gap=0.16, half=0.13, width=0.075, slant=0.06):
    """Two narrow, angry slanted eye slits (inner ends low)."""
    for sx in (-1, 1):
        p, n = surf.toward(V((gap * sx, -6, z)), V((gap * sx, 0, z)))
        with parts.use("glow"):
            parts.stroke(p, n, [(-half * sx * 0.2, -slant), (half * sx, slant * 0.6)], width, color, weights=HEAD,
                         lift=0.02, taper=False)


def chest_front(surf, z=1.0):
    return surf.toward(V((0, -6, z)), V((0, 0, z)))


def back_cape(parts, color_fn, z_top=1.22, z_bot=0.3, r_top=0.36, r_bot=0.55, arc=2.6, rows=8, cols=14,
              ragged=0.0, cy=0.04):
    """A cape hanging from the shoulders down the back (chest bone, rigid)."""
    import random
    rng = random.Random(3)
    verts = K.cape(parts, V((0, cy, 0)), z_top, z_bot, r_top, r_bot, arc, color_fn, CHEST, rows=rows, cols=cols,
                   flare=0.15, thick=0.03)
    if ragged:
        # Tatter the hem: drop alternate bottom columns up by a random amount.
        per = (rows + 1) * (cols + 1)
        for side in (0, 1):
            for c in range(cols + 1):
                cut = ragged * (0.3 + 0.7 * rng.random()) if c % 2 else 0.0
                for r in range(rows + 1):
                    v = verts[side * per + r * (cols + 1) + c]
                    t = r / rows
                    v.co.z += cut * t ** 3
    return verts


def sun_disc(parts, center, radius, n_rays, c_disc, c_ray, c_tip, weights, back=V((0, 1, 0))):
    """A sun halo behind the head: a thin disc and a ring of long tapering rays."""
    t_, b_, n_ = L.frame(back)
    parts.ellipsoid(center, (radius, radius, radius * 0.12), basis=Matrix((t_, b_, n_)).transposed(), color=None,
                    weights=weights, seg=18, rings=6, color_fn=lambda u: L.mix(c_ray, c_disc, 1.0 - abs(u.z) * 0.0))
    for i in range(n_rays):
        a = 2.0 * math.pi * i / n_rays + math.pi / n_rays
        d = t_ * math.cos(a) + b_ * math.sin(a)
        ln = radius * (0.95 if i % 2 else 0.6)
        parts.blob(center + d * radius * 0.7, (radius * 0.16, radius * 0.05), d, ln, None, weights=weights, seg=6,
                   rings=4, tip=0.1, up=n_, color_fn=lambda a_: L.mix(c_ray, c_tip, a_))


def sky_high_warden(arm, body):
    """แม่ทัพปีกสุริยัน: the winged sun general: gold plate over white, a gold helm with a
    white plume and a blazing sun disc behind it, great white-gold wings, a crimson cape."""
    L.delete_faces(body, ("Helmet", "Jaw", "Head", "Eyes"))
    L.clean(body, quads=False, merge=1e-5)
    gold, white, crimson = D("ffd25a"), D("fff7ea"), D("d8412f")
    pal = {"metal": (gold, 0.55), "leather": (white, 0.5), "cloth": (crimson, 0.6), "bone": (D("fff1d8"), 0.9),
           "dark": (D("6b3a1e"), 0.2), "cloak": (white, 0.62)}
    knight_paint(body, pal)
    surf, parts = start(body)
    knight_helm(parts, D("ffe27a"), D("e9a93c"), D("fffaf0"), D("e9dcc4"), faceplate=0.3)
    crest(parts, D("ffffff"), D("ffffff"), height=0.34, width=0.09, n=8)
    with parts.use("keep"):
        sun_disc(parts, HELM_C + V((0, 0.42, 0.18)), 0.5, 12, D("ffcf4a"), D("ffb23a"), D("fff3b0"), HEAD)
    for sx in (-1, 1):
        pauldron(parts, sx, lambda u: L.mix(D("e8a23a"), D("ffe68a"), L.smooth(-0.4, 0.9, u.z)), scale=1.25)
        S.wing(parts, V((0.16 * sx, 0.3, 1.25)), sx, 0.95, CHEST, D("fff8ec"), D("ffffff"), rows=(5, 4, 3),
               lift=1.0, back=0.25, accent=D("ffd86a"), accent_rows=(0,))
    back_cape(parts, lambda u, v, out: (D("ffd25a") if abs(u) > 0.82 or v > 0.9 else L.mix(D("e04a34"), D("b02a22"), v))
              if out else D("8a1c18"), arc=1.9, r_bot=0.44, z_bot=0.36)
    # the sun emblem on the breastplate
    p, n = chest_front(surf, 1.02)
    with parts.use("keepdetail"):
        parts.decal(p, n, S.star_shape(8, 0.16, 0.08), D("fff2a8"), lift=0.03)
    K.join_parts(body, parts.to_object())
    surf, parts = start(body)
    visor(parts, surf, 1.66, C("ffc040"), half=0.28, width=0.1)
    finish(body, parts)


def eclipse_warrior(arm, body):
    """อัศวินเกราะราตรี: a night knight in violet-black plate with silver edges: a closed helm
    with a silver faceplate and a violet eye slit, a silver crescent moon on the brow, a
    dark plume and a purple half cape."""
    L.delete_faces(body, ("Helmet", "Jaw", "Head", "Eyes"))
    L.clean(body, quads=False, merge=1e-5)
    steel, black, plum = D("7a62b0"), D("2d2642"), D("54307c")
    pal = {"metal": (steel, 0.55), "leather": (black, 0.5), "cloth": (plum, 0.6), "bone": (D("2a2638"), 0.9),
           "dark": (D("15121f"), 0.2), "cloak": (D("3d2b66"), 0.62)}
    knight_paint(body, pal)
    surf, parts = start(body)
    knight_helm(parts, D("5d4a8e"), D("2a2140"), D("d4d6ea"), D("8d90ad"), faceplate=0.3, peak=0.13)
    crest(parts, D("2a1f40"), D("7a52c0"), height=0.24, width=0.06, n=7, start=20, end=110)
    with parts.use("keep"):
        S.crescent(parts, HELM_C + V((0, -0.47, 0.3)), V((0, -1, 0.35)), V((0, 0.35, 1)), 0.2, 0.5, HEAD,
                   lambda t, k: L.mix(D("e9ecff"), D("a9aed0"), k * 0.6), thick=0.05)
    for sx in (-1, 1):
        pauldron(parts, sx, lambda u: L.mix(D("3b2d5e"), D("c9cce2"), L.smooth(0.2, 0.95, u.z)), scale=1.1)
    back_cape(parts, lambda u, v, out: L.mix(D("5a3590"), D("2a1846"), v) if out else D("1c1430"), r_bot=0.48,
              z_bot=0.42, arc=2.2)
    K.join_parts(body, parts.to_object())
    surf, parts = start(body)
    visor(parts, surf, 1.66, C("c070ff"), half=0.27, width=0.09)
    finish(body, parts)


def eclipse_dreadknight(arm, body):
    """ขุนพลเกราะคราส: the eclipse general: heavy black-and-silver plate, a horned helm with
    two burning violet eye slits, spiked silver pauldrons, an eclipse (black sun with a gold
    corona) on the chest and a long tattered mantle."""
    L.delete_faces(body, ("Helmet", "Jaw", "Head", "Eyes"))
    L.clean(body, quads=False, merge=1e-5)
    black, silver, wine = D("34304a"), D("d6d9ec"), D("4a1f52")
    pal = {"metal": (black, 0.55), "leather": (silver, 0.5), "cloth": (wine, 0.6), "bone": (D("1e1a2a"), 0.9),
           "dark": (D("100d18"), 0.2), "cloak": (D("2a1a3e"), 0.62)}
    knight_paint(body, pal)
    surf, parts = start(body)
    knight_helm(parts, D("4a4566"), D("1c1828"), D("2a2638"), D("15121e"), faceplate=0.3, radii=(0.5, 0.52, 0.5))
    # silver brow ridge and two swept-back horns
    parts.frustum(HELM_C + V((0, 0, -0.16)), V((0, 0, 1)), 0.515, 0.5, 0.1,
                  lambda t, side: L.mix(D("8d90ad"), silver, t), HEAD, seg=28)
    for sx in (-1, 1):
        K.horn(parts, HELM_C + V((0.34 * sx, -0.05, 0.3)), V((0.75 * sx, 0.35, 0.55)), 0.62, 0.12, HEAD,
               D("e2e4f2"), D("2a2340"), bend=V((0.05 * sx, 0.3, 0.32)), mode="keep", seg=10)
        pauldron(parts, sx, lambda u: L.mix(D("1c1828"), D("5a5578"), L.smooth(-0.3, 0.95, u.z)), scale=1.45,
                 spikes=3, spike_col=(D("9a9cb8"), D("f4f5ff")))
    back_cape(parts, lambda u, v, out: L.mix(D("3a2258"), D("120c1e"), v) if out else D("4a1f52"), r_top=0.4,
              r_bot=0.66, z_bot=0.1, arc=3.0, ragged=0.22, cols=16)
    p, n = chest_front(surf, 1.0)
    with parts.use("keep"):
        parts.ellipsoid(p + n * 0.02, (0.13, 0.13, 0.13), color=D("0d0a14"), weights=CHEST, seg=14, rings=8)
    with parts.use("glow"):
        S.ring(parts, p + n * 0.04, n, 0.15, 0.025, D("ffcf6a"), CHEST, seg=24)
    K.join_parts(body, parts.to_object())
    surf, parts = start(body)
    eye_slits(parts, surf, 1.68, C("ff4fd8"))
    finish(body, parts)


# ================================================================ robed casters (Skeleton_Mage)

def robe_paint(body, pal, skull, robe=None):
    """pal by atlas class; skull(co, n) -> colour for the skull / jaw; robe(co, kind) ->
    colour (or None) overrides the robe body's cloth."""

    def paint(name, co, n, info):
        if name in ("Skull", "Jaw", "Head"):
            return skull(co, n)
        kind, val = S.tex_class(info["tex"])
        if robe and name == "Body":
            c = robe(co, kind)
            if c is not None:
                return shade(c, val, pal[kind][1], lo=0.8, hi=1.1)
        base, ref = pal[kind]
        return shade(base, val, ref)

    K.paint_body(body, paint, face_mode=eyes_mode, tex=True)


HEAD_C = V((0, 0.0, 1.74))


def hand_frame(arm, bone="handslot.r", clip="Idle"):
    """(rest position, rest->posed rotation) of a hand in a clip's first frame: lets a held
    prop be built upright as the creature actually holds it."""
    m = L.pose_matrix(arm, bone, clip)
    pos = arm.data.bones[bone].head_local.copy()
    return pos, m.to_3x3()


def held(arm, posed_dir, bone="handslot.r"):
    """A posed (world) direction -> the rest-space direction for a part skinned to bone."""
    _p, rot = hand_frame(arm, bone)
    return (rot.inverted() @ posed_dir).normalized()


def sky_oracle(arm, body):
    """ผู้พยากรณ์แห่งเมฆา: a cloud oracle: white and sky-blue robes, a white hood trimmed in
    gold over a shadowed face with gold glowing eyes and a third eye, a gold diadem,
    clouds billowing about the shoulders and hem."""
    L.delete_faces(body, ("Hat", "Jaw", "Skull", "Eyes"))
    L.clean(body, quads=False, merge=1e-5)
    white, sky, gold = D("f8fbff"), D("7cc3ff"), D("ffd768")
    pal = {"cloth": (white, 0.62), "leather": (gold, 0.5), "metal": (sky, 0.6), "bone": (D("cfe3ff"), 0.9),
           "dark": (D("3d4f86"), 0.2)}
    robe_paint(body, pal, lambda co, n: D("1d2752"),
               robe=lambda co, kind: None if kind == "leather" else L.mix(sky, white, L.smooth(0.55, 0.95, co.z)))
    surf, parts = start(body)
    # the shadowed face inside the hood, two calm glowing eyes
    parts.ellipsoid(V((0, -0.02, 1.74)), (0.42, 0.42, 0.42), color=None, weights=HEAD, seg=18, rings=10,
                    color_fn=lambda u: L.mix(D("17204a"), D("33478a"), L.smooth(-0.8, 0.9, u.z)))
    with parts.use("glow"):
        for sx in (-1, 1):
            parts.sphere_cap(V((0, -0.02, 1.74)), 0.42, V((0.34 * sx, -1, -0.2)).normalized(), (0.25, 0.15),
                             C("ffe680"), HEAD, lift=0.015, seg=14, rings=2)
    # hood: white outside, sky inside, gold rim round the face opening
    open_dir = V((0, -1, -0.15)).normalized()

    def hood_col(u, out):
        if not out:
            return D("4f7fc8")
        rim = L.smooth(1.1, 0.96, u.angle(open_dir))
        return L.mix(L.mix(D("dfe9fb"), white, L.smooth(-0.4, 0.8, u.z)), gold, rim)

    S.shell(parts, V((0, 0.08, 1.74)), (0.6, 0.57, 0.56), hood_col, HEAD, open_dir=open_dir, open_angle=0.92,
            thick=0.06, seg=24, rings=12, peak=0.14)
    # diadem gem + third eye on the brow
    with parts.use("keep"):
        parts.ellipsoid(V((0, -0.4, 2.02)), (0.075, 0.04, 0.09), color=None, weights=HEAD, seg=10, rings=6,
                        color_fn=lambda u: L.mix(D("e9a63a"), D("fff3c0"), L.smooth(-0.6, 0.8, u.z)))
    with parts.use("glow"):
        parts.ellipsoid(V((0, -0.435, 2.02)), (0.04, 0.02, 0.05), color=C("8fe8ff"), weights=HEAD, seg=8, rings=5)
    # clouds: shoulders and hem
    top, bot = D("ffffff"), D("b9d4f2")
    for sx in (-1, 1):
        S.cloud(parts, V((0.33 * sx, 0.02, 1.27)), 0.2, {"upperarm.l" if sx > 0 else "upperarm.r": 1.0}, top, bot,
                n=5, seed=3 + sx)
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.4
        S.cloud(parts, V((math.cos(a) * 0.42, math.sin(a) * 0.38, 0.42)), 0.17, {"hips": 1.0}, top, bot, n=3,
                seed=10 + i, spread=0.8)
    finish(body, parts)


def eclipse_mage(arm, body):
    """จอมเวทจันทร์ดับ: the dark-moon mage: a pale skull with violet ember eyes under a black
    circlet that carries a great silver crescent and a dead black moon, a high star-lined
    collar and violet-black robes trimmed in silver."""
    L.delete_faces(body, ("Hat",))
    L.clean(body, quads=False, merge=1e-5)
    violet, black, silver = D("54308a"), D("1f1a2e"), D("cfd0e8")
    pal = {"cloth": (violet, 0.62), "leather": (black, 0.5), "metal": (silver, 0.6), "bone": (D("e8def4"), 0.9),
           "dark": (D("120e1c"), 0.2)}
    robe_paint(body, pal, lambda co, n: L.mix(D("b8a8d0"), D("f1ebfa"), L.smooth(1.3, 2.0, co.z)))
    S.recolor_eyes(body, lambda co: C("c45cff"))
    surf, parts = start(body)
    # black circlet round the skull top
    parts.frustum(V((0, 0.0, 1.97)), V((0, 0.12, 1)), 0.445, 0.455, 0.07,
                  lambda t, side: L.mix(D("15111f"), D("3a2f58"), t) if side else D("15111f"), HEAD, seg=28)
    with parts.use("keep"):
        # the great crescent rising behind, horns up
        S.crescent(parts, V((0, 0.12, 2.36)), V((0, -1, 0.1)), V((0, 0, 1)), 0.46, 0.42, HEAD,
                   lambda t, k: L.mix(D("f4f5ff"), D("9a9cc0"), 0.2 + 0.5 * k), thick=0.08, seg=20)
        # the dead moon at its heart
        parts.ellipsoid(V((0, 0.05, 2.28)), (0.15, 0.15, 0.15), color=None, weights=HEAD, seg=14, rings=8,
                        color_fn=lambda u: L.mix(D("05040a"), D("2b1f45"), L.smooth(0.2, 1.0, -u.y)))
    with parts.use("glow"):
        S.ring(parts, V((0, 0.03, 2.28)), V((0, -1, 0.1)), 0.165, 0.018, C("b56bff"), HEAD, seg=24, tube=5)
    # high standing collar
    K.cape(parts, V((0, 0.02, 0)), 1.62, 1.22, 0.52, 0.34, 3.6,
           lambda u, v, out: (D("d9dbf0") if v < 0.12 else L.mix(D("3a2266"), D("1a1230"), v)) if out else D("24183c"),
           CHEST, rows=4, cols=16, thick=0.03)
    finish(body, parts)


def scythe(arm, parts, length=2.7, blade=1.15, grip=0.3):
    """The reaper's scythe, held in the right hand: upright in Idle, the blade forward at
    the top (built in rest space from the hand's Idle pose), skinned to the hand."""
    w = {"hand.r": 1.0}
    pos, rot = hand_frame(arm, "handslot.r")
    inv = rot.inverted()
    up = (inv @ V((0, 0, 1))).normalized()
    fwd = (inv @ V((-1.0, -0.55, 0))).normalized()
    fwd = (fwd - up * fwd.dot(up)).normalized()
    side = up.cross(fwd).normalized()
    bot = pos - up * (length * grip)
    top = pos + up * (length * (1.0 - grip))
    with parts.use("keep"):
        parts.blob(bot, 0.06, up, length, None, weights=w, seg=8, rings=4, tip=0.85,
                   color_fn=lambda a: L.mix(D("1a1626"), D("3a3256"), a))
        for k in (0.08, 0.62, 0.97):
            parts.ellipsoid(bot + up * (length * k), (0.07, 0.07, 0.04), basis=_basis_z(up), color=D("cfd3ea"),
                            weights=w, seg=10, rings=5)
        # the socket where blade meets shaft, a silver crescent collar
        parts.ellipsoid(top, (0.1, 0.1, 0.12), basis=_basis_z(up), color=None, weights=w, seg=10, rings=6,
                        color_fn=lambda u: L.mix(D("8d92b4"), D("eef0ff"), L.smooth(-0.5, 0.8, u.z)))
    with parts.use("glow"):
        # long curved blade sweeping forward and down, starlight blue to white edge
        parts.blob(top - up * 0.02, (0.03, 0.17), fwd, blade, None, weights=w, seg=10, rings=8, tip=0.04,
                   bend=-up * 0.6 - fwd * 0.1, up=up,
                   color_fn=lambda a: L.mix(C("6fb8ff"), C("f2fbff"), L.smooth(0.0, 0.9, a)))
        parts.blob(top + up * 0.02, 0.035, up, 0.25, C("bfe8ff"), weights=w, seg=6, rings=4, tip=0.1)
    return side


def eclipse_reaper(arm, body):
    """ผู้เก็บเกี่ยวแสงดาว: the starlight reaper: a pale skull with star-white eyes deep in a
    tall pointed night-blue hood, a long tattered cloak scattered with stars, a dark
    eclipse ring behind the head and a great scythe with a blade of starlight."""
    L.delete_faces(body, ("Hat",))
    L.clean(body, quads=False, merge=1e-5)
    night, ink, silver = D("2b2548"), D("16121f"), D("c4c9e2")
    pal = {"cloth": (night, 0.62), "leather": (D("3b3360"), 0.5), "metal": (silver, 0.6), "bone": (D("dfe2ee"), 0.9),
           "dark": (D("0e0b16"), 0.2)}
    robe_paint(body, pal, lambda co, n: L.mix(D("9a9fb8"), D("eef0f8"), L.smooth(1.35, 2.05, co.z)))
    S.recolor_eyes(body, lambda co: C("d9fbff"))
    surf, parts = start(body)
    open_dir = V((0, -1, -0.12)).normalized()

    def hood_col(u, out):
        if not out:
            return D("08060e")
        return L.mix(D("1a1530"), D("3a3266"), L.smooth(-0.6, 0.9, u.z))

    S.shell(parts, V((0, 0.1, 1.78)), (0.58, 0.6, 0.58), hood_col, HEAD, open_dir=open_dir, open_angle=0.9,
            thick=0.06, seg=22, rings=12, peak=0.45)
    # long ragged cloak
    cy, arc = 0.06, 3.2
    back_cape(parts, lambda u, v, out: L.mix(D("2e2754"), D("0f0c1a"), v) if out else D("120e1c"), r_top=0.42,
              r_bot=0.7, z_top=1.3, z_bot=0.06, arc=arc, ragged=0.28, cols=16, cy=cy)
    import random
    rng = random.Random(5)
    with parts.use("glow"):
        for i in range(11):
            u, v = rng.uniform(-0.85, 0.85), rng.uniform(0.15, 0.85)
            a = math.pi * 0.5 + u * arc * 0.5 * (1.0 + 0.15 * v)
            r = 0.42 + (0.7 - 0.42) * v + 0.045
            c = V((math.cos(a) * r, cy + math.sin(a) * r, 1.3 + (0.06 - 1.3) * v))
            out = V((math.cos(a), math.sin(a), 0))
            sz = rng.uniform(0.025, 0.05)
            for d in (V((0, 0, 1)), out.cross(V((0, 0, 1)))):
                parts.ellipsoid(c, (sz * 0.35, sz * 0.35, sz * 1.6), basis=_basis_z(d), color=C("e8f6ff"),
                                weights=CHEST, seg=6, rings=4)
        # dark eclipse ring behind the head
        S.ring(parts, V((0, 0.62, 2.0)), V((0, 1, 0.15)), 0.5, 0.03, None, HEAD, seg=32, tube=5,
               color_fn=lambda t, s_: L.mix(C("8a5cff"), C("e7d6ff"), 0.5 + 0.5 * math.cos(t * 2 * math.pi * 4)))
    scythe(arm, parts)
    finish(body, parts)


# ================================================================ bone soldiers (Skeleton_Minion / Rogue)

def bone_paint(body, pal, bone_col, part_kind=None):
    """Skeleton bodies: bone by its own painted shading, the rest by atlas class."""

    def paint(name, co, n, info):
        kind, val = S.tex_class(info["tex"])
        if part_kind:
            kind = part_kind(name, kind)
        if kind == "bone":
            return shade(L.mix(bone_col[0], bone_col[1], L.smooth(0.2, 2.1, co.z)), val, 0.9, lo=0.75, hi=1.08)
        base, ref = pal[kind]
        return shade(base, val, ref)

    K.paint_body(body, paint, face_mode=eyes_mode, tex=True)


def eclipse_minion(arm, body):
    """ทหารกระดูกคราส: an eclipse bone soldier: warm ivory bones with soft shade, violet ember
    eyes, an iron skull-cap with a silver crescent and a ragged purple tabard."""
    L.clean(body, quads=False, merge=1e-5)
    pal = {"cloth": (D("6a3fa8"), 0.62), "leather": (D("3a2d4a"), 0.55), "metal": (D("9aa0b8"), 0.6),
           "dark": (D("1c1626"), 0.2), "cloak": (D("5b3a8f"), 0.75)}
    bone_paint(body, pal, (D("d9cbb4"), D("fbf4e6")), lambda name, kind: "cloak" if name == "Cloak" else kind)
    S.recolor_eyes(body, lambda co: C("b45cff"))
    surf, parts = start(body)
    # iron skull-cap with a rim and a silver crescent
    parts.ellipsoid(V((0, 0.02, 1.86)), (0.5, 0.52, 0.37), color=None, weights=HEAD, seg=22, rings=10,
                    squash_bottom=0.85, color_fn=lambda u: L.mix(D("3a3354"), D("7d77a0"), L.smooth(-0.2, 0.9, u.z)))
    parts.frustum(V((0, 0.02, 1.8)), V((0, 0, 1)), 0.52, 0.51, 0.07,
                  lambda t, side: L.mix(D("595478"), D("aeb2cc"), t), HEAD, seg=26)
    with parts.use("keep"):
        S.crescent(parts, V((0, -0.47, 1.98)), V((0, -1, 0.3)), V((0, 0.3, 1)), 0.13, 0.5, HEAD,
                   lambda t, k: L.mix(D("f0f2ff"), D("b0b4d0"), k * 0.6), thick=0.04)
    finish(body, parts)


def eclipse_rogue(arm, body):
    """เงามีดราตรี: a night-blade skeleton: a violet-black hood and cape, a scarf over the jaw,
    magenta ember eyes and silver buckles."""
    L.clean(body, quads=False, merge=1e-5)
    pal = {"cloth": (D("3a2560"), 0.62), "leather": (D("2a2235"), 0.55), "metal": (D("b9bdd6"), 0.6),
           "dark": (D("120e18"), 0.2), "hood": (D("332252"), 0.7)}
    bone_paint(body, pal, (D("cfc4d8"), D("f4effa")),
               lambda name, kind: "hood" if name in ("Hood", "Cape") else kind)
    S.recolor_eyes(body, lambda co: C("ff5ce0"))
    surf, parts = start(body)
    # scarf over the lower face, a tail down the back
    parts.frustum(V((0, -0.02, 1.3)), V((0, -0.08, 1)), 0.4, 0.46, 0.25,
                  lambda t, side: L.mix(D("1e1430"), D("4a2f78"), t), HEAD, seg=24)
    S.feather(parts, V((0.12, 0.38, 1.45)), V((0.35, 1, -0.9)), 0.55, 0.08, CHEST, D("3e2868"), D("1e1430"),
              up=V((0, 0, 1)), tip=0.5, thick=0.3)
    finish(body, parts)


# ================================================================ pegasi (Horse_White)

HORSE_HEAD = {"Head": 1.0}
WITHERS = {"Torso3": 0.55, "Torso2": 0.45}


UPPER_LEGS = ("FrontUpperLeg.L", "FrontUpperLeg.R", "BackLeg.L", "BackLeg.R", "BackUpperLeg.L", "BackUpperLeg.R")
LOWER_LEGS = ("FrontLowerLeg.L", "FrontLowerLeg.R", "BackLowerLeg.L", "BackLowerLeg.R", "IKFrontLeg.L", "IKFrontLeg.R",
              "IKBackLeg.L", "IKBackLeg.R", "FF.L", "FF.R", "FFB.L", "FFB.R")


def horse_base(arm, body):
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    L.clean(body)
    # sturdier, rounder cartoon legs
    K.thicken(body, arm, UPPER_LEGS, 1.2)
    K.thicken(body, arm, LOWER_LEGS, 1.55)
    L.subdivide(body, 1)
    L.decimate_to(body, 4300)
    L.relax(body, 2, 0.4)


def horse_eye_spot(surf, sx, y=-2.86, z=4.18):
    p, n = surf.toward(V((sx * 3.0, y, z)), V((0.0, y, z)))
    return p, n


def sky_pegasus(arm, body):
    """เพกาซัสปีกอรุณ: a dawn-winged pegasus: pearl white coat with a lilac-blue shade
    underneath, a flowing golden mane and tail, gold hooves, large bright sky-blue eyes,
    white wings with dawn-gold primaries, a small golden halo set close above the ears."""
    import remaster_monsters as M
    horse_base(arm, body)
    white, shade_c, gold = D("fffdf8"), D("cdd3f2"), D("ffd36a")

    def paint(name, co, n, info):
        if name == "Hair":
            return L.mix(D("f0a640"), D("ffe9a0"), L.smooth(-0.02, 0.08, info["bump"]))
        if name == "Hooves":
            return L.mix(D("d99a35"), gold, L.smooth(0.0, 0.25, co.z))
        if name == "Muzzle":
            return D("f5d6dc")
        c = L.mix(shade_c, white, L.smooth(-0.7, 0.4, n.z))
        return L.mix(c, D("f8eedd"), L.smooth(1.4, 0.6, co.z) * 0.6)

    K.paint_body(body, paint)
    surf, parts = start(body)
    for sx in (-1, 1):
        p, n = horse_eye_spot(surf, sx)
        with parts.use("keep"):
            M.sparkly_eye(parts, p - n * 0.06, 0.15, V((0.75 * sx, -0.65, 0.05)).normalized(), D("2a6fd8"),
                          D("9fe4ff"), HORSE_HEAD, iris=0.62, pupil=0.3, lid=D("f4f2fa"))
        S.wing(parts, V((0.24 * sx, -0.8, 3.12)), sx, 1.6, WITHERS, D("fffdf6"), D("ffffff"), rows=(6, 5, 4),
               lift=1.0, back=0.3, accent=D("ffd877"), accent_rows=(0,))
    with parts.use("glow"):
        S.ring(parts, V((0, -2.45, 5.1)), V((0, 0.35, 1)), 0.32, 0.035, None, {"Torso3": 1.0}, flat=0.6,
               color_fn=lambda t, s_: L.mix(C("ffc83a"), C("fff2c0"), 0.5 + 0.5 * s_))
    finish(body, parts)


def sky_storm_pegasus(arm, body):
    """เพกาซัสพายุทอง: the golden storm pegasus (elite): a thundercloud-blue coat with gold
    lightning on its flanks, a storm-cloud mane with gold streaks, a gold faceplate and
    breastplate, a crown of lightning spikes, burning gold eyes, great storm-blue wings
    with gold primaries and storm clouds about its hooves."""
    import remaster_monsters as M
    horse_base(arm, body)
    top, belly, gold = D("41507e"), D("9eabcf"), D("ffcf55")

    def paint(name, co, n, info):
        if name == "Hair":
            return L.mix(D("262c48"), D("ffd45c"), L.smooth(0.02, 0.1, info["bump"]))
        if name == "Hooves":
            return L.mix(D("c98a2a"), gold, L.smooth(0.0, 0.25, co.z))
        if name == "Muzzle":
            return D("2c3352")
        return L.mix(belly, top, L.smooth(-0.6, 0.6, n.z))

    K.paint_body(body, paint)
    surf, parts = start(body)
    for sx in (-1, 1):
        p, n = horse_eye_spot(surf, sx)
        with parts.use("keep"):
            M.sparkly_eye(parts, p - n * 0.06, 0.14, V((0.75 * sx, -0.65, 0.05)).normalized(), D("c86a10"),
                          D("ffe070"), HORSE_HEAD, iris=0.66, pupil=0.26, lid=D("3a4774"))
        q, nq = horse_eye_spot(surf, sx, z=4.33)
        parts.stroke(q, nq, [(0.12 * sx, 0.05), (0.0, 0.0), (-0.14 * sx, -0.06)], 0.06, D("1e2440"),
                     weights=HORSE_HEAD, lift=0.03)
        # lightning on the flank and the shoulder
        for (y, z, sz, turn) in ((0.45, 2.75, 0.8, 0.2), (-0.95, 2.45, 0.55, -0.3)):
            q, nq = surf.toward(V((sx * 3.0, y, z)), V((0.0, y, z)))
            K.zigzag(parts, q, nq, sz, C("ffd44a"), turn=turn * sx)
        S.wing(parts, V((0.24 * sx, -0.8, 3.12)), sx, 2.1, WITHERS, D("3d4a78"), D("8fa0d4"), rows=(6, 5, 4),
               lift=1.15, back=0.3, accent=D("ffd060"), accent_rows=(0, 1))
    # gold faceplate down the face, a gem on the brow
    p, n = surf.toward(V((0, -6, 5.2)), V((0, -2.7, 3.9)))
    with parts.use("keep"):
        parts.decal(p, n, M_ellipse(0.11, 0.36), gold, weights=HORSE_HEAD, lift=0.02, up=V((0, 0.6, 0.8)),
                    detail=False)
        parts.ellipsoid(p + n * 0.05, (0.08, 0.06, 0.1), color=None, weights=HORSE_HEAD, seg=10, rings=6,
                        color_fn=lambda u: L.mix(D("2a74d8"), D("bff0ff"), L.smooth(-0.5, 0.9, u.z)))
        # crown of lightning spikes between the ears
        for i, a in enumerate((-0.45, 0.0, 0.45)):
            K.horn(parts, V((math.sin(a) * 0.14, -2.42, 4.62)), V((math.sin(a) * 0.6, 0.15, 1)), 0.42 if i == 1 else 0.3,
                   0.06, HORSE_HEAD, D("e9a530"), D("fff4b8"), mode="keep", seg=8)
    # a gold collar at the base of the neck
    with parts.use("keep"):
        S.ring(parts, V((0, -1.5, 3.0)), V((0, -0.55, 0.85)), 0.43, 0.07, None, {"Neck1": 1.0}, seg=28, tube=6,
               color_fn=lambda t, s_: L.mix(D("c98a2a"), D("ffe48a"), 0.5 + 0.5 * s_))
    finish(body, parts)


def M_ellipse(rx, ry, n=20):
    return [(math.cos(2 * math.pi * i / n) * rx, math.sin(2 * math.pi * i / n) * ry) for i in range(n)]


# ================================================================ cloud sheep (blob/Dog)

def sky_cloud_sheep(arm, body):
    """แกะปุยเมฆ (sky_cloud_alpaca's new look): a round cloud sheep floating on its own
    little cloud: a fleece of white cloud puffs shaded sky blue underneath, a cream face
    with big sky-blue eyes, blush and a smile, floppy pink-lined ears, small curled gold
    horns, a tuft of fleece on the brow and two tiny cloud wings."""
    import remaster_monsters as M
    import recipes_critters as RC
    RC.drop_islands(body, lambda c, size, mat: mat == "Eye_White" or (mat == "Eye_Black" and abs(c.x) > 0.1))
    # a small sheep's nose instead of the dog's big one
    ni = L.mat_index(body, "Eye_Black")
    nose = {v for p in body.data.polygons if p.material_index == ni for v in p.vertices}
    nc = sum((body.data.vertices[i].co for i in nose), V()) / max(1, len(nose))
    for i in nose:
        v = body.data.vertices[i]
        v.co = nc + (v.co - nc) * 0.55 + V((0, 0.06, 0.04))
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 2600)
    wool, wool_shade, face = D("ffffff"), D("b9d3f4"), D("fff1e4")

    def paint(name, co, n, info):
        if name == "Eye_Black":
            return D("c96a7e")
        if name == "Dog_Secondary" or (co.y < -0.5 and co.z < 1.15 and abs(co.x) < 0.75):
            return L.mix(D("f6dccb"), face, L.smooth(0.2, 0.9, co.z))
        if co.z > 1.0 and abs(co.x) > 0.6:  # the floppy ears
            return L.mix(D("f4c3cc"), D("fde4e8"), L.smooth(-0.3, 0.6, n.z))
        return L.mix(wool_shade, wool, L.smooth(-0.6, 0.5, n.z))

    K.paint_body(body, paint)
    surf, parts = start(body)
    center = V((0, 0.05, 0.85))
    # the fleece
    for d in S_fib(40):
        if d.y < -0.35 and d.z < 0.62:
            continue  # leave the face open
        if d.z < -0.3:
            continue
        p, n = M.dir_hit(surf, center, d)
        if p is None or (p.z > 1.0 and abs(p.x) > 0.62):
            continue  # not over the ears
        r = 0.2 + 0.06 * (0.5 + 0.5 * d.z)
        parts.ellipsoid(p + n * 0.03, (r, r, r * 0.9), color=None, weights=p, seg=9, rings=5,
                        color_fn=lambda u: L.mix(wool_shade, wool, L.smooth(-0.7, 0.5, u.z)))
    # brow tuft
    for (x, z) in ((-0.17, 1.38), (0.17, 1.38), (0.0, 1.47)):
        p, n = M.front_hit(surf, x, z)
        if p is not None:
            parts.ellipsoid(p + n * 0.06, (0.17, 0.15, 0.15), color=None, weights={"Head": 1.0}, seg=10, rings=6,
                            color_fn=lambda u: L.mix(wool_shade, wool, L.smooth(-0.7, 0.5, u.z)))
    for sx in (-1.0, 1.0):
        with parts.use("keep"):
            M.sparkly_eye(parts, V((0.4 * sx, -0.62, 0.86)), 0.21, V((0.3 * sx, -1.0, 0.0)).normalized(),
                          D("1d5fd0"), D("8fe0ff"), {"Head": 1.0}, iris=0.66, pupil=0.34)
        p, n = M.front_hit(surf, 0.62 * sx, 0.55)
        if p is not None:
            M.cheek(parts, p, n, 0.12, 0.07, D("ff9fb0"))
        # small curled gold horns just above the ears
        # small curled gold ram horns over the ears
        hc = V((0.6 * sx, -0.3, 1.18))
        with parts.use("keep"):
            for k in range(9):
                t = k / 8
                th = math.radians(80 + 300 * t)
                r = 0.2 * (1.0 - 0.55 * t)
                q = hc + V((sx * (0.02 + 0.14 * t), -math.cos(th) * r, math.sin(th) * r))
                rad = 0.09 * (1.0 - 0.5 * t)
                parts.ellipsoid(q, (rad, rad, rad), color=None, weights={"Head": 1.0}, seg=6, rings=4,
                                color_fn=lambda u, t=t: L.mix(D("e0a038"), D("fff0b8"), 0.3 + 0.5 * t + 0.2 * u.z))
        # tiny cloud wings
        S.wing(parts, V((0.42 * sx, 0.5, 1.15)), sx, 0.6, {"Body": 1.0}, D("eaf4ff"), D("ffffff"), rows=(4, 3),
               lift=0.9, back=0.3, width=0.2)
    p, n = M.front_hit(surf, 0.0, 0.3)
    if p is not None:
        M.smile_mouth(parts, p, n, 0.12, 0.09, D("7a3040"), D("ff8a9a"))
    p, n = M.front_hit(surf, 0.0, 0.5)
    if p is not None:
        with parts.use("keep"):
            parts.ellipsoid(p, (0.09, 0.05, 0.06), color=D("e58da0"), weights={"Head": 1.0}, seg=10, rings=6)
    # the cushion of cloud it floats on
    S.cloud(parts, V((0, 0.05, 0.08)), 0.62, {"Body": 1.0}, D("ffffff"), D("9fc2ee"), n=7, seed=4, flat=0.55,
            spread=1.3)
    finish(body, parts)


def S_fib(n):
    out = []
    for i in range(n):
        z = 1.0 - 2.0 * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1.0 - z * z))
        a = i * math.pi * (3.0 - math.sqrt(5.0))
        out.append(V((r * math.cos(a), r * math.sin(a), z)))
    return out


RECIPES = {
    "star/Skeleton_Warrior_sky_warden": sky_warden,
    "star/Skeleton_Warrior_sky_high_warden": sky_high_warden,
    "star/Skeleton_Warrior_eclipse_warrior": eclipse_warrior,
    "star/Skeleton_Warrior_eclipse_dreadknight": eclipse_dreadknight,
    "star/Skeleton_Mage_sky_oracle": sky_oracle,
    "star/Skeleton_Mage_eclipse_mage": eclipse_mage,
    "star/Skeleton_Mage_eclipse_reaper": eclipse_reaper,
    "star/Skeleton_Minion_eclipse_minion": eclipse_minion,
    "star/Skeleton_Rogue_eclipse_rogue": eclipse_rogue,
    "star/Horse_White_sky_pegasus": sky_pegasus,
    "star/Horse_White_sky_storm_pegasus": sky_storm_pegasus,
    "blob/Dog_sky_cloud_alpaca": sky_cloud_sheep,
}


def source(name):
    """remaster/star/Skeleton_Warrior_sky_warden -> star/Skeleton_Warrior.glb"""
    d, base = name.split("/")
    for rig in ("Skeleton_Warrior", "Skeleton_Mage", "Skeleton_Minion", "Skeleton_Rogue", "Horse_White", "Alpaca"):
        if base.startswith(rig + "_"):
            return os.path.join(SRC, d, rig + ".glb")
    if base.startswith("Dog_"):
        return os.path.join(SRC, d, "Dog.gltf")  # blob/Dog
    raise KeyError(name)


def build(name):
    import bpy
    L.reset()
    path = source(name)
    if path.endswith(".glb") and "/star/" in path and "Skeleton" in path:
        arm, body = S.load_rig(path)
    else:
        arm, body = L.load(path)
    clips = sorted(a.name for a in bpy.data.actions)
    before = L.tri_count(body)
    RECIPES[name](arm, body)
    out = os.path.join(OUT, name + ".glb")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    K.export(arm, body, out, clips)
    print("REMASTER %s tris %d -> %d, %d bytes, clips %s" % (name, before, L.tri_count(body), os.path.getsize(out),
                                                          ",".join(clips)))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    for name in (args or list(RECIPES)):
        build(name)
