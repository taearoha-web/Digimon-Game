"""Clips of the legend summons (Wind Monkey King, Poseidon) and a rig check.

Character animation, authored as code: every clip is a function of time that returns a
full-body pose, sampled at 30 fps into every joint.

* Legs are solved with two-bone IK from foot targets, so feet plant on the ground while
  the hips bob, sway and turn, and the knees bend by themselves.
* Walk and Run are real gait cycles: stance and swing per foot with heel strike and toe
  off, hip bob (low at contact for the walk, low at mid-stance for the run), lateral
  weight shift, pelvis yaw and drop, counter-rotating chest and arms, a stabilised head.
* Actions are key-framed with Hermite curves: a "flat" key holds (eases in and out), an
  "auto" key flows through (Catmull-Rom), so anticipation -> strike -> follow-through ->
  recovery read with weight. The strike lands on the LegendMoves `impact` second.
* Overlap: the chest follows the hips, the head the chest, the free arm the chest, and
  the secondary bones (tail, hair, robe tails, spec "extra") trail behind their parents.

The weapon is rigid in the right hand (legend_weights), so the arm and wrist swing it.

Clips (MonsterVisual keys in brackets):
  Idle [idle]   Walk [walk]   Run [run]   Attack [attack]   HitReact [hurt]   Death [die]
  Skill1 [skill1]   Skill2 [skill2]
    staff   (Wind Monkey King): Attack = staff sweep, Skill1 = whirlwind spin, Skill2 = staff slam
    trident (Poseidon):         Attack = trident thrust, Skill1 = maelstrom swirl, Skill2 = trident slam
"""
import math
import numpy as np
from scipy.spatial.transform import Rotation as Rot

TAU = 2 * math.pi
FPS = 30


def E(x=0.0, y=0.0, z=0.0):
    """Degrees about the rig's axes (rest is identity, so local axes are world axes at rest).
    x+ pitches a bone that points up forward and swings a hanging limb back; y+ turns the
    body to its left; z+ rolls the top of an upright bone to its right and swings a left
    limb out."""
    return Rot.from_euler("xyz", [x, y, z], degrees=True)


# ---------------------------------------------------------------- curves

def K(*keys, loop=None):
    """Hermite curve through keys (t, value[, "flat"|"auto"]). A flat key has zero slope
    (the motion settles there: ease in and out); an auto key flows through (Catmull-Rom).
    Values are scalars or tuples. loop=length wraps the curve for cycles."""
    ts = np.array([k[0] for k in keys], float)
    vs = [np.atleast_1d(np.array(k[1], float)) for k in keys]
    modes = [k[2] if len(k) > 2 else "auto" for k in keys]
    n = len(keys)
    tan = []
    for i in range(n):
        if modes[i] == "flat" or n == 1:
            tan.append(np.zeros_like(vs[i]))
            continue
        if i == 0 or i == n - 1:
            if loop is not None:
                a, b = vs[-2] if i == 0 else vs[n - 2], vs[1] if i == n - 1 else vs[1]
                dt = (ts[-1] - ts[-2]) + (ts[1] - ts[0])
                tan.append((b - a) / dt)
            else:
                tan.append(np.zeros_like(vs[i]))
            continue
        tan.append((vs[i + 1] - vs[i - 1]) / (ts[i + 1] - ts[i - 1]))

    def f(t):
        if loop is not None:
            t = ts[0] + (t - ts[0]) % loop
        if t <= ts[0]:
            v = vs[0]
        elif t >= ts[-1]:
            v = vs[-1]
        else:
            i = int(np.searchsorted(ts, t, side="right")) - 1
            h = ts[i + 1] - ts[i]
            s = (t - ts[i]) / h
            h00 = 2 * s ** 3 - 3 * s ** 2 + 1
            h10 = s ** 3 - 2 * s ** 2 + s
            h01 = -2 * s ** 3 + 3 * s ** 2
            h11 = s ** 3 - s ** 2
            v = h00 * vs[i] + h10 * h * tan[i] + h01 * vs[i + 1] + h11 * h * tan[i + 1]
        return v if len(v) > 1 else float(v[0])
    return f


