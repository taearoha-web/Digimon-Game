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
                    weights=weights, seg=24, rings=8, color_fn=lambda u: L.mix(c_ray, c_disc, 1.0 - abs(u.z) * 0.0))
    for i in range(n_rays):
        a = 2.0 * math.pi * i / n_rays + math.pi / n_rays
        d = t_ * math.cos(a) + b_ * math.sin(a)
        ln = radius * (0.95 if i % 2 else 0.6)
        parts.blob(center + d * radius * 0.7, (radius * 0.16, radius * 0.05), d, ln, None, weights=weights, seg=8,
                   rings=5, tip=0.1, up=n_, color_fn=lambda a_: L.mix(c_ray, c_tip, a_))


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
    crest(parts, D("ffffff"), D("ffffff"), height=0.34, width=0.09, n=10)
    with parts.use("keep"):
        sun_disc(parts, HELM_C + V((0, 0.42, 0.18)), 0.5, 14, D("ffcf4a"), D("ffb23a"), D("fff3b0"), HEAD)
    for sx in (-1, 1):
        pauldron(parts, sx, lambda u: L.mix(D("e8a23a"), D("ffe68a"), L.smooth(-0.4, 0.9, u.z)), scale=1.25)
        S.wing(parts, V((0.16 * sx, 0.28, 1.25)), sx, 0.9, CHEST, D("fff8ec"), D("ffffff"), rows=(6, 5, 4),
               lift=1.1, back=0.6, accent=D("ffd86a"), accent_rows=(2,))
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


RECIPES = {
    "star/Skeleton_Warrior_sky_warden": sky_warden,
    "star/Skeleton_Warrior_sky_high_warden": sky_high_warden,
    "star/Skeleton_Warrior_eclipse_warrior": eclipse_warrior,
    "star/Skeleton_Warrior_eclipse_dreadknight": eclipse_dreadknight,
    "star/Skeleton_Mage_sky_oracle": sky_oracle,
    "star/Skeleton_Mage_eclipse_mage": eclipse_mage,
}


def source(name):
    """remaster/star/Skeleton_Warrior_sky_warden -> star/Skeleton_Warrior.glb"""
    d, base = name.split("/")
    for rig in ("Skeleton_Warrior", "Skeleton_Mage", "Skeleton_Minion", "Skeleton_Rogue", "Horse_White", "Alpaca"):
        if base.startswith(rig + "_"):
            return os.path.join(SRC, d, rig + ".glb")
    if base.startswith("Dog_"):
        return os.path.join(SRC, d, "Dog.gltf")
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
