"""Skin weights of a legend summon: body parts, seams and smooth joints.

The decimated legends are one fused surface: the free hand is welded to the robe at the
hip, the staff to the cloth at the feet, the legs to each other. Weights alone cannot let
those parts move apart (whatever bridges them stretches like a web), so the rig works in
three steps:

1. Parts. Every triangle gets the bone that dominates it (distance to the bone segments,
   smoothed over the welded surface); the weapon is its own part, held by the hand.
   Islands too small to be a real part (a scrap of robe that happens to pass the forearm)
   join the part around them, so each part is one solid piece.
2. Seams. Two parts that do not share a joint (the forearm and the robe at the hip, the
   staff and the cloth at the feet, the two legs, a hand and the head) are cut apart at
   the vertices they share: those vertices are doubled, one copy per side. The triangle
   count does not change; the parts simply stop being glued where the decimation welded
   them. Parts that do share a joint (shoulder, elbow, wrist, hip, knee, ankle, neck, the
   whole torso, the robe from the hips down to the shins) stay one surface.
3. Weights. Per side of every seam, each vertex takes the bones its part may bend with,
   by distance, then smoothed over the cut surface many times (a heat-diffusion-like
   falloff), so a joint bends over a wide band instead of a crease. The weapon stays rigid
   in the hand. Four bones per vertex, renormalised, with a last restricted smoothing so the
   four-bone cut leaves no step.

compute() returns the new vertex list (as indices into the input vertices), the re-indexed
faces, the four joints and weights per new vertex and a few diagnostics.
"""
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

TORSO = ("Hips", "Spine", "Chest", "Neck", "Head")


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
    # Secondary bones (tail, hair, robe tails): chains hung from a body bone, driven by
    # the clips with lagging sway. Each claims the surface within its radius.
    for x in spec.get("extra", []):
        bones.append((x["name"], x["parent"], np.array(x["head"], float), np.array(x["tail"], float)))
    return bones


def seg_dist(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)


def _parents(bones):
    return {b[0]: b[1] for b in bones}


def joined(a, b, parent):
    """True when parts a and b may stay one surface (they bend at a shared joint)."""
    if a == b:
        return True
    if a in TORSO and b in TORSO:
        return True
    if parent.get(a) == b or parent.get(b) == a:
        return True
    pair = {a, b}
    for s in ("L", "R"):
        # the armpit, the collar, a robe hanging from the hips over the shin, the belt line
        if pair in ({f"{s}_UpperArm", "Spine"}, {f"{s}_UpperArm", "Neck"}, {f"{s}_Shin", "Hips"},
                    {f"{s}_Thigh", "Spine"}):
            return True
        # within one limb, two joints apart (a sleeve over the wrist, a boot over the knee)
        if pair in ({f"{s}_UpperArm", f"{s}_Hand"}, {f"{s}_Thigh", f"{s}_Foot"}):
            return True
    return False


