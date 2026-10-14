"""Decimate a dense textured mesh and re-bake its colour onto a fresh atlas.
usage: bake.py src.glb out.glb target_tris tex_size"""
import sys, time, trimesh, numpy as np, fast_simplification as fs, xatlas
from PIL import Image, ImageFilter
from scipy.spatial import cKDTree
src, dst, target, size = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
t0 = time.time()
s = trimesh.load(src); m = list(s.geometry.values())[0]
V0 = m.vertices.astype(np.float64); F0 = m.faces; UV0 = m.visual.uv
tex0 = np.asarray(m.visual.material.baseColorTexture.convert('RGB')).astype(np.float32)
H0, W0 = tex0.shape[:2]
# 1. Weld seams so the decimator sees one surface, then decimate.
w = trimesh.Trimesh(V0, F0, process=True)
pts, faces = fs.simplify(w.vertices.astype(np.float32), w.faces.astype(np.int64), target_count=target, agg=7)
lo = trimesh.Trimesh(pts, faces, process=False)
print('decimated', len(pts), len(faces), round(time.time() - t0, 1))
# 2. New atlas.
vmap, idx, uvs = xatlas.parametrize(lo.vertices.astype(np.float32), lo.faces.astype(np.uint32))
P = lo.vertices[vmap]; T = idx
print('atlas', len(P), len(T), round(time.time() - t0, 1))
# 3. Dense samples of the original surface with their UVs and normals.
N = 3_000_000
fidx = np.random.default_rng(1).integers(0, len(F0), N)
r1 = np.sqrt(np.random.default_rng(2).random(N)); r2 = np.random.default_rng(3).random(N)
b = np.stack([1 - r1, r1 * (1 - r2), r1 * r2], 1)
tri = F0[fidx]
sp = (V0[tri] * b[:, :, None]).sum(1)
suv = (UV0[tri] * b[:, :, None]).sum(1)
sn = m.face_normals[fidx]
sp = np.concatenate([sp, V0]); suv = np.concatenate([suv, UV0])
vn = m.vertex_normals; sn = np.concatenate([sn, vn])
tree = cKDTree(sp)
print('samples', len(sp), round(time.time() - t0, 1))
# 4. Rasterise every atlas triangle, find the nearest original sample facing the same way.
img = np.zeros((size, size, 3), np.float32); filled = np.zeros((size, size), bool)
fn = np.cross(P[T[:, 1]] - P[T[:, 0]], P[T[:, 2]] - P[T[:, 0]]); fn /= np.linalg.norm(fn, axis=1, keepdims=True) + 1e-12
px_all = []; pos_all = []; nrm_all = []
U = uvs * (size - 1)
for k in range(len(T)):
    a, bb, c = U[T[k]]
    xmin, xmax = int(np.floor(min(a[0], bb[0], c[0]))), int(np.ceil(max(a[0], bb[0], c[0])))
    ymin, ymax = int(np.floor(min(a[1], bb[1], c[1]))), int(np.ceil(max(a[1], bb[1], c[1])))
    xs, ys = np.meshgrid(np.arange(xmin, xmax + 1), np.arange(ymin, ymax + 1))
    q = np.stack([xs.ravel() + 0.0, ys.ravel() + 0.0], 1)
    v0, v1 = bb - a, c - a; d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
    den = d00 * d11 - d01 * d01
    if abs(den) < 1e-12: continue
    v2 = q - a; d20, d21 = v2 @ v0, v2 @ v1
    l1 = (d11 * d20 - d01 * d21) / den; l2 = (d00 * d21 - d01 * d20) / den; l0 = 1 - l1 - l2
    ok = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
    if not ok.any(): continue
    q = q[ok].astype(int); L = np.stack([l0[ok], l1[ok], l2[ok]], 1)
    pos = L @ P[T[k]]
    px_all.append(q); pos_all.append(pos); nrm_all.append(np.repeat(fn[k][None], len(q), 0))
px = np.concatenate(px_all); pos = np.concatenate(pos_all); nrm = np.concatenate(nrm_all)
print('texels', len(px), round(time.time() - t0, 1))
dist, nn = tree.query(pos, k=8)
dots = np.abs(np.einsum('ijk,ik->ij', sn[nn], nrm))  # thin cloth: either side is fine, but prefer aligned
score = dist / (dist[:, :1] + 1e-6) - 0.5 * dots
pick = nn[np.arange(len(nn)), np.argmin(score, 1)]
uvp = suv[pick]
tx = np.clip((uvp[:, 0] % 1.0) * (W0 - 1), 0, W0 - 1).astype(int)
ty = np.clip((1 - (uvp[:, 1] % 1.0)) * (H0 - 1), 0, H0 - 1).astype(int)
col = tex0[ty, tx]
yy = (size - 1) - px[:, 1]; xx = px[:, 0]
img[yy, xx] = col; filled[yy, xx] = True
# 5. Dilate so mip-mapping never pulls in the empty background.
out = Image.fromarray(img.clip(0, 255).astype(np.uint8)); mask = Image.fromarray((filled * 255).astype(np.uint8))
for _ in range(12):
    grown = out.filter(ImageFilter.MaxFilter(3)); gmask = mask.filter(ImageFilter.MaxFilter(3))
    out = Image.composite(out, grown, mask); mask = gmask
print('baked', round(time.time() - t0, 1))
mat = trimesh.visual.material.PBRMaterial(baseColorTexture=out, metallicFactor=0.0, roughnessFactor=0.8, doubleSided=True)
res = trimesh.Trimesh(vertices=P, faces=T, visual=trimesh.visual.TextureVisuals(uv=uvs, material=mat), process=False)
res.export(dst)
out.save(dst.replace('.glb', '_tex.png'))
print('done', dst, len(P), len(T), round(time.time() - t0, 1))
