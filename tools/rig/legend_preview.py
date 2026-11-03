"""Quick software previews of a legend summon's clips (no Godot needed).

usage: [CELL=300] [NOGIF=1] legend_preview.py MODEL.glb SPEC.json OUT_DIR [CLIP,CLIP..] [FRAMES]
(CELL: pixel size of one sheet cell; NOGIF: sheets only)

Skins the shipped mesh with freshly computed weights (legend_weights) and freshly
authored clips (legend_clips), then paints every triangle (painter's sort, flat
lambert over the atlas colour) from the front, the 3/4 and the side. Writes one contact
sheet per clip (rows = views, columns = time) and an animated GIF per clip, so a pose can
be judged in seconds while authoring. Edges that stretch past STRETCH_CM are drawn red:
a tear shows on the sheet before it ever reaches the game.
"""
import sys, os, json, struct, io, math
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import legend_clips as lc
import legend_weights as lw

CT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
STRETCH_CM = 4.0
CELL = int(os.environ.get("CELL", "260"))


def load(path):
    raw = open(path, "rb").read()
    jlen = struct.unpack_from("<I", raw, 12)[0]
    gl = json.loads(raw[20:20 + jlen])
    blen = struct.unpack_from("<I", raw, 20 + jlen)[0]
    bin0 = raw[28 + jlen:28 + jlen + blen]

    def read(i):
        a = gl["accessors"][i]
        v = gl["bufferViews"][a["bufferView"]]
        off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
        n = a["count"] * NC[a["type"]]
        arr = np.frombuffer(bin0, CT[a["componentType"]], n, off)
        return arr.reshape(a["count"], NC[a["type"]]) if NC[a["type"]] > 1 else arr

    prim = gl["meshes"][0]["primitives"][0]
    V = read(prim["attributes"]["POSITION"]).astype(np.float64)
    UV = read(prim["attributes"]["TEXCOORD_0"]).astype(np.float64)
    F = read(prim["indices"]).astype(np.int64).reshape(-1, 3)
    imgv = gl["bufferViews"][gl["images"][0]["bufferView"]]
    tex = Image.open(io.BytesIO(bin0[imgv["byteOffset"]:imgv["byteOffset"] + imgv["byteLength"]])).convert("RGB")
    nodes = gl["nodes"]
    joints = gl["skins"][0]["joints"]
    parent_of = {}
    for i, n in enumerate(nodes):
        for ch in n.get("children", []):
            parent_of[ch] = i
    heads = {}
    for j in joints:
        p, h = j, np.zeros(3)
        while p is not None:
            h += np.array(nodes[p].get("translation", [0, 0, 0]), float)
            p = parent_of.get(p)
        heads[j] = h
    bones = []
    for j in joints:
        p = parent_of.get(j)
        bones.append((nodes[j]["name"], nodes[p]["name"] if p is not None and p in joints else None, heads[j]))
    return V, UV, F, tex, bones


def face_colours(UV, F, tex):
    t = np.asarray(tex, np.float64) / 255.0
    h, w = t.shape[:2]
    c = UV[F].mean(1)
    x = np.clip((c[:, 0] * w).astype(int), 0, w - 1)
    y = np.clip((c[:, 1] * h).astype(int), 0, h - 1)
    return t[y, x]


VIEWS = {"front": 0.0, "3/4": 40.0, "side": 90.0}


