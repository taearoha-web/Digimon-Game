"""Rig a baked, height-normalised humanoid god and write a skinned, animated glb.
usage: build_rig.py baked.glb spec.json out.glb"""
import sys, json, io, math, struct
import numpy as np, trimesh
from scipy.sparse import coo_matrix

src, specf, dst = sys.argv[1], sys.argv[2], sys.argv[3]
spec = json.load(open(specf))
s = trimesh.load(src); m = list(s.geometry.values())[0]
V = m.vertices.astype(np.float64); F = m.faces.astype(np.int64); UV = m.visual.uv.astype(np.float64)
N = m.vertex_normals.astype(np.float64)
J = {k: np.array(v, float) for k, v in spec["joints"].items()}

# ---------------- skeleton (rest rotations are identity: authoring in world axes) -------------
# name, parent, head joint, tail point (for the skin segment)
def tip(a, b, k=0.5): return J[a] + (J[a] - J[b]) * k
BONES = [
    ("Root", None, np.zeros(3), None),
    ("Hips", "Root", J["hips"], J["spine"]),
    ("Spine", "Hips", J["spine"], J["chest"]),
    ("Chest", "Spine", J["chest"], J["neck"]),
    ("Neck", "Chest", J["neck"], J["head"]),
    ("Head", "Neck", J["head"], J["head"] + np.array([0, spec.get("head_len", 0.13), 0])),
]
for s_ in ("R", "L"):
    BONES += [
        (f"{s_}_UpperArm", "Chest", J[f"{s_}_shoulder"], J[f"{s_}_elbow"]),
        (f"{s_}_Forearm", f"{s_}_UpperArm", J[f"{s_}_elbow"], J[f"{s_}_hand"]),
        (f"{s_}_Hand", f"{s_}_Forearm", J[f"{s_}_hand"], tip(f"{s_}_hand", f"{s_}_elbow", 0.35)),
        (f"{s_}_Thigh", "Hips", J[f"{s_}_hip"], J[f"{s_}_knee"]),
        (f"{s_}_Shin", f"{s_}_Thigh", J[f"{s_}_knee"], J[f"{s_}_ankle"]),
        (f"{s_}_Foot", f"{s_}_Shin", J[f"{s_}_ankle"], J[f"{s_}_ankle"] + np.array([0, -0.05, 0.08])),
    ]
names = [b[0] for b in BONES]; index = {n: i for i, n in enumerate(names)}
heads = np.array([b[2] for b in BONES])

# ---------------- skin weights -------------------------------------------------------------
def seg_dist(P, a, b):
    ab = b - a; t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)
skinned = [i for i, b in enumerate(BONES) if b[3] is not None]
D = np.stack([seg_dist(V, BONES[i][2], BONES[i][3]) for i in skinned], 1)
W = 1.0 / (D ** 2 + 1e-4) ** 2
# keep the four strongest
order = np.argsort(-W, 1)[:, :4]
Wk = np.take_along_axis(W, order, 1); Wk /= Wk.sum(1, keepdims=True)
full = np.zeros((len(V), len(BONES)))
for c in range(4):
    full[np.arange(len(V)), np.array(skinned)[order[:, c]]] += Wk[:, c]
# smooth over the mesh so cloth bends instead of tearing
rows = np.concatenate([F[:, 0], F[:, 1], F[:, 2], F[:, 1], F[:, 2], F[:, 0]])
cols = np.concatenate([F[:, 1], F[:, 2], F[:, 0], F[:, 0], F[:, 1], F[:, 2]])
A = coo_matrix((np.ones(len(rows)), (rows, cols)), shape=(len(V), len(V))).tocsr()
A.data[:] = 1.0
deg = np.asarray(A.sum(1)).ravel() + 1e-9
for _ in range(int(spec.get("smooth", 8))):
    full = 0.5 * full + 0.5 * (A @ full) / deg[:, None]
