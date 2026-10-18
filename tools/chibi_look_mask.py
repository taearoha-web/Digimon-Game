"""Bake the look mask of a chibi hero: which texels are hair and which are eyes.
usage: python3 tools/chibi_look_mask.py assets/models/heroes/chibi_boy.glb assets/models/heroes/chibi_boy_look_mask.png

The chibi bodies come from Tripo with a fragmented texture atlas, where hair and
leather share the same browns. Their rig separates them: hair, bangs and brows are
skinned to Hair_* / Brow_* bones, the eyes to Eye_L / Eye_R, the mouth to Mouth_* /
Jaw. Each triangle is classified by its skin weights and painted into UV space:
  R = 255 hair (hair and brow bones), 128 the rest of the head outside the mouth
      (scalp and face: hair or skin, told apart by the texel's colour)
  G = eye area: Eye-bone triangles plus every triangle inside the eye's ellipsoid,
      since Tripo skins only the middle of each eye to the eye bone; 255 inside
      the iris core (below the lid), 128 for the rest of the eye
shaders/chibi_outfit.gdshader recolours non-skin texels under R with the hair colour
and the iris under G with the eye colour; skin texels follow the skin tone anywhere.
"""
import sys, json, struct, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 512
src, out = sys.argv[1], sys.argv[2]
raw = open(src, "rb").read()
jlen = struct.unpack_from("<I", raw, 12)[0]
gl = json.loads(raw[20:20 + jlen])
blen = struct.unpack_from("<I", raw, 20 + jlen)[0]
bin0 = raw[28 + jlen:28 + jlen + blen]
CT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read(i):
    a = gl["accessors"][i]
    v = gl["bufferViews"][a["bufferView"]]
    off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    n = a["count"] * NC[a["type"]]
    arr = np.frombuffer(bin0, CT[a["componentType"]], n, off).astype(np.float64)
    if a.get("normalized") and a["componentType"] == 5121:
        arr /= 255.0
    if a.get("normalized") and a["componentType"] == 5123:
        arr /= 65535.0
    return arr.reshape(a["count"], NC[a["type"]]) if NC[a["type"]] > 1 else arr


prim = gl["meshes"][0]["primitives"][0]
V = read(prim["attributes"]["POSITION"])
UV = read(prim["attributes"]["TEXCOORD_0"])
JJ = read(prim["attributes"]["JOINTS_0"]).astype(int)
WW = read(prim["attributes"]["WEIGHTS_0"])
F = read(prim["indices"]).astype(int).reshape(-1, 3)
names = [gl["nodes"][j]["name"] for j in gl["skins"][0]["joints"]]


def weight_of(pred):
    sel = np.array([pred(n) for n in names])
    return (WW * sel[JJ]).sum(axis=1)


hair = weight_of(lambda n: n.startswith("Hair_") or n.startswith("Brow_"))
eye = weight_of(lambda n: n.startswith("Eye_"))
face = weight_of(lambda n: n.startswith("Mouth_") or n == "Jaw")
head = weight_of(lambda n: n == "Head")

# Per triangle: mean weights of its corners, and its centre.
th, te, tf, thd = (w[F].mean(axis=1) for w in (hair, eye, face, head))
centre = V[F].mean(axis=1)
# Each eye's ellipsoid from its bone's vertices, grown so it covers the whole iris
# and lashes; only front-facing face triangles (not hair) can join it.
eye_l = weight_of(lambda n: n == "Eye_L") > 0.5
eye_r = weight_of(lambda n: n == "Eye_R") > 0.5
near_eye = np.zeros(len(F), bool)
iris_core = np.zeros(len(F), bool)
for sel in (eye_l, eye_r):
    if sel.sum() < 3:
        continue
    pts = V[sel]
    mid = (pts.min(0) + pts.max(0)) / 2
    half = np.maximum((pts.max(0) - pts.min(0)) / 2, 0.01) * np.array([1.7, 1.9, 1.0]) + np.array([0.008, 0.008, 0.02])
    # The bone holds the upper iris: the ellipsoid reaches further down than up.
    mid[1] -= half[1] * 0.2
    d = ((centre - mid) / half) ** 2
    near_eye |= d.sum(axis=1) <= 1.0
    # The iris itself: lower and narrower, clear of the lid's shading above it.
    core_mid = mid - np.array([0.0, half[1] * 0.1, 0.0])
    core_half = half * np.array([0.62, 0.55, 1.0])
    iris_core |= (((centre - core_mid) / core_half) ** 2).sum(axis=1) <= 1.0
is_eye = (te > 0.35) | (near_eye & (th < 0.25) & (tf < 0.3))
is_hair = ~is_eye & (th > 0.25)
is_head = ~is_eye & ~is_hair & (tf < 0.3) & (thd > 0.6)

img = Image.new("RGB", (SIZE, SIZE))
draw = ImageDraw.Draw(img)
# Head first, then hair and eyes over it where islands touch.
for group, colour in ((is_head, (128, 0, 0)), (is_hair, (255, 0, 0)), (is_eye, (0, 128, 0)), (is_eye & iris_core, (0, 255, 0))):
    for tri in F[group]:
        draw.polygon([(UV[i][0] * SIZE, UV[i][1] * SIZE) for i in tri], fill=colour)
# Close the seams between neighbouring triangles of an island.
img = img.filter(ImageFilter.MaxFilter(3))
img.save(out, optimize=True)
print(os.path.basename(src), "hair tris", int(is_hair.sum()), "head tris", int(is_head.sum()), "eye tris", int(is_eye.sum()), "of", len(F), "->", out)
