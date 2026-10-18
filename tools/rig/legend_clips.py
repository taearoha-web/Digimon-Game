"""Clips of the legend summons (Wind Monkey King, Poseidon) and a rig check.

The models are one fused surface: cloth, ribbons and the weapon touch everywhere,
and the weapon is skinned to the chest. Every clip therefore moves the body as a
whole (hips, spine, chest, head) and keeps the weapon arm within a few degrees of
the chest, so nothing pulls the cloth away from the weapon. The free (left) arm
gestures, the head looks. check_stretch() skins every clip at several times and
measures how much each mesh edge stretches or squashes: the proof that no pose
tears the surface.

Clips (MonsterVisual keys in brackets):
  Idle [idle]   Walk [walk]   Run [run]   Attack [attack]   HitReact [hurt]   Death [die]
  Skill1 [skill1]   Skill2 [skill2]
    staff   (Wind Monkey King): Skill1 = whirlwind spin, Skill2 = staff slam into the ground
    trident (Poseidon):         Skill1 = maelstrom sweep,  Skill2 = trident slam (ice crystals)
"""
import math
import numpy as np

TAU = 2 * math.pi


def q_axis(axis, deg):
    ax = np.array(axis, float)
    ax /= np.linalg.norm(ax)
    h = math.radians(deg) / 2
    return np.array([*(ax * math.sin(h)), math.cos(h)])


def q_mul(a, b):
    x1, y1, z1, w1 = a
    x2, y2, z2, w2 = b
    return np.array([w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2, w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
                     w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2, w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2])


def q_euler(x=0, y=0, z=0):
    """Degrees, applied X then Y then Z in world-ish axes (the rig's rest is identity)."""
    return q_mul(q_axis([0, 0, 1], z), q_mul(q_axis([0, 1, 0], y), q_axis([1, 0, 0], x)))


def ease(x):
    return x * x * (3 - 2 * x)


def keys(points):
    """[(u, value), ...] -> piecewise smooth function of u in 0..1."""
    def f(u):
        for (u0, v0), (u1, v1) in zip(points, points[1:]):
            if u <= u1:
                k = ease((u - u0) / max(u1 - u0, 1e-9))
                return np.array(v0, float) * (1 - k) + np.array(v1, float) * k
        return np.array(points[-1][1], float)
    return f


class Clip:
    def __init__(self, name, length, loop, fps=30):
        self.name, self.length, self.loop, self.fps = name, length, loop, fps
        self.rot, self.tr = {}, {}

    def _times(self):
        n = int(round(self.length * self.fps)) + 1
        return np.linspace(0, self.length, n)

    def rotate(self, bone, fn):
        ts = self._times()
        self.rot[bone] = (ts, np.array([fn(t / self.length) for t in ts]))

    def move(self, bone, fn):
        ts = self._times()
        self.tr[bone] = (ts, np.array([fn(t / self.length) for t in ts]))


