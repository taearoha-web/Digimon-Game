"""Team skyeclipse's helpers (sky citadel and eclipse realm, star 100-200 monsters).

Built on remaster_lib + kit_critters' material set (Skin / Detail tinted, Keep / KeepDetail
untinted, KeepGlow unlit). Adds:
  load_rig      imports a .glb rig, turns bone-parented props (helmet, hat, hood, cape)
                into skinned parts, tags every source mesh by its part name, joins them;
  tex_class     sorts a KayKit atlas colour into bone / metal / cloth / leather / dark;
  ring, hood, wing, plume, cloud ... procedural parts for halos, cowls, feathered wings.
"""
import colorsys
import math

import bpy
from mathutils import Matrix, Vector

import remaster_lib as L
import kit_critters as K

C = L.srgb
V = Vector


def D(hex_or_tuple, gamma=0.5):
    """A colour as it should SHOW in game (lifts dark mid-tones, see recipes_critters.D)."""
    c = L.srgb(hex_or_tuple)
    return V((c.x ** gamma, c.y ** gamma, c.z ** gamma))


# ---------------------------------------------------------------- loading

def load_rig(path, drop=()):
    """Imports a rig; meshes parented to a bone become skinned to it; each source mesh's
    faces get a material named after its part (the text after the rig's prefix, e.g.
    "Helmet") so paint() can tell them apart. Meshes whose part is in `drop` are removed.
    Returns (armature, body)."""
    bpy.ops.import_scene.gltf(filepath=path, disable_bone_shape=True)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    meshes = []
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            continue
        if o.parent != arm:
            bpy.data.objects.remove(o)
            continue
        part = o.name.split("_")[-1] if "_" in o.name else o.name
        if part in drop:
            bpy.data.objects.remove(o)
            continue
        if o.parent_type == "BONE":
            mw = o.matrix_world.copy()
            bone = o.parent_bone
            o.parent = None
            o.data.transform(mw)
            o.matrix_world = Matrix.Identity(4)
            g = o.vertex_groups.new(name=bone)
            g.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
            o.parent = arm
            o.parent_type = "OBJECT"
            o.matrix_parent_inverse = Matrix.Identity(4)
            mod = o.modifiers.new("Armature", "ARMATURE")
            mod.object = arm
        tex_mat = o.data.materials[0] if o.data.materials else None
        tag = bpy.data.materials.new(part)
        if tex_mat is not None and tex_mat.name == "Glow":
            tag.name = "Eyes"
        o.data.materials.clear()
        o.data.materials.append(tag)
        meshes.append(o)
    body = meshes[0]
    if len(meshes) > 1:
        with L._ctx(body, meshes):
            bpy.ops.object.join()
    body.name = "Model"
    return arm, body


def tex_class(c):
    """A KayKit atlas colour (linear) -> (kind, value): kind in bone / metal / cloth /
    leather / dark, value its brightness (keeps the atlas' painted shading)."""
    s = V([x ** (1 / 2.2) for x in c])
    h, sat, val = colorsys.rgb_to_hsv(s.x, s.y, s.z)
    if val < 0.25:
        return "dark", val
    if sat < 0.09:
        return "metal", val
    if h > 0.75 or h < 0.02 and s.z > s.y:
        return "cloth", val
    if sat < 0.22 and val > 0.82:
        return "bone", val
    if val > 0.86:
        return "bone", val
    return "leather", val


# ---------------------------------------------------------------- parts