# the weapon is rigid in the right hand
wp = spec["weapon"]; a, b = np.array(wp["top"]), np.array(wp["bottom"])
wd = seg_dist(V, a, b)
ab = b - a; tt = np.clip(((V - a) @ ab) / (ab @ ab), 0, 1)
rad = np.where(tt < wp.get("head_frac", 0.18), wp.get("head_radius", 0.07), wp["radius"])
weapon = wd < rad
full[weapon] = 0; full[weapon, index[spec.get("weapon_bone", "Chest")]] = 1.0
# smooth again so the weapon edge blends into the cloth around it
for _ in range(3):
    full = 0.5 * full + 0.5 * (A @ full) / deg[:, None]
print("weapon verts", int(weapon.sum()), "of", len(V))
# top four again, normalised
order = np.argsort(-full, 1)[:, :4]
WW = np.take_along_axis(full, order, 1); WW = np.where(WW < 0.02, 0, WW); WW /= WW.sum(1, keepdims=True)
JJ = order.astype(np.uint16)

# ---------------- animation authoring ------------------------------------------------------
def q_axis(axis, deg):
    ax = np.array(axis, float); ax /= np.linalg.norm(ax); h = math.radians(deg) / 2
    return np.array([*(ax * math.sin(h)), math.cos(h)])
def q_mul(a, b):
    x1, y1, z1, w1 = a; x2, y2, z2, w2 = b
    return np.array([w1*x2 + x1*w2 + y1*z2 - z1*y2, w1*y2 - x1*z2 + y1*w2 + z1*x2, w1*z2 + x1*y2 - y1*x2 + z1*w2, w1*w2 - x1*x2 - y1*y2 - z1*z2])
def q_euler(x=0, y=0, z=0):  # degrees, applied X then Y then Z in world-ish axes
    return q_mul(q_axis([0, 0, 1], z), q_mul(q_axis([0, 1, 0], y), q_axis([1, 0, 0], x)))

clips = {}
def clip(name, length, loop, fps=30):
    clips[name] = {"length": length, "loop": loop, "fps": fps, "rot": {}, "tr": {}}
    return clips[name]
def sample(c, bone, fn):
    n = int(round(c["length"] * c["fps"])) + 1
    ts = np.linspace(0, c["length"], n)
    c["rot"][bone] = (ts, np.array([fn(t / c["length"]) for t in ts]))
def sample_tr(c, bone, fn):
    n = int(round(c["length"] * c["fps"])) + 1
    ts = np.linspace(0, c["length"], n)
    c["tr"][bone] = (ts, np.array([fn(t / c["length"]) for t in ts]))
def ease(x): return x * x * (3 - 2 * x)
def keys(points):  # [(u, value), ...] -> piecewise smooth function
    def f(u):
        for (u0, v0), (u1, v1) in zip(points, points[1:]):
            if u <= u1:
                k = ease((u - u0) / max(u1 - u0, 1e-9)); return np.array(v0) * (1 - k) + np.array(v1) * k
        return np.array(points[-1][1])
    return f
TAU = 2 * math.pi
st = spec["style"]  # "trident" or "staff"
hips = J["hips"]

# The models are one fused surface (cloth, ribbons and weapon touch everywhere), so the
# motion is carried by the body as a whole: hover, lean, twist and breathe, a free arm
# that gestures and a head that looks around. Nothing pulls the weapon away from the cloth.
# Idle: hover, breathing, a slow look around, the free arm sways.
c = clip("Idle", 3.2, True)
sample_tr(c, "Hips", lambda u: hips + np.array([0, 0.014 * math.sin(u * TAU), 0]))
sample(c, "Hips", lambda u: q_euler(y=2.0 * math.sin(u * TAU * 0.5), z=0.8 * math.sin(u * TAU)))
sample(c, "Spine", lambda u: q_euler(x=1.2 * math.sin(u * TAU)))
sample(c, "Chest", lambda u: q_euler(x=1.5 * math.sin(u * TAU + 0.6)))
sample(c, "Head", lambda u: q_euler(x=-2.0 * math.sin(u * TAU + 1.0), y=7.0 * math.sin(u * TAU * 0.5)))
sample(c, "L_UpperArm", lambda u: q_euler(x=-4.0 * math.sin(u * TAU + 0.4), z=3.0 * math.sin(u * TAU)))
sample(c, "R_UpperArm", lambda u: q_euler(x=-1.0 * math.sin(u * TAU + 0.9)))

