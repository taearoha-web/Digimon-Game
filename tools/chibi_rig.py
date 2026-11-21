"""Stage 2 of tools/import_chibi.py: fit the chibi skeleton to a decimated sculpt,
copy the skin weights from the base chibi's body and write a skinned glb.

  /opt/bpy5/bin/python tools/import_chibi.py rig CACHE.npz tools/chibi_models.json NAME OUT.glb [PREVIEW.npz]

Landmarks (tools/chibi_models.json, the model facing +Z, feet on y=0, height 1,
x = the character's left): shoulder = where the upper arm leaves the torso,
fingertip = the tip of the hanging hand, crotch / chin heights, ankle, hip_x.
The base chibis' own landmarks are in the same file ("base_boy", "base_girl").

Joints are placed by region: each arm and leg chain by the similarity that takes
the base's landmarks onto the model's (so the elbow sits at the same fraction of
the arm), the spine by the crotch-to-chin heights, the head and its bones moved
with the chin and scaled with the head. The bind pose keeps the base's bone
rolls; the rest pose keeps the base's local rotations with the fitted bone
lengths, so the base clips (whose bone offsets Godot drops as constant) play on it.

Weights: the base body is posed into the fit (each region's similarity), then
every vertex takes the weights of the nearest point of that posed surface
(barycentric blend), the face, hair and eye bones fold into Head, and the
weights are smoothed over the mesh a few times.
"""
import json, struct, sys, math
import numpy as np

HEAD_KIDS = ('Hair_', 'Eye_', 'Brow_', 'Mouth_', 'Jaw')


# --- glb reading ----------------------------------------------------------
CT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8, 5120: np.int8, 5122: np.int16}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def load_glb(path):
    f = open(path, 'rb').read()
    n = struct.unpack('<I', f[12:16])[0]
    j = json.loads(f[20:20 + n])
    o = 20 + n
    bl = struct.unpack('<I', f[o:o + 4])[0]
    return j, f[o + 8:o + 8 + bl]


def accessor(j, b, i):
    a = j['accessors'][i]
    bv = j['bufferViews'][a['bufferView']]
    n = NC[a['type']]
    dt = np.dtype(CT[a['componentType']])
    off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    st = bv.get('byteStride', 0)
    if st and st != dt.itemsize * n:
        raw = np.frombuffer(b, np.uint8, count=st * a['count'], offset=off).reshape(a['count'], st)[:, :dt.itemsize * n].copy()
        arr = raw.view(dt).reshape(a['count'], n)
    else:
        arr = np.frombuffer(b, dt, count=a['count'] * n, offset=off).reshape(a['count'], n)
    if a.get('normalized'):
        arr = arr.astype(np.float32) / np.iinfo(dt).max
    return arr