def ring(parts, center, axis, radius, thick, color, weights, seg=32, tube=6, flat=1.0, color_fn=None):
    """A torus (halo, circlet, eclipse corona). flat squashes the tube along the axis."""
    t_, b_, n_ = L.frame(axis)
    cos, cols = [], []
    for i in range(seg):
        a = 2.0 * math.pi * i / seg
        rdir = t_ * math.cos(a) + b_ * math.sin(a)
        for j in range(tube):
            b = 2.0 * math.pi * j / tube
            p = center + rdir * (radius + math.cos(b) * thick) + n_ * (math.sin(b) * thick * flat)
            cos.append(p)
            cols.append(color_fn(i / seg, math.sin(b)) if color_fn else color)
    faces = []
    for i in range(seg):
        for j in range(tube):
            a0 = i * tube + j
            a1 = i * tube + (j + 1) % tube
            b0 = ((i + 1) % seg) * tube + j
            b1 = ((i + 1) % seg) * tube + (j + 1) % tube
            faces.append((a0, b0, b1, a1))
    return parts._add(cos, faces, lambda k: cols[k], weights, False)


def shell(parts, center, radii, color_fn, weights, open_dir=None, open_angle=0.0, thick=0.04, seg=20, rings=12,
          peak=0.0, basis=Matrix.Identity(3)):
    """A two-sided ellipsoid shell (hood, cowl) with a clean round opening of open_angle
    (radians, half-angle) around open_dir (the face hole), its rim closed. peak pulls the
    top up and back into a point (a pointed hood). color_fn(u unit dir, outside) -> colour."""
    n_ = (open_dir if open_dir is not None else V((0, 0, -1))).normalized()
    t_, b_, _n = L.frame(n_)
    th0 = open_angle if open_dir is not None else 0.0
    cos, cols = [], []
    for side in (1, 0):
        for r in range(rings + 1):
            th = th0 + (math.pi - th0) * r / rings
            for s_ in range(seg):
                ph = 2.0 * math.pi * s_ / seg
                u = n_ * math.cos(th) + (t_ * math.cos(ph) + b_ * math.sin(ph)) * math.sin(th)
                k = 1.0 if side else 1.0 - thick / max(radii)
                p = V((u.x * radii[0], u.y * radii[1], u.z * radii[2])) * k
                if peak and u.z > 0:
                    p.z += peak * u.z ** 3 * k
                    p.y += peak * 0.35 * u.z ** 3
                cos.append(center + basis @ p)
                cols.append(color_fn(u, bool(side)))
    per = (rings + 1) * seg
    faces = []
    for side in (1, 0):
        base = 0 if side else per
        for r in range(rings):
            for s_ in range(seg):
                a = base + r * seg + s_
                b = base + r * seg + (s_ + 1) % seg
                quad = (a, b, b + seg, a + seg)
                faces.append(tuple(reversed(quad)) if side else quad)
    if open_dir is not None:
        for s_ in range(seg):
            a, b = s_, (s_ + 1) % seg
            faces.append((b, b + per, a + per, a))
    return parts._add(cos, faces, lambda i: cols[i], weights, False)


def feather(parts, root, direction, length, width, weights, c0, c1, up, tip=0.3, bend=None, thick=0.25, seg=6):
    """One flat, rounded feather (wing / plume / tail)."""
    return parts.blob(root, (width, width * thick), direction, length, None, weights=weights, seg=seg, rings=5,
                      tip=tip, bend=bend, color_fn=lambda a: L.mix(c0, c1, L.smooth(0.1, 1.0, a)), up=up)


def wing(parts, root, side, span, weights, c_root, c_tip, rows=(7, 6, 5), lift=0.5, back=0.4, droop=0.0,
         scale=1.0, accent=None, accent_rows=(0,)):
    """A folded-up feathered wing on the creature's back. side +1 = its left (+X). The
    wing's leading edge runs out and up from root; rows of feathers hang from it,
    longest at the tip (primaries) -> shortest (coverts) on top."""
    out = V((side, back, lift)).normalized()
    tip_pt = root + out * span
    for r, n in enumerate(rows):
        k = 1.0 - r * 0.28
        for i in range(n):
            t = (i + 0.5) / n
            base = root.lerp(tip_pt, 0.12 + 0.88 * t) + V((0, 0.03 * r, 0.05 * r))
            # Feathers sweep out and down; outermost point further out.
            d = V((side * (0.25 + 0.9 * t), 0.25 + 0.15 * t, -1.0 + 0.55 * t + droop)).normalized()
            length = span * (0.45 + 0.55 * t) * k * scale
            w = span * 0.075 * (1.0 + 0.3 * t) * k
            c1 = accent if (accent is not None and r in accent_rows) else c_tip
            feather(parts, base, d, length, w, weights, c_root, c1, up=V((0, 1, 0)), tip=0.35,
                    bend=V((side * 0.1, 0.05, 0.05)) * length)
    # The bony leading edge (arm of the wing), a soft rounded bar.
    parts.blob(root, (span * 0.07, span * 0.06), out, span * 1.02, None, weights=weights, seg=10, rings=6, tip=0.45,
               color_fn=lambda a: L.mix(c_root, c_root.lerp(c_tip, 0.4), a))


