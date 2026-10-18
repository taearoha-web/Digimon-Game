"""Import the Defender's supplied models into the game's asset layout.

usage: python3 tools/defender_import.py SOURCE_DIR [OUT_ROOT]
  SOURCE_DIR holds the two unpacked archives:
    ผู้พิทักษ์_Defender/  (Lv.10-100 shields, Lv.100 wings)
    ผู้พิทักษ์_200ดาว/     (200-star wardrobe, shield and wings)
  OUT_ROOT defaults to assets/models.

What it writes (same layout as the other classes):
  weapons/greatshield_<0-9>.glb           Lv.10..100 shields, static, grip at the origin
  divine_gear/defender_<boy|girl>_<armor|helm|boots>.glb   200-star wardrobe, skinned
  divine_gear/defender_greatshield.glb    200-star shield, static
  wings/wings_defender.glb                Lv.100 class wings, skinned + clips
  star_wings/wings_defender.glb           200-star wings, skinned + clips
  divine_gear/DEFENDER_PROVENANCE.json

The sources are generated meshes of many small parts without normals. Per file:
every primitive is gathered (shields are posed to their rest pose and lose their
rig, clothes and wings keep theirs), parts sharing a material become one surface,
coincident vertices are welded, the surface is simplified with meshoptimizer to
a triangle budget, and smooth normals are rebuilt with a crease angle so hard
armour edges stay sharp. The supplied rig matches the game's chibi rig bone for
bone (same names and bind poses), so clothes keep their weights and bind as is.
"""
import sys, os, json, struct, hashlib
import numpy as np
import meshoptimizer as mo

CT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8, 5122: np.int16, 5120: np.int8}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
CREASE_DEG = 50.0