def smooth(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


def wave(t, period, phase=0.0):
    return math.sin(TAU * (t / period - phase))


# ---------------------------------------------------------------- the rig

class Rig:
    """The legend skeleton (rest rotations identity) with forward kinematics and leg IK."""

    def __init__(self, bones):
        # bones: [(name, parent, head)] in height-1 space
        self.names = [b[0] for b in bones]
        self.parent = {b[0]: b[1] for b in bones}
        self.head = {b[0]: np.array(b[2], float) for b in bones}
        self.extra = [n for n in self.names if n not in CORE]

    def solve(self, pose):
        """pose: dict(hips=offset xyz, rot={bone: Rot}, feet={"L": (ankle xyz, Rot), ...},
        body_yaw=deg) -> ({bone: quat xyzw}, hips translation)."""
        rot = pose.get("rot", {})
        hips_t = self.head["Hips"] + np.array(pose.get("hips", (0, 0, 0)), float)
        out = {n: rot.get(n, Rot.identity()) for n in self.names}
        R_hips = out["Hips"]
        for s, (target, foot_rot) in pose.get("feet", {}).items():
            th, sh, ft = f"{s}_Thigh", f"{s}_Shin", f"{s}_Foot"
            H = hips_t + R_hips.apply(self.head[th] - self.head["Hips"])
            side = 1.0 if s == "L" else -1.0
            pole = R_hips.apply([0.18 * side, 0.0, 1.0])
            g_th, g_sh = self._two_bone(th, sh, ft, H, np.array(target, float), pole, R_hips)
            out[th] = R_hips.inv() * g_th
            out[sh] = g_th.inv() * g_sh
            out[ft] = g_sh.inv() * foot_rot
        arms = pose.get("arms", {})
        if arms:
            # chest frame by forward kinematics
            R_sp = R_hips * out["Spine"]
            R_ch = R_sp * out["Chest"]
            p_sp = hips_t + R_hips.apply(self.head["Spine"] - self.head["Hips"])
            p_ch = p_sp + R_sp.apply(self.head["Chest"] - self.head["Spine"])

            def chest_point(p):
                return p_ch + R_ch.apply(np.array(p, float) - self.head["Chest"])
            hand_world = {}
            for s in ("R", "L"):
                if s not in arms:
                    continue
                spec = arms[s]
                ua, fa, hd = f"{s}_UpperArm", f"{s}_Forearm", f"{s}_Hand"
                S = chest_point(self.head[ua])
                if "grip" in spec:
                    # this hand holds the other hand's weapon, `grip` along its axis
                    other_pos, other_R = hand_world[spec["grip_hand"]]
                    A = other_pos + other_R.apply(spec["axis"]) * spec["grip"]
                else:
                    A = chest_point(self.head[hd] + np.array(spec.get("hand", (0, 0, 0)), float))
                # the elbow bends the way it does at rest, nudged by `pole` (chest space)
                sh, el, ha = self.head[ua], self.head[fa], self.head[hd]
                u0 = (ha - sh) / np.linalg.norm(ha - sh)
                rp = (el - sh) - u0 * ((el - sh) @ u0)
                rp /= max(np.linalg.norm(rp), 1e-9)
                pole = R_ch.apply(rp + np.array(spec.get("pole", (0.0, 0.0, 0.0)), float))
                g_ua, g_fa = self._two_bone(ua, fa, hd, S, A, pole, R_ch)
                out[ua] = R_ch.inv() * g_ua
                out[fa] = g_ua.inv() * g_fa
                if "aim" in spec:
                    # the hand turns so the weapon's axis points along `aim` (chest space)
                    axis, aim = np.array(spec["axis"], float), np.array(spec["aim"], float)
                    g_hd = _align(axis, R_ch.apply(aim))
                    if spec.get("roll"):
                        g_hd = Rot.from_rotvec(R_ch.apply(aim) / np.linalg.norm(aim) * math.radians(spec["roll"])) * g_hd
                    # A forearm shares the wrist's twist along its length: half the twist
                    # about the forearm axis goes into the forearm (it turns on its own
                    # axis, so the hand stays where the IK put it).
                    rel = (g_fa.inv() * g_hd).as_quat()
                    fa_axis = (self.head[hd] - self.head[fa]) / np.linalg.norm(self.head[hd] - self.head[fa])
                    tw = np.array([*(fa_axis * (rel[:3] @ fa_axis)), rel[3]])
                    if np.linalg.norm(tw) > 1e-6:
                        half = Rot.from_rotvec(Rot.from_quat(tw / np.linalg.norm(tw)).as_rotvec() * 0.5)
                        g_fa = g_fa * half
                        out[fa] = g_ua.inv() * g_fa
                    out[hd] = g_fa.inv() * g_hd
                elif "hand_rot" in spec:
                    out[hd] = g_fa.inv() * R_ch * spec["hand_rot"]
                else:
                    out[hd] = rot.get(hd, Rot.identity())
                hand_world[s] = (A, g_fa * out[hd])
        return {n: out[n].as_quat() for n in self.names}, hips_t

    def _two_bone(self, b1, b2, b3, H, A, pole, R_parent):
        """Global rotations of b1, b2 so b2's head bends toward `pole` and b3's head reaches A."""
        l1 = np.linalg.norm(self.head[b2] - self.head[b1])
        l2 = np.linalg.norm(self.head[b3] - self.head[b2])
        d_vec = A - H
        d = np.linalg.norm(d_vec)
        u = d_vec / max(d, 1e-9)
        d = min(max(d, abs(l1 - l2) + 1e-4), (l1 + l2) * 0.9995)
        A = H + u * d
        p = pole - u * (pole @ u)
        p /= max(np.linalg.norm(p), 1e-9)
        a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
        h = math.sqrt(max(l1 * l1 - a * a, 0.0))
        Kn = H + a * u + h * p
        rest1 = (self.head[b2] - self.head[b1]) / l1
        rest2 = (self.head[b3] - self.head[b2]) / l2
        g1 = _align(R_parent.apply(rest1), (Kn - H) / l1) * R_parent
        g2 = _align(g1.apply(rest2), (A - Kn) / l2) * g1
        return g1, g2


CORE = {"Root", "Hips", "Spine", "Chest", "Neck", "Head", "R_UpperArm", "R_Forearm", "R_Hand", "R_Thigh", "R_Shin", "R_Foot",
        "L_UpperArm", "L_Forearm", "L_Hand", "L_Thigh", "L_Shin", "L_Foot"}


def _align(a, b):
    """Smallest rotation turning direction a onto b."""
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    c = np.cross(a, b)
    s = np.linalg.norm(c)
    dot = float(np.clip(a @ b, -1, 1))
    if s < 1e-9:
        return Rot.identity()
    return Rot.from_rotvec(c / s * math.atan2(s, dot))


class Clip:
    def __init__(self, name, length, loop):
        self.name, self.length, self.loop = name, length, loop
        self.rot, self.tr = {}, {}
        self.ground_speed = 0.0


def bake(rig, name, length, loop, fn):
    """Sample fn(t) -> pose at 30 fps into per-bone tracks (constant tracks dropped)."""
    c = Clip(name, length, loop)
    n = int(round(length * FPS)) + 1
    ts = np.linspace(0, length, n)
    qs = {b: [] for b in rig.names}
    hp = []
    for t in ts:
        q, h = rig.solve(fn(float(t)))
        for b in rig.names:
            qs[b].append(q[b])
        hp.append(h)
    for b in rig.names:
        arr = np.array(qs[b])
        for i in range(1, len(arr)):           # keep quaternion signs continuous
            if arr[i] @ arr[i - 1] < 0:
                arr[i] = -arr[i]
        if np.abs(arr - np.array([0, 0, 0, 1])).max() > 1e-5:
            c.rot[b] = (ts, arr)
    c.tr["Hips"] = (ts, np.array(hp))
    return c


# ---------------------------------------------------------------- authoring

def author(style, bones, spec=None):
    """All clips for one legend. style: "staff" | "trident"; bones: [(name, parent, head)]."""
    spec = spec or {}
    rig = Rig(bones)
    head = rig.head
    ank = {s: head[f"{s}_Foot"].copy() for s in "LR"}
    clips = {}
    tail_bones = [n for n in rig.extra]

    def foot(s, dx=0.0, dy=0.0, dz=0.0, pitch=0.0, yaw=0.0, body_yaw=0.0):
        p = ank[s] + np.array([dx, dy, dz])
        if body_yaw:
            p = E(y=body_yaw).apply(p)
        return (p, E(y=body_yaw + yaw) * E(x=pitch))

    def secondary(rot, t, sway_fn, amp=1.0):
        """Secondary chains trail their parents: the tip lags more than the root."""
        for i, n in enumerate(tail_bones):
            k = 1.0 + 0.6 * (i % 3)
            sx, sy, sz = sway_fn(t - 0.08 * k)
            rot[n] = E(sx * amp * k, sy * amp * k, sz * amp * k)

    # ------------------------------------------------------------ stance (contrapposto)
    # The neutral standing pose every non-cycle clip starts and ends in: weight on the left
    # leg, hips shifted over it and dropped on the right, the right knee eased, chest and
    # head tilted back against the hips.
    STAND = dict(hx=0.010, hy=-0.012, hz=0.0, roll=2.5, chest_roll=-2.0, head_roll=1.0)

    def stand_pose(t, breath=1.0, shift=0.0):
        b = wave(t, 3.0) * breath                  # breathing, 3 s
        hx = STAND["hx"] + shift
        rot = {
            "Hips": E(x=1.0, y=-3.0, z=STAND["roll"] + shift * 120),
            "Spine": E(x=-0.6 * b + 1.0, y=1.5, z=-1.2 - shift * 60),
            "Chest": E(x=-1.2 * b - 1.0, y=1.5, z=STAND["chest_roll"] - shift * 50),
            "Neck": E(x=0.5 * b, z=0.5),
            "Head": E(x=2.0 + 0.6 * b, y=2.0, z=STAND["head_roll"]),
            "L_UpperArm": E(x=2.0 + 0.8 * b, z=-2.0 + 1.2 * b),
            "L_Forearm": E(x=-6.0 - 1.0 * b),
            "L_Hand": E(x=-4.0, z=3.0),
            "R_UpperArm": E(x=-0.5 * b, z=-0.8 * b),
            "R_Forearm": E(x=0.4 * b),
        }
        feet = {"L": foot("L", 0.004, 0, 0.0), "R": foot("R", -0.012, 0.0, 0.03, yaw=-8)}
        return dict(hips=(hx, STAND["hy"] + 0.004 * b, 0.0), rot=rot, feet=feet)

    # ------------------------------------------------------------ Idle (6 s: two breaths, a fidget)
    def idle(t):
        shift = 0.006 * math.sin(TAU * t / 6.0)    # slow weight drift
        p = stand_pose(t, 1.0, shift)
        r = p["rot"]
        # second half: look over the left shoulder, then back across to the right
        look = K((0, 0, "flat"), (2.6, 0, "flat"), (3.4, 22), (4.0, 24, "flat"), (4.6, -10), (5.2, -12, "flat"), (6.0, 0, "flat"))(t)
        nod = K((0, 0, "flat"), (2.6, 0, "flat"), (3.4, -4), (4.6, 3), (5.4, 0, "flat"), (6.0, 0, "flat"))(t)
        r["Head"] = r["Head"] * E(x=nod, y=look * 0.6)
        r["Neck"] = r["Neck"] * E(y=look * 0.3)
        r["Chest"] = r["Chest"] * E(y=look * 0.15)
        # the free hand flexes, the weapon arm re-grips (the weapon rocks a little)
        flex = K((0, 0, "flat"), (1.2, 0, "flat"), (1.8, 1), (2.4, 0, "flat"), (6.0, 0, "flat"))(t)
        r["L_Forearm"] = r["L_Forearm"] * E(x=-10 * flex)
        r["L_Hand"] = r["L_Hand"] * E(x=-14 * flex, z=6 * flex)
        r["L_UpperArm"] = r["L_UpperArm"] * E(x=-4 * flex, z=3 * flex)
        grip = K((0, 0, "flat"), (3.6, 0, "flat"), (4.2, 1), (4.8, 0, "flat"), (6.0, 0, "flat"))(t)
        r["R_Hand"] = E(x=-5 * grip, z=3 * grip)
        r["R_Forearm"] = r["R_Forearm"] * E(x=-4 * grip)
        secondary(r, t, lambda u: (3 * wave(u, 3.0), 4 * wave(u, 6.0, 0.2), 2 * wave(u, 3.0, 0.3)))
        return p

    clips["Idle"] = bake(rig, "Idle", 6.0, True, idle)

    # ------------------------------------------------------------ gait
    def gait(T, stride, duty, lift, bob, bob_run, lean, sway, yaw, roll, arm, fore, staff_arm, carry):
        """A locomotion cycle of period T covering `stride` (one foot's full cycle) per T."""
        def fn(t):
            ph = (t / T) % 1.0
            feet = {}
            for s, off in (("L", 0.0), ("R", 0.5)):
                q = (ph - off) % 1.0
                half = stride * duty * 0.5
                if q < duty:                       # stance: planted, sliding back with the ground
                    k = q / duty
                    z = half - 2 * half * k
                    y = 0.0
                    pitch = -14 * (1 - smooth(k / 0.18)) + 26 * smooth((k - 0.7) / 0.3)
                else:                              # swing: lift, carry forward, reach
                    k = (q - duty) / (1 - duty)
                    z = -half + 2 * half * smooth(k)
                    y = lift * math.sin(math.pi * k) ** 1.2
                    pitch = 26 * (1 - smooth(k / 0.45)) - 14 * smooth((k - 0.55) / 0.45)
                # keep the toe (or heel) on the ground while the foot rolls
                y += 0.075 * max(0.0, math.sin(math.radians(pitch))) + 0.03 * max(0.0, -math.sin(math.radians(pitch)))
                inward = -0.012 if s == "L" else 0.012
                feet[s] = foot(s, inward, y, z, pitch=pitch)
            c = math.cos(TAU * 2 * (ph - 0.30))    # +1 at mid-stance
            hy = -0.018 - bob_run + (bob * c if bob_run == 0 else -bob * c)
            hx = sway * math.sin(TAU * (ph - 0.06))
            pyaw = -yaw * math.cos(TAU * ph)
            proll = roll * math.sin(TAU * (ph - 0.04))
            lag = 0.06
            cyaw = yaw * 1.3 * math.cos(TAU * (ph - lag))
            r = {
                "Hips": E(x=lean, y=pyaw, z=proll),
                "Spine": E(x=lean * 0.25 + 1.5 * math.cos(TAU * 2 * (ph - 0.35)), y=cyaw * 0.4, z=-proll * 0.5),
                "Chest": E(x=lean * 0.15 + 1.5 * math.cos(TAU * 2 * (ph - 0.40)), y=cyaw * 0.6, z=-proll * 0.4),
                "Neck": E(x=-lean * 0.4, y=-0.3 * (cyaw - yaw)),
                "Head": E(x=-lean * 0.7 - 1.2 * math.cos(TAU * 2 * (ph - 0.45)), y=-0.5 * (cyaw - yaw) * math.cos(0), z=-proll * 0.3),
            }
            sw = math.cos(TAU * (ph - 0.08))       # +1: left arm back (left leg forward)
            r["L_UpperArm"] = E(x=arm * sw - arm * 0.15, z=-3 - 2 * abs(sw))
            r["L_Forearm"] = E(x=-fore * (0.6 + 0.4 * max(0.0, -math.cos(TAU * (ph - 0.16)))))
            r["L_Hand"] = E(x=-6 - 6 * max(0.0, -sw))
            sr = math.cos(TAU * (ph - 0.58))       # the weapon arm swings against the right leg
            r["R_UpperArm"] = E(x=-staff_arm * (0.55 + 0.45 * sr) - carry[0], z=-carry[1])
            r["R_Forearm"] = E(x=-carry[2] - staff_arm * 0.3 * (0.5 + 0.5 * sr))
            r["R_Hand"] = E(x=-carry[3] + 3 * sr)
            secondary(r, t, lambda u: (6 + 4 * math.cos(TAU * 2 * u / T), 6 * math.cos(TAU * (u / T - 0.1)), 4 * math.sin(TAU * u / T)))
            return dict(hips=(hx, hy, 0.0), rot=r, feet=feet)
        return fn

    WALK_T, WALK_STRIDE = 1.2, 0.56
    RUN_T, RUN_STRIDE = 0.66, 0.92
    clips["Walk"] = bake(rig, "Walk", WALK_T, True, gait(WALK_T, WALK_STRIDE, 0.62, 0.07, 0.010, 0.0, 4.0, 0.012, 7.0, 3.5, 16.0, 14.0, 7.0, (6.0, 2.0, 4.0, 0.0)))
    clips["Walk"].ground_speed = WALK_STRIDE / WALK_T
    clips["Run"] = bake(rig, "Run", RUN_T, True, gait(RUN_T, RUN_STRIDE, 0.38, 0.11, 0.016, 0.03, 11.0, 0.008, 10.0, 4.0, 28.0, 40.0, 10.0, (22.0, 6.0, 26.0, 22.0)))
    clips["Run"].ground_speed = RUN_STRIDE / RUN_T

    def action_pose(t):
        """Actions start and end in the stance, breathing held low."""
        return stand_pose(0.0, 0.3)

    def layer(p, **rots):
        for b, r in rots.items():
            p["rot"][b] = p["rot"].get(b, Rot.identity()) * r
        return p

    def feet_shift(p, L=(0, 0, 0), R=(0, 0, 0), Lp=0.0, Rp=0.0, yaw=0.0):
        p["feet"] = {"L": foot("L", 0.004 + L[0], L[1], L[2], pitch=Lp, body_yaw=yaw),
                     "R": foot("R", -0.012 + R[0], R[1], 0.03 + R[2], pitch=Rp, yaw=-8, body_yaw=yaw)}
        return p

    def hips_add(p, d):
        h = np.array(p["hips"], float) + np.array(d, float)
        p["hips"] = tuple(h)
        return p

    def trail(r, t, fn):
        secondary(r, t, fn)

    # The weapon: aimed by its direction in the chest frame, (azimuth a: 0 forward, +90 to
    # the body's left; elevation e: +90 straight up, past 90 tipping behind). The staff is
    # aimed by its long (lower) end, the trident by its prongs.
    wp = spec.get("weapon", {})
    w_top, w_bot = np.array(wp.get("top", (0, 1, 0)), float), np.array(wp.get("bottom", (0, 0, 0)), float)
    axis = (w_bot - w_top) if style == "staff" else (w_top - w_bot)
    axis /= np.linalg.norm(axis)
    rest_a = math.degrees(math.atan2(axis[0], axis[2]))
    rest_e = math.degrees(math.asin(axis[1]))
    if style == "trident":
        # prongs up: express as a slight tip back (e past 90) so slams and thrusts pitch over the front
        rest_a, rest_e = (rest_a + 180.0) % 360.0 - 180.0, 180.0 - rest_e
        if abs(rest_a) > 90:
            rest_a = (rest_a + 180.0) % 360.0 - 180.0

    def aim(a, e):
        a, e = math.radians(a), math.radians(e)
        return (math.sin(a) * math.cos(e), math.sin(e), math.cos(a) * math.cos(e))

    def wield(p, hand, a, e, pole=(0, 0, 0), roll=0.0):
        p.setdefault("arms", {})["R"] = {"hand": hand, "axis": tuple(axis), "aim": aim(a, e), "pole": pole, "roll": roll}
        p["rot"].pop("R_UpperArm", None)
        p["rot"].pop("R_Forearm", None)
        return p

    if style == "staff":
        # ------------------------------------------------ Attack: staff sweep (hit at 0.42 s)
        # coil to the right with the staff drawn back (0-0.24), whip the long end across the
        # front (0.24-0.42), carry it through to the left (-0.56), settle back (-0.8).
        def attack(t):
            p = action_pose(t)
            k = lambda *ks: K(*ks)(t)
            yaw = k((0, 0, "flat"), (0.24, -30, "flat"), (0.42, 22), (0.56, 34, "flat"), (0.8, 0, "flat"))
            dip = k((0, 0, "flat"), (0.24, -0.02, "flat"), (0.42, -0.05), (0.56, -0.045, "flat"), (0.8, 0, "flat"))
            step = k((0, 0, "flat"), (0.2, 0, "flat"), (0.36, 0.09, "flat"), (0.62, 0.09, "flat"), (0.8, 0, "flat"))
            lift = k((0, 0, "flat"), (0.28, 0.05), (0.36, 0, "flat"), (0.8, 0, "flat"))
            hips_add(p, (-0.012 * (yaw < 0) * min(1, -yaw / 30), dip, step * 0.35))
            feet_shift(p, L=(0.01, lift, step), Lp=-10 * lift / 0.05)
            layer(p, Hips=E(x=k((0, 0, "flat"), (0.24, -4), (0.42, 8), (0.56, 6, "flat"), (0.8, 0, "flat")), y=yaw * 0.45),
                  Spine=E(y=yaw * 0.25, x=k((0, 0, "flat"), (0.24, -3), (0.42, 5), (0.8, 0, "flat"))),
                  Chest=E(y=K((0, 0, "flat"), (0.27, -30, "flat"), (0.45, 22), (0.6, 34, "flat"), (0.8, 0, "flat"))(t) * 0.4,
                          x=k((0, 0, "flat"), (0.24, -4), (0.42, 6), (0.8, 0, "flat"))),
                  Head=E(y=-yaw * 0.55, x=k((0, 0, "flat"), (0.24, 4), (0.42, -4), (0.8, 0, "flat"))))
            hand = k((0, (0, 0, 0), "flat"), (0.24, (-0.03, 0.12, -0.16), "flat"), (0.42, (0.13, 0.0, 0.07)), (0.56, (0.24, -0.02, -0.0), "flat"), (0.8, (0, 0, 0), "flat"))
            a = k((0, rest_a, "flat"), (0.24, -150, "flat"), (0.42, 25), (0.56, 95, "flat"), (0.8, rest_a, "flat"))
            e = k((0, rest_e, "flat"), (0.24, 12, "flat"), (0.42, -6), (0.56, -4, "flat"), (0.8, rest_e, "flat"))
            pole = k((0, (0, 0, 0), "flat"), (0.24, (-0.6, -0.2, 0), "flat"), (0.42, (0, -0.6, 0)), (0.8, (0, 0, 0), "flat"))
            wield(p, hand, a, e, pole)
            # the free arm counter-balances
            p["rot"]["L_UpperArm"] = E(x=k((0, 0, "flat"), (0.24, -24), (0.42, 22), (0.56, 26, "flat"), (0.8, 0, "flat")),
                                       z=k((0, 0, "flat"), (0.24, 14), (0.42, 22), (0.8, 0, "flat")))
            p["rot"]["L_Forearm"] = E(x=k((0, 0, "flat"), (0.24, -30), (0.42, -12), (0.8, -6, "flat")))
            trail(p["rot"], t, lambda u: (8 * K((0, 0), (0.3, 1), (0.6, -1), (0.8, 0))(u), -K((0, 0, "flat"), (0.24, -30, "flat"), (0.42, 22), (0.56, 34, "flat"), (0.8, 0, "flat"))(u) * 0.5, 0))
            return p
        clips["Attack"] = bake(rig, "Attack", 0.8, False, attack)

        # ------------------------------------------------ Skill1: whirlwind spin (hit at 0.55 s)
        def skill1(t):
            p = action_pose(t)
            k = lambda *ks: K(*ks)(t)
            spin = k((0, 0, "flat"), (0.2, -35, "flat"), (0.55, 300), (0.74, 360, "flat"), (1.1, 360, "flat"))
            crouch = k((0, 0, "flat"), (0.2, -0.05, "flat"), (0.45, -0.015), (0.6, -0.06), (0.78, -0.05, "flat"), (1.1, 0, "flat"))
            hop = k((0, 0, "flat"), (0.25, 0), (0.38, 0.05), (0.52, 0), (1.1, 0, "flat"))
            hips_add(p, (0, crouch + hop, 0))
            feet_shift(p, L=(0.03, hop * 0.9, 0), R=(-0.03, hop * 0.9, 0), yaw=spin)
            layer(p, Hips=E(y=spin, x=k((0, 0, "flat"), (0.2, 6), (0.6, 10), (0.78, 8, "flat"), (1.1, 0, "flat"))),
                  Chest=E(y=k((0, 0, "flat"), (0.2, -12), (0.4, 12), (0.6, 8), (0.8, -4), (1.1, 0, "flat")), x=k((0, 0, "flat"), (0.2, 4), (1.1, 0, "flat"))),
                  Head=E(y=k((0, 0, "flat"), (0.2, 16), (0.4, -14), (0.7, -6), (1.1, 0, "flat")), x=k((0, 0, "flat"), (0.2, -6), (0.6, -8), (1.1, 0, "flat"))))
            # the staff held out flat to the right, leading the spin
            hand = k((0, (0, 0, 0), "flat"), (0.2, (-0.07, 0.03, -0.02), "flat"), (0.78, (-0.07, 0.03, -0.02), "flat"), (1.1, (0, 0, 0), "flat"))
            a = k((0, rest_a, "flat"), (0.2, -60, "flat"), (0.55, -45), (0.78, -60, "flat"), (1.1, rest_a, "flat"))
            e = k((0, rest_e, "flat"), (0.2, -6, "flat"), (0.78, -6, "flat"), (1.1, rest_e, "flat"))
            wield(p, hand, a, e, (-0.5, -0.3, 0))
            out = k((0, 0, "flat"), (0.2, 1, "flat"), (0.78, 1, "flat"), (1.1, 0, "flat"))
            p["rot"]["L_UpperArm"] = E(x=-10 * out, z=48 * out)
            p["rot"]["L_Forearm"] = E(x=-20 * out)
            trail(p["rot"], t, lambda u: (14 * min(1, u / 0.3), -20 * K((0, 0), (0.3, 0), (0.55, 1), (0.8, 0.3), (1.1, 0))(u), 6))
            return p
        clips["Skill1"] = bake(rig, "Skill1", 1.1, False, skill1)

        # ------------------------------------------------ Skill2: staff slam (hit at 0.6 s)
        # rise with the staff raised overhead (long end up behind), then bring it over the
        # top and drive the long end into the ground in front, hold, recover.
        def skill2(t):
            p = action_pose(t)
            k = lambda *ks: K(*ks)(t)
            rise = k((0, 0, "flat"), (0.12, -0.03, "flat"), (0.42, 0.04, "flat"), (0.6, -0.075), (0.66, -0.08, "flat"), (0.9, -0.065, "flat"), (1.2, 0, "flat"))
            fwd = k((0, 0, "flat"), (0.42, -0.02, "flat"), (0.6, 0.07), (0.9, 0.07, "flat"), (1.2, 0, "flat"))
            step = k((0, 0, "flat"), (0.4, 0.0, "flat"), (0.58, 0.14, "flat"), (0.95, 0.14, "flat"), (1.2, 0, "flat"))
            lift = k((0, 0, "flat"), (0.3, 0.0), (0.46, 0.08), (0.58, 0, "flat"), (1.2, 0, "flat"))
            hips_add(p, (0, rise, fwd))
            feet_shift(p, L=(0.02, lift + max(0.0, rise) * 0.6, step), R=(0, max(0.0, rise) * 0.6, 0), Lp=-8)
            bend = k((0, 0, "flat"), (0.42, -12, "flat"), (0.6, 22), (0.68, 24, "flat"), (0.9, 18, "flat"), (1.2, 0, "flat"))
            layer(p, Hips=E(x=bend * 0.4), Spine=E(x=bend * 0.35), Chest=E(x=bend * 0.4, y=k((0, 0, "flat"), (0.42, -10), (0.6, 6), (1.2, 0, "flat"))),
                  Head=E(x=-bend * 0.5 + K((0, 0), (0.42, 0), (0.6, 0), (0.66, 6), (0.75, 0))(t)))
            hand = k((0, (0, 0, 0), "flat"), (0.42, (0.08, 0.2, -0.08), "flat"), (0.6, (0.12, -0.08, 0.1)), (0.66, (0.12, -0.09, 0.1), "flat"), (0.9, (0.1, -0.07, 0.08), "flat"), (1.2, (0, 0, 0), "flat"))
            e = k((0, rest_e, "flat"), (0.42, 112, "flat"), (0.6, -40), (0.66, -44, "flat"), (0.9, -40, "flat"), (1.2, rest_e, "flat"))
            a = k((0, rest_a, "flat"), (0.42, 8, "flat"), (0.9, 8, "flat"), (1.2, rest_a, "flat"))
            wield(p, hand, a, e, k((0, (0, 0, 0), "flat"), (0.42, (-0.6, 0.2, 0), "flat"), (0.6, (-0.3, -0.3, 0)), (1.2, (0, 0, 0), "flat")))
            p["rot"]["L_UpperArm"] = E(x=k((0, 0, "flat"), (0.42, -70, "flat"), (0.6, -40), (0.9, -32, "flat"), (1.2, 0, "flat")), z=k((0, 0, "flat"), (0.42, -10, "flat"), (0.6, 10), (1.2, 0, "flat")))
            p["rot"]["L_Forearm"] = E(x=k((0, 0, "flat"), (0.42, -40, "flat"), (0.6, -20), (1.2, -6, "flat")))
            trail(p["rot"], t, lambda u: (K((0, 0), (0.42, -10), (0.6, 18), (0.8, 6), (1.2, 0))(u), 0, 0))
            return p
        clips["Skill2"] = bake(rig, "Skill2", 1.2, False, skill2)
    else:
        # ------------------------------------------------ Attack: trident thrust (the orb leaves at once; thrust lands 0.24 s)
        def attack(t):
            p = action_pose(t)
            k = lambda *ks: K(*ks)(t)
            yaw = k((0, 0, "flat"), (0.12, -22, "flat"), (0.24, 14), (0.36, 18, "flat"), (0.8, 0, "flat"))
            lunge = k((0, 0, "flat"), (0.12, -0.03, "flat"), (0.24, 0.07), (0.4, 0.08, "flat"), (0.8, 0, "flat"))
            step = k((0, 0, "flat"), (0.1, 0, "flat"), (0.24, 0.11, "flat"), (0.55, 0.11, "flat"), (0.8, 0, "flat"))
            lift = k((0, 0, "flat"), (0.17, 0.05), (0.24, 0, "flat"), (0.8, 0, "flat"))
            hips_add(p, (0, -abs(lunge) * 0.45, lunge))
            feet_shift(p, L=(0.0, lift, step), Lp=-8)
            layer(p, Hips=E(y=yaw * 0.4, x=k((0, 0, "flat"), (0.12, -5), (0.24, 9), (0.4, 8, "flat"), (0.8, 0, "flat"))),
                  Spine=E(y=yaw * 0.3), Chest=E(y=K((0, 0, "flat"), (0.14, -22, "flat"), (0.27, 14), (0.4, 18, "flat"), (0.8, 0, "flat"))(t) * 0.4,
                                                 x=k((0, 0, "flat"), (0.12, -4), (0.24, 6), (0.8, 0, "flat"))),
                  Head=E(y=-yaw * 0.6, x=k((0, 0, "flat"), (0.12, 3), (0.24, -5), (0.8, 0, "flat"))))
            # draw the trident back level at the shoulder, then drive the prongs forward
            hand = k((0, (0, 0, 0), "flat"), (0.12, (0.02, 0.08, -0.14), "flat"), (0.24, (0.1, 0.02, 0.1)), (0.4, (0.1, 0.02, 0.09), "flat"), (0.8, (0, 0, 0), "flat"))
            e = k((0, rest_e, "flat"), (0.12, 12, "flat"), (0.24, 2), (0.4, 0, "flat"), (0.8, rest_e, "flat"))
            a = k((0, rest_a, "flat"), (0.12, -6, "flat"), (0.24, 4), (0.8, rest_a, "flat"))
            wield(p, hand, a, e, k((0, (0, 0, 0), "flat"), (0.12, (-0.5, 0.0, -0.3), "flat"), (0.24, (-0.4, -0.4, 0)), (0.8, (0, 0, 0), "flat")))
            p["rot"]["L_UpperArm"] = E(x=k((0, 0, "flat"), (0.12, -30), (0.24, 18), (0.4, 20, "flat"), (0.8, 0, "flat")), z=k((0, 0, "flat"), (0.12, 10), (0.24, 18), (0.8, 0, "flat")))
            p["rot"]["L_Forearm"] = E(x=k((0, 0, "flat"), (0.12, -40), (0.24, -15), (0.8, -6, "flat")))
            trail(p["rot"], t, lambda u: (K((0, 0), (0.12, -6), (0.3, 10), (0.6, -3), (0.8, 0))(u), 0, 0))
            return p
        clips["Attack"] = bake(rig, "Attack", 0.8, False, attack)

        # ------------------------------------------------ Skill1: maelstrom (hit at 0.65 s)
        # the trident raised overhead and stirred in a circle, then swept down at the target.
        def skill1(t):
            p = action_pose(t)
            k = lambda *ks: K(*ks)(t)
            circ = k((0, 0, "flat"), (0.15, 0, "flat"), (0.5, 1.0), (0.6, 1.0, "flat"), (1.2, 1.0))
            ang = TAU * circ
            up = k((0, 0, "flat"), (0.15, 1), (0.5, 1, "flat"), (0.65, 0.2), (0.8, 0.15, "flat"), (1.2, 0, "flat"))
            rise = k((0, 0, "flat"), (0.15, 0.03), (0.5, 0.05, "flat"), (0.65, -0.06), (0.8, -0.055, "flat"), (1.2, 0, "flat"))
            step = k((0, 0, "flat"), (0.5, 0, "flat"), (0.64, 0.12, "flat"), (0.95, 0.12, "flat"), (1.2, 0, "flat"))
            lift = k((0, 0, "flat"), (0.5, 0), (0.58, 0.05), (0.64, 0, "flat"), (1.2, 0, "flat"))
            hips_add(p, (0.01 * math.sin(ang) * up, rise, step * 0.4))
            feet_shift(p, L=(0, lift + max(0.0, rise) * 0.7, step), R=(0, max(0.0, rise) * 0.7, 0), Lp=-8)
            sweep = k((0, 0, "flat"), (0.5, -10, "flat"), (0.65, 24), (0.8, 30, "flat"), (1.2, 0, "flat"))
            layer(p, Hips=E(x=sweep * 0.3, y=10 * math.sin(ang) * up + sweep * 0.3), Spine=E(x=-6 * up + sweep * 0.2, z=-5 * math.cos(ang) * up),
                  Chest=E(x=-8 * up + sweep * 0.3, y=12 * math.sin(ang - 0.4) * up), Head=E(x=-12 * up - sweep * 0.2 + 4, y=-8 * math.sin(ang - 0.8) * up))
            # hand overhead circling, prongs to the sky; then the prongs sweep down at the target
            r = 0.05 * up
            hand = np.array(k((0, (0, 0, 0), "flat"), (0.15, (0.1, 0.2, -0.02)), (0.5, (0.1, 0.2, -0.02), "flat"), (0.65, (0.1, 0.0, 0.14)), (0.8, (0.1, 0.0, 0.13), "flat"), (1.2, (0, 0, 0), "flat")))
            hand = hand + np.array([r * math.cos(ang), 0, r * math.sin(ang)])
            e = k((0, rest_e, "flat"), (0.15, 72), (0.5, 72, "flat"), (0.65, -18), (0.8, -20, "flat"), (1.2, rest_e, "flat"))
            a = k((0, rest_a, "flat"), (0.15, rest_a), (0.5, rest_a + 360), (0.65, 360 + 6), (0.8, 360, "flat"), (1.2, 360 + rest_a, "flat"))
            wield(p, tuple(hand), a, e, (0.0, 0.3 * up, 0), roll=0)
            p["rot"]["L_UpperArm"] = E(x=k((0, 0, "flat"), (0.15, -40), (0.5, -60, "flat"), (0.65, -80), (0.8, -78, "flat"), (1.2, 0, "flat")),
                                       z=k((0, 0, "flat"), (0.15, 30), (0.5, 26, "flat"), (0.65, 6), (1.2, 0, "flat")))
            p["rot"]["L_Forearm"] = E(x=k((0, 0, "flat"), (0.15, -30), (0.65, -10), (1.2, -6, "flat")))
            p["rot"]["L_Hand"] = E(x=k((0, 0, "flat"), (0.5, -10), (0.65, 20), (1.2, 0, "flat")))
            trail(p["rot"], t, lambda u: (-10 * up, 18 * math.sin(TAU * K((0, 0), (0.15, 0), (0.5, 1), (1.2, 1))(u)), 8 * math.cos(TAU * u)))
            return p
        clips["Skill1"] = bake(rig, "Skill1", 1.2, False, skill1)

        # ------------------------------------------------ Skill2: trident slam (hit at 0.6 s)
        def skill2(t):
            p = action_pose(t)
            k = lambda *ks: K(*ks)(t)
            rise = k((0, 0, "flat"), (0.1, -0.03, "flat"), (0.42, 0.04, "flat"), (0.6, -0.075), (0.66, -0.08, "flat"), (1.0, -0.065, "flat"), (1.3, 0, "flat"))
            fwd = k((0, 0, "flat"), (0.42, -0.02, "flat"), (0.6, 0.06), (1.0, 0.06, "flat"), (1.3, 0, "flat"))
            step = k((0, 0, "flat"), (0.4, 0, "flat"), (0.58, 0.12, "flat"), (1.0, 0.12, "flat"), (1.3, 0, "flat"))
            lift = k((0, 0, "flat"), (0.3, 0), (0.46, 0.08), (0.58, 0, "flat"), (1.3, 0, "flat"))
            hips_add(p, (0, rise, fwd))
            feet_shift(p, L=(0.02, lift + max(0.0, rise) * 0.6, step), R=(0, max(0.0, rise) * 0.6, 0), Lp=-8)
            bend = k((0, 0, "flat"), (0.42, -12, "flat"), (0.6, 20), (0.68, 22, "flat"), (1.0, 16, "flat"), (1.3, 0, "flat"))
            layer(p, Hips=E(x=bend * 0.4), Spine=E(x=bend * 0.3), Chest=E(x=bend * 0.4), Head=E(x=-bend * 0.5 + K((0, 0), (0.6, 0), (0.66, 6), (0.76, 0))(t)))
            # raise the trident high, then drive its butt straight down into the ground
            hand = k((0, (0, 0, 0), "flat"), (0.42, (0.08, 0.2, -0.02), "flat"), (0.6, (0.07, 0.0, 0.1)), (0.66, (0.07, -0.01, 0.1), "flat"), (1.0, (0.06, 0.0, 0.08), "flat"), (1.3, (0, 0, 0), "flat"))
            e = k((0, rest_e, "flat"), (0.42, 95, "flat"), (0.6, 82), (0.66, 80, "flat"), (1.0, 82, "flat"), (1.3, rest_e, "flat"))
            a = k((0, rest_a, "flat"), (0.42, 0, "flat"), (1.0, 0, "flat"), (1.3, rest_a, "flat"))
            wield(p, hand, a, e, k((0, (0, 0, 0), "flat"), (0.42, (-0.5, 0.0, 0), "flat"), (0.6, (-0.3, -0.2, 0)), (1.3, (0, 0, 0), "flat")))
            p["rot"]["L_UpperArm"] = E(x=k((0, 0, "flat"), (0.42, -75, "flat"), (0.6, -50), (1.0, -42, "flat"), (1.3, 0, "flat")), z=k((0, 0, "flat"), (0.42, -18, "flat"), (0.6, -20), (1.3, 0, "flat")))
            p["rot"]["L_Forearm"] = E(x=k((0, 0, "flat"), (0.42, -30, "flat"), (0.6, -40), (1.0, -36, "flat"), (1.3, 0, "flat")))
            trail(p["rot"], t, lambda u: (K((0, 0), (0.42, -10), (0.6, 18), (0.8, 6), (1.3, 0))(u), 0, 0))
            return p
        clips["Skill2"] = bake(rig, "Skill2", 1.3, False, skill2)

    # ------------------------------------------------ HitReact: recoil and recover
    def hit(t):
        p = action_pose(t)
        k = lambda *ks: K(*ks)(t)
        rec = k((0, 0, "flat"), (0.08, 1), (0.16, 0.9, "flat"), (0.45, 0, "flat"))
        rec_lag = K((0, 0, "flat"), (0.12, 1), (0.2, 0.85, "flat"), (0.45, 0, "flat"))(t)
        hips_add(p, (0.0, -0.02 * rec, -0.035 * rec))
        layer(p, Hips=E(x=-6 * rec, y=6 * rec), Spine=E(x=-5 * rec_lag), Chest=E(x=-7 * rec_lag, y=8 * rec_lag, z=3 * rec_lag),
              Head=E(x=-10 * K((0, 0, "flat"), (0.14, 1), (0.24, 0.8, "flat"), (0.45, 0, "flat"))(t), y=-6 * rec_lag))
        p["rot"]["L_UpperArm"] = p["rot"]["L_UpperArm"] * E(x=-14 * rec_lag, z=16 * rec_lag)
        p["rot"]["L_Forearm"] = p["rot"]["L_Forearm"] * E(x=-20 * rec_lag)
        p["rot"]["R_UpperArm"] = p["rot"]["R_UpperArm"] * E(x=-8 * rec_lag, z=-10 * rec_lag)
        trail(p["rot"], t, lambda u: (-12 * K((0, 0), (0.1, 1), (0.3, -0.3), (0.45, 0))(u), 0, 0))
        return p
    clips["HitReact"] = bake(rig, "HitReact", 0.45, False, hit)

    # ------------------------------------------------ Death: stagger, knees give, collapse forward
    def death(t):
        p = action_pose(t)
        k = lambda *ks: K(*ks)(t)
        drop = k((0, 0, "flat"), (0.18, 0.01), (0.3, -0.02), (0.75, -0.1), (0.9, -0.11), (1.0, -0.105, "flat"), (1.4, -0.105, "flat"))
        back = k((0, 0, "flat"), (0.18, -0.04, "flat"), (0.75, 0.04), (1.4, 0.05, "flat"))
        slump = k((0, 0, "flat"), (0.18, -12), (0.4, -4), (0.8, 36), (0.95, 46), (1.05, 44, "flat"), (1.4, 44, "flat"))
        hips_add(p, (0.0, drop, back))
        feet_shift(p, R=(0, 0, k((0, 0, "flat"), (0.18, -0.06, "flat"), (1.4, -0.06, "flat"))), L=(0, 0, 0.02))
        layer(p, Hips=E(x=slump * 0.35, z=k((0, 0, "flat"), (0.3, 0), (0.9, 6, "flat"), (1.4, 6, "flat"))), Spine=E(x=slump * 0.3), Chest=E(x=slump * 0.35, y=k((0, 0, "flat"), (0.18, 10), (0.8, -6), (1.4, -6, "flat"))),
              Head=E(x=K((0, 0, "flat"), (0.22, -18), (0.5, -6), (0.95, 30), (1.1, 24, "flat"), (1.4, 24, "flat"))(t)))
        hang = k((0, 0, "flat"), (0.18, -0.5), (0.6, 0.3), (0.95, 1, "flat"), (1.4, 1, "flat"))
        p["rot"]["L_UpperArm"] = p["rot"]["L_UpperArm"] * E(x=-20 * hang, z=10 * max(0.0, -hang) * 3)
        p["rot"]["L_Forearm"] = p["rot"]["L_Forearm"] * E(x=6 * hang)
        p["rot"]["R_UpperArm"] = E(x=-25 * hang, z=-12 * max(0.0, -hang) * 3)
        p["rot"]["R_Hand"] = E(x=k((0, 0, "flat"), (0.5, 0), (1.0, 30, "flat"), (1.4, 30, "flat")))
        trail(p["rot"], t, lambda u: (K((0, 0), (0.2, -10), (0.9, 20), (1.4, 16))(u), 0, 0))
        return p
    clips["Death"] = bake(rig, "Death", 1.4, False, death)
    return clips


# ---------------- rig check: skin every clip and measure the surface ----------------

def q_to_m(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def _sample(track, t, rot=False):
    ts, vals = track
    i = int(np.searchsorted(ts, t, side="right")) - 1
    i = max(0, min(i, len(ts) - 2))
    k = min(1.0, max(0.0, (t - ts[i]) / max(ts[i + 1] - ts[i], 1e-9)))
    v = vals[i] * (1 - k) + vals[i + 1] * k
    return v / np.linalg.norm(v) if rot else v


def pose_vertices(V, JJ, WW, bones, clip, t):
    """Skinned vertex positions of one clip at time t. bones: [(name, parent, head)]."""
    index = {b[0]: i for i, b in enumerate(bones)}
    G = [None] * len(bones)
    for i, (name, parent, head) in enumerate(bones):
        local_t = head - (bones[index[parent]][2] if parent else np.zeros(3))
        if name in clip.tr:
            local_t = _sample(clip.tr[name], t)
        R = q_to_m(_sample(clip.rot[name], t, True)) if name in clip.rot else np.eye(3)
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


def check_stretch(V, F, JJ, WW, bones, clips, height=1.0, samples=13):
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
