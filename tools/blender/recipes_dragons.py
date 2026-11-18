"""Team dragons: one distinct dragon per monster on the two dragon rigs (see
remaster_monsters.py for the pipeline, kit_flyers for the Glow materials).

    /opt/bpy5/bin/python tools/blender/recipes_dragons.py [flying/Dragon_storm_dragon ...]

flying/Dragon (a big winged head):  sand_dragon keeps the base model (flying/Dragon.glb,
also the drake summon); storm_dragon, cloud_whelp and leviathan_whelp get variants.
flying/Dragon_Evolved (full body):  fire_dragon keeps the base model (also the elder
summon); magma, gold, abyss, prism and shrine dragons get variants.
A variant is written to remaster/flying/<Rig>_<monster_id>.glb and that monster's "model"
points at "remaster/flying/<Rig>_<monster_id>". These recipes supersede dragon_young /
dragon_elder in recipes_flyers.py for the two base models.

Every recipe first removes the rig's own head horns (the last round's extra horns hid
inside them), then grows its own: swept, zig-zag, crag, crown, antler or crystal horns,
plus frills, fins, manes, plates and elemental marks, so each dragon reads by its
silhouette, not only by its colour. Variants are painted in their own colours and use a
white (or near-white) tint.
"""
import colorsys
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import remaster_lib as L  # noqa: E402
import kit_flyers as K  # noqa: E402
import recipes_flyers as F  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

C = L.srgb
V = Vector
WHITE = C("ffffff")
HEAD = {"Head": 1.0}
HC = V((0.0, -0.12, 2.45))  # centre of the skull (both rigs, rest pose)


# ================================================================ shapes