class Glb:
    def __init__(self, path):
        raw = open(path, "rb").read()
        jl = struct.unpack_from("<I", raw, 12)[0]
        self.g = json.loads(raw[20:20 + jl])
        bl = struct.unpack_from("<I", raw, 20 + jl)[0]
        self.bin = raw[28 + jl:28 + jl + bl]
        self.path = path

    def acc(self, i, as_float=True):
        a = self.g["accessors"][i]
        v = self.g["bufferViews"][a["bufferView"]]
        n = NC[a["type"]]
        dt = np.dtype(CT[a["componentType"]])
        stride = v.get("byteStride", 0) or dt.itemsize * n
        off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
        if stride == dt.itemsize * n:
            arr = np.frombuffer(self.bin, dt, a["count"] * n, off).reshape(a["count"], n)
        else:
            arr = np.stack([np.frombuffer(self.bin, dt, n, off + k * stride) for k in range(a["count"])])
        if as_float:
            arr = arr.astype(np.float64)
            if a.get("normalized"):
                arr /= float(np.iinfo(dt).max)
        return arr if n > 1 else arr[:, 0]

    def local(self, node):
        if "matrix" in node:
            return np.array(node["matrix"], float).reshape(4, 4).T
        t = np.array(node.get("translation", [0, 0, 0]), float)
        x, y, z, w = node.get("rotation", [0, 0, 0, 1])
        s = np.array(node.get("scale", [1, 1, 1]), float)
        r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                      [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                      [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
        m = np.eye(4)
        m[:3, :3] = r * s
        m[:3, 3] = t
        return m

    def world(self):
        parent = {}
        for i, n in enumerate(self.g["nodes"]):
            for c in n.get("children", []):
                parent[c] = i
        cache = {}

        def w(i):
            if i not in cache:
                m = self.local(self.g["nodes"][i])
                cache[i] = w(parent[i]) @ m if i in parent else m
            return cache[i]
        return [w(i) for i in range(len(self.g["nodes"]))]


def mat_key(m):
    pbr = m.get("pbrMetallicRoughness", {})
    return json.dumps({"c": [round(x, 4) for x in pbr.get("baseColorFactor", [1, 1, 1, 1])],
                       "m": round(pbr.get("metallicFactor", 1.0), 3), "r": round(pbr.get("roughnessFactor", 1.0), 3),
                       "e": [round(x, 4) for x in m.get("emissiveFactor", [0, 0, 0])],
                       "a": m.get("alphaMode", "OPAQUE"), "d": m.get("doubleSided", False)}, sort_keys=True)


def gather(glbs, static):
    """Surfaces keyed by material: positions, joints, weights, triangle indices."""
    surfaces = {}
    materials = {}
    skin_src = None
    for doc in glbs:
        g = doc.g
        world = doc.world()
        for ni, node in enumerate(g["nodes"]):
            if "mesh" not in node:
                continue
            skin = g["skins"][node["skin"]] if "skin" in node else None
            joint_mats = None
            if skin is not None:
                ibm = doc.acc(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
                joint_mats = np.stack([world[j] @ ibm[k] for k, j in enumerate(skin["joints"])])
                if skin_src is None:
                    skin_src = (doc, node["skin"])
            for prim in g["meshes"][node["mesh"]]["primitives"]:
                if prim.get("mode", 4) != 4:
                    continue
                pos = doc.acc(prim["attributes"]["POSITION"])
                idx = doc.acc(prim["indices"], False).astype(np.int64) if "indices" in prim else np.arange(len(pos))
                jo = doc.acc(prim["attributes"]["JOINTS_0"], False).astype(np.int64) if skin is not None and "JOINTS_0" in prim["attributes"] else None
                we = doc.acc(prim["attributes"]["WEIGHTS_0"]) if jo is not None else None
                if skin is None:
                    pos = (np.c_[pos, np.ones(len(pos))] @ world[ni].T)[:, :3]
                elif static:
                    blend = np.einsum("vk,vkij->vij", we / np.maximum(we.sum(1, keepdims=True), 1e-9), joint_mats[jo])
                    pos = np.einsum("vij,vj->vi", blend, np.c_[pos, np.ones(len(pos))])[:, :3]
                    jo = we = None
                m = g["materials"][prim["material"]] if "material" in prim else {}
                key = mat_key(m)
                materials.setdefault(key, m)
                s = surfaces.setdefault(key, {"pos": [], "jo": [], "we": [], "idx": [], "n": 0})
                s["pos"].append(pos)
                if jo is not None:
                    s["jo"].append(jo)
                    s["we"].append(we)
                s["idx"].append(idx.reshape(-1, 3) + s["n"])
                s["n"] += len(pos)
    out = []
    for key, s in surfaces.items():
        out.append({"material": materials[key], "pos": np.concatenate(s["pos"]),
                    "jo": np.concatenate(s["jo"]) if s["jo"] else None,
                    "we": np.concatenate(s["we"]) if s["we"] else None,
                    "tri": np.concatenate(s["idx"])})
    return out, skin_src


def weld(s):
    q = np.round(s["pos"] / 1e-5).astype(np.int64)
    _, first, inverse = np.unique(q, axis=0, return_index=True, return_inverse=True)
    inverse = inverse.reshape(-1)
    s["pos"] = s["pos"][first]
    if s["jo"] is not None:
        s["jo"] = s["jo"][first]
        s["we"] = s["we"][first]
    tri = inverse[s["tri"]]
    tri = tri[(tri[:, 0] != tri[:, 1]) & (tri[:, 1] != tri[:, 2]) & (tri[:, 0] != tri[:, 2])]
    s["tri"] = tri


def simplify(s, ratio):
    tri = s["tri"]
    if len(tri) < 64 or ratio >= 1.0:
        return
    idx = tri.reshape(-1).astype(np.uint32)
    dest = np.zeros_like(idx)
    target = max(int(len(idx) * ratio) // 3 * 3, 36)
    n = mo.simplify(dest, idx, s["pos"].astype(np.float32), target_index_count=target, target_error=0.02)
    s["tri"] = dest[:n].reshape(-1, 3).astype(np.int64)
    used = np.unique(s["tri"])
    remap = np.full(len(s["pos"]), -1, np.int64)
    remap[used] = np.arange(len(used))
    s["pos"] = s["pos"][used]
    if s["jo"] is not None:
        s["jo"] = s["jo"][used]
        s["we"] = s["we"][used]
    s["tri"] = remap[s["tri"]]


def normals(s):
    """Split vertices where faces meet sharper than CREASE_DEG; smooth elsewhere."""
    p, tri = s["pos"], s["tri"]
    fn = np.cross(p[tri[:, 1]] - p[tri[:, 0]], p[tri[:, 2]] - p[tri[:, 0]])
    area = np.linalg.norm(fn, axis=1, keepdims=True)
    fu = fn / np.maximum(area, 1e-12)
    cos_lim = np.cos(np.radians(CREASE_DEG))
    corners = tri.reshape(-1)
    face_of = np.repeat(np.arange(len(tri)), 3)
    order = np.argsort(corners, kind="stable")
    new_pos, new_n, new_jo, new_we, new_idx = [], [], [], [], np.zeros(len(corners), np.int64)
    start = 0
    sc = corners[order]
    while start < len(order):
        end = start
        v = sc[start]
        while end < len(order) and sc[end] == v:
            end += 1
        group = order[start:end]
        faces = face_of[group]
        groups = []
        for c, f in zip(group, faces):
            for gi in groups:
                if np.dot(fu[f], fu[gi["f"][0]]) >= cos_lim:
                    gi["c"].append(c)
                    gi["f"].append(f)
                    break
            else:
                groups.append({"c": [c], "f": [f]})
        for gi in groups:
            nrm = (fn[gi["f"]]).sum(0)
            nrm /= max(np.linalg.norm(nrm), 1e-12)
            k = len(new_pos)
            new_pos.append(p[v])
            new_n.append(nrm)
            if s["jo"] is not None:
                new_jo.append(s["jo"][v])
                new_we.append(s["we"][v])
            new_idx[gi["c"]] = k
        start = end
    s["pos"] = np.array(new_pos)
    s["nrm"] = np.array(new_n)
    if s["jo"] is not None:
        s["jo"] = np.array(new_jo)
        w = np.array(new_we)
        s["we"] = w / np.maximum(w.sum(1, keepdims=True), 1e-9)
    s["tri"] = new_idx.reshape(-1, 3)


class Writer:
    def __init__(self):
        self.bin = bytearray()
        self.views = []
        self.accs = []

    def add(self, arr, ctype, atype, target=None, minmax=False):
        arr = np.ascontiguousarray(arr)
        while len(self.bin) % 4:
            self.bin.append(0)
        off = len(self.bin)
        self.bin += arr.tobytes()
        view = {"buffer": 0, "byteOffset": off, "byteLength": arr.nbytes}
        if target:
            view["target"] = target
        self.views.append(view)
        a = {"bufferView": len(self.views) - 1, "componentType": ctype, "count": len(arr), "type": atype}
        if minmax:
            a["min"] = arr.min(0).tolist()
            a["max"] = arr.max(0).tolist()
        self.accs.append(a)
        return len(self.accs) - 1


def write(path, surfaces, skin_src, keep_anims, origin_shift=None, root_scale=None):
    w = Writer()
    prims, mats = [], []
    for s in surfaces:
        pos = s["pos"] - (origin_shift if origin_shift is not None else 0)
        attrs = {"POSITION": w.add(pos.astype(np.float32), 5126, "VEC3", 34962, True),
                 "NORMAL": w.add(s["nrm"].astype(np.float32), 5126, "VEC3", 34962)}
        if s["jo"] is not None:
            attrs["JOINTS_0"] = w.add(s["jo"].astype(np.uint16), 5123, "VEC4", 34962)
            attrs["WEIGHTS_0"] = w.add(s["we"].astype(np.float32), 5126, "VEC4", 34962)
        big = len(pos) > 65535
        ind = w.add(s["tri"].reshape(-1).astype(np.uint32 if big else np.uint16), 5125 if big else 5123, "SCALAR", 34963)
        m = dict(s["material"])
        m.pop("name", None)
        mats.append(m)
        prims.append({"attributes": attrs, "indices": ind, "material": len(mats) - 1})
    doc = {"asset": {"version": "2.0", "generator": "Toon Tale defender_import.py"}, "scene": 0,
           "meshes": [{"name": "Body", "primitives": prims}], "materials": mats}
    if skin_src is None:
        doc["nodes"] = [{"name": os.path.splitext(os.path.basename(path))[0], "mesh": 0}]
        doc["scenes"] = [{"nodes": [0]}]
    else:
        src, si = skin_src
        g = src.g
        skin = g["skins"][si]
        # Keep the armature: joints with their parents, the skin and (wings) the clips.
        keep = set(skin["joints"])
        parent = {c: i for i, n in enumerate(g["nodes"]) for c in n.get("children", [])}
        for j in list(keep):
            p = parent.get(j)
            while p is not None:
                keep.add(p)
                p = parent.get(p)
        order = sorted(keep)
        remap = {old: k for k, old in enumerate(order)}
        nodes = []
        for old in order:
            n = {k: v for k, v in g["nodes"][old].items() if k not in ("mesh", "skin", "children", "camera")}
            ch = [remap[c] for c in g["nodes"][old].get("children", []) if c in remap]
            if ch:
                n["children"] = ch
            nodes.append(n)
        nodes.append({"name": "Body", "mesh": 0, "skin": 0})
        roots = [remap[i] for i in order if parent.get(i) not in keep] + [len(nodes) - 1]
        if root_scale is not None:
            # Shrinks the whole armature (the skinned mesh follows its joints).
            for r in roots[:-1]:
                nodes[r]["scale"] = [root_scale] * 3
        ibm = src.acc(skin["inverseBindMatrices"]).astype(np.float32)
        doc["skins"] = [{"joints": [remap[j] for j in skin["joints"]], "inverseBindMatrices": w.add(ibm, 5126, "MAT4")}]
        if "skeleton" in skin and skin["skeleton"] in remap:
            doc["skins"][0]["skeleton"] = remap[skin["skeleton"]]
        doc["nodes"] = nodes
        doc["scenes"] = [{"nodes": roots}]
        if keep_anims:
            anims = []
            for a in g.get("animations", []):
                samplers, channels = [], []
                for ch in a["channels"]:
                    tn = ch["target"].get("node")
                    if tn not in remap:
                        continue
                    smp = a["samplers"][ch["sampler"]]
                    ia = src.g["accessors"][smp["input"]]
                    inp = src.acc(smp["input"]).astype(np.float32)
                    outv = src.acc(smp["output"]).astype(np.float32)
                    ii = w.add(inp.reshape(-1), 5126, "SCALAR")
                    w.accs[ii]["min"] = [float(inp.min())]
                    w.accs[ii]["max"] = [float(inp.max())]
                    oa = src.g["accessors"][smp["output"]]
                    oi = w.add(outv, 5126, oa["type"])
                    samplers.append({"input": ii, "output": oi, "interpolation": smp.get("interpolation", "LINEAR")})
                    channels.append({"sampler": len(samplers) - 1, "target": {"node": remap[tn], "path": ch["target"]["path"]}})
                if channels:
                    anims.append({"name": a.get("name", "Clip"), "samplers": samplers, "channels": channels})
            if anims:
                doc["animations"] = anims
    doc["accessors"] = w.accs
    doc["bufferViews"] = w.views
    while len(w.bin) % 4:
        w.bin.append(0)
    doc["buffers"] = [{"byteLength": len(w.bin)}]
    js = json.dumps(doc, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(w.bin)) + struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(w.bin), 0x004E4942) + bytes(w.bin)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "wb").write(out)
    return len(out)


def build(sources, dest, budget, static=False, keep_anims=False, grip_bone=None, root_scale=None):
    docs = [Glb(p) for p in sources]
    src_tris = 0
    for d in docs:
        for m in d.g["meshes"]:
            for pr in m["primitives"]:
                if "indices" in pr:
                    src_tris += d.g["accessors"][pr["indices"]]["count"] // 3
    surfaces, skin_src = gather(docs, static)
    for s in surfaces:
        weld(s)
    total = sum(len(s["tri"]) for s in surfaces)
    ratio = min(1.0, budget / max(total, 1))
    for s in surfaces:
        simplify(s, ratio)
        normals(s)
    shift = None
    if grip_bone is not None:
        d = docs[0]
        world = d.world()
        for i, n in enumerate(d.g["nodes"]):
            if n.get("name") == grip_bone:
                shift = world[i][:3, 3]
                break
    size = write(dest, surfaces, None if static else skin_src, keep_anims, shift, root_scale)
    tris = sum(len(s["tri"]) for s in surfaces)
    return {"file": os.path.relpath(dest, OUT), "sources": [os.path.relpath(p, SRC) for p in sources],
            "source_triangles": src_tris, "triangles": tris, "surfaces": len(surfaces), "skinned": not static,
            "animations": keep_anims, "bytes": size, "sha256": hashlib.sha256(open(dest, "rb").read()).hexdigest()}


SRC = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else "assets/models"
D = os.path.join(SRC, "ผู้พิทักษ์_Defender")
S = os.path.join(SRC, "ผู้พิทักษ์_200ดาว")
TIERS = ["Lv10_ฝึกหัด", "Lv20_เหล็กกล้า", "Lv30_มิธริล", "Lv40_ราชวงศ์", "Lv50_มังกรเพลิง",
         "Lv60_น้ำแข็ง", "Lv70_เงามืด", "Lv80_ศักดิ์สิทธิ์", "Lv90_สายฟ้า", "Lv100_เทพเจ้า"]
GENDER = {"boy": "ชาย", "girl": "หญิง"}
files = []


def only_glb(folder):
    return sorted(os.path.join(folder, f) for f in os.listdir(folder) if f.endswith(".glb"))


for i, t in enumerate(TIERS):
    shield = only_glb(os.path.join(D, "ชุดผู้พิทักษ์_" + t, "อาวุธ"))[0]
    files.append(build([shield], os.path.join(OUT, "weapons", "greatshield_%d.glb" % i), 3200, static=True, grip_bone="Shield"))
star = os.path.join(S, "ชุดผู้พิทักษ์_200ดาว_ดาราจักรนิรันดร์")
for gender, th in GENDER.items():
    body = os.path.join(star, "ชุด", th)
    files.append(build([os.path.join(body, "เสื้อ.glb"), os.path.join(body, "กางเกง.glb")],
                       os.path.join(OUT, "divine_gear", "defender_%s_armor.glb" % gender), 8800))
    files.append(build([os.path.join(body, "หมวก.glb")], os.path.join(OUT, "divine_gear", "defender_%s_helm.glb" % gender), 3300))
    files.append(build([os.path.join(body, "รองเท้า.glb")], os.path.join(OUT, "divine_gear", "defender_%s_boots.glb" % gender), 2900))
files.append(build(only_glb(os.path.join(star, "อาวุธ")), os.path.join(OUT, "divine_gear", "defender_greatshield.glb"), 4500, static=True, grip_bone="Shield"))
lv100_wings = only_glb([os.path.join(D, f) for f in os.listdir(D) if f.startswith("ปีกผู้พิทักษ์_Lv100")][0])
files.append(build(lv100_wings, os.path.join(OUT, "wings", "wings_defender.glb"), 4200, keep_anims=True, root_scale=0.8))
star_wings = only_glb([os.path.join(S, f) for f in os.listdir(S) if f.startswith("ปีกผู้พิทักษ์_200ดาว")][0])
files.append(build(star_wings, os.path.join(OUT, "star_wings", "wings_defender.glb"), 6200, keep_anims=True, root_scale=0.8))

manifest = {"source": "User-uploaded ผู้พิทักษ์_Defender_ครบชุด.zip and ผู้พิทักษ์_200ดาว.zip (Dropbox /Tae/Toontale/Defender)",
            "ownership": "User-supplied assets; no claim of public-domain rights or third-party redistribution license.",
            "pipeline": "tools/defender_import.py: gather primitives (shields posed to rest and unrigged, grip bone 'Shield' moved to the origin), merge by material, weld coincident vertices, meshoptimizer simplify to a triangle budget, crease-angle normals (%d deg). Clothes and wings keep the supplied skin (bind poses match the game's chibi rig); wings keep their clips." % CREASE_DEG,
            "files": files,
            "totals": {"source_triangles": sum(f["source_triangles"] for f in files), "shipping_triangles": sum(f["triangles"] for f in files),
                       "shipping_bytes": sum(f["bytes"] for f in files), "glbs": len(files)}}
open(os.path.join(OUT, "divine_gear", "DEFENDER_PROVENANCE.json"), "w").write(json.dumps(manifest, ensure_ascii=False, indent=1))
for f in files:
    print("%-42s %7d -> %6d tris  %4d KB" % (f["file"], f["source_triangles"], f["triangles"], f["bytes"] // 1024))
print("total", manifest["totals"])
