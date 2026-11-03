"""Re-author the clips of a shipped legend summon (no 18 MB source needed).
usage: rerig_legend.py assets/models/monsters/summon/WindKing.glb tools/rig/windking.json [report.json]

Reads the mesh and texture from the glb build_rig.py wrote, cuts the welded parts apart
and recomputes the skin weights (legend_weights.compute), rebuilds the skeleton from the
spec (with its secondary chains) and the animations (legend_clips.author), runs the
stretch check, then writes the glb back in place. The rig check result is merged into
the report file. Running it again on its own output gives the same rig: the seam copies
weld back together before the parts are cut.
"""
import sys, json, struct, io, os
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import legend_clips as lc
import legend_weights as lw

src, specf = sys.argv[1], sys.argv[2]
report_path = sys.argv[3] if len(sys.argv) > 3 else None
spec = json.load(open(specf))
raw = open(src, "rb").read()
assert raw[:4] == b"glTF"
jlen = struct.unpack_from("<I", raw, 12)[0]
gl = json.loads(raw[20:20 + jlen])
blen = struct.unpack_from("<I", raw, 20 + jlen)[0]
bin0 = raw[28 + jlen:28 + jlen + blen]

CT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read(acc_i):
    a = gl["accessors"][acc_i]
    v = gl["bufferViews"][a["bufferView"]]
    off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    n = a["count"] * NC[a["type"]]
    arr = np.frombuffer(bin0, CT[a["componentType"]], n, off)
    return arr.reshape(a["count"], NC[a["type"]]) if NC[a["type"]] > 1 else arr


prim = gl["meshes"][0]["primitives"][0]
V = read(prim["attributes"]["POSITION"]).astype(np.float64)
N = read(prim["attributes"]["NORMAL"]).astype(np.float32)
UV = read(prim["attributes"]["TEXCOORD_0"]).astype(np.float32)
JJ = read(prim["attributes"]["JOINTS_0"]).astype(np.uint16)
WW = read(prim["attributes"]["WEIGHTS_0"]).astype(np.float32)
F = read(prim["indices"]).astype(np.uint32).reshape(-1, 3)
imgv = gl["bufferViews"][gl["images"][0]["bufferView"]]
jb = bin0[imgv["byteOffset"]:imgv["byteOffset"] + imgv["byteLength"]]

# Skeleton from the spec (the core bones build_rig.py made, plus the secondary chains).
bones = [(b[0], b[1], np.array(b[2], float)) for b in lw.bones_of(spec)]
names = [b[0] for b in bones]
old_heads = {}
nodes = gl["nodes"]
parent_of = {ch: i for i, n in enumerate(nodes) for ch in n.get("children", [])}
for j in gl["skins"][0]["joints"]:
    h, p = np.zeros(3), j
    while p is not None:
        h += np.array(nodes[p].get("translation", [0, 0, 0]), float)
        p = parent_of.get(p)
    old_heads[nodes[j]["name"]] = h
drift = max(float(np.abs(old_heads[n] - h).max()) for n, _, h in bones if n in old_heads)
assert drift < 1e-3, "the glb skeleton does not match the spec joints (%.4f)" % drift

# Parts, seams and skin weights from the mesh and the spec. Seam vertices are doubled
# (one copy per side), so positions, normals and UVs are re-indexed through r["src"].
r = lw.compute(V, F, spec)
V, N, UV = V[r["src"]], N[r["src"]], UV[r["src"]]
F, JJ, WW = r["F"], r["J"], r["W"]
print(spec["name"], "seams", r["seams"], "verts", len(V), "weapon verts", int(r["weapon"].sum()))
clips = lc.author(spec["style"], [(b[0], b[1], b[2]) for b in bones], spec)
report = lc.check_stretch(V, F.astype(np.int64), JJ, WW, bones, clips, float(spec.get("height_m", 3.5)))
print(spec["name"], "stretch:", json.dumps(report))

# ---------------- glTF writer (same layout build_rig.py uses) ----------------
buf = bytearray()
views = []
accs = []