def cloud(parts, center, size, weights, top, bottom, n=7, seed=1, flat=0.7, spread=1.0):
    """A cartoon cloud: overlapping puffs, light on top, shaded underneath."""
    import random
    rng = random.Random(seed)
    for i in range(n):
        a = 2.0 * math.pi * i / n + rng.uniform(-0.3, 0.3)
        r = size * spread * (0.55 if i else 0.0) * rng.uniform(0.8, 1.1)
        c = center + V((math.cos(a) * r, math.sin(a) * r * 0.6, rng.uniform(-0.1, 0.25) * size))
        rad = size * rng.uniform(0.45, 0.62) * (1.25 if i == 0 else 1.0)
        parts.ellipsoid(c, (rad, rad * 0.9, rad * flat), color=None, weights=weights, seg=10, rings=6,
                        color_fn=lambda u: L.mix(bottom, top, L.smooth(-0.6, 0.6, u.z)))


def star_shape(n=5, r_out=1.0, r_in=0.45, rot=0.0):
    pts = []
    for i in range(n * 2):
        a = math.pi * 0.5 + rot + math.pi * i / n
        r = r_out if i % 2 == 0 else r_in
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts


def crescent(parts, center, normal, up, radius, width, weights, color_fn, arc=150.0, seg=18, thick=0.05):
    """A flat crescent moon facing `normal`, horns pointing `up`: outer arc of `radius`,
    fattest (width x radius) at the bottom, tapering to points at the horns.
    color_fn(t along 0..1, k 0 outer / 1 inner) -> colour."""
    t_, b_, n_ = L.frame(normal, up)
    cos, cols, faces = [], [], []
    A = math.radians(arc)
    for side in (0, 1):
        for i in range(seg + 1):
            t = i / seg
            a = -math.pi * 0.5 + (t * 2.0 - 1.0) * A
            w = width * math.cos((t * 2.0 - 1.0) * math.pi * 0.5) ** 0.8
            outer = V((math.cos(a), math.sin(a))) * radius
            inner = outer * (1.0 - w) + V((0.0, w * radius * 0.35))
            for k, q in enumerate((outer, inner)):
                p = center + t_ * q.x + b_ * q.y + n_ * (thick * (0.5 if side else -0.5))
                cos.append(p)
                cols.append(color_fn(t, k))
    n2 = 2 * (seg + 1)
    for i in range(seg):
        a, b, c, d = 2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2
        faces.append((a, b, c, d))
        faces.append((n2 + d, n2 + c, n2 + b, n2 + a))
        faces.append((a, d, n2 + d, n2 + a))
        faces.append((b, n2 + b, n2 + c, c))
    return parts._add(cos, faces, lambda i: cols[i], weights, False)


def recolor_eyes(obj, color_fn):
    """Recolours the source's glowing eye faces (part "Eyes") and puts them on KeepGlow."""
    me = obj.data
    attr = me.color_attributes["Col"]
    for p in me.polygons:
        if p.material_index == K.MODES["glow"]:
            for li in p.loop_indices:
                c = color_fn(me.vertices[me.loops[li].vertex_index].co)
                attr.data[li].color = (c[0], c[1], c[2], 1.0)