def author(style, hips, arm_cap=12.0, fore_cap=8.0):
    """All clips for one legend. `style` is "staff" or "trident"; `hips` the rest hips joint.
    arm_cap / fore_cap: how far (degrees) the free arm and its forearm may turn."""
    hips = np.array(hips, float)
    clips = {}

    def new(name, length, loop):
        c = Clip(name, length, loop)
        clips[name] = c
        return c

    def xy(k):
        return q_euler(x=k[0], y=k[1])

    def xz(k):
        return q_euler(x=k[0], z=k[1])

    # The free arm is a fold of the robe fused to the leg: it gestures within ARM degrees.
    ARM = float(arm_cap)
    FORE = float(fore_cap)

    def arm(k):
        k = np.array(k, float)
        m = max(abs(k[0]), abs(k[1]), 1e-9)
        return xz(k * min(1.0, ARM / m))

    def fore(v):
        return q_euler(x=max(-FORE, min(FORE, float(v))))

    # Idle: hover, breathing, a slow look around, the free arm sways.
    c = new("Idle", 3.2, True)
    c.move("Hips", lambda u: hips + np.array([0, 0.014 * math.sin(u * TAU), 0]))
    c.rotate("Hips", lambda u: q_euler(y=2.0 * math.sin(u * TAU * 0.5), z=0.8 * math.sin(u * TAU)))
    c.rotate("Spine", lambda u: q_euler(x=1.2 * math.sin(u * TAU)))
    c.rotate("Chest", lambda u: q_euler(x=1.5 * math.sin(u * TAU + 0.6)))
    c.rotate("Head", lambda u: q_euler(x=-2.0 * math.sin(u * TAU + 1.0), y=7.0 * math.sin(u * TAU * 0.5)))
    c.rotate("L_UpperArm", lambda u: arm([-4.0 * math.sin(u * TAU + 0.4), 3.0 * math.sin(u * TAU)]))
    c.rotate("R_UpperArm", lambda u: q_euler(x=-1.0 * math.sin(u * TAU + 0.9)))

    # Walk / Run: a god glides, leaning into the motion and swaying.
    for name, length, amp in (("Walk", 1.4, 1.0), ("Run", 1.0, 1.6)):
        c = new(name, length, True)
        c.move("Hips", lambda u, a=amp: hips + np.array([0, 0.02 + 0.010 * a * math.sin(u * TAU * 2), 0]))
        c.rotate("Hips", lambda u, a=amp: q_euler(x=5 * a, y=3 * math.sin(u * TAU), z=1.5 * math.sin(u * TAU)))
        c.rotate("Chest", lambda u, a=amp: q_euler(x=1.5 * a, y=-2 * math.sin(u * TAU)))
        c.rotate("Head", lambda u, a=amp: q_euler(x=-4 * a))
        c.rotate("L_UpperArm", lambda u, a=amp: arm([-3.5 * a * math.sin(u * TAU), 2.5 * a]))

    if style == "staff":
        # Attack: a horizontal staff sweep carried by the whole body (turn, lean, step).
        c = new("Attack", 0.8, False)
        c.rotate("Hips", lambda u: xy(keys([(0, [0, 0]), (0.3, [-5, -26]), (0.5, [9, 24]), (0.75, [4, 8]), (1, [0, 0])])(u)))
        c.move("Hips", lambda u: hips + np.array([0, keys([(0, 0), (0.3, 0.03), (0.5, -0.02), (1, 0)])(u), keys([(0, 0), (0.3, -0.03), (0.5, 0.06), (1, 0)])(u)]))
        c.rotate("Chest", lambda u: xy(keys([(0, [0, 0]), (0.3, [-4, -8]), (0.5, [5, 8]), (1, [0, 0])])(u)))
        c.rotate("Head", lambda u: q_euler(y=keys([(0, 0), (0.3, 14), (0.5, -10), (1, 0)])(u)))
        c.rotate("L_UpperArm", lambda u: arm(keys([(0, [0, 0]), (0.3, [-20, 32]), (0.5, [-30, 14]), (1, [0, 0])])(u)))
        c.rotate("L_Forearm", lambda u: fore(keys([(0, 0), (0.3, -14), (0.5, -6), (1, 0)])(u)))
        c.rotate("R_UpperArm", lambda u: q_euler(x=keys([(0, 0), (0.3, 4), (0.5, -7), (1, 0)])(u)))
        # Skill1 "whirlwind": the whole body spins once with the staff out, rising a little.
        c = new("Skill1", 1.1, False)
        c.rotate("Hips", lambda u: q_euler(x=float(keys([(0, 0), (0.25, -6), (0.8, -4), (1, 0)])(u)), y=float(keys([(0, 0), (0.2, -20), (0.85, 340), (1, 360)])(u))))
        c.move("Hips", lambda u: hips + np.array([0, keys([(0, 0), (0.25, 0.06), (0.8, 0.05), (1, 0)])(u), 0]))
        c.rotate("Chest", lambda u: q_euler(x=keys([(0, 0), (0.25, -5), (0.8, -3), (1, 0)])(u)))
        c.rotate("Head", lambda u: q_euler(x=keys([(0, 0), (0.25, -8), (0.8, -6), (1, 0)])(u)))
        c.rotate("L_UpperArm", lambda u: arm(keys([(0, [0, 0]), (0.25, [-30, 42]), (0.8, [-28, 40]), (1, [0, 0])])(u)))
        c.rotate("L_Forearm", lambda u: fore(keys([(0, 0), (0.25, -12), (0.8, -12), (1, 0)])(u)))
        c.rotate("R_UpperArm", lambda u: q_euler(x=keys([(0, 0), (0.25, -6), (0.8, -6), (1, 0)])(u)))
        # Skill2 "staff slam": rear back lifting the staff's foot, then drive the whole body down.
        c = new("Skill2", 1.2, False)
        c.rotate("Hips", lambda u: q_euler(x=keys([(0, 0), (0.35, -7), (0.5, 11), (0.65, 9), (1, 0)])(u)))
        c.move("Hips", lambda u: hips + np.array([0, keys([(0, 0), (0.35, 0.07), (0.5, -0.07), (0.65, -0.06), (1, 0)])(u), keys([(0, 0), (0.35, -0.04), (0.5, 0.09), (0.65, 0.08), (1, 0)])(u)]))
        c.rotate("Spine", lambda u: q_euler(x=keys([(0, 0), (0.35, -6), (0.5, 4), (0.65, 4), (1, 0)])(u)))
        c.rotate("Chest", lambda u: q_euler(x=keys([(0, 0), (0.35, -12), (0.5, 8), (0.65, 7), (1, 0)])(u)))
        c.rotate("Head", lambda u: q_euler(x=keys([(0, 0), (0.35, -10), (0.5, 10), (0.65, 8), (1, 0)])(u)))
        c.rotate("L_UpperArm", lambda u: arm(keys([(0, [0, 0]), (0.35, [-50, 24]), (0.5, [-10, 8]), (0.65, [-8, 8]), (1, [0, 0])])(u)))
        c.rotate("L_Forearm", lambda u: fore(keys([(0, 0), (0.35, -20), (0.5, -4), (1, 0)])(u)))
        c.rotate("R_UpperArm", lambda u: q_euler(x=keys([(0, 0), (0.35, 5), (0.5, -8), (0.65, -7), (1, 0)])(u)))
    else:
        # Attack: gather (lean back, rise, free arm lifts), then a forward thrust with the trident.
        c = new("Attack", 0.8, False)
        c.rotate("Hips", lambda u: xy(keys([(0, [0, 0]), (0.38, [-7, 10]), (0.55, [13, -6]), (0.8, [5, -2]), (1, [0, 0])])(u)))
        c.move("Hips", lambda u: hips + np.array([0, keys([(0, 0), (0.38, 0.035), (0.55, -0.01), (1, 0)])(u), keys([(0, 0), (0.38, -0.02), (0.55, 0.06), (1, 0)])(u)]))
        c.rotate("Chest", lambda u: q_euler(x=keys([(0, 0), (0.38, -3), (0.55, 4), (1, 0)])(u)))
        c.rotate("Head", lambda u: q_euler(x=keys([(0, 0), (0.38, -6), (0.55, 6), (1, 0)])(u)))
        c.rotate("L_UpperArm", lambda u: arm(keys([(0, [0, 0]), (0.38, [-25, 30]), (0.55, [-45, 10]), (1, [0, 0])])(u)))
        c.rotate("L_Forearm", lambda u: fore(keys([(0, 0), (0.38, -15), (0.55, -5), (1, 0)])(u)))
        c.rotate("R_UpperArm", lambda u: q_euler(x=keys([(0, 0), (0.38, 3), (0.55, -6), (1, 0)])(u)))
        # Skill1 "maelstrom": raise the trident high, then a wide twisting sweep that stirs the sea.
        c = new("Skill1", 1.2, False)
        c.rotate("Hips", lambda u: xy(keys([(0, [0, 0]), (0.3, [-8, 0]), (0.5, [-4, 42]), (0.75, [2, -38]), (1, [0, 0])])(u)))
        c.move("Hips", lambda u: hips + np.array([0, keys([(0, 0), (0.3, 0.09), (0.5, 0.07), (0.75, 0.04), (1, 0)])(u), 0]))
        c.rotate("Spine", lambda u: q_euler(x=keys([(0, 0), (0.3, -6), (0.5, -3), (1, 0)])(u)))
        c.rotate("Chest", lambda u: xy(keys([(0, [0, 0]), (0.3, [-10, 0]), (0.5, [-6, 6]), (0.75, [-2, -6]), (1, [0, 0])])(u)))
        c.rotate("Head", lambda u: q_euler(x=keys([(0, 0), (0.3, -14), (0.5, -8), (1, 0)])(u)))
        c.rotate("L_UpperArm", lambda u: arm(keys([(0, [0, 0]), (0.3, [-55, 30]), (0.5, [-50, 26]), (0.75, [-30, 16]), (1, [0, 0])])(u)))
        c.rotate("L_Forearm", lambda u: fore(keys([(0, 0), (0.3, -18), (0.75, -8), (1, 0)])(u)))
        c.rotate("R_UpperArm", lambda u: q_euler(x=keys([(0, 0), (0.3, -8), (0.5, -6), (1, 0)])(u)))
        # Skill2 "glacial slam": rear back, then drive the trident's foot into the ground and hold while ice forms.
        c = new("Skill2", 1.3, False)
        c.rotate("Hips", lambda u: q_euler(x=keys([(0, 0), (0.33, -7), (0.48, 11), (0.7, 9), (1, 0)])(u)))
        c.move("Hips", lambda u: hips + np.array([0, keys([(0, 0), (0.33, 0.08), (0.48, -0.07), (0.7, -0.06), (1, 0)])(u), keys([(0, 0), (0.33, -0.04), (0.48, 0.09), (0.7, 0.08), (1, 0)])(u)]))
        c.rotate("Spine", lambda u: q_euler(x=keys([(0, 0), (0.33, -6), (0.48, 4), (0.7, 4), (1, 0)])(u)))
        c.rotate("Chest", lambda u: q_euler(x=keys([(0, 0), (0.33, -12), (0.48, 8), (0.7, 7), (1, 0)])(u)))
        c.rotate("Head", lambda u: q_euler(x=keys([(0, 0), (0.33, -10), (0.48, 10), (0.7, 8), (1, 0)])(u)))
        c.rotate("L_UpperArm", lambda u: arm(keys([(0, [0, 0]), (0.33, [-50, 24]), (0.48, [-10, 8]), (0.7, [-8, 8]), (1, [0, 0])])(u)))
        c.rotate("L_Forearm", lambda u: fore(keys([(0, 0), (0.33, -20), (0.48, -4), (1, 0)])(u)))
        c.rotate("R_UpperArm", lambda u: q_euler(x=keys([(0, 0), (0.33, 5), (0.48, -8), (0.7, -7), (1, 0)])(u)))

    # Hit: rock back and recover.
    c = new("HitReact", 0.45, False)
    c.rotate("Hips", lambda u: q_euler(x=keys([(0, 0), (0.25, -8), (1, 0)])(u)))
    c.rotate("Head", lambda u: q_euler(x=keys([(0, 0), (0.25, -8), (1, 0)])(u)))
    c.move("Hips", lambda u: hips + np.array([0, 0, keys([(0, 0), (0.25, -0.03), (1, 0)])(u)]))

    # Death: sink and fade back.
    c = new("Death", 1.2, False)
    c.rotate("Hips", lambda u: q_euler(x=keys([(0, 0), (1, -25)])(u)))
    c.move("Hips", lambda u: hips + np.array([0, keys([(0, 0), (1, -0.2)])(u), keys([(0, 0), (1, -0.08)])(u)]))
    return clips