# Walk / Run: a god glides, leaning into the motion and swaying.
for name, length, amp in (("Walk", 1.4, 1.0), ("Run", 1.0, 1.6)):
    c = clip(name, length, True)
    sample_tr(c, "Hips", lambda u, a=amp: hips + np.array([0, 0.02 + 0.010 * a * math.sin(u * TAU * 2), 0]))
    sample(c, "Hips", lambda u, a=amp: q_euler(x=5 * a, y=3 * math.sin(u * TAU), z=1.5 * math.sin(u * TAU)))
    sample(c, "Chest", lambda u, a=amp: q_euler(x=1.5 * a, y=-2 * math.sin(u * TAU)))
    sample(c, "Head", lambda u, a=amp: q_euler(x=-4 * a))
    sample(c, "L_UpperArm", lambda u, a=amp: q_euler(x=-6 * a * math.sin(u * TAU), z=4 * a))

# Attack: gather (lean back, rise, free arm lifts), then a forward surge with the weapon.
c = clip("Attack", 0.8, False)
sample(c, "Hips", lambda u: (lambda k: q_euler(x=k[0], y=k[1]))(keys([(0, [0, 0]), (0.38, [-7, 10]), (0.55, [13, -6]), (0.8, [5, -2]), (1, [0, 0])])(u)))
sample_tr(c, "Hips", lambda u: hips + np.array([0, keys([(0, 0), (0.38, 0.035), (0.55, -0.01), (1, 0)])(u), keys([(0, 0), (0.38, -0.02), (0.55, 0.06), (1, 0)])(u)]))
sample(c, "Chest", lambda u: q_euler(x=keys([(0, 0), (0.38, -3), (0.55, 4), (1, 0)])(u)))
sample(c, "Head", lambda u: q_euler(x=keys([(0, 0), (0.38, -6), (0.55, 6), (1, 0)])(u)))
sample(c, "L_UpperArm", lambda u: (lambda k: q_euler(x=k[0], z=k[1]))(keys([(0, [0, 0]), (0.38, [-25, 30]), (0.55, [-45, 10]), (1, [0, 0])])(u)))
sample(c, "L_Forearm", lambda u: q_euler(x=keys([(0, 0), (0.38, -15), (0.55, -5), (1, 0)])(u)))
sample(c, "R_UpperArm", lambda u: q_euler(x=keys([(0, 0), (0.38, 3), (0.55, -6), (1, 0)])(u)))

# Hit: rock back and recover.
c = clip("HitReact", 0.45, False)
sample(c, "Hips", lambda u: q_euler(x=keys([(0, 0), (0.25, -8), (1, 0)])(u)))
sample(c, "Head", lambda u: q_euler(x=keys([(0, 0), (0.25, -8), (1, 0)])(u)))
sample_tr(c, "Hips", lambda u: hips + np.array([0, 0, keys([(0, 0), (0.25, -0.03), (1, 0)])(u)]))

# Death: sink and fade back.
c = clip("Death", 1.2, False)
sample(c, "Hips", lambda u: q_euler(x=keys([(0, 0), (1, -25)])(u)))
sample_tr(c, "Hips", lambda u: hips + np.array([0, keys([(0, 0), (1, -0.2)])(u), keys([(0, 0), (1, -0.08)])(u)]))

# ---------------- glTF writer ---------------------------------------------------------------
buf = bytearray(); views = []; accs = []
def add(arr, target=None, comp=5126, kind="VEC3", minmax=False, norm=False):
    arr = np.ascontiguousarray(arr)
    while len(buf) % 4: buf.append(0)
    off = len(buf); data = arr.tobytes(); buf.extend(data)
    v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
    if target: v["target"] = target
    views.append(v)
    a = {"bufferView": len(views) - 1, "componentType": comp, "count": int(arr.shape[0]), "type": kind}
    if norm: a["normalized"] = True
    if minmax:
        a["min"] = np.atleast_1d(arr.min(0)).astype(float).tolist(); a["max"] = np.atleast_1d(arr.max(0)).astype(float).tolist()
    accs.append(a); return len(accs) - 1