def q2m(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def swing(a, b):
    """Smallest rotation taking direction a onto direction b."""
    a = a / np.linalg.norm(a); b = b / np.linalg.norm(b)
    v = np.cross(a, b); c = float(np.dot(a, b)); s = np.linalg.norm(v)
    if s < 1e-9:
        return np.eye(3)
    k = v / s
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    ang = math.atan2(s, c)
    return np.eye(3) + math.sin(ang) * K + (1 - math.cos(ang)) * K @ K


class Base:
    def __init__(self, path):
        j, b = load_glb(path)
        self.j = j
        N = j['nodes']
        self.nodes = N
        par = {}
        for i, n in enumerate(N):
            for c in n.get('children', []):
                par[c] = i
        skin = j['skins'][0]
        self.joints = skin['joints']
        self.names = [N[i]['name'] for i in self.joints]
        self.index = {n: k for k, n in enumerate(self.names)}
        self.parent = [self.index.get(N[par[i]]['name'], -1) if i in par else -1 for i in self.joints]
        self.root_node = par[self.joints[self.names.index('Hips')]]
        self.local_r = [q2m(N[i].get('rotation', [0, 0, 0, 1])) for i in self.joints]
        self.local_q = [N[i].get('rotation', [0, 0, 0, 1]) for i in self.joints]
        self.local_s = [N[i].get('scale', [1, 1, 1]) for i in self.joints]
        self.local_t = [np.array(N[i].get('translation', [0, 0, 0]), float) for i in self.joints]
        G = [None] * len(self.joints)
        for k in self.order():
            M = np.eye(4); M[:3, :3] = self.local_r[k]; M[:3, 3] = self.local_t[k]
            G[k] = M if self.parent[k] < 0 else G[self.parent[k]] @ M
        self.G = G
        self.P = np.array([g[:3, 3] for g in G])
        self.R = [g[:3, :3] for g in G]
        pr = j['meshes'][0]['primitives'][0]
        self.V = accessor(j, b, pr['attributes']['POSITION']).astype(float)
        self.F = accessor(j, b, pr['indices']).reshape(-1, 3).astype(np.int64)
        js = accessor(j, b, pr['attributes']['JOINTS_0']).astype(int)
        ws = accessor(j, b, pr['attributes']['WEIGHTS_0']).astype(float)
        W = np.zeros((len(self.V), len(self.joints)))
        for c in range(4):
            np.add.at(W, (np.arange(len(self.V)), js[:, c]), ws[:, c])
        self.W = W / W.sum(1, keepdims=True)
        ibm = accessor(j, b, skin['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1)
        assert max(np.abs(G[k] @ ibm[k] - np.eye(4)).max() for k in range(len(G))) < 1e-4, 'base bind pose is not its rest'

    def order(self):
        out, seen = [], set()
        while len(out) < len(self.parent):
            for k, p in enumerate(self.parent):
                if k not in seen and (p < 0 or p in seen):
                    out.append(k); seen.add(k)
        return out

    def chain(self, name):
        """name and every joint below it."""
        top = self.index[name]
        out = []
        for k in range(len(self.names)):
            a = k
            while a >= 0 and a != top:
                a = self.parent[a]
            if a == top:
                out.append(k)
        return out


def similarity(a0, a1, b0, b1):
    """(R, s, t): x -> R s (x - a0) + b0 maps segment a onto segment b."""
    R = swing(a1 - a0, b1 - b0)
    s = np.linalg.norm(b1 - b0) / np.linalg.norm(a1 - a0)
    return R, s, a0, b0


def fit(base, bl, ml, V):
    """Fitted global joint matrices and, per joint, the similarity used for the base body."""
    n = len(base.names)
    P = base.P.copy()
    newP = np.zeros_like(P)
    Rg = [r.copy() for r in base.R]
    sim = [None] * n
    mir = np.array([-1.0, 1, 1])
    cb, cn = bl['crotch'], ml['crotch']
    hb, hn = bl['chin'], ml['chin']

    def fy(y):  # spine heights: crotch and chin pinned
        return cn + (y - cb) * (hn - cn) / (hb - cb)

    # torso z: the model's body centre against the base's, per height (median of the middle slab)
    def zmid(Vs, y):
        m = (np.abs(Vs[:, 1] - y) < 0.02) & (np.abs(Vs[:, 0]) < 0.07)
        return float(np.median(Vs[m, 2])) if m.sum() > 10 else 0.0
    sx = ml['shoulder'][0] / bl['shoulder'][0]
    for name in ('Hips', 'Spine', 'Chest', 'Neck', 'Head'):
        k = base.index[name]
        y = fy(P[k, 1])
        dz = zmid(V, y) - zmid(base.V, P[k, 1])
        newP[k] = [P[k, 0], y, P[k, 2] + dz]
        sim[k] = (np.eye(3), 1.0, P[k], newP[k])
    # head and its bones: moved with the chin, scaled with the head
    hs = (1.0 - hn) / (1.0 - hb) * ml.get('head_scale', 1.0)
    k_head = base.index['Head']
    for k in base.chain('Head'):
        if k == k_head:
            continue
        newP[k] = newP[k_head] + hs * (P[k] - P[k_head])
    for k in base.chain('Head'):
        sim[k] = (np.eye(3), hs, P[k_head], newP[k_head])
    for side, S in ((1.0, 'Left'), (-1.0, 'Right')):
        m = np.array([side, 1, 1])
        # clavicle: same offset from the upper arm, width scaled
        k_sh, k_ua = base.index[S + 'Shoulder'], base.index[S + 'UpperArm']
        sb, tb = np.array(bl['shoulder']) * m, np.array(bl['fingertip']) * m
        sn, tn = np.array(ml['shoulder']) * m, np.array(ml['fingertip']) * m
        off = P[k_sh] - P[k_ua]
        newP[k_sh] = sn + np.array([off[0] * sx, off[1], off[2]])
        sim[k_sh] = (np.eye(3), 1.0, P[k_sh], newP[k_sh])
        R, s, a0, b0 = similarity(sb, tb, sn, tn)
        for k in base.chain(S + 'UpperArm'):
            newP[k] = R @ (s * (P[k] - a0)) + b0
            Rg[k] = R @ base.R[k]
            sim[k] = (R, s, a0, b0)
        # leg: hip joint and ankle
        k_ul, k_ft = base.index[S + 'UpperLeg'], base.index[S + 'Foot']
        hip_b = P[k_ul]
        hip_n = newP[base.index['Hips']] + np.array([side * ml['hip_x'], (P[k_ul, 1] - P[base.index['Hips'], 1]), P[k_ul, 2] - P[base.index['Hips'], 2]])
        ank_b = P[k_ft]
        ank_n = np.array(ml['ankle']) * m
        R, s, a0, b0 = similarity(hip_b, ank_b, hip_n, ank_n)
        for k in base.chain(S + 'UpperLeg'):
            newP[k] = R @ (s * (P[k] - a0)) + b0
            Rg[k] = R @ base.R[k]
            sim[k] = (R, s, a0, b0)
    # anything left (skirt panels on the hips): the spine's height map, hips width
    hx = ml['hip_x'] / bl['hip_x']
    k_hips = base.index['Hips']
    for k in range(n):
        if sim[k] is None:
            d = P[k] - P[k_hips]
            newP[k] = newP[k_hips] + np.array([d[0] * hx, d[1] * (hn - cn) / (hb - cb), d[2]])
            sim[k] = (np.eye(3), 1.0, P[k], newP[k])
    G = []
    for k in range(n):
        M = np.eye(4); M[:3, :3] = Rg[k]; M[:3, 3] = newP[k]
        G.append(M)
    return G, sim


def pose_base(base, sim):
    """The base body moved into the fit: each joint's similarity, blended by its weights."""
    out = np.zeros_like(base.V)
    for k, (R, s, a0, b0) in enumerate(sim):
        w = base.W[:, k]
        m = w > 0
        if not m.any():
            continue
        out[m] += w[m, None] * ((base.V[m] - a0) * s @ R.T + b0)
    return out


def transfer(base, posed, V, F_new, smooth_iters=3):
    import bpy  # noqa: F401  (brings mathutils)
    from mathutils.bvhtree import BVHTree
    from mathutils import Vector
    tree = BVHTree.FromPolygons([tuple(p) for p in posed], [tuple(int(i) for i in f) for f in base.F])
    W = np.zeros((len(V), base.W.shape[1]))
    for i, v in enumerate(V):
        loc, nrm, fi, dist = tree.find_nearest(Vector(v))
        a, b, c = base.F[fi]
        pa, pb, pc = posed[a], posed[b], posed[c]
        p = np.array(loc)
        v0, v1, v2 = pb - pa, pc - pa, p - pa
        d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
        d20, d21 = v2 @ v0, v2 @ v1
        den = d00 * d11 - d01 * d01
        if abs(den) < 1e-14:
            l1 = l2 = 1 / 3
        else:
            l1 = (d11 * d20 - d01 * d21) / den; l2 = (d00 * d21 - d01 * d20) / den
        l1, l2 = np.clip(l1, 0, 1), np.clip(l2, 0, 1)
        l0 = max(0.0, 1 - l1 - l2)
        W[i] = l0 * base.W[a] + l1 * base.W[b] + l2 * base.W[c]
    # Face, eye and hair bones fold into the head: this sculpt's hair and face differ.
    head = base.index['Head']
    for k, nm in enumerate(base.names):
        if nm.startswith(HEAD_KIDS):
            W[:, head] += W[:, k]; W[:, k] = 0
    # Smooth over the mesh (neighbour average), keeping half of the vertex's own.
    nv = len(V)
    nb = [[] for _ in range(nv)]
    for f in F_new:
        for x in range(3):
            nb[f[x]].append(f[(x + 1) % 3]); nb[f[x]].append(f[(x + 2) % 3])
    rows = np.concatenate([np.full(len(l), i) for i, l in enumerate(nb)])
    cols = np.concatenate([np.array(l, int) for l in nb])
    deg = np.bincount(rows, minlength=nv).astype(float)
    for _ in range(smooth_iters):
        acc = np.zeros_like(W)
        np.add.at(acc, rows, W[cols])
        W = 0.5 * W + 0.5 * acc / np.maximum(deg, 1)[:, None]
    return W


def _smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def _seg_dist(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / (ab @ ab), 0.0, 1.0)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)


def garment(W, V, F, G, base, o, fingertip):
    """A skirt, dress or puffy shorts (spec "skirt"): the nearest-point copy gives the
    cloth the thigh under it, so the hem tears and stretches as the legs swing. Below
    `top` (fading in over `fade`) and outside the leg cylinders (`leg_r` around each
    thigh and shin, `leg_fade` soft) but above `bottom`, every leg weight moves to the
    Hips, except a share that grows (smoothstep) from 0 at `top` to `hem_thigh` at
    `hem` and goes to the thigh of the vertex's side (blended over `seam` across x=0,
    so the front and back seams do not split). Below `arm_top`, a vertex farther than
    `arm_r` from the arm (shoulder to fingertip) and not mostly arm (the hand itself)
    drops its arm weights to the Hips: the hanging hand lends them to the cloth
    beside it and drags shards out with it. Then the cloth (not the hands) is
    averaged with its neighbours `smooth` times. Returns the weights and the cloth
    amount."""
    ix = base.index
    P = np.array([g[:3, 3] for g in G])
    y, x = V[:, 1], V[:, 0]
    g = 1.0 - _smoothstep(o['top'], o['top'] + o.get('fade', 0.03), y)
    g *= _smoothstep(o.get('bottom', 0.0) - 0.01, o.get('bottom', 0.0) + 0.01, y)
    lr = o.get('leg_r', 0.04)
    near = np.full(len(V), 9.0)
    for S in ('Left', 'Right'):
        a, k, f = P[ix[S + 'UpperLeg']], P[ix[S + 'LowerLeg']], P[ix[S + 'Foot']]
        near = np.minimum(near, np.minimum(_seg_dist(V, a, k), _seg_dist(V, k, f)))
    g *= _smoothstep(lr, lr + o.get('leg_fade', 0.015), near)
    legs = [ix[S + p] for S in ('Left', 'Right') for p in ('UpperLeg', 'LowerLeg', 'Foot', 'Toes')]
    L = W[:, legs].sum(1)
    s = o.get('hem_thigh', 0.25) * _smoothstep(o['top'], o['hem'], y)
    wl = _smoothstep(-o.get('seam', 0.03), o.get('seam', 0.03), x)
    T = W.copy()
    T[:, legs] = 0
    T[:, ix['Hips']] += L * (1 - s)
    T[:, ix['LeftUpperLeg']] += L * s * wl
    T[:, ix['RightUpperLeg']] += L * s * (1 - wl)
    W = (1 - g)[:, None] * W + g[:, None] * T
    arm = [k for k, nm in enumerate(base.names) if any(p in nm for p in ('UpperArm', 'LowerArm', 'Hand', 'Thumb', 'Index', 'Middle', 'Ring', 'Little'))]
    da = np.full(len(V), 9.0)
    for S, sx in (('Left', 1.0), ('Right', -1.0)):
        tip = np.array(fingertip) * np.array([sx, 1, 1])
        pts = [P[ix[S + 'UpperArm']], P[ix[S + 'LowerArm']], P[ix[S + 'Hand']], tip]
        for a, b in zip(pts[:-1], pts[1:]):
            da = np.minimum(da, _seg_dist(V, a, b))
    ar = o.get('arm_r', 0.03)
    at = o.get('arm_top', o['top'] + 0.04)
    A = W[:, arm].sum(1)
    h = (1.0 - _smoothstep(at, at + 0.02, y)) * _smoothstep(ar, ar + 0.01, da) * (1.0 - _smoothstep(0.8, 0.95, A))
    A = A * h
    W[:, arm] *= (1 - h)[:, None]
    W[:, ix['Hips']] += A
    g = np.maximum(g, h * (A > 1e-4)) * (1.0 - _smoothstep(0.5, 0.9, W[:, arm].sum(1)))
    rows, cols, deg = _adjacency(F, len(V))
    for _ in range(int(o.get('smooth', 4))):
        acc = np.zeros_like(W)
        np.add.at(acc, rows, W[cols])
        avg = acc / np.maximum(deg, 1)[:, None]
        W = W + (g * 0.5)[:, None] * (avg - W)
    return W, g


def _adjacency(F, nv):
    nb = [[] for _ in range(nv)]
    for f in F:
        for x in range(3):
            nb[f[x]].append(f[(x + 1) % 3]); nb[f[x]].append(f[(x + 2) % 3])
    rows = np.concatenate([np.full(len(l), i) for i, l in enumerate(nb)])
    cols = np.concatenate([np.array(l, int) for l in nb])
    return rows, cols, np.bincount(rows, minlength=nv).astype(float)


def top4(W):
    idx = np.argsort(-W, axis=1)[:, :4]
    w = np.take_along_axis(W, idx, 1)
    w = w / w.sum(1, keepdims=True)
    return idx, w


def normals(V, F):
    """Smooth, area-weighted normals, shared by the copies of a vertex on a uv seam."""
    _u, weld = np.unique(np.round(V, 6), axis=0, return_inverse=True)
    weld = weld.reshape(-1)
    Fw = weld[F]
    fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    n = np.zeros((weld.max() + 1, 3))
    for c in range(3):
        np.add.at(n, Fw[:, c], fn)
    length = np.linalg.norm(n, axis=1, keepdims=True)
    n = np.where(length > 1e-12, n / np.maximum(length, 1e-12), np.array([0.0, 1.0, 0.0]))
    return n[weld]


def m2q(M):
    m = M
    t = np.trace(m)
    if t > 0:
        s = math.sqrt(t + 1.0) * 2
        q = [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, 0.25 * s]
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        q = [0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s, (m[2, 1] - m[1, 2]) / s]
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        q = [(m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s, (m[0, 2] - m[2, 0]) / s]
    else:
        s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        q = [(m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s, (m[1, 0] - m[0, 1]) / s]
    q = np.array(q); return q / np.linalg.norm(q)


def write_glb(path, base, G, offset, V, N, UV, F, J, Wt, COL, jpg, image_name):
    n = len(base.names)
    nodes = []
    # joints: base local rotation/scale, translation = fitted offset in the fitted parent's frame
    for k in range(n):
        node = {'name': base.names[k]}
        q = base.local_q[k]
        if any(abs(a) > 1e-9 for a in q[:3]):
            node['rotation'] = [float(a) for a in q]
        if base.local_s[k] != [1, 1, 1]:
            node['scale'] = [float(a) for a in base.local_s[k]]
        if base.parent[k] < 0:
            t = base.local_t[k]  # Hips: the base's, the clips key it anyway
        else:
            p = base.parent[k]
            t = G[p][:3, :3].T @ (G[k][:3, 3] - G[p][:3, 3])
        node['translation'] = [float(a) for a in t]
        kids = [c for c in range(n) if base.parent[c] == k]
        if kids:
            node['children'] = kids
        nodes.append(node)
    mesh_node = n
    root = n + 1
    nodes.append({'name': 'chibi_body', 'mesh': 0, 'skin': 0})
    nodes.append({'name': 'ChibiRigFull', 'children': [base.index['Hips'], mesh_node], 'translation': [float(a) for a in offset]})
    blobs = []
    views = []
    accs = []

    def add(arr, target=None, comp=5126, typ='VEC3', minmax=False, norm=False):
        data = np.ascontiguousarray(arr).tobytes()
        off = sum(len(b) for b in blobs)
        pad = (-len(data)) % 4
        blobs.append(data + b'\0' * pad)
        v = {'buffer': 0, 'byteOffset': off, 'byteLength': len(data)}
        if target:
            v['target'] = target
        views.append(v)
        a = {'bufferView': len(views) - 1, 'componentType': comp, 'count': int(len(arr)), 'type': typ}
        if norm:
            a['normalized'] = True
        if minmax:
            a['min'] = [float(x) for x in arr.min(0)]; a['max'] = [float(x) for x in arr.max(0)]
        accs.append(a)
        return len(accs) - 1
    pos = add(V.astype(np.float32), 34962, minmax=True)
    nor = add(N.astype(np.float32), 34962)
    tex = add(UV.astype(np.float32), 34962, typ='VEC2')
    col = add((np.clip(COL, 0, 1) * 255 + 0.5).astype(np.uint8), 34962, comp=5121, typ='VEC4', norm=True)
    jnt = add(J.astype(np.uint8), 34962, comp=5121, typ='VEC4')
    wgt = add(Wt.astype(np.float32), 34962, typ='VEC4')
    idx = add(F.astype(np.uint16 if len(V) < 65536 else np.uint32).reshape(-1), 34963, comp=5123 if len(V) < 65536 else 5125, typ='SCALAR')
    ibm = np.array([np.linalg.inv(g).T.reshape(-1) for g in G], np.float32)
    ib = add(ibm, typ='MAT4')
    img_off = sum(len(b) for b in blobs)
    jb = bytes(jpg)
    blobs.append(jb + b'\0' * ((-len(jb)) % 4))
    views.append({'buffer': 0, 'byteOffset': img_off, 'byteLength': len(jb)})
    gl = {
        'asset': {'version': '2.0', 'generator': 'tools/import_chibi.py'},
        'scene': 0, 'scenes': [{'nodes': [root]}], 'nodes': nodes,
        'meshes': [{'name': 'chibi_body', 'primitives': [{'attributes': {'POSITION': pos, 'NORMAL': nor, 'TEXCOORD_0': tex, 'COLOR_0': col, 'JOINTS_0': jnt, 'WEIGHTS_0': wgt}, 'indices': idx, 'material': 0}]}],
        'materials': [{'name': 'chibi_body', 'doubleSided': True, 'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'metallicFactor': 0, 'roughnessFactor': 0.85}}],
        'textures': [{'source': 0, 'sampler': 0}], 'samplers': [{'magFilter': 9729, 'minFilter': 9987}],
        'images': [{'bufferView': len(views) - 1, 'mimeType': 'image/jpeg', 'name': image_name}],
        'skins': [{'name': 'ChibiRig', 'joints': list(range(n)), 'inverseBindMatrices': ib}],
        'accessors': accs, 'bufferViews': views,
    }
    binary = b''.join(blobs)
    gl['buffers'] = [{'byteLength': len(binary)}]
    js = json.dumps(gl, separators=(',', ':')).encode()
    js += b' ' * ((-len(js)) % 4)
    with open(path, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(binary)))
        f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack('<II', len(binary), 0x004E4942)); f.write(binary)


def main(argv):
    cache, spec_path, name, out = argv[:4]
    preview = argv[4] if len(argv) > 4 else None
    spec = json.load(open(spec_path))
    ml = spec['models'][name]
    base_name = 'base_' + ml['base']
    bl = spec[base_name]
    import os
    here = os.path.dirname(os.path.abspath(spec_path))
    base = Base(os.path.join(here, '..', bl['glb']))
    d = np.load(cache)
    V = d['pos'].astype(float)
    # the sculpts face +X: turn to +Z, feet on 0, 1 tall (the base chibis' size)
    V = np.column_stack([-V[:, 2], V[:, 1], V[:, 0]])
    V[:, 1] -= V[:, 1].min()
    V /= V[:, 1].max()
    F = d['faces'].astype(np.int64)
    G, sim = fit(base, bl, ml, V)
    posed = pose_base(base, sim)
    # Weights live on the welded surface: the copies of a vertex on a uv seam must
    # move together, or the seams open as the body bends.
    _u, weld = np.unique(np.round(V, 6), axis=0, return_inverse=True)
    weld = weld.reshape(-1)
    first = np.zeros(weld.max() + 1, int)
    first[weld[::-1]] = np.arange(len(weld))[::-1]
    W = transfer(base, posed, V[first], weld[F], int(ml.get('smooth', 3)))
    if 'skirt' in ml:
        W, cloth = garment(W, V[first], weld[F], G, base, ml['skirt'], ml['fingertip'])
        print('%s: cloth on %d of %d welded verts' % (name, int((cloth > 0.5).sum()), len(cloth)))
    W = W[weld]
    # vertex colour R: how much may be recoloured as outfit (head, neck, hands stay)
    keep = np.zeros(len(V))
    for k, nm in enumerate(base.names):
        if nm in ('Head', 'Neck') or 'Hand' in nm or any(f in nm for f in ('Thumb', 'Index', 'Middle', 'Ring', 'Little')):
            keep += W[:, k]
    r = np.clip(1.0 - keep / np.maximum(W.sum(1), 1e-9), 0, 1)
    COL = np.column_stack([r, r, r, np.ones_like(r)])
    J, Wt = top4(W)
    # the clips key Hips at the base's place: the whole fit moves by the difference
    k_hips = base.index['Hips']
    offset = G[k_hips][:3, 3] - base.P[k_hips]
    for g in G:
        g[:3, 3] -= offset
    Vs = V - offset
    write_glb(out, base, G, offset, Vs, normals(V, F), d['uv'], F, J, Wt, COL, d['jpg'], 'basecolor')
    print('%s: %d verts %d tris, offset %s' % (name, len(V), len(F), np.round(offset, 3)))
    if preview:
        np.savez_compressed(preview, V=Vs, F=F, J=J, W=Wt, G=np.array(G), names=np.array(base.names), posed=posed, base_F=base.F, offset=offset)