def render(P, F, col, yaw_deg, size=260, bad=None, scale=None, centre=(0.0, 0.5)):
    a = math.radians(yaw_deg)
    R = np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])
    Q = P @ R.T
    tri = Q[F]
    n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    light = np.array([-0.4, 0.6, 0.7])
    light /= np.linalg.norm(light)
    shade = 0.45 + 0.55 * np.abs(n @ light)
    rgb = np.clip(col * shade[:, None], 0, 1)
    if bad is not None:
        rgb[bad] = [1.0, 0.1, 0.1]
    depth = tri[:, :, 2].mean(1)
    order = np.argsort(depth)
    s = scale or size * 0.92
    img = Image.new("RGB", (size, size), (200, 214, 230))
    d = ImageDraw.Draw(img)
    # ground line
    gy = size * 0.5 + (centre[1] - 0.0) * s
    d.line([(0, gy), (size, gy)], fill=(150, 160, 150), width=1)
    xs = size * 0.5 + (tri[:, :, 0] - centre[0]) * s
    ys = size * 0.5 - (tri[:, :, 1] - centre[1]) * s
    cols = (rgb * 255).astype(int)
    for i in order:
        d.polygon([(xs[i, 0], ys[i, 0]), (xs[i, 1], ys[i, 1]), (xs[i, 2], ys[i, 2])], fill=tuple(cols[i]))
    return img


def main():
    model, specf, out = sys.argv[1], sys.argv[2], sys.argv[3]
    only = sys.argv[4].split(",") if len(sys.argv) > 4 and sys.argv[4] else None
    frames = int(sys.argv[5]) if len(sys.argv) > 5 else 8
    os.makedirs(out, exist_ok=True)
    spec = json.load(open(specf))
    V, UV, F, tex, bones = load(model)
    r = lw.compute(V, F, spec)
    V, UV, F = V[r["src"]], UV[r["src"]], r["F"].astype(np.int64)
    JJ, WW = r["J"], r["W"]
    bones = [(b[0], b[1], b[2]) for b in lw.bones_of(spec)]
    clips = lc.author(spec["style"], bones, spec)
    col = face_colours(UV, F, tex)
    height = float(spec.get("height_m", 3.5))
    edges = np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]])
    rest = np.linalg.norm(V[edges[:, 0]] - V[edges[:, 1]], axis=1)
    for name, clip in clips.items():
        if only and name not in only:
            continue
        ts = np.linspace(0, clip.length * (1 - 1.0 / frames if clip.loop else 1.0), frames)
        S = CELL
        cw = int(S * 0.77)
        sheet = Image.new("RGB", (frames * cw, len(VIEWS) * S + 24), (255, 255, 255))
        gif = []
        for fi, t in enumerate(ts):
            P = lc.pose_vertices(V, JJ, WW, bones, clip, t)
            e = np.abs(np.linalg.norm(P[edges[:, 0]] - P[edges[:, 1]], axis=1) - rest) * height * 100
            bad_e = e > STRETCH_CM
            bad = np.zeros(len(F), bool)
            nf = len(F)
            bad[np.where(bad_e)[0] % nf] = True
            for vi, (vn, yaw) in enumerate(VIEWS.items()):
                im = render(P, F, col, yaw, S, bad)
                sheet.paste(im.crop(((S - cw) // 2, 0, (S - cw) // 2 + cw, S)), (fi * cw, vi * S + 24))
            d = ImageDraw.Draw(sheet)
            d.text((fi * cw + 6, 6), "%s t=%.2fs  max %.1fcm" % (name, t, float(e.max())), fill=(0, 0, 0))
        sheet.save(os.path.join(out, "%s_%s.png" % (spec["name"], name)))
        gts = [] if os.environ.get("NOGIF") else np.arange(0, clip.length + 1e-6, 1.0 / 15)
        for t in gts:
            P = lc.pose_vertices(V, JJ, WW, bones, clip, t)
            a = render(P, F, col, 0.0, 240)
            b = render(P, F, col, 40.0, 240)
            c = render(P, F, col, 90.0, 240)
            fr = Image.new("RGB", (720, 240))
            fr.paste(a, (0, 0)); fr.paste(b, (240, 0)); fr.paste(c, (480, 0))
            gif.append(fr)
        if gif:
            gif[0].save(os.path.join(out, "%s_%s.gif" % (spec["name"], name)), save_all=True, append_images=gif[1:], duration=int(1000 / 15), loop=0)
        print("wrote", name)


if __name__ == "__main__":
    main()