def compute(V, F, spec):
    """dict(src, F, J, W, weapon, labels, seams): the new vertices as indices into V, the
    re-indexed faces, JOINTS uint16 [n,4] and WEIGHTS float32 [n,4] per new vertex, the
    weapon mask (per new vertex), the part (bone index) of every face, and the seam count."""
    F = np.asarray(F, np.int64)
    bones = bones_of(spec)
    names = [b[0] for b in bones]
    index = {n: i for i, n in enumerate(names)}
    parent = _parents(bones)
    nb = len(bones)
    # Welded surface: the atlas split vertices at UV seams; all graph work is on positions.
    _, uid = np.unique(np.round(V, 5), axis=0, return_inverse=True)
    uid = uid.ravel()
    n = int(uid.max()) + 1
    P = np.zeros((n, 3))
    P[uid] = V
    FU = uid[F]

    def graph(Fx, count):
        r = np.concatenate([Fx[:, 0], Fx[:, 1], Fx[:, 2], Fx[:, 1], Fx[:, 2], Fx[:, 0]])
        c = np.concatenate([Fx[:, 1], Fx[:, 2], Fx[:, 0], Fx[:, 0], Fx[:, 1], Fx[:, 2]])
        A = coo_matrix((np.ones(len(r)), (r, c)), shape=(count, count)).tocsr()
        A.data[:] = 1.0
        return A, np.asarray(A.sum(1)).ravel() + 1e-9

    A, deg = graph(FU, n)

    # ---- 1. distance weights per welded vertex, smoothed: the parts ----
    segs = [(i, b[2], b[3]) for i, b in enumerate(bones) if b[3] is not None]
    skinned = np.array([s[0] for s in segs])
    D = np.stack([seg_dist(P, s[1], s[2]) for s in segs], 1)
    radius = np.full(len(segs), 9.0)
    for k, s in enumerate(segs):
        for x in spec.get("extra", []):
            if x["name"] == names[s[0]]:
                radius[k] = float(x.get("radius", 0.05))
    # an extra bone claims only what lies within its radius
    D = np.where(D > radius[None, :], D + 1.0, D)
    W = np.zeros((n, nb))
    W[:, skinned] = 1.0 / (D ** 2 + 2e-4) ** 1.5
    W /= W.sum(1, keepdims=True)
    for _ in range(4):
        W = 0.5 * W + 0.5 * (A @ W) / deg[:, None]
    # The weapon: its own part, rigid in the holding hand.
    wp = spec["weapon"]
    a, b = np.array(wp["top"], float), np.array(wp["bottom"], float)
    ab = b - a
    tt = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
    rad = np.where(tt < wp.get("head_frac", 0.18), wp.get("head_radius", 0.07), wp["radius"])
    weapon_w = seg_dist(P, a, b) < rad
    hand = index[spec.get("weapon_bone", "R_Hand")]
    # Limbs claim only the surface near their bone (spec "core": radius per limb bone, in
    # height-1 units): a robe, a scarf or a skirt panel farther out belongs to the torso
    # and bends smoothly with the limbs under it instead of riding one of them rigidly.
    core = spec.get("core", {})
    Wl = W.copy()
    Dfull = np.full((n, nb), 9.0)
    Dfull[:, skinned] = D
    for i, nm in enumerate(names):
        r = core.get(nm.split("_", 1)[-1])
        if r is not None and nm not in TORSO:
            Wl[Dfull[:, i] > float(r), i] = 0.0
    tor = np.array([nm in TORSO for nm in names])
    none = Wl.sum(1) < 1e-9
    Wl[none] = W[none] * tor
    face_w = Wl[FU].sum(1)
    lab = np.argmax(face_w, 1)
    lab[weapon_w[FU].all(1)] = hand
    is_weapon_face = weapon_w[FU].all(1)

    # Faces adjacent through an edge, for cleaning the parts.
    nf = len(F)
    e = np.concatenate([FU[:, [0, 1]], FU[:, [1, 2]], FU[:, [2, 0]]])
    e.sort(1)
    fid = np.tile(np.arange(nf), 3)
    key = e[:, 0] * n + e[:, 1]
    o = np.argsort(key)
    ks, fs = key[o], fid[o]
    same = ks[1:] == ks[:-1]
    fa, fb = fs[:-1][same], fs[1:][same]
    FA = coo_matrix((np.ones(len(fa) * 2), (np.concatenate([fa, fb]), np.concatenate([fb, fa]))), shape=(nf, nf)).tocsr()

    # Majority smoothing of the parts (not the weapon), then islands below min_part
    # triangles join their neighbours.
    min_part = int(spec.get("min_part", 60))
    for _ in range(int(spec.get("vote_passes", 3))):
        votes = np.zeros((nf, nb))
        np.add.at(votes, (np.arange(nf), lab), 1.5)
        nbr = FA.tocoo()
        np.add.at(votes, (nbr.row, lab[nbr.col]), 1.0)
        new = np.argmax(votes, 1)
        new[is_weapon_face] = hand
        lab = new
    for _ in range(6):
        changed = False
        # components of same-label faces
        m = lab[fa] == lab[fb]
        G = coo_matrix((np.ones(m.sum()), (fa[m], fb[m])), shape=(nf, nf))
        k, comp = connected_components(G, directed=False)
        size = np.bincount(comp, minlength=k)
        small = size[comp] < min_part
        if not small.any():
            break
        # each small face takes the most common label among its neighbours in other components
        nbr = FA.tocoo()
        votes = np.zeros((nf, nb))
        other = comp[nbr.row] != comp[nbr.col]
        np.add.at(votes, (nbr.row[other], lab[nbr.col[other]]), 1.0)
        # relabel whole small components by their summed border votes
        cv = np.zeros((k, nb))
        np.add.at(cv, comp, votes)
        cbest = np.argmax(cv, 1)
        sel = small & (cv[comp].sum(1) > 0) & ~is_weapon_face
        if sel.any():
            lab[sel] = cbest[comp[sel]]
            changed = True
        if not changed:
            break

    # ---- 2. seams: per welded vertex, the parts around it grouped by joints ----
    JOIN = np.zeros((nb, nb), bool)
    for i in range(nb):
        for j in range(nb):
            JOIN[i, j] = joined(names[i], names[j], parent)
    # An upper arm and the torso share a joint only at the shoulder: below it (a sleeve
    # lying against the ribs, an elbow against the robe) they are cut apart.
    sh_r = float(spec.get("shoulder_radius", 0.09))
    tor_idx = [index[nm] for nm in TORSO]
    arm_far = {}
    for s_ in ("L", "R"):
        ua = index[f"{s_}_UpperArm"]
        arm_far[ua] = np.linalg.norm(P - bones[ua][2], axis=1) > sh_r
    corner_w = FU.ravel()                      # welded vertex of each corner
    corner_lab = np.repeat(lab, 3)
    order = np.lexsort((corner_lab, corner_w))
    cw, cl = corner_w[order], corner_lab[order]
    node_of_corner = np.empty(len(corner_w), np.int64)
    nodes_w, nodes_labels = [], []
    i = 0
    seams = 0
    while i < len(cw):
        j = i
        while j < len(cw) and cw[j] == cw[i]:
            j += 1
        # Every pair in a group must share a joint (no chains: forearm - upper arm -
        # spine - hips would glue an elbow to the robe at the hip). The parts with the most
        # corners here pick first.
        lab_here, counts = np.unique(cl[i:j], return_counts=True)
        labels = [int(x) for x in lab_here[np.argsort(-counts, kind="stable")]]
        w_here = cw[i]
        JN = JOIN
        far_here = [ua for ua, far in arm_far.items() if far[w_here]]
        if far_here and len(labels) > 1:
            JN = JOIN.copy()
            for ua in far_here:
                JN[ua, tor_idx] = False
                JN[tor_idx, ua] = False
        groups = []
        for L in labels:
            for g in groups:
                if all(JN[L, x] for x in g):
                    g.add(L)
                    break
            else:
                groups.append({L})
        if len(groups) > 1:
            seams += 1
        gid = {}
        for g in groups:
            nid = len(nodes_w)
            nodes_w.append(cw[i])
            nodes_labels.append(g)
            for L in g:
                gid[L] = nid
        for k2 in range(i, j):
            node_of_corner[order[k2]] = gid[cl[k2]]
        i = j
    nn = len(nodes_w)
    nodes_w = np.array(nodes_w)
    FN = node_of_corner.reshape(-1, 3)
    # bones each node may bend with: its parts and every bone joined to them
    allowed = np.zeros((nn, nb), bool)
    for k2, g in enumerate(nodes_labels):
        for L in g:
            allowed[k2] |= JOIN[L]
    allowed[:, index["Root"]] = False
    # A torso surface borrows the upper arm only around the shoulder (a little wider than
    # the seam, so the blend fades across the shoulder instead of stepping): the robe at
    # the waist beside a hanging arm must not follow the arm when it rises overhead.
    PW = P[np.array(nodes_w)]
    for s in ("L", "R"):
        ua = index[f"{s}_UpperArm"]
        far = np.linalg.norm(PW - bones[ua][2], axis=1) > sh_r * float(spec.get("shoulder_blend", 1.6))
        own_arm = np.array([ua in g for g in nodes_labels])
        allowed[far & ~own_arm, ua] = False
    # Whatever belongs to the hand's part but lies away from the hand itself (the rest of
    # the weapon's surface, scraps welded to it) is rigid in the hand: an arm weight far
    # down a 3 m staff would bend the staff.
    hb = bones[hand]
    far_hand = np.array([g == {hand} for g in nodes_labels]) & (seg_dist(P[nodes_w], hb[2], hb[3]) > float(spec.get("hand_radius", 0.08)))
    allowed[far_hand] = False
    allowed[far_hand, hand] = True

    # ---- 3. weights on the cut surface ----
    AN, degn = graph(FN, nn)
    PN = P[nodes_w]
    Wn = np.zeros((nn, nb))
    Wn[:, skinned] = 1.0 / (np.stack([seg_dist(PN, s[1], s[2]) for s in segs], 1) ** 2 + 2e-4) ** 1.5
    # extra bones reach only their radius
    for k, s in enumerate(segs):
        if radius[k] < 9.0:
            far = seg_dist(PN, s[1], s[2]) > radius[k]
            Wn[far, s[0]] = 0.0
    Wn *= allowed
    # a vertex whose part is a bone takes at least a share of that bone
    own = np.zeros((nn, nb))
    for k2, g in enumerate(nodes_labels):
        for L in g:
            own[k2, L] = 1.0
    Wn = Wn / np.maximum(Wn.sum(1, keepdims=True), 1e-12)
    Wn = 0.6 * Wn + 0.4 * own / own.sum(1, keepdims=True)
    weapon_n = np.zeros(nn, bool)
    for k2, g in enumerate(nodes_labels):
        if g == {hand} and weapon_w[nodes_w[k2]]:
            weapon_n[k2] = True
    rigid = np.zeros(nb)
    rigid[hand] = 1.0
    Wn[weapon_n] = rigid
    for _ in range(int(spec.get("smooth", 14))):
        nxt = 0.5 * Wn + 0.5 * (AN @ Wn) / degn[:, None]
        nxt *= allowed
        nxt /= np.maximum(nxt.sum(1, keepdims=True), 1e-12)
        nxt[weapon_n] = rigid
        Wn = nxt
    # Cloth: the robe, skirt and scarves (torso parts away from the torso bones) relax
    # towards harmonic weights between the limbs and the body that hold them, so legs that
    # stride apart spread the stretch over the whole panel instead of one crease.
    cloth_iters = int(spec.get("cloth_smooth", 0))
    if cloth_iters:
        tor_i = [index[nm] for nm in TORSO]
        near_body = np.min(np.stack([seg_dist(PN, bones[i][2], bones[i][3]) for i in tor_i], 1), 1) < float(spec.get("body_radius", 0.09))
        cloth_n = np.array([g <= set(tor_i) for g in nodes_labels]) & ~near_body & ~weapon_n
        for _ in range(cloth_iters):
            nxt = (AN @ Wn) / degn[:, None]
            nxt *= allowed
            nxt /= np.maximum(nxt.sum(1, keepdims=True), 1e-12)
            Wn[cloth_n] = nxt[cloth_n]
    order4 = np.argsort(-Wn, 1)[:, :4]
    mask = np.zeros_like(Wn, bool)
    np.put_along_axis(mask, order4, True, 1)
    cut = np.where(mask, Wn, 0.0)
    cut /= np.maximum(cut.sum(1, keepdims=True), 1e-9)
    for _ in range(2):
        nxt = np.where(mask, 0.5 * cut + 0.5 * (AN @ cut) / degn[:, None], 0.0)
        nxt[weapon_n] = cut[weapon_n]
        cut = nxt / np.maximum(nxt.sum(1, keepdims=True), 1e-9)
    WW = np.take_along_axis(cut, order4, 1)
    WW = np.where(WW < 0.01, 0, WW)
    WW /= WW.sum(1, keepdims=True)
    JJ = order4

    # ---- output vertices: one per (input vertex, node) actually used ----
    pair = np.stack([F.ravel(), FN.ravel()], 1)
    upair, inv = np.unique(pair, axis=0, return_inverse=True)
    inv = inv.ravel()
    src = upair[:, 0]
    node = upair[:, 1]
    return {
        "src": src, "F": inv.reshape(-1, 3).astype(np.uint32),
        "J": JJ[node].astype(np.uint16), "W": WW[node].astype(np.float32),
        "weapon": weapon_n[node], "labels": lab, "names": names, "seams": seams,
        "node": node,
    }