def tube(parts, pts, radii, col_fn, weights, detail=False, seg=10, flat=1.0, up=None):
    """A smooth curved tube along pts with a radius per point (horn, whisker, tendril),
    capped at both ends. col_fn(t 0 root..1 tip, angle) -> colour. flat squashes the
    cross-section along the second frame axis (blade-like horns)."""
    n = len(pts)
    tans = []
    for i in range(n):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, n - 1)]
        tans.append((b - a).normalized())
    ref = up or V((0, 0, 1))
    if abs(ref.dot(tans[0])) > 0.9:
        ref = V((1, 0, 0)) if abs(tans[0].x) < 0.9 else V((0, 1, 0))
    nrm = (ref - tans[0] * ref.dot(tans[0])).normalized()
    lens = [0.0]
    for i in range(1, n):
        lens.append(lens[-1] + (pts[i] - pts[i - 1]).length)
    total = lens[-1] or 1.0
    cos, cols = [], []
    for i in range(n):
        if i > 0:
            t0, t1 = tans[i - 1], tans[i]
            ax = t0.cross(t1)
            if ax.length > 1e-6:
                nrm = Matrix.Rotation(t0.angle(t1), 3, ax.normalized()) @ nrm
        nrm = (nrm - tans[i] * nrm.dot(tans[i])).normalized()
        bi = tans[i].cross(nrm)
        t = lens[i] / total
        for s in range(seg):
            a = 2.0 * math.pi * s / seg
            cos.append(pts[i] + (nrm * math.cos(a) + bi * math.sin(a) * flat) * radii[i])
            cols.append(col_fn(t, a))
    cos.append(pts[0] - tans[0] * radii[0] * 0.3)
    cols.append(col_fn(0.0, 0.0))
    cos.append(pts[-1] + tans[-1] * radii[-1] * 0.8)
    cols.append(col_fn(1.0, 0.0))
    c0, c1 = len(cos) - 2, len(cos) - 1
    faces = []
    for i in range(n - 1):
        for s in range(seg):
            a, b = i * seg + s, i * seg + (s + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    for s in range(seg):
        faces.append((c0, (s + 1) % seg, s))
        last = (n - 1) * seg
        faces.append((c1, last + s, last + (s + 1) % seg))
    return parts._add(cos, faces, lambda i: cols[i], weights, detail)


def curve(p0, d0, length, n=7, bend=V((0, 0, 0)), twist_up=0.0, zig=None):
    """Points of a horn: start p0, initial direction d0, curving by `bend` (added
    direction per unit length, applied progressively), optional zig-zag offsets."""
    pts = [p0.copy()]
    d = d0.normalized()
    step = length / (n - 1)
    p = p0.copy()
    for i in range(1, n):
        d = (d + bend * step).normalized()
        p = p + d * step
        q = p.copy()
        if zig is not None:
            q = q + zig * (1.0 if i % 2 else -1.0) * (1.0 - i / n * 0.5)
        pts.append(q)
    return pts


def taper(n, r0, r1=0.012, power=1.0):
    return [r0 + (r1 - r0) * (i / (n - 1)) ** power for i in range(n)]


def ring_col(root, tip, bands=0.0, k=0.9):
    """Horn colour: root to tip with optional growth bands."""
    def f(t, a):
        c = L.mix(root, tip, L.smooth(0.0, k, t))
        if bands:
            c = L.mix(c, c * 0.72, max(0.0, math.sin(t * bands * math.pi)) ** 6 * (1.0 - t))
        return c
    return f


def head_point(surf, direction, center=HC, sink=0.05):
    p, n = F.dir_hit(surf, center, direction)
    if p is None:
        return None, None
    return p - n * sink, n


def shard(parts, base, axis, length, width, col_fn, weights, detail=False, sides=6):
    """A cut crystal: a few-sided prism with a pointed tip."""
    axis = axis.normalized()
    ts = (0.0, 0.12, 0.62, 0.8, 1.0)
    rs = (width * 0.75, width, width * 0.96, width * 0.55, 0.006)
    tube(parts, [base + axis * length * t for t in ts], list(rs), lambda t, a: col_fn(t), weights, detail=detail,
         seg=sides)


def puff(parts, center, r, col_top, col_low, weights, n=5, seed=1, squash=0.75):
    """A cluster of round cloud puffs."""
    rng = random.Random(seed)
    for k in range(n):
        a = 2.0 * math.pi * k / n + rng.uniform(-0.3, 0.3)
        off = V((math.cos(a) * r * 0.7, math.sin(a) * r * 0.7, rng.uniform(-0.1, 0.25) * r))
        rr = r * rng.uniform(0.55, 0.8)
        parts.ellipsoid(center + off, (rr, rr, rr * squash), color=None, weights=weights, seg=8, rings=5,
                        color_fn=lambda u: L.mix(col_low, col_top, L.smooth(-0.8, 0.6, u.z)))
    parts.ellipsoid(center + V((0, 0, r * 0.25)), (r * 0.75, r * 0.75, r * 0.6), color=None, weights=weights, seg=8,
                    rings=5, color_fn=lambda u: L.mix(col_low, col_top, L.smooth(-0.8, 0.6, u.z)))


def fan(parts, root, spine_dirs, lengths, col_fn, weights, detail=False, thick=0.025, steps=5, spine_col=None,
        spine_r=0.03, normal_hint=None):
    """A frill / fin: membrane stretched between spines radiating from root.
    col_fn(r_t along spine, c_t across) -> colour; spines drawn as thin tubes."""
    if normal_hint is not None:
        a = spine_dirs[0].normalized() * lengths[0]
        b = spine_dirs[-1].normalized() * lengths[-1] - a
        if b.cross(a).dot(normal_hint) < 0.0:
            spine_dirs, lengths = list(reversed(spine_dirs)), list(reversed(lengths))
    rows = []
    for k in range(steps + 1):
        t = k / steps
        rows.append([root + d.normalized() * ln * max(t, 0.04) for d, ln in zip(spine_dirs, lengths)])
    parts.membrane(rows, col_fn, weights, detail=detail, thick=thick, normal_hint=normal_hint)
    if spine_col is not None:
        for d, ln in zip(spine_dirs, lengths):
            pts = [root + d.normalized() * ln * t for t in (0.0, 0.35, 0.7, 1.08)]
            tube(parts, pts, [spine_r, spine_r * 0.8, spine_r * 0.55, 0.006], spine_col, weights, seg=6)


def zig_stroke(parts, surf, center, direction, length, width, col, detail="glow", seed=3, up=V((0, 0, 1)),
               lift=0.012, kinks=5):
    """A forked lightning bolt painted on the hide (glowing)."""
    p, n = F.dir_hit(surf, center, direction)
    if p is None:
        return
    rng = random.Random(seed)
    path = [(0.0, 0.0)]
    for i in range(1, kinks + 1):
        path.append((rng.uniform(-0.35, 0.35) * length / kinks + (0.12 if i % 2 else -0.12) * length / kinks * 3,
                     -length * i / kinks))
    parts.stroke(p, n, path, width, col, detail=detail, lift=lift, up=up)


# ================================================================ base prep / paint

def prep(body, tris, sub=False, drop_fangs=False, relax_mats=("Dragon_Main",)):
    """Eyes measured, eye faces and the rig's own head horns removed (fangs too when
    asked), welded, re-meshed to about `tris`."""
    eyes = K.eye_balls(body, ("Eye_White",))

    def horn(c, n, g):
        if n != "Dragon_Horn" or g.startswith("Wing"):
            return False
        return c.z > 2.4 or drop_fangs

    L.delete_faces(body, ("Eye_White", "Eye_Black"), where=horn)
    L.clean(body)
    _fill_head_holes(body)
    if sub:
        L.subdivide(body, 1)
    L.decimate_to(body, tris)
    L.relax(body, 2, 0.35, relax_mats)
    return eyes


def _fill_head_holes(body):
    """Caps the holes the removed horns leave in the skull (open borders on the head,
    away from the wings), then smooths the patch."""
    import bmesh
    groups = L.dominant_groups(body)
    bm = bmesh.new()
    bm.from_mesh(body.data)
    edges = [e for e in bm.edges if e.is_boundary and all(
        not groups[v.index].startswith("Wing") and v.co.z > 2.3 for v in e.verts)]
    print("HOLE EDGES", len(edges))
    res = bmesh.ops.holes_fill(bm, edges=edges, sides=400)
    faces = res.get("faces", [])
    if faces:
        bmesh.ops.triangulate(bm, faces=faces)
    bm.to_mesh(body.data)
    bm.free()


def hide_paint(top, mid, belly, plate_line, membrane, membrane_edge, horn_root, horn_tip, mouth, scale_size=0.2,
               extra=None):
    """recipes_flyers' dragon paint, then extra(name, co, n, info, colour) -> colour."""
    base = F._dragon_paint(top, mid, belly, plate_line, membrane, membrane_edge, horn_root, horn_tip, mouth,
                           scale_size)
    if extra is None:
        return base

    def paint(name, co, n, info):
        return extra(name, co, n, info, base(name, co, n, info))
    return paint


def eyes_(parts, eyes, lid, brow, ball, open_=0.3, tilt=0.5, slit=(0.09, 0.55), scale=0.98, ring=None,
          lower=0.55, brow_size=1.25):
    for c, r in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        gaze = V((0.35 * sx, -1.0, 0.05)).normalized()
        K.fierce_eye(parts, c, r * scale, gaze, HEAD, lid, brow=brow, ball=ball, slit=slit, tilt=tilt, open_=open_,
                     brow_size=brow_size, lower_lid=lower, ring=ring)


def nostrils(parts, surf, col, z=2.05, x=0.1):
    for sx in (-1.0, 1.0):
        p, n = F.front_hit(surf, x * sx, z)
        if p is not None:
            parts.decal(p, n, [(math.cos(a) * 0.04, math.sin(a) * 0.025) for a in
                               [i * math.pi / 6 for i in range(12)]], col, rings=1, lift=0.01)


def finish(body, parts, ao=0.5, shade=V((0.55, 0.45, 0.5))):
    K.join_parts(body, parts.to_object())
    L.bake_ao(body, strength=ao, shade=shade)


def spine_row(parts, surf, zs, col_fn, size=1.0, y_bias=0.3, weights=None, detail=False, sides=8, lean=-0.4,
              flat=0.38):
    """Dorsal spines down the back of the neck / body at heights zs [(z, scale)]."""
    for z, s in zs:
        p, n = surf.toward(V((0.0, 5.0, z + 0.25)), V((0.0, y_bias, z)))
        if p is None:
            continue
        parts.blob(p - n * 0.04, (0.16 * s * size, 0.16 * s * size * flat), (n + V((0, 0.3, lean))).normalized(),
                   0.48 * s * size, None, weights=weights or p, seg=sides, rings=5, tip=0.05, color_fn=col_fn,
                   detail=detail, up=V((1, 0, 0)))


# ================================================================ flying/Dragon (winged head)

def sand_dragon(arm, body):
    """Base flying/Dragon: sand_dragon (sand tint) and the drake summon (teal tint).
    A desert dragon: long oryx horns swept far back, a banded thorny-devil frill fanning
    from each jaw, a short rhino horn on the snout, dune bands across a pale sandstone
    hide (pale so each tint repaints it), sandstone thorns down the neck."""
    eyes = prep(body, 4400, sub=True)
    top, mid, belly = C("8a7462"), C("eadcbc"), C("fff8e6")
    horn_root, horn_tip = C("5a4a40"), C("fff6e2")

    def dunes(name, co, n, info, c):
        if name == "Dragon_Main" and not info["bone"].startswith("Wing"):
            band = 0.5 + 0.5 * math.sin(co.z * 13.0 + co.y * 6.0 + math.sin(co.x * 5.0) * 1.2)
            c = L.mix(c, c * 0.74, L.smooth(0.72, 0.95, band) * (0.3 + 0.7 * L.smooth(-0.1, 0.5, n.y + n.z)))
        if name == "Dragon_Secondary" and info["bone"].startswith("Wing"):
            band = abs(math.sin((co.y * 1.6 + abs(co.x) * 0.5) * 7.0))
            c = L.mix(c, c * 0.6, L.smooth(0.15, 0.0, band) * 0.8)
        return c

    paint = hide_paint(top, mid, belly, C("b8a68a"), C("6a5848"), C("f0dcb8"), horn_root, horn_tip, C("3a0e18"),
                       extra=dunes)
    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    eyes_(parts, eyes, C("c8b494"), C("5a4a42"), C("fff0b0"))
    hc = ring_col(horn_root, horn_tip, bands=7)
    for sx in (-1.0, 1.0):
        # Oryx horns: rise from the brow, sweep back and slightly out, far behind the skull.
        p, n = head_point(surf, V((0.45 * sx, 0.05, 1.0)))
        if p is not None:
            pts = curve(p, V((0.8 * sx, 0.45, 0.6)), 1.35, n=8, bend=V((0.1 * sx, 0.8, -0.3)))
            tube(parts, pts, taper(8, 0.14, 0.014, 0.9), hc, HEAD, seg=9)
        # Jaw frill: five banded spines with sand membrane between, fanning back.
        p, n = head_point(surf, V((1.0 * sx, 0.2, -0.2)), sink=0.06)
        if p is not None:
            dirs = [V((0.9 * sx, 0.35, -0.7 + 0.35 * k)) for k in range(5)]
            lens = [0.55, 0.75, 0.85, 0.75, 0.55]

            def frill(r, c):
                col = L.mix(C("f2dcb0"), C("c89a68"), L.smooth(0.3, 1.0, r))
                return L.mix(col, col * 0.7, L.smooth(0.85, 1.0, abs(math.sin(c * math.pi * 4.0))) * r)
            fan(parts, p, dirs, lens, frill, HEAD, spine_col=ring_col(C("7a6250"), C("fff2dc")), spine_r=0.028,
                normal_hint=V((0, -1.0, 0)))
    # Snout horn (rhino), short and blunt.
    p, n = head_point(surf, V((0.0, -1.0, 0.55)))
    if p is not None:
        tube(parts, curve(p, V((0, -0.35, 1.0)), 0.36, n=5, bend=V((0, 0.9, 0))), taper(5, 0.075, 0.01), hc, HEAD,
             seg=8)
        p2, n2 = head_point(surf, V((0.0, -0.8, 0.85)))
        if p2 is not None:
            tube(parts, curve(p2, V((0, -0.1, 1.0)), 0.2, n=4, bend=V((0, 1.0, 0))), taper(4, 0.05, 0.01), hc, HEAD,
                 seg=7)
    # Sandstone thorns down the neck.
    spine_row(parts, surf, [(2.95, 0.55), (2.75, 0.7), (2.5, 0.75), (2.25, 0.7), (2.0, 0.6), (1.8, 0.5)],
              lambda t: L.mix(C("8a7060"), C("fff0d8"), t), y_bias=0.0, lean=-0.2)
    nostrils(parts, surf, C("2a1810"), z=2.15, x=0.2)
    finish(body, parts, shade=V((0.55, 0.47, 0.5)))
    return {"glow": "ffd060", "strength": 1.3}


def storm_dragon(arm, body):
    """storm_dragon มังกรสายฟ้าคำราม (boss): a thunderhead dragon. Zig-zag lightning-bolt
    horns, a tall three-blade crest, a collar of dark storm cloud round the neck, slate
    hide crackling with glowing bolts, storm-dark wing skin veined with lightning."""
    eyes = prep(body, 4400, sub=True)
    top, mid, belly = C("2c3858"), C("62789e"), C("d8e0ee")
    horn_root, horn_tip = C("1a1e30"), C("d8f4ff")

    def storm(name, co, n, info, c):
        if name == "Dragon_Main" and not info["bone"].startswith("Wing"):
            cl = K.fbm(co, 0.35)
            c = L.mix(c, C("7a8cb8"), L.smooth(0.15, 0.5, cl) * 0.35)
        if name == "Dragon_Secondary" and info["bone"].startswith("Wing"):
            v = abs(K.fbm(co * V((1, 1, 2.5)), 0.4, 2))
            c = L.mix(C("141a34"), C("2c3c6c"), L.smooth(1.5, 2.5, co.z))
            c = L.mix(c, C("bff0ff"), L.smooth(0.04, 0.0, v) * 0.9)
        return c

    paint = hide_paint(top, mid, belly, C("8898b8"), C("1a2040"), C("6a80c0"), horn_root, horn_tip, C("12081e"),
                       extra=storm)
    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    eyes_(parts, eyes, C("3a4a78"), C("141a30"), C("e8fcff"), open_=0.26, tilt=0.6)
    bolt = lambda t, a: L.mix(C("232a48"), C("f0fcff"), L.smooth(0.25, 0.95, t))  # noqa: E731
    for sx in (-1.0, 1.0):
        # Lightning horns: a jagged bolt rising up-and-back.
        p, n = head_point(surf, V((0.5 * sx, 0.05, 1.0)))
        if p is not None:
            d = V((0.12 * sx, 0.25, 1.0)).normalized()
            pts = [p]
            q = p.copy()
            steps = [(0.28, 0.0), (0.22, 0.6), (0.22, -0.55), (0.2, 0.55), (0.18, -0.4), (0.15, 0.3)]
            side = V((sx, 0.0, 0.0))
            for k, (ln, off) in enumerate(steps):
                q = q + d * ln + side * off * 0.22 + V((0, 0.06 * k, 0))
                pts.append(q.copy())
            tube(parts, pts, taper(len(pts), 0.105, 0.012, 0.8), bolt, HEAD, seg=7, flat=0.65)
        # Bolt marks running down the cheeks and the neck (glowing).
        zig_stroke(parts, surf, HC + V((0, 0.1, -0.1)), V((1.0 * sx, -0.1, 0.1)), 0.45, 0.04, C("e0fbff"),
                   seed=2 if sx > 0 else 5)
        zig_stroke(parts, surf, V((0.0, 0.1, 2.1)), V((0.8 * sx, 0.6, -0.2)), 0.5, 0.045, C("e0fbff"),
                   seed=7 if sx > 0 else 11)
    # Three-blade crest along the crown (tall, swept back).
    for k, (y, h) in enumerate(((-0.25, 0.55), (0.0, 0.75), (0.3, 0.55))):
        p, n = head_point(surf, V((0.0, y, 1.0)))
        if p is not None:
            parts.blob(p, (0.13, 0.04), V((0, 0.45 + 0.1 * k, 1.0)), h, None, weights=HEAD, seg=8, rings=6, tip=0.04,
                       color_fn=lambda t: L.mix(C("1a2040"), C("bff0ff"), L.smooth(0.4, 1.0, t)),
                       up=V((1, 0, 0)), bend=V((0, 0.18, 0)))
    # Storm-cloud collar round the neck.
    for k in range(7):
        a = math.pi * (0.1 + 0.8 * k / 6)
        d = V((math.cos(a), 0.55 + 0.4 * math.sin(a), -0.15))
        p, n = F.dir_hit(surf, V((0.0, 0.2, 2.15)), d)
        if p is not None:
            puff(parts, p + n * 0.06, 0.22, C("aab4d0"), C("3a4468"), p, n=2, seed=k)
    nostrils(parts, surf, C("0a0814"), z=2.15, x=0.2)
    finish(body, parts, ao=0.45, shade=V((0.5, 0.5, 0.65)))
    return {"glow": "aef4ff", "strength": 1.7}


def cloud_whelp(arm, body):
    """cloud_whelp ลูกมังกรเมฆา (sky isle whelp): a young sky dragon wrapped in cloud. Snow-
    white hide fading to sky blue, little gold nub horns (two pairs), a fluffy cloud
    tuft on the crown and a cloud ruff round the neck, sky-blue wing skin; bright,
    wider eyes (a whelp, still fierce but young)."""
    eyes = prep(body, 4200, sub=True)
    top, mid, belly = C("8ac4ee"), C("f4faff"), C("ffffff")
    horn_root, horn_tip = C("d89a2a"), C("fff2b0")
    paint = hide_paint(top, mid, belly, C("cfe4f6"), C("6fb6ea"), C("e8f6ff"), horn_root, horn_tip, C("3a1a40"),
                       scale_size=0.24)
    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    eyes_(parts, eyes, C("cfe6fa"), C("6a9ac8"), C("eafcff"), open_=0.55, tilt=0.25, slit=(0.12, 0.5), lower=0.35,
          brow_size=0.9, ring=C("3a9ae8"))
    hc = ring_col(horn_root, horn_tip)
    for sx in (-1.0, 1.0):
        for k, (d, ln, r) in enumerate(((V((0.5 * sx, 0.1, 1.0)), 0.36, 0.085), (V((0.85 * sx, 0.35, 0.55)), 0.26, 0.065))):
            p, n = head_point(surf, d)
            if p is not None:
                tube(parts, curve(p, (n + V((0, 0.5, 0.2))).normalized(), ln, n=5, bend=V((0, 1.2, 0.3))),
                     taper(5, r, 0.03, 1.2), hc, HEAD, seg=8)
    # Cloud tuft on the crown and a cloud ruff.
    p, n = head_point(surf, V((0.0, 0.25, 1.0)), sink=-0.02)
    if p is not None:
        puff(parts, p + V((0, 0.05, 0.05)), 0.24, C("ffffff"), C("bcd8f0"), HEAD, n=5, seed=3)
    for k in range(5):
        a = math.pi * (0.05 + 0.9 * k / 4)
        d = V((math.cos(a), 0.65 + 0.35 * math.sin(a), -0.35))
        p, n = F.dir_hit(surf, V((0.0, 0.2, 2.1)), d)
        if p is not None:
            puff(parts, p + n * 0.05, 0.21, C("ffffff"), C("b8d4ee"), p, n=2, seed=10 + k)
    nostrils(parts, surf, C("4a6a90"), z=2.15, x=0.2)
    finish(body, parts, ao=0.4, shade=V((0.6, 0.65, 0.85)))
    return {"glow": "bff0ff", "strength": 1.2}


def leviathan_whelp(arm, body):
    """leviathan_whelp ลูกเลวีอาธานคลั่ง (drowned abyss elite): a sea-serpent whelp, no horns.
    A tall finned crest down the skull and neck, fan ear-fins, jaw barbels, gill slits,
    a ring of extra fangs, deep-sea teal hide with glowing bioluminescent spots, fin-
    ribbed wing skin."""
    eyes = prep(body, 4000, sub=True)
    top, mid, belly = C("1a5a80"), C("34b0cc"), C("cff8ee")
    horn_root, horn_tip = C("4a6a70"), C("f0fff8")

    def sea(name, co, n, info, c):
        if name == "Dragon_Secondary" and info["bone"].startswith("Wing"):
            rib = abs(math.sin((co.y * 1.2 + abs(co.x) * 0.6) * 8.0))
            c = L.mix(C("0e4a6a"), C("5ad8d0"), L.smooth(0.6, 1.5, co.y))
            c = L.mix(c, C("08283c"), L.smooth(0.2, 0.0, rib) * 0.85)
        return c

    paint = hide_paint(top, mid, belly, C("6ab8b0"), C("0e4a6a"), C("5ad8d0"), horn_root, horn_tip, C("1a0420"),
                       scale_size=0.15, extra=sea)
    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    eyes_(parts, eyes, C("16607a"), C("08303e"), C("c8fff0"), open_=0.3, tilt=0.55, slit=(0.07, 0.6))
    fin_col = lambda r, c: L.mix(L.mix(C("1a7a98"), C("8af0e0"), L.smooth(0.3, 1.0, r)), C("0a3048"),  # noqa: E731
                                 L.smooth(0.85, 1.0, abs(math.sin(c * math.pi * 5.0))) * 0.7)
    spine = ring_col(C("0e3a50"), C("d8fff4"))
    # Head crest fin: spines from the brow back over the skull.
    p, n = head_point(surf, V((0.0, -0.1, 1.0)), sink=0.05)
    if p is not None:
        dirs = [V((0, 0.15 + 0.32 * k, 1.0 - 0.14 * k)) for k in range(6)]
        lens = [0.5, 0.75, 0.82, 0.75, 0.6, 0.42]
        fan(parts, p, dirs, lens, fin_col, HEAD, spine_col=spine, spine_r=0.03, normal_hint=V((1, 0, 0)), steps=4)
    # Neck fin continues behind.
    p, n = F.dir_hit(surf, V((0.0, 0.2, 2.2)), V((0, 1.0, 0.1)))
    if p is not None:
        dirs = [V((0, 0.5 + 0.2 * k, 0.6 - 0.35 * k)) for k in range(4)]
        fan(parts, p - n * 0.05, dirs, [0.45, 0.5, 0.42, 0.3], fin_col, p, spine_col=spine, spine_r=0.025,
            normal_hint=V((1, 0, 0)), steps=3)
    for sx in (-1.0, 1.0):
        # Ear fins fanning back from the side of the skull.
        p, n = head_point(surf, V((1.0 * sx, 0.15, 0.25)), sink=0.06)
        if p is not None:
            dirs = [V((0.55 * sx, 0.5 + 0.15 * k, 0.65 - 0.38 * k)) for k in range(5)]
            fan(parts, p, dirs, [0.5, 0.62, 0.66, 0.58, 0.45], fin_col, HEAD, spine_col=spine, spine_r=0.026,
                normal_hint=V((sx, 0, 0)))
        # Barbels from the jaw corners.
        p, n = head_point(surf, V((0.75 * sx, -0.8, -0.55)), sink=0.03)
        if p is not None:
            pts = curve(p, V((0.3 * sx, -0.3, -1.0)), 0.6, n=7, bend=V((0.4 * sx, 0.6, 0.3)))
            tube(parts, pts, taper(7, 0.035, 0.012), lambda t, a: L.mix(C("1a6a80"), C("aaffe8"), t), HEAD, seg=6)
        # Gill slits on the neck.
        for k in range(3):
            p, n = F.dir_hit(surf, V((0.0, 0.0, 2.15 - 0.08 * k)), V((1.0 * sx, 0.35 + 0.15 * k, -0.1)))
            if p is not None:
                parts.stroke(p, n, [(0.0, 0.12), (0.03 * sx, 0.0), (0.0, -0.12)], 0.035, C("06202c"), lift=0.012)
        # Extra fangs along the jaw.
        for k in range(3):
            x = (0.16 + 0.1 * k) * sx
            p, n = F.front_hit(surf, x, 1.9)
            if p is not None:
                K.fang(parts, p + V((0, 0.02, 0.02)), V((0.1 * sx, -0.3, -1.0)), 0.16 - 0.03 * k, 0.03, HEAD)
    # Bioluminescent spots along the sides of the head and neck.
    rng = random.Random(4)
    for k in range(22):
        sx = 1.0 if k % 2 else -1.0
        a = rng.uniform(-0.2, 1.0)
        d = V((sx, a, rng.uniform(-0.6, 0.6)))
        p, n = F.dir_hit(surf, V((0.0, 0.0, 2.35)), d)
        if p is not None and n.dot(V((0, -1, 0))) < 0.6:
            r = rng.uniform(0.025, 0.045)
            parts.decal(p, n, [(math.cos(t) * r, math.sin(t) * r) for t in [i * math.pi / 5 for i in range(10)]],
                        C("c8fff4"), rings=1, lift=0.012, detail="glow")
    nostrils(parts, surf, C("041820"), z=2.15, x=0.2)
    finish(body, parts, ao=0.45, shade=V((0.45, 0.55, 0.65)))
    return {"glow": "7affea", "strength": 1.6}


# ================================================================ flying/Dragon_Evolved (full body)

def _elder_prep(body, tris=4800, drop_fangs=False):
    return prep(body, tris, drop_fangs=drop_fangs)


def fire_dragon(arm, body):
    """Base flying/Dragon_Evolved: fire_dragon (untinted), the elder summon (gold tint).
    A forest-fire guardian: great horns swept back and up past the skull, a crest of
    flame-tongue spines burning from crown to tail, a glowing ember seam down the
    throat and chest, a flame at the tail tip; amber hide with a red crest."""
    eyes = _elder_prep(body, 4900)
    top, mid, belly = C("9a2c14"), C("f2aa4c"), C("fff2b8")
    horn_root, horn_tip = C("3a2a2a"), C("fff0d0")
    paint = hide_paint(top, mid, belly, C("c8782e"), C("8a2a18"), C("ffb050"), horn_root, horn_tip, C("5a0a14"))
    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    eyes_(parts, eyes, C("c85a24"), C("7a2a12"), C("ffe08a"))
    hc = ring_col(horn_root, horn_tip, bands=6)
    for sx in (-1.0, 1.0):
        p, n = head_point(surf, V((0.5 * sx, 0.1, 1.0)))
        if p is not None:
            pts = curve(p, V((0.55 * sx, 0.75, 0.35)), 1.2, n=8, bend=V((0.1 * sx, -0.2, 1.1)))
            tube(parts, pts, taper(8, 0.16, 0.014, 0.9), hc, HEAD, seg=10)
        p, n = head_point(surf, V((1.0 * sx, 0.15, 0.15)))
        if p is not None:
            tube(parts, curve(p, V((0.85 * sx, 0.6, -0.1)), 0.45, n=5, bend=V((0, 0.4, 0.6))), taper(5, 0.07, 0.01),
                 hc, HEAD, seg=8)
    flame = lambda t: L.mix(C("ff5a10"), C("fff0a0"), L.smooth(0.2, 1.0, t))  # noqa: E731
    # Flame crest: wavy flame tongues from the crown down the neck and back.
    for k, (d, s) in enumerate(((V((0, -0.2, 1.0)), 0.8), (V((0, 0.3, 1.0)), 1.1), (V((0, 0.8, 0.8)), 1.15),
                                (V((0, 1.0, 0.4)), 1.0), (V((0.5, 0.4, 0.8)), 0.7), (V((-0.5, 0.4, 0.8)), 0.7))):
        p, n = head_point(surf, d)
        if p is not None:
            parts.blob(p, (0.14 * s, 0.06 * s), (n + V((0, 0.7, 0.25))).normalized(), 0.7 * s, None, weights=HEAD,
                       seg=8, rings=6, tip=0.03, color_fn=flame, detail="glow2", up=V((1, 0, 0)),
                       bend=V((0, 0.12, 0.12 * (1 if k % 2 else -1))))
    spine_row(parts, surf, [(1.35, 0.85), (1.1, 0.75), (0.85, 0.65), (0.6, 0.55), (0.4, 0.45)], flame,
              y_bias=0.3, detail="glow2", sides=7)
    # Tail flame.
    p, n = surf.toward(V((0.0, 4.0, 0.25)), V((0.0, 0.46, 0.3)))
    if p is not None:
        for k in range(3):
            a = (k - 1) * 0.5
            parts.blob(p, (0.1, 0.06), V((math.sin(a) * 0.6, 0.8, 0.7)), 0.45 - 0.08 * abs(k - 1), None, weights=p,
                       seg=8, rings=5, tip=0.03, color_fn=flame, detail="glow2")
    nostrils(parts, surf, C("2a0806"))
    finish(body, parts, shade=V((0.55, 0.42, 0.45)))
    return {"glow": "ffa820", "strength": 1.3, "glow2": "ff7a20", "strength2": 1.1}


def magma_dragon(arm, body):
    """magma_dragon มังกรแมกมาจ้าวภูเขาไฟ (volcano lord): a basalt dragon split by molten
    cracks. Thick obsidian crag horns curling forward like a bull's with glowing tips,
    volcanic boulder plates along the spine and shoulders with lava welling between,
    smoking vents, a molten belly glow."""
    eyes = _elder_prep(body, 4600)
    top, mid, belly = C("1a1414"), C("3a2a26"), C("ff8a2a")
    horn_root, horn_tip = C("120c10"), C("ffb040")

    def lava(name, co, n, info, c):
        if name == "Dragon_Main":
            d0, d1 = K.cells(co, 0.36)
            crack = L.smooth(0.08, 0.0, d1 - d0)
            heat = L.smooth(1.8, 0.6, co.z) * 0.4 + max(0.0, -n.y) * 0.4 + 0.25
            c = L.mix(c, L.mix(C("ff4a10"), C("ffd060"), crack), crack * min(1.0, heat + 0.2))
        if name == "Dragon_Secondary" and info["bone"].startswith("Wing"):
            d0, d1 = K.cells(co, 0.3)
            c = L.mix(C("2a1a18"), C("5a2a1a"), L.smooth(1.6, 2.4, co.z))
            c = L.mix(c, C("ff6a1a"), L.smooth(0.1, 0.0, d1 - d0) * 0.9)
        if name == "Dragon_Secondary" and not info["bone"].startswith("Wing") and info["bone"] != "Head":
            c = L.mix(C("ff7a1a"), C("ffd070"), L.smooth(0.9, 1.4, co.z))
        return c

    paint = hide_paint(top, mid, belly, C("ff5a10"), C("2a1a18"), C("8a3a1a"), horn_root, horn_tip, C("ff4a10"),
                       extra=lava)
    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    eyes_(parts, eyes, C("2a1c1a"), C("120a0a"), C("fff0a0"), open_=0.24, tilt=0.6)
    obs = lambda t, a: L.mix(C("1a1216"), C("4a3a40"), 0.5 + 0.5 * math.sin(a * 2.5)) if t < 0.78 else \
        L.mix(C("ff7a20"), C("fff0a0"), L.smooth(0.78, 1.0, t))  # noqa: E731
    for sx in (-1.0, 1.0):
        # Bull horns: out to the side, then forward and up.
        p, n = head_point(surf, V((0.75 * sx, 0.15, 0.75)))
        if p is not None:
            pts = curve(p, V((1.0 * sx, 0.25, 0.25)), 1.15, n=8, bend=V((-0.25 * sx, -0.9, 0.9)))
            tube(parts, pts, taper(8, 0.15, 0.015, 0.8), obs, HEAD, seg=6)
        # Smoking vents on the shoulders.
        p, n = F.dir_hit(surf, V((0.25 * sx, 0.2, 1.5)), V((0.6 * sx, 0.5, 0.7)))
        if p is not None:
            parts.frustum(p - n * 0.04, n, 0.13, 0.08, 0.16, lambda t, side: C("2a2020") if side else C("ff9a30"), p,
                          seg=8)
            parts.ellipsoid(p + n * 0.15, (0.07, 0.07, 0.03), basis=K.basis(n), color=C("ffe080"), weights=p,
                            detail="glow", seg=8, rings=4)
    # Volcanic boulders along the spine with lava between.
    rng = random.Random(7)
    for z, s in ((2.85, 0.9), (2.55, 1.0), (2.2, 0.9), (1.85, 0.95), (1.5, 1.0), (1.2, 0.85), (0.9, 0.7),
                 (0.6, 0.55)):
        p, n = surf.toward(V((0.0, 5.0, z + 0.2)), V((0.0, 0.0 if z > 1.9 else 0.3, z)))
        if p is None:
            continue
        parts.ellipsoid(p + n * 0.02, (0.11 * s, 0.11 * s, 0.07 * s), basis=K.basis(n), color=C("ff8a20"), weights=p,
                        detail="glow", seg=8, rings=4)
        for j in range(2):
            ax = (n + V(((j - 0.5) * 0.9, 0.2, rng.uniform(-0.2, 0.3)))).normalized()
            parts.blob(p - n * 0.03 + V(((j - 0.5) * 0.12 * s, 0, 0)), (0.13 * s, 0.1 * s), ax, 0.3 * s, None, weights=p,
                       seg=5, rings=3, tip=0.35,
                       color_fn=lambda t: L.mix(C("2a2224"), C("5a4a48"), t))
    # Molten seam down the chest.
    p, n = F.front_hit(surf, 0.0, 1.5)
    if p is not None:
        parts.stroke(p, n, [(0.0, 0.3), (0.05, 0.12), (-0.03, -0.04), (0.04, -0.2), (0.0, -0.36)], 0.08,
                     C("ffd060"), detail="glow", lift=0.012)
    nostrils(parts, surf, C("ff6a10"))
    finish(body, parts, ao=0.4, shade=V((0.6, 0.45, 0.45)))
    return {"glow": "ff8a1a", "strength": 1.8}


def gold_dragon(arm, body):
    """gold_dragon มังกรทองเทพเจ้า (god-dragon boss): radiant gold scales and ivory belly,
    a seven-horned crown fanning above the skull, a sun-jewel set in the brow, long
    flowing eastern whiskers, an ivory mane, gold breast plates and a sun disc of rays
    behind the head."""
    eyes = _elder_prep(body, 4100)
    top, mid, belly = C("c88a10"), C("ffd860"), C("fff6dc")
    horn_root, horn_tip = C("c89020"), C("fffbe8")

    def gold(name, co, n, info, c):
        sheen = max(0.0, n.dot(V((0.3, -0.6, 0.75)).normalized()))
        return L.mix(c, C("fffbe0"), sheen ** 6 * 0.6)

    paint = hide_paint(top, mid, belly, C("e8b040"), C("d89a20"), C("fff0a0"), horn_root, horn_tip, C("6a1020"),
                       extra=gold)
    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    eyes_(parts, eyes, C("d8a030"), C("8a5a10"), C("fff8d0"), open_=0.3, tilt=0.45, ring=C("e04020"))
    hc = ring_col(C("e0a020"), C("fffbe8"), bands=5)
    # Crown: five horns fanning wide above the skull, the middle tallest, the outer
    # pair flaring out and curling up at the tips.
    for k in range(5):
        a = (k - 2) / 2.0
        d = V((0.8 * a, 0.2 + 0.2 * abs(a), 1.0)).normalized()
        p, n = head_point(surf, d)
        if p is None:
            continue
        ln = 1.05 - 0.2 * abs(a)
        pts = curve(p, V((1.7 * a, 0.45, 1.0 - 0.35 * abs(a))), ln, n=7, bend=V((0.3 * a, 0.4, 1.6 * abs(a))))
        tube(parts, pts, taper(7, 0.13 - 0.02 * abs(a), 0.012, 0.9), hc, HEAD, seg=9)
    # Sun disc of rays behind the head.
    centre = V((0.0, 0.45, 2.7))
    for k in range(13):
        a = math.pi * (-0.1 + 1.2 * k / 12)
        d = V((math.cos(a), 0.0, math.sin(a)))
        parts.blob(centre + d * 0.35, (0.07, 0.025), d, 0.42 if k % 2 == 0 else 0.3, None, weights=HEAD, seg=6, rings=4,
                   tip=0.05, color_fn=lambda t: L.mix(C("ffe070"), C("fff8d0"), t), detail="glow", up=V((0, 1, 0)))
    parts.frustum(centre - V((0, 0.03, 0)), V((0, 1, 0)), 0.38, 0.38, 0.05,
                  lambda t, side: C("ffd040") if side else C("fff0a0"), HEAD, seg=28)
    # Brow jewel.
    p, n = F.front_hit(surf, 0.0, 2.62)
    if p is not None:
        parts.ellipsoid(p + n * 0.02, (0.1, 0.1, 0.06), basis=K.basis(n), color=None, weights=HEAD, seg=8, rings=5,
                        color_fn=lambda u: C("ffd040"))
        parts.ellipsoid(p + n * 0.07, (0.07, 0.07, 0.045), basis=K.basis(n), color=None, weights=HEAD, detail="glow2",
                        seg=6, rings=4, color_fn=lambda u: L.mix(C("ff4060"), C("ffd0d8"), L.smooth(0.0, 1.0, u.z)))
    for sx in (-1.0, 1.0):
        # Whiskers: long, drooping and curling back.
        p, n = head_point(surf, V((0.35 * sx, -1.0, -0.2)), sink=0.02)
        if p is not None:
            pts = curve(p, V((0.5 * sx, -0.35, -0.8)), 1.1, n=9, bend=V((0.9 * sx, 1.0, 0.9)))
            tube(parts, pts, taper(9, 0.04, 0.012), lambda t, a: L.mix(C("e8b040"), C("fff8e0"), t), HEAD, seg=6)
        # Ivory mane locks down the neck sides.
        for k in range(3):
            p, n = F.dir_hit(surf, V((0.0, 0.1, 2.35 - 0.2 * k)), V((0.8 * sx, 0.8, 0.0)))
            if p is not None:
                pts = curve(p - n * 0.03, (n + V((0, 0.8, -0.3))).normalized(), 0.55 - 0.08 * k, n=5,
                            bend=V((0.3 * sx, 0.2, -0.6)))
                tube(parts, pts, taper(5, 0.075, 0.012), lambda t, a: L.mix(C("f4e8c8"), C("ffffff"), t), p, seg=7,
                     flat=0.5)
    nostrils(parts, surf, C("6a3a08"))
    finish(body, parts, ao=0.45, shade=V((0.62, 0.5, 0.42)))
    return {"glow": "ffd860", "strength": 1.4, "glow2": "ff3050", "strength2": 1.6}


def abyss_dragon(arm, body):
    """abyss_dragon ราชามังกรอเวจี (king of the abyss, final dragon boss): near-black violet
    hide split by crimson rune cracks, a crown of six bone horns (two great demon horns
    curving forward), four burning eyes, jaw and cheek spikes, bone plates down the
    spine, tattered blood-dark wings."""
    eyes = _elder_prep(body, 3800)
    top, mid, belly = C("120a1c"), C("2e1a3e"), C("5a2a3a")
    horn_root, horn_tip = C("3a2a30"), C("f4ead8")

    def abyss(name, co, n, info, c):
        if name == "Dragon_Main" and not info["bone"].startswith("Wing"):
            d0, d1 = K.cells(co, 0.28)
            c = L.mix(c, C("ff1a3a"), L.smooth(0.07, 0.0, d1 - d0) * 0.75)
        if name == "Dragon_Secondary" and info["bone"].startswith("Wing"):
            rag = K.fbm(co, 0.12, 2)
            c = L.mix(C("1a0a14"), C("6a0a20"), L.smooth(0.6, 1.4, co.y))
            c = L.mix(c, C("060208"), L.smooth(0.2, 0.45, rag))
        return c

    paint = hide_paint(top, mid, belly, C("8a1a2a"), C("2a0a18"), C("6a0a20"), horn_root, horn_tip, C("ff1a3a"),
                       extra=abyss)
    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    eyes_(parts, eyes, C("2a1838"), C("0e0814"), C("ffb0b0"), open_=0.22, tilt=0.65, slit=(0.06, 0.6))
    # Second, smaller pair of burning eyes above the first.
    for c, r in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        c2 = c + V((0.03 * sx, 0.06, 0.3))
        p, n = surf.toward(c2 + V((0.1 * sx, -3.0, 0.0)), c2 + V((0, 0.2, 0)))
        if p is not None:
            K.fierce_eye(parts, p + n * 0.02, r * 0.5, V((0.35 * sx, -1.0, 0.2)), HEAD, C("2a1838"), ball=C("ffb0b0"),
                         slit=(0.08, 0.5), tilt=0.7, open_=0.25)
    bone = ring_col(C("2a1a24"), C("f8f0e0"), bands=8, k=0.75)
    for sx in (-1.0, 1.0):
        # Great demon horns: back, out, then sweeping forward with the tips aimed ahead.
        p, n = head_point(surf, V((0.55 * sx, 0.15, 0.9)))
        if p is not None:
            pts = curve(p, V((0.55 * sx, 0.75, 0.5)), 1.55, n=10, bend=V((0.1 * sx, -0.95, 0.65)))
            tube(parts, pts, taper(10, 0.16, 0.012, 0.85), bone, HEAD, seg=10)
        # Two lesser horns behind, straight back.
        for k, d in enumerate((V((0.3 * sx, 0.6, 0.85)), V((0.85 * sx, 0.6, 0.35)))):
            p, n = head_point(surf, d)
            if p is not None:
                pts = curve(p, V((0.3 * sx, 1.0, 0.25 - 0.2 * k)), 0.7 - 0.12 * k, n=6, bend=V((0, 0.0, 0.4)))
                tube(parts, pts, taper(6, 0.08, 0.01), bone, HEAD, seg=8)
        # Jaw spikes.
        for k in range(3):
            p, n = head_point(surf, V((0.9 * sx, -0.5 + 0.25 * k, -0.6)), sink=0.03)
            if p is not None:
                tube(parts, curve(p, (n + V((0.3 * sx, 0.5, -0.4))).normalized(), 0.28 - 0.05 * k, n=4,
                                  bend=V((0, 0.8, 0))), taper(4, 0.045, 0.008), bone, HEAD, seg=6)
        # Glowing rune strokes on the shoulders.
        p, n = F.dir_hit(surf, V((0.2 * sx, 0.1, 1.45)), V((0.8 * sx, -0.4, 0.4)))
        if p is not None:
            parts.stroke(p, n, [(0.0, 0.15), (0.06 * sx, 0.05), (-0.02 * sx, -0.03), (0.07 * sx, -0.14)], 0.04,
                         C("ff4060"), detail="glow", lift=0.012)
    # Bone plates down the spine.
    spine_row(parts, surf, [(2.9, 0.75), (2.6, 0.85), (2.25, 0.9), (1.9, 0.95), (1.55, 1.0), (1.25, 0.9),
                            (0.95, 0.75), (0.65, 0.6), (0.4, 0.5)],
              lambda t: L.mix(C("3a2a30"), C("f4ead8"), L.smooth(0.0, 0.8, t)), y_bias=0.15, flat=0.25, lean=-0.1)
    # Chest rune.
    p, n = F.front_hit(surf, 0.0, 1.4)
    if p is not None:
        parts.stroke(p, n, [(-0.15, 0.12), (0.0, -0.1), (0.15, 0.12)], 0.05, C("ff3050"), detail="glow", lift=0.012)
        parts.stroke(p + V((0, 0, -0.12)), n, [(0.0, 0.08), (0.0, -0.2)], 0.05, C("ff3050"), detail="glow",
                     lift=0.012)
    nostrils(parts, surf, C("ff1a3a"))
    finish(body, parts, ao=0.4, shade=V((0.55, 0.45, 0.6)))
    return {"glow": "ff2a48", "strength": 1.9}


def _rainbow(co, sat=0.38, val=1.0, shift=0.0):
    h = (co.z * 0.22 + co.x * 0.12 + co.y * 0.1 + shift) % 1.0
    r, g, b = colorsys.hsv_to_rgb(h, sat, val)
    return C((r, g, b))


def prism_dragon(arm, body):
    """prism_dragon มังกรแก้วเจ็ดสี (rare rainbow crystal dragon): a pearly white body whose
    scales shimmer through the seven colours, a crown of cut crystal shards instead of
    horns, crystal clusters on the back, shoulders and tail, a gem in the chest, prism-
    tinted wing skin; glowing crystal tips."""
    eyes = _elder_prep(body, 4300)
    horn_root, horn_tip = C("c8e8ff"), C("ffffff")

    def prism(name, co, n, info):
        if name == "Dragon_Horn":
            return L.mix(C("d0f0ff"), WHITE, L.smooth(-0.02, 0.12, info["bump"]))
        if name == "Dragon_Secondary":
            if info["bone"].startswith("Wing"):
                return L.mix(_rainbow(co, 0.4, 1.0, 0.3), WHITE, 0.25 + L.smooth(1.4, 0.4, co.y) * 0.3)
            if info["bone"] == "Head":
                return C("3a2a6a")
        c = L.mix(C("f4f6ff"), _rainbow(co, 0.22), 0.45)
        c = L.mix(c, C("c8d4f4"), L.smooth(0.2, 0.9, max(0.0, n.y)) * 0.35)
        facet = K.scales(co, 0.24)
        c = L.mix(c, c * 0.8, facet * 0.45)
        sheen = max(0.0, n.dot(V((0.3, -0.6, 0.75)).normalized()))
        return L.mix(c, WHITE, sheen ** 5 * 0.5)

    L.paint_body(body, prism)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    eyes_(parts, eyes, C("dce8ff"), C("9aa8e0"), C("ffffff"), open_=0.32, tilt=0.45, ring=C("8a60ff"))

    def cry(shift):
        return lambda t: L.mix(L.mix(_rainbow(V((0, 0, shift * 4.0)), 0.45, 1.0), C("cdeeff"), 0.45), WHITE,
                               L.smooth(0.45, 1.0, t))

    # Crystal crown: three great cut crystals and two lesser ones flaring out.
    for k in range(5):
        a = (k - 2) / 2.0
        p, n = head_point(surf, V((0.75 * a, 0.2 + 0.1 * abs(a), 1.0)))
        if p is not None:
            big = abs(a) < 0.6
            shard(parts, p, V((0.9 * a, 0.3, 1.0 - 0.3 * abs(a))), (1.05 if k == 2 else 0.8) if big else 0.55,
                  0.15 if big else 0.1, cry(k * 0.15), HEAD)
    for sx in (-1.0, 1.0):
        p, n = head_point(surf, V((1.0 * sx, 0.3, 0.35)))
        if p is not None:
            shard(parts, p, V((0.9 * sx, 0.6, 0.3)), 0.55, 0.08, cry(0.4), HEAD, sides=4)
            shard(parts, p, V((0.7 * sx, 0.8, -0.1)), 0.38, 0.06, cry(0.55), HEAD, sides=4)
        # Shoulder clusters.
        p, n = F.dir_hit(surf, V((0.2 * sx, 0.2, 1.5)), V((0.6 * sx, 0.6, 0.6)))
        if p is not None:
            for j, (d, ln) in enumerate(((V((0.4 * sx, 0.3, 1.0)), 0.5), (V((0.9 * sx, 0.2, 0.5)), 0.35),
                                         (V((0.1 * sx, 0.8, 0.6)), 0.3))):
                shard(parts, p - n * 0.03, d, ln, 0.07, cry(0.2 + 0.2 * j), p, sides=5)
    # Back and tail clusters.
    rng = random.Random(3)
    for k, (z, s) in enumerate(((2.6, 0.8), (2.2, 0.9), (1.8, 1.0), (1.4, 1.0), (1.05, 0.85), (0.7, 0.7),
                                (0.35, 0.8))):
        p, n = surf.toward(V((0.0, 5.0, z + 0.2)), V((0.0, 0.0 if z > 1.9 else 0.3, z)))
        if p is None:
            continue
        for j in range(2 if k < 6 else 3):
            d = (n + V((rng.uniform(-0.6, 0.6), 0.4, rng.uniform(-0.1, 0.5)))).normalized()
            shard(parts, p - n * 0.03, d, 0.42 * s * rng.uniform(0.8, 1.2), 0.075 * s, cry(k * 0.13 + j * 0.3), p,
                  sides=5)
    # Glowing crystal tips: small bright gems at the chest and brow.
    for z, r in ((1.4, 0.1), (2.62, 0.07)):
        p, n = F.front_hit(surf, 0.0, z)
        if p is not None:
            parts.ellipsoid(p + n * 0.03, (r, r, r * 0.6), basis=K.basis(n), color=None, weights=p if z < 2 else HEAD,
                            detail="glow", seg=6, rings=3, color_fn=lambda u: L.mix(C("b0f0ff"), WHITE, u.z * 0.5 + 0.5))
    nostrils(parts, surf, C("8a90c0"))
    finish(body, parts, ao=0.35, shade=V((0.7, 0.68, 0.85)))
    return {"glow": "c8f8ff", "strength": 1.5}


def shrine_dragon(arm, body):
    """shrine_dragon มังกรผู้เฝ้าศาลเทพ (shrine guardian elite): red-lacquer hide and a gold
    belly, branching antler horns banded in gold, a jade mane of curling locks, long
    whiskers, a glowing pearl set in the brow, a gold collar hung with bells."""
    eyes = _elder_prep(body, 3900)
    top, mid, belly = C("8a1a14"), C("dc4630"), C("f2bd48")
    horn_root, horn_tip = C("c89a50"), C("fff0c8")
    paint = hide_paint(top, mid, belly, C("b07a20"), C("8a1a14"), C("f2bd48"), horn_root, horn_tip, C("3a0810"))
    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    eyes_(parts, eyes, C("b0281a"), C("5a0a08"), C("fff0b0"), open_=0.3, tilt=0.5, ring=C("1aa684"))
    antler = lambda t, a: L.mix(C("fff0c8"), C("d8a040"), 0.6) if 0.18 < t < 0.26 else L.mix(  # noqa: E731
        C("c89a50"), C("fff4d8"), t)
    for sx in (-1.0, 1.0):
        # Antlers: a main beam back-and-up with two forward tines.
        p, n = head_point(surf, V((0.45 * sx, 0.1, 1.0)))
        if p is not None:
            pts = curve(p, V((0.3 * sx, 0.55, 0.8)), 1.1, n=8, bend=V((0.15 * sx, 0.3, 0.5)))
            tube(parts, pts, taper(8, 0.085, 0.015), antler, HEAD, seg=8)
            for j, k in enumerate((3, 5)):
                tp = curve(pts[k], V((0.25 * sx, -0.4, 1.0)), 0.42 - 0.1 * j, n=4, bend=V((0, 0.6, 0.3)))
                tube(parts, tp, taper(4, 0.05, 0.01), lambda t, a: L.mix(C("e0b870"), C("fff4d8"), t), HEAD, seg=6)
        # Whiskers.
        p, n = head_point(surf, V((0.3 * sx, -1.0, -0.15)), sink=0.02)
        if p is not None:
            pts = curve(p, V((0.5 * sx, -0.35, -0.8)), 1.0, n=9, bend=V((0.9 * sx, 1.0, 0.9)))
            tube(parts, pts, taper(9, 0.035, 0.012), lambda t, a: L.mix(C("e8c060"), C("fff4d0"), t), HEAD, seg=6)
        # Jade mane: curling locks down the cheeks and neck.
        for k in range(4):
            p, n = F.dir_hit(surf, V((0.0, 0.05, 2.5 - 0.2 * k)), V((0.9 * sx, 0.6, 0.1)))
            if p is not None:
                pts = curve(p - n * 0.03, (n + V((0, 0.7, 0.2))).normalized(), 0.5 - 0.05 * k, n=6,
                            bend=V((0.2 * sx, 0.4, -1.4)))
                tube(parts, pts, taper(6, 0.09, 0.02), lambda t, a: L.mix(C("0b6a54"), C("6af0c0"), t), p, seg=7,
                     flat=0.55)
    p, n = head_point(surf, V((0.0, 0.5, 1.0)))
    if p is not None:
        for k in range(3):
            pts = curve(p, V(((k - 1) * 0.4, 0.7, 0.5)), 0.55, n=6, bend=V((0, 0.4, -1.4)))
            tube(parts, pts, taper(6, 0.1, 0.02), lambda t, a: L.mix(C("0b6a54"), C("6af0c0"), t), HEAD, seg=7,
                 flat=0.55)
    # Brow pearl in a gold setting.
    p, n = F.front_hit(surf, 0.0, 2.62)
    if p is not None:
        parts.ellipsoid(p + n * 0.02, (0.11, 0.11, 0.05), basis=K.basis(n), color=C("e8b040"), weights=HEAD, seg=10,
                        rings=4)
        parts.ellipsoid(p + n * 0.07, (0.075, 0.075, 0.075), color=None, weights=HEAD, detail="glow", seg=8, rings=6,
                        color_fn=lambda u: L.mix(C("e0fff4"), WHITE, u.z * 0.5 + 0.5))
    # Gold collar with bells.
    for k in range(9):
        a = math.pi * (0.0 + 1.0 * k / 8)
        d = V((math.cos(a), -0.7 * math.sin(a), -0.1))
        p, n = F.dir_hit(surf, V((0.0, 0.0, 1.78)), d)
        if p is None:
            continue
        parts.ellipsoid(p + n * 0.01, (0.1, 0.06, 0.05), basis=K.basis(n), color=C("e8b040"), weights=p, seg=8,
                        rings=4)
        if k % 2 == 0 and 1 <= k <= 7:
            parts.ellipsoid(p + n * 0.07 + V((0, 0, -0.09)), (0.06, 0.06, 0.07), color=None, weights=p, seg=8, rings=5,
                            color_fn=lambda u: L.mix(C("a06a10"), C("fff0a0"), L.smooth(-0.6, 0.8, u.z)))
    nostrils(parts, surf, C("3a0806"))
    finish(body, parts, ao=0.45, shade=V((0.58, 0.45, 0.45)))
    return {"glow": "d8fff0", "strength": 1.5}


# ================================================================ registry / runner

RECIPES = {
    "flying/Dragon": sand_dragon,
    "flying/Dragon_storm_dragon": storm_dragon,
    "flying/Dragon_cloud_whelp": cloud_whelp,
    "flying/Dragon_leviathan_whelp": leviathan_whelp,
    "flying/Dragon_Evolved": fire_dragon,
    "flying/Dragon_Evolved_magma_dragon": magma_dragon,
    "flying/Dragon_Evolved_gold_dragon": gold_dragon,
    "flying/Dragon_Evolved_abyss_dragon": abyss_dragon,
    "flying/Dragon_Evolved_prism_dragon": prism_dragon,
    "flying/Dragon_Evolved_shrine_dragon": shrine_dragon,
}


def source(name):
    return "flying/Dragon_Evolved" if name.startswith("flying/Dragon_Evolved") else "flying/Dragon"


def build(name):
    import bpy
    L.reset()
    arm, body = L.load(os.path.join(F.SRC, source(name) + ".gltf"))
    K.atlas_regions(body)
    clips = sorted(a.name for a in bpy.data.actions)
    before = L.tri_count(body)
    opts = RECIPES[name](arm, body) or {}
    out = os.path.join(F.OUT, name + ".glb")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    K.export(arm, body, out, clips, glow=opts.get("glow", "ffc040"), glow2=opts.get("glow2"),
             strength=opts.get("strength", 1.6), strength2=opts.get("strength2", 1.6))
    lo, hi = L.bounds(body)
    print("REMASTER %s tris %d -> %d, %d bytes, bounds z %.2f..%.2f y %.2f..%.2f, clips %s" % (
        name, before, L.tri_count(body), os.path.getsize(out), lo.z, hi.z, lo.y, hi.y, ",".join(clips)))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    for name in (args or list(RECIPES)):
        build(name)
