"""Skin weights of a legend summon (the weighting of build_rig.py, with a bending weapon).

Every vertex takes up to four bones by distance to the bone segments, smoothed over the
mesh so cloth bends instead of tearing. The weapon is one piece with the body: its upper
part moves rigidly with the chest (it is held there), its lower part blends into whatever
it touches (the hand, the cloth, the foot and the ground), so a lean or a slam flexes the
weapon a little along its length instead of ripping it from the cloth it is fused to.
"""
import numpy as np
from scipy.sparse import coo_matrix


def bones_of(spec):
    """[(name, parent, head, tail)] in the spec's height-1 space (tail None = not skinned)."""
    J = {k: np.array(v, float) for k, v in spec["joints"].items()}

    def tip(a, b, k=0.5):
        return J[a] + (J[a] - J[b]) * k

    bones = [
        ("Root", None, np.zeros(3), None),
        ("Hips", "Root", J["hips"], J["spine"]),
        ("Spine", "Hips", J["spine"], J["chest"]),
        ("Chest", "Spine", J["chest"], J["neck"]),
        ("Neck", "Chest", J["neck"], J["head"]),
        ("Head", "Neck", J["head"], J["head"] + np.array([0, spec.get("head_len", 0.13), 0])),
    ]
    for s in ("R", "L"):
        bones += [
            (f"{s}_UpperArm", "Chest", J[f"{s}_shoulder"], J[f"{s}_elbow"]),
            (f"{s}_Forearm", f"{s}_UpperArm", J[f"{s}_elbow"], J[f"{s}_hand"]),
            (f"{s}_Hand", f"{s}_Forearm", J[f"{s}_hand"], tip(f"{s}_hand", f"{s}_elbow", 0.35)),
            (f"{s}_Thigh", "Hips", J[f"{s}_hip"], J[f"{s}_knee"]),
            (f"{s}_Shin", f"{s}_Thigh", J[f"{s}_knee"], J[f"{s}_ankle"]),
            (f"{s}_Foot", f"{s}_Shin", J[f"{s}_ankle"], J[f"{s}_ankle"] + np.array([0, -0.05, 0.08])),
        ]
    return bones


def seg_dist(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)


def compute(V, F, spec):
    """(JOINTS uint16 [n,4], WEIGHTS float32 [n,4], weapon mask, weapon t along the shaft)."""
    bones = bones_of(spec)
    index = {b[0]: i for i, b in enumerate(bones)}
    # The hands and feet of these robed gods are folds of cloth, not free limbs: they are
    # skinned as the end of the forearm / shin, so fewer bones compete over the robe and
    # the top-four cut below never flips between neighbours.
    segs = {}
    for name, parent, head, tail in bones:
        if tail is None:
            continue
        if name.endswith("_Hand") or name.endswith("_Foot"):
            segs[parent] = (segs[parent][0], tail)
        else:
            segs[name] = (head, tail)
    skinned = [index[n] for n in segs]
    D = np.stack([seg_dist(V, *segs[bones[i][0]]) for i in skinned], 1)
    W = 1.0 / (D ** 2 + 2e-4) ** 1.5
    order = np.argsort(-W, 1)[:, :4]
    Wk = np.take_along_axis(W, order, 1)
    Wk /= Wk.sum(1, keepdims=True)
    full = np.zeros((len(V), len(bones)))
    for c in range(4):
        full[np.arange(len(V)), np.array(skinned)[order[:, c]]] += Wk[:, c]
    # Smooth over the welded surface: the atlas split most vertices at UV seams, and a
    # seam copy that smoothed differently from its twin would open a crack in every pose.
    _, uid = np.unique(np.round(V, 5), axis=0, return_inverse=True)
    uid = uid.ravel()
    n = int(uid.max()) + 1
    rows = uid[np.concatenate([F[:, 0], F[:, 1], F[:, 2], F[:, 1], F[:, 2], F[:, 0]])]
    cols = uid[np.concatenate([F[:, 1], F[:, 2], F[:, 0], F[:, 0], F[:, 1], F[:, 2]])]
    A = coo_matrix((np.ones(len(rows)), (rows, cols)), shape=(n, n)).tocsr()
    A.data[:] = 1.0
    deg = np.asarray(A.sum(1)).ravel() + 1e-9
    count = np.bincount(uid, minlength=n)[:, None]

    def smooth(w, k):
        u = np.zeros((n, w.shape[1]))
        np.add.at(u, uid, w)
        u /= count
        for _ in range(k):
            u = 0.5 * u + 0.5 * (A @ u) / deg[:, None]
        return u[uid]

    full = smooth(full, int(spec.get("smooth", 8)))
    # The weapon: rigid with the chest at the top, blending into its surroundings lower down.
    wp = spec["weapon"]
    a, b = np.array(wp["top"], float), np.array(wp["bottom"], float)
    ab = b - a
    tt = np.clip(((V - a) @ ab) / (ab @ ab), 0, 1)
    rad = np.where(tt < wp.get("head_frac", 0.18), wp.get("head_radius", 0.07), wp["radius"])
    weapon = seg_dist(V, a, b) < rad
    blend = np.clip((tt - float(wp.get("bend_from", 0.5))) / max(float(wp.get("bend_to", 0.95)) - float(wp.get("bend_from", 0.5)), 1e-6), 0, 1)
    blend = blend * blend * (3 - 2 * blend)
    rigid = np.zeros(len(bones))
    rigid[index[spec.get("weapon_bone", "Chest")]] = 1.0
    full[weapon] = (1 - blend[weapon])[:, None] * rigid[None, :] + blend[weapon][:, None] * full[weapon]
    # The upper weapon stays exactly rigid; only its lower part and the cloth around it blend.
    hold = weapon & (blend < 0.02)
    for _ in range(3):
        nxt = smooth(full, 1)
        nxt[hold] = full[hold]
        full = nxt
    # Four bones per vertex, then two more smoothing passes restricted to each vertex's
    # own four, so the cut itself leaves no step between neighbours.
    order = np.argsort(-full, 1)[:, :4]
    mask = np.zeros_like(full, dtype=bool)
    np.put_along_axis(mask, order, True, 1)
    cut = np.where(mask, full, 0.0)
    cut /= np.maximum(cut.sum(1, keepdims=True), 1e-9)
    for _ in range(2):
        nxt = np.where(mask, smooth(cut, 1), 0.0)
        nxt[hold] = cut[hold]
        cut = nxt / np.maximum(nxt.sum(1, keepdims=True), 1e-9)
    WW = np.take_along_axis(cut, order, 1)
    WW = np.where(WW < 0.01, 0, WW)
    WW /= WW.sum(1, keepdims=True)
    return order.astype(np.uint16), WW.astype(np.float32), weapon, tt