pos = add(V.astype(np.float32), 34962, minmax=True)
nor = add(N.astype(np.float32), 34962)
uvv = UV.copy(); uvv[:, 1] = 1 - uvv[:, 1]
tex = add(uvv.astype(np.float32), 34962, kind="VEC2")
jnt = add(JJ, 34962, comp=5123, kind="VEC4")
wgt = add(WW.astype(np.float32), 34962, kind="VEC4")
ind = add(F.astype(np.uint32).ravel(), 34963, comp=5125, kind="SCALAR")
img = m.visual.material.baseColorTexture.convert("RGB")
bio = io.BytesIO(); img.save(bio, "JPEG", quality=int(spec.get("jpeg", 88))); jb = bio.getvalue()
while len(buf) % 4: buf.append(0)
views.append({"buffer": 0, "byteOffset": len(buf), "byteLength": len(jb)}); buf.extend(jb); imgview = len(views) - 1
# nodes: 0 = mesh node, 1.. = bones
nodes = [{"name": spec["name"], "mesh": 0, "skin": 0}]
bone_node = {}
for i, (n, p, h, _) in enumerate(BONES):
    local = h - (BONES[index[p]][2] if p else np.zeros(3))
    nodes.append({"name": n, "translation": local.tolist()}); bone_node[n] = len(nodes) - 1
for i, (n, p, h, _) in enumerate(BONES):
    if p: nodes[bone_node[p]].setdefault("children", []).append(bone_node[n])
ibm = np.zeros((len(BONES), 4, 4), np.float32)
for i, b in enumerate(BONES):
    M = np.eye(4); M[:3, 3] = -b[2]; ibm[i] = M.T  # column-major
ibm_acc = add(ibm.reshape(len(BONES), 16), kind="MAT4")
anims = []
for cname, c in clips.items():
    samplers = []; channels = []
    for bone, (ts, qs) in c["rot"].items():
        ta = add(ts.astype(np.float32), minmax=True, kind="SCALAR"); qa = add(np.array(qs, np.float32), kind="VEC4")
        samplers.append({"input": ta, "output": qa, "interpolation": "LINEAR"}); channels.append({"sampler": len(samplers) - 1, "target": {"node": bone_node[bone], "path": "rotation"}})
    for bone, (ts, vs) in c["tr"].items():
        ta = add(ts.astype(np.float32), minmax=True, kind="SCALAR"); va = add(np.array(vs, np.float32), kind="VEC3")
        samplers.append({"input": ta, "output": va, "interpolation": "LINEAR"}); channels.append({"sampler": len(samplers) - 1, "target": {"node": bone_node[bone], "path": "translation"}})
    anims.append({"name": cname, "samplers": samplers, "channels": channels})
gl = {
    "asset": {"version": "2.0", "generator": "toon-tale build_rig.py"},
    "scene": 0, "scenes": [{"nodes": [0, bone_node["Root"]]}], "nodes": nodes,
    "meshes": [{"name": spec["name"], "primitives": [{"attributes": {"POSITION": pos, "NORMAL": nor, "TEXCOORD_0": tex, "JOINTS_0": jnt, "WEIGHTS_0": wgt}, "indices": ind, "material": 0}]}],
    "materials": [{"name": spec["name"], "doubleSided": True, "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 0.85}}],
    "textures": [{"source": 0, "sampler": 0}], "samplers": [{"magFilter": 9729, "minFilter": 9987}],
    "images": [{"bufferView": imgview, "mimeType": "image/jpeg"}],
    "skins": [{"joints": [bone_node[n] for n in names], "inverseBindMatrices": ibm_acc, "skeleton": bone_node["Root"]}],
    "animations": anims, "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(buf)}],
}
js = json.dumps(gl, separators=(",", ":")).encode()
while len(js) % 4: js += b" "
while len(buf) % 4: buf.append(0)
out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(buf)) + struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(buf), 0x004E4942) + bytes(buf)
open(dst, "wb").write(out)
print("wrote", dst, len(out), "bytes", len(V), "verts", len(F), "tris", list(clips))