def add(arr, target=None, comp=5126, kind="VEC3", minmax=False):
    arr = np.ascontiguousarray(arr)
    while len(buf) % 4:
        buf.append(0)
    off = len(buf)
    data = arr.tobytes()
    buf.extend(data)
    v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
    if target:
        v["target"] = target
    views.append(v)
    a = {"bufferView": len(views) - 1, "componentType": comp, "count": int(arr.shape[0]), "type": kind}
    if minmax:
        a["min"] = np.atleast_1d(arr.min(0)).astype(float).tolist()
        a["max"] = np.atleast_1d(arr.max(0)).astype(float).tolist()
    accs.append(a)
    return len(accs) - 1


pos = add(V.astype(np.float32), 34962, minmax=True)
nor = add(N, 34962)
tex = add(UV, 34962, kind="VEC2")
jnt = add(JJ, 34962, comp=5123, kind="VEC4")
wgt = add(WW, 34962, kind="VEC4")
ind = add(F.ravel(), 34963, comp=5125, kind="SCALAR")
while len(buf) % 4:
    buf.append(0)
views.append({"buffer": 0, "byteOffset": len(buf), "byteLength": len(jb)})
buf.extend(jb)
imgview = len(views) - 1
out_nodes = [{"name": spec["name"], "mesh": 0, "skin": 0}]
bone_node = {}
for name, parent, head in bones:
    local = head - (bones[names.index(parent)][2] if parent else np.zeros(3))
    out_nodes.append({"name": name, "translation": local.tolist()})
    bone_node[name] = len(out_nodes) - 1
for name, parent, head in bones:
    if parent:
        out_nodes[bone_node[parent]].setdefault("children", []).append(bone_node[name])
ibm = np.zeros((len(bones), 4, 4), np.float32)
for i, b in enumerate(bones):
    M = np.eye(4)
    M[:3, 3] = -b[2]
    ibm[i] = M.T
ibm_acc = add(ibm.reshape(len(bones), 16), kind="MAT4")
anims = []
for cname, c in clips.items():
    samplers, channels = [], []
    for bone, (ts, qs) in c.rot.items():
        ta = add(ts.astype(np.float32), minmax=True, kind="SCALAR")
        qa = add(np.array(qs, np.float32), kind="VEC4")
        samplers.append({"input": ta, "output": qa, "interpolation": "LINEAR"})
        channels.append({"sampler": len(samplers) - 1, "target": {"node": bone_node[bone], "path": "rotation"}})
    for bone, (ts, vs) in c.tr.items():
        ta = add(ts.astype(np.float32), minmax=True, kind="SCALAR")
        va = add(np.array(vs, np.float32), kind="VEC3")
        samplers.append({"input": ta, "output": va, "interpolation": "LINEAR"})
        channels.append({"sampler": len(samplers) - 1, "target": {"node": bone_node[bone], "path": "translation"}})
    anims.append({"name": cname, "samplers": samplers, "channels": channels})
out = {
    "asset": {"version": "2.0", "generator": "toon-tale rerig_legend.py"},
    "scene": 0, "scenes": [{"nodes": [0, bone_node["Root"]]}], "nodes": out_nodes,
    "meshes": [{"name": spec["name"], "primitives": [{"attributes": {"POSITION": pos, "NORMAL": nor, "TEXCOORD_0": tex, "JOINTS_0": jnt, "WEIGHTS_0": wgt}, "indices": ind, "material": 0}]}],
    "materials": gl["materials"], "textures": gl["textures"], "samplers": gl["samplers"],
    "images": [{"bufferView": imgview, "mimeType": "image/jpeg"}],
    "skins": [{"joints": [bone_node[n] for n in names], "inverseBindMatrices": ibm_acc, "skeleton": bone_node["Root"]}],
    "animations": anims, "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(buf)}],
}
js = json.dumps(out, separators=(",", ":")).encode()
while len(js) % 4:
    js += b" "
while len(buf) % 4:
    buf.append(0)
blob = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(buf)) + struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(buf), 0x004E4942) + bytes(buf)
open(src, "wb").write(blob)
print("wrote", src, len(blob), "bytes", len(V), "verts", len(F), "tris", list(clips))
if report_path:
    full = json.load(open(report_path)) if os.path.exists(report_path) else {}
    full[spec["name"]] = {"verts": int(len(V)), "tris": int(len(F)), "clips": list(clips), "stretch": report}
    json.dump(full, open(report_path, "w"), indent=1)