# ---------------- rig check: skin every clip and measure the surface ----------------

def q_to_m(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def _sample(track, t):
    ts, vals = track
    i = int(np.searchsorted(ts, t, side="right")) - 1
    i = max(0, min(i, len(ts) - 2))
    k = (t - ts[i]) / max(ts[i + 1] - ts[i], 1e-9)
    return vals[i] * (1 - k) + vals[i + 1] * k


def pose_vertices(V, JJ, WW, bones, clip, t):
    """Skinned vertex positions of one clip at time t. bones: [(name, parent, head)]."""
    index = {b[0]: i for i, b in enumerate(bones)}
    G = [None] * len(bones)
    for i, (name, parent, head) in enumerate(bones):
        local_t = head - (bones[index[parent]][2] if parent else np.zeros(3))
        if name in clip.tr:
            local_t = _sample(clip.tr[name], t)
        R = q_to_m(_sample(clip.rot[name], t)) if name in clip.rot else np.eye(3)
        M = np.eye(4)
        M[:3, :3] = R
        M[:3, 3] = local_t
        G[i] = M if parent is None else G[index[parent]] @ M
    skin = np.zeros((len(bones), 4, 4))
    for i, (name, parent, head) in enumerate(bones):
        ibm = np.eye(4)
        ibm[:3, 3] = -head
        skin[i] = G[i] @ ibm
    out = np.zeros_like(V)
    Vh = np.concatenate([V, np.ones((len(V), 1))], 1)
    for c in range(JJ.shape[1]):
        j = JJ[:, c]
        w = WW[:, c][:, None]
        out += w * np.einsum("nij,nj->ni", skin[j][:, :3, :], Vh)
    return out


def check_stretch(V, F, JJ, WW, bones, clips, height=1.0, samples=9):
    """How much every clip deforms the surface, in the model's final size (`height` metres).
    Per clip: shear_max_cm / shear_p999_cm = the largest / 99.9th-percentile change in the
    length of a mesh edge (a tear shows here first; a rigid turn changes no length), and
    stretch_p999 = the 99.9th-percentile length ratio of edges at least 1.5 cm long."""
    edges = np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]])
    rest_v = V[edges[:, 0]] - V[edges[:, 1]]
    rest = np.linalg.norm(rest_v, axis=1)
    long = rest * height >= 0.015
    report = {}
    worst = 0.0
    for name, clip in clips.items():
        shear_max, shear_p999, st_p999 = 0.0, 0.0, 0.0
        for t in np.linspace(0, clip.length, samples):
            P = pose_vertices(V, JJ, WW, bones, clip, t)
            d = P[edges[:, 0]] - P[edges[:, 1]]
            shear = np.abs(np.linalg.norm(d, axis=1) - rest) * height * 100.0
            shear_max = max(shear_max, float(shear.max()))
            shear_p999 = max(shear_p999, float(np.percentile(shear, 99.9)))
            r = np.linalg.norm(d[long], axis=1) / rest[long]
            r = np.maximum(r, 1.0 / np.maximum(r, 1e-6))
            st_p999 = max(st_p999, float(np.percentile(r, 99.9)))
        report[name] = {"shear_max_cm": round(shear_max, 2), "shear_p999_cm": round(shear_p999, 2), "stretch_p999": round(st_p999, 3)}
        worst = max(worst, shear_max)
    report["worst_shear_cm"] = round(worst, 2)
    return report
