#!/usr/bin/env python3
"""One ORIGINAL music track per place, synthesised from simple waveforms (no
samples, no copyrighted material) and encoded to Ogg Vorbis for the web build.

Every zone, the town, the title screen, the tower, the ranked coliseum, the
guild war and the training arena get their own key / tempo / meter /
instrumentation, plus the victory and defeat jingles.  Loops are rendered in
whole bars and every note tail wraps around to the start of the buffer, so
the loop point is seamless (nothing fades).  All randomness is seeded per track.

The note / path helpers come from generate_placeholder_audio.py; the
instruments here are numpy-vectorised (additive band-limited oscillators,
plucked strings, bells, choir and string pads, organ, brass, timpani, hand
drums, a crowd bed ...) so the whole set renders in a minute or so.

Usage:
  python3 tools/generate_zone_music.py            # every track -> audio/music/*.ogg
  python3 tools/generate_zone_music.py snow abyss # only these
  python3 tools/generate_zone_music.py --spectrograms DIR   # also PNG spectrograms
Needs numpy, scipy, ffmpeg (libvorbis).  The WAV intermediates go to a temp dir.
"""
import importlib.util
import math
import os
import subprocess
import sys
import tempfile
import wave as wavefile

import numpy as np
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("gpa", os.path.join(HERE, "generate_placeholder_audio.py"))
gpa = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gpa)
note_freq = gpa.note_freq
MUSIC_DIR = gpa.MUSIC_DIR

RATE = 32000            # render / encode sample rate
NYQ = RATE / 2.0
TAU = math.tau
OGG_QUALITY = "2"       # libvorbis -q:a (about 48-64 kbps mono at 32 kHz)

NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
CHORD_INTERVALS = {
    "": [0, 4, 7], "m": [0, 3, 7], "dim": [0, 3, 6], "aug": [0, 4, 8], "5": [0, 7, 12],
    "sus2": [0, 2, 7], "sus4": [0, 5, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10],
    "maj7": [0, 4, 7, 11], "add9": [0, 4, 7, 14], "madd9": [0, 3, 7, 14], "6": [0, 4, 7, 9],
    "m6": [0, 3, 7, 9], "wt": [0, 4, 8], "wt2": [0, 2, 6, 10], "m9": [0, 3, 7, 10, 14],
}


# ---------------------------------------------------------------------------
# Pitch helpers
# ---------------------------------------------------------------------------

def midi_of(name):
    return int(round(12 * math.log2(note_freq(name) / 440.0) + 69))


def name_of(midi):
    return "%s%d" % (NOTE_NAMES[midi % 12], midi // 12 - 1)


def transpose(bars, semis):
    return [[(d, None if n is None else name_of(midi_of(n) + semis)) for d, n in bar] for bar in bars]


def chord_notes(name, octave=3):
    """'Dm' -> ['D3','F3','A3'];  'F#sus2/4' puts the chord in octave 4."""
    if "/" in name:
        name, octave = name.split("/")
        octave = int(octave)
    root = name[0]
    rest = name[1:]
    if rest[:1] in ("#", "b"):
        root += rest[0]
        rest = rest[1:]
    base = midi_of(root + str(octave))
    return [name_of(base + i) for i in CHORD_INTERVALS[rest]]


def bars(text, bpb=4):
    """'E5:1 G5:.5 -:2.5 | ...' -> [[(dur, note|None), ...], ...]; bars must sum to bpb."""
    out = []
    for i, bar in enumerate(text.strip().split("|")):
        notes = []
        for tok in bar.split():
            n, d = tok.split(":")
            notes.append((float(d), None if n in ("-", "r") else n))
        total = sum(d for d, _ in notes)
        assert abs(total - bpb) < 1e-6, "bar %d sums to %s, not %s: %r" % (i, total, bpb, bar)
        out.append(notes)
    return out


def prog(text):
    return text.split()


# ---------------------------------------------------------------------------
# DSP helpers (all vectorised)
# ---------------------------------------------------------------------------

_SOS = {}


def _sos(kind, cutoff, order=2):
    key = (kind, round(float(cutoff[0] if isinstance(cutoff, tuple) else cutoff), 1),
           round(float(cutoff[1]), 1) if isinstance(cutoff, tuple) else 0, order)
    if key not in _SOS:
        if kind == "bp":
            lo, hi = cutoff
            _SOS[key] = signal.butter(order, [max(10.0, lo), min(NYQ * 0.98, hi)], btype="bandpass", fs=RATE, output="sos")
        else:
            c = min(NYQ * 0.98, max(10.0, cutoff))
            _SOS[key] = signal.butter(order, c, btype=kind, fs=RATE, output="sos")
    return _SOS[key]


def lp(x, cutoff, order=2):
    return signal.sosfilt(_sos("lowpass", cutoff, order), x)


def hp(x, cutoff, order=2):
    return signal.sosfilt(_sos("highpass", cutoff, order), x)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos("bp", (lo, hi), order), x)


def env_adsr(n, a, d, s, r, hold):
    """Linear ADSR over n samples; the note holds `hold` seconds then releases for r."""
    t = np.arange(n) / RATE
    a = max(0.001, min(a, hold * 0.5))
    d = max(0.001, min(d, max(0.001, hold - a)))
    xp = [0.0, a, a + d, max(a + d + 1e-4, hold), max(a + d + 2e-4, hold) + max(r, 0.002)]
    fp = [0.0, 1.0, s, s, 0.0]
    return np.interp(t, xp, fp)


def phase_of(freq, n, vib=0.0, vib_rate=5.5, vib_delay=0.15, glide_from=None, glide=0.08):
    """Fundamental phase (radians) with optional vibrato and pitch glide."""
    t = np.arange(n) / RATE
    f = np.full(n, float(freq))
    if glide_from is not None and glide > 0:
        k = np.clip(t / glide, 0.0, 1.0)
        f = glide_from * (1 - k) + freq * k
    if vib:
        depth = vib * np.clip((t - vib_delay) / 0.25, 0.0, 1.0)
        f = f * (1.0 + depth * np.sin(TAU * vib_rate * t))
    return TAU * np.cumsum(f) / RATE


def wave(phase, kind, fmax, duty=0.5, kmax=40):
    """Band-limited saw / square / tri / pulse / sine built from harmonics."""
    if kind == "sine":
        return np.sin(phase)
    K = max(1, min(kmax, int(NYQ * 0.9 / max(fmax, 1.0))))
    out = np.zeros_like(phase)
    for k in range(1, K + 1):
        if kind == "saw":
            out += np.sin(k * phase) / k
        elif kind == "square" and k % 2 == 1:
            out += np.sin(k * phase) / k
        elif kind == "tri" and k % 2 == 1:
            out += ((-1) ** ((k - 1) // 2)) * np.sin(k * phase) / (k * k)
        elif kind == "pulse":
            out += (2.0 / (k * math.pi)) * math.sin(math.pi * k * duty) * np.cos(k * phase)
    peak = np.max(np.abs(out))
    return out / peak if peak > 1e-9 else out


def partials(freq, n, ratios, amps, decays, attack=0.002, jitter=None):
    """Sum of decaying sine partials (plucks, bells, mallets)."""
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for ratio, amp, decay in zip(ratios, amps, decays):
        f = freq * ratio
        if f >= NYQ * 0.95:
            continue
        if jitter is not None:
            f *= 1.0 + jitter * (ratio - 1.0) * 0.002
        out += amp * np.sin(TAU * f * t) * np.exp(-decay * t)
    if attack > 0:
        out *= np.clip(t / attack, 0.0, 1.0)
    return out


def norm(x, peak=1.0):
    m = np.max(np.abs(x)) if len(x) else 0.0
    return x * (peak / m) if m > 1e-9 else x


def echo(x, delay, feedback, repeats=4):
    d = int(delay * RATE)
    out = np.zeros(len(x) + d * repeats)
    out[: len(x)] += x
    g = 1.0
    for i in range(1, repeats + 1):
        g *= feedback
        out[i * d: i * d + len(x)] += x * g
    return out


# ---------------------------------------------------------------------------
# Instruments: inst(freq, dur, rng, **kw) -> samples (peak about 1.0)
# ---------------------------------------------------------------------------

def _hold(dur, r):
    n = int((dur + r) * RATE)
    return n, dur


def brass(freq, dur, rng, bright=1.0, vib=0.004):
    n, hold = _hold(dur, 0.09)
    env = env_adsr(n, 0.04, 0.12, 0.85, 0.09, hold)
    ph = phase_of(freq, n, vib=vib, vib_delay=0.25)
    x = wave(ph * 0.996, "saw", freq) + wave(ph * 1.004, "saw", freq) + 0.5 * wave(ph, "square", freq)
    dark, light = lp(x, 700), lp(x, 1800 + 2400 * bright)
    return norm((dark + (light - dark) * np.sqrt(env)) * env)


def low_brass(freq, dur, rng):
    n, hold = _hold(dur, 0.08)
    env = env_adsr(n, 0.03, 0.1, 0.8, 0.08, hold)
    ph = phase_of(freq, n, vib=0.003)
    x = wave(ph * 0.995, "saw", freq) + wave(ph * 1.005, "saw", freq) + 0.7 * wave(ph * 0.5, "square", freq * 0.5)
    return norm(lp(x, 500 + 700 * np.max(env)) * env)


def strings(freq, dur, rng, bright=1.0):
    n, hold = _hold(dur, 0.35)
    env = env_adsr(n, 0.14, 0.2, 0.9, 0.35, hold)
    ph = phase_of(freq, n, vib=0.003, vib_rate=5.0, vib_delay=0.3)
    x = sum(wave(ph * (1 + c), "saw", freq) for c in (-0.008, -0.003, 0.004, 0.009))
    return norm(lp(x, 1500 + 1500 * bright) * env)


def pad(freq, dur, rng, cutoff=1100):
    n, hold = _hold(dur, 0.8)
    env = env_adsr(n, 0.45, 0.4, 0.9, 0.8, hold)
    ph = phase_of(freq, n, vib=0.002, vib_rate=0.4, vib_delay=0.0)
    x = sum(wave(ph * (1 + c), "saw", freq) for c in (-0.006, 0.0, 0.007)) + 0.6 * wave(ph * 0.5, "tri", freq * 0.5)
    return norm(lp(x, cutoff) * env)


def choir(freq, dur, rng, dark=False):
    n, hold = _hold(dur, 0.5)
    env = env_adsr(n, 0.3, 0.3, 0.9, 0.5, hold)
    out = np.zeros(n)
    for det in (-0.004, 0.0, 0.005):
        ph = phase_of(freq * (1 + det), n, vib=0.006, vib_rate=5.2, vib_delay=0.35)
        for k in range(1, 20):
            f = freq * k
            if f >= NYQ * 0.9:
                break
            if dark:
                g = math.exp(-((f - 420) / 220) ** 2) + 0.5 * math.exp(-((f - 900) / 300) ** 2) + 0.12
            else:
                g = math.exp(-((f - 650) / 250) ** 2) + 0.6 * math.exp(-((f - 1100) / 300) ** 2) + 0.25 * math.exp(-((f - 2500) / 500) ** 2) + 0.15
            out += g / math.sqrt(k) * np.sin(k * ph)
    breath = lp(rng.uniform(-1, 1, n), 1500) * 0.03
    return norm((lp(out, 3200) + breath) * env)


def organ(freq, dur, rng):
    n, hold = _hold(dur, 0.06)
    env = env_adsr(n, 0.012, 0.02, 1.0, 0.06, hold)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for ratio, amp in ((0.5, 0.6), (1, 1.0), (1.5, 0.35), (2, 0.7), (3, 0.3), (4, 0.45), (6, 0.18), (8, 0.22)):
        if freq * ratio < NYQ * 0.9:
            out += amp * np.sin(TAU * freq * ratio * t)
    trem = 1.0 - 0.1 * (0.5 + 0.5 * np.sin(TAU * 6.3 * t))
    return norm(out * trem * env)


def flute(freq, dur, rng, breath=0.12):
    n, hold = _hold(dur, 0.1)
    env = env_adsr(n, 0.06, 0.1, 0.9, 0.1, hold)
    ph = phase_of(freq, n, vib=0.005, vib_rate=5.2, vib_delay=0.22)
    x = np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph) + 0.05 * np.sin(4 * ph)
    t = np.arange(n) / RATE
    noise = bp(rng.uniform(-1, 1, n), freq * 1.5, min(NYQ * 0.9, freq * 4)) * np.exp(-t * 14) * breath
    return norm((x + noise) * env)


def whistle(freq, dur, rng):
    n, hold = _hold(dur, 0.08)
    env = env_adsr(n, 0.03, 0.05, 0.9, 0.08, hold)
    ph = phase_of(freq, n, vib=0.012, vib_rate=6.0, vib_delay=0.12)
    return norm((np.sin(ph) + 0.08 * np.sin(2 * ph)) * env)


def theremin(freq, dur, rng, glide_from=None):
    n, hold = _hold(dur, 0.15)
    env = env_adsr(n, 0.08, 0.1, 0.9, 0.15, hold)
    ph = phase_of(freq, n, vib=0.01, vib_rate=6.5, vib_delay=0.05, glide_from=glide_from, glide=min(0.3, dur * 0.4))
    return norm((np.sin(ph) + 0.2 * np.sin(2 * ph) + 0.05 * np.sin(3 * ph)) * env)


def pluck(freq, dur, rng, bright=1.0, damp=1.0, kmax=24):
    n, hold = _hold(dur, 0.25)
    K = max(2, min(kmax, int(NYQ * 0.9 / freq)))
    ks = np.arange(1, K + 1)
    out = partials(freq, n, ks, (1.0 / ks ** (1.0 / bright)), (2.2 + 1.6 * ks) * damp, attack=0.0015)
    cut = np.ones(n)
    tail = int(0.25 * RATE)
    cut[-tail:] = np.linspace(1, 0, tail)
    return norm(out * cut)


def lute(freq, dur, rng):
    return pluck(freq, dur, rng, bright=0.8, damp=1.6, kmax=12)


def koto(freq, dur, rng):
    return pluck(freq, dur, rng, bright=1.3, damp=0.9, kmax=30)


def marimba(freq, dur, rng):
    n, hold = _hold(dur, 0.15)
    return norm(partials(freq, n, [1, 4, 10], [1.0, 0.35, 0.08], [6.0, 13.0, 24.0], attack=0.0015))


def clav(freq, dur, rng):
    n, hold = _hold(dur, 0.06)
    t = np.arange(n) / RATE
    env = np.exp(-t * 7.0) * env_adsr(n, 0.002, 0.02, 1.0, 0.06, hold)
    ph = phase_of(freq, n)
    return norm(bp(wave(ph, "pulse", freq, duty=0.32), 250, 2800) * env)


def reed(freq, dur, rng):
    n, hold = _hold(dur, 0.08)
    env = env_adsr(n, 0.05, 0.1, 0.9, 0.08, hold)
    ph = phase_of(freq, n, vib=0.009, vib_rate=6.2, vib_delay=0.15)
    x = wave(ph, "saw", freq) + 0.6 * wave(ph, "pulse", freq, duty=0.3)
    return norm(bp(x, 500, 3200) * env)


def bell(freq, dur, rng):
    n = int((dur + 2.0) * RATE)
    out = partials(freq, n, [0.5, 1.0, 1.19, 1.56, 2.0, 2.51, 2.66, 3.01, 4.1],
                   [0.5, 1.0, 0.55, 0.4, 0.5, 0.3, 0.25, 0.2, 0.1], [1.0, 1.1, 1.6, 2.0, 1.8, 2.6, 3.0, 3.6, 5.0], attack=0.003)
    return norm(out)


def glock(freq, dur, rng):
    n = int((dur + 1.2) * RATE)
    return norm(partials(freq, n, [1.0, 2.76, 5.4, 8.9], [1.0, 0.3, 0.12, 0.04], [2.5, 4.5, 7.0, 9.0], attack=0.002))


def glass(freq, dur, rng):
    n = int((dur + 0.9) * RATE)
    return norm(partials(freq, n, [1.0, 3.01, 4.99, 7.02], [1.0, 0.22, 0.1, 0.04], [3.5, 7.0, 11.0, 15.0], attack=0.003))


def synth_bass(freq, dur, rng, cutoff=520):
    n, hold = _hold(dur, 0.05)
    env = env_adsr(n, 0.004, 0.12, 0.55, 0.05, hold)
    ph = phase_of(freq, n)
    x = wave(ph, "saw", freq) + 0.8 * wave(ph * 0.5, "square", freq * 0.5)
    return norm(lp(x, cutoff) * env)


def pulse_synth(freq, dur, rng):
    n, hold = _hold(dur, 0.04)
    env = env_adsr(n, 0.003, 0.08, 0.5, 0.04, hold)
    ph = phase_of(freq, n)
    return norm(lp(wave(ph, "pulse", freq, duty=0.25), 2600) * env)


def sub(freq, dur, rng):
    n, hold = _hold(dur, 0.08)
    env = env_adsr(n, 0.01, 0.05, 0.95, 0.08, hold)
    return np.sin(phase_of(freq, n)) * env


def pizz(freq, dur, rng):
    return norm(lp(pluck(freq, min(dur, 0.5), rng, bright=0.9, damp=2.2, kmax=10), 900))


def dark_lead(freq, dur, rng):
    n, hold = _hold(dur, 0.12)
    env = env_adsr(n, 0.02, 0.1, 0.8, 0.12, hold)
    ph = phase_of(freq, n, vib=0.006, vib_rate=4.5, vib_delay=0.3)
    x = wave(ph, "square", freq) + 0.5 * wave(ph * 1.5, "saw", freq * 1.5)
    x = np.tanh(2.2 * lp(x, 1400))
    return norm(x * env)


# --- drums / percussion (cached, seeded) --------------------------------------

_DRUMS = {}


def drum(name, rng, pitch=None):
    key = (name, pitch)
    if key in _DRUMS:
        return _DRUMS[key]
    drng = np.random.default_rng(abs(hash(key)) % (2 ** 32))
    T = lambda d: np.arange(int(d * RATE)) / RATE
    if name == "kick":
        t = T(0.32)
        f = 48 + 120 * np.exp(-t * 32)
        x = np.sin(TAU * np.cumsum(f) / RATE) * np.exp(-t * 9) + lp(drng.uniform(-1, 1, len(t)), 3000) * np.exp(-t * 260) * 0.5
    elif name == "bigkick":
        t = T(0.6)
        f = 40 + 90 * np.exp(-t * 22)
        x = np.sin(TAU * np.cumsum(f) / RATE) * np.exp(-t * 5) + lp(drng.uniform(-1, 1, len(t)), 400) * np.exp(-t * 16) * 0.6
    elif name == "taiko":
        t = T(0.8)
        f = 55 + 70 * np.exp(-t * 18)
        x = np.sin(TAU * np.cumsum(f) / RATE) * np.exp(-t * 4) + lp(drng.uniform(-1, 1, len(t)), 900) * np.exp(-t * 20) * 0.8
        x += 0.3 * np.sin(TAU * 112 * t) * np.exp(-t * 7)
    elif name == "stomp":
        t = T(0.4)
        x = lp(drng.uniform(-1, 1, len(t)), 180) * np.exp(-t * 14) * 1.5 + np.sin(TAU * 58 * t) * np.exp(-t * 12)
    elif name == "snare":
        t = T(0.28)
        x = bp(drng.uniform(-1, 1, len(t)), 1200, 7500) * np.exp(-t * 20) + 0.6 * np.sin(TAU * 185 * t) * np.exp(-t * 28) + 0.3 * np.sin(TAU * 330 * t) * np.exp(-t * 40)
    elif name == "clicksnare":
        t = T(0.16)
        x = bp(drng.uniform(-1, 1, len(t)), 2500, 9000) * np.exp(-t * 36) + 0.5 * np.sin(TAU * 240 * t) * np.exp(-t * 50)
    elif name == "brush":
        t = T(0.24)
        x = lp(drng.uniform(-1, 1, len(t)), 4500) * np.exp(-t * 16) * (1 - np.exp(-t * 300))
    elif name == "hat":
        t = T(0.08)
        x = hp(drng.uniform(-1, 1, len(t)), 6500) * np.exp(-t * 62)
    elif name == "ohat":
        t = T(0.4)
        x = hp(drng.uniform(-1, 1, len(t)), 6000) * np.exp(-t * 9)
    elif name == "ride":
        t = T(0.9)
        x = bp(drng.uniform(-1, 1, len(t)), 4000, 11000) * np.exp(-t * 5) * 0.5
        for f in drng.uniform(3000, 9000, 8):
            x += 0.12 * np.sin(TAU * f * t) * np.exp(-t * 4)
    elif name == "crash":
        t = T(2.2)
        x = bp(drng.uniform(-1, 1, len(t)), 2500, 12500) * np.exp(-t * 2.2)
        for f in drng.uniform(2500, 8000, 6):
            x += 0.08 * np.sin(TAU * f * t) * np.exp(-t * 2.5)
    elif name == "tom":
        f0 = pitch or 140.0
        t = T(0.45)
        f = f0 + 0.6 * f0 * np.exp(-t * 20)
        x = np.sin(TAU * np.cumsum(f) / RATE) * np.exp(-t * 8) + lp(drng.uniform(-1, 1, len(t)), 1500) * np.exp(-t * 60) * 0.4
    elif name == "timpani":
        f0 = pitch or 73.4
        t = T(1.6)
        f = f0 + 0.25 * f0 * np.exp(-t * 25)
        ph = TAU * np.cumsum(f) / RATE
        x = (np.sin(ph) + 0.4 * np.sin(1.5 * ph) + 0.2 * np.sin(2.0 * ph)) * np.exp(-t * 2.4)
        x += lp(drng.uniform(-1, 1, len(t)), 260) * np.exp(-t * 30) * 1.2
        x = lp(x, 1800)
    elif name == "djembe_bass":
        t = T(0.35)
        f = 82 + 50 * np.exp(-t * 30)
        x = np.sin(TAU * np.cumsum(f) / RATE) * np.exp(-t * 11) + lp(drng.uniform(-1, 1, len(t)), 700) * np.exp(-t * 50) * 0.4
    elif name == "djembe_tone":
        t = T(0.2)
        x = np.sin(TAU * 190 * t) * np.exp(-t * 22) + bp(drng.uniform(-1, 1, len(t)), 800, 3000) * np.exp(-t * 45) * 0.5
    elif name == "djembe_slap":
        t = T(0.12)
        x = bp(drng.uniform(-1, 1, len(t)), 1500, 6000) * np.exp(-t * 42) + 0.5 * np.sin(TAU * 350 * t) * np.exp(-t * 60)
    elif name == "shaker":
        t = T(0.12)
        x = hp(drng.uniform(-1, 1, len(t)), 5000) * np.exp(-t * 42) * np.clip(t / 0.012, 0, 1)
    elif name == "tamb":
        t = T(0.28)
        x = bp(drng.uniform(-1, 1, len(t)), 5000, 10000) * np.exp(-t * 16)
        for f in drng.uniform(6000, 9500, 5):
            x += 0.1 * np.sin(TAU * f * t) * np.exp(-t * 14)
    elif name == "woodblock":
        t = T(0.08)
        x = np.sin(TAU * 900 * t) * np.exp(-t * 70) + 0.5 * np.sin(TAU * 1700 * t) * np.exp(-t * 90)
    elif name == "clap":
        t = T(0.26)
        x = np.zeros(len(t))
        for k, off in enumerate((0.0, 0.011, 0.023)):
            i = int(off * RATE)
            seg = bp(drng.uniform(-1, 1, len(t) - i), 1000, 4500)
            x[i:] += seg * np.exp(-(t[: len(t) - i]) * (40 if k < 2 else 13))
    elif name == "metal":
        t = T(0.9)
        base = pitch or 620.0
        x = np.zeros(len(t))
        for ratio, amp in ((1, 1), (1.41, 0.7), (2.3, 0.5), (2.97, 0.4), (3.8, 0.3), (5.3, 0.2)):
            x += amp * np.sin(TAU * base * ratio * t) * np.exp(-t * (5 + ratio))
        x += hp(drng.uniform(-1, 1, len(t)), 5000) * np.exp(-t * 40) * 0.5
    elif name == "rim":
        t = T(0.06)
        x = bp(drng.uniform(-1, 1, len(t)), 1500, 5000) * np.exp(-t * 80) + np.sin(TAU * 1100 * t) * np.exp(-t * 110)
    else:
        raise KeyError(name)
    _DRUMS[key] = norm(x)
    return _DRUMS[key]


# ---------------------------------------------------------------------------
# The track buffer: circular adds keep the loop seamless
# ---------------------------------------------------------------------------

class Track:
    def __init__(self, name, bpm, bars, bpb=4, swing=0.0, seed=1, loop=True):
        self.name, self.bpm, self.bars, self.bpb, self.swing, self.loop = name, bpm, bars, bpb, swing, loop
        self.beat = 60.0 / bpm
        self.n = int(round(bars * bpb * self.beat * RATE))
        self.buf = np.zeros(self.n + (0 if loop else int(3.0 * RATE)))
        self.rng = np.random.default_rng(seed)
        self.prev_freq = None
        self._cache = {}

    def render(self, inst, freq, dur, **kw):
        """Identical notes (same instrument, pitch, length, options) render once per track."""
        key = (inst.__name__, round(freq, 4), round(dur, 5), tuple(sorted((k, round(v, 5) if isinstance(v, float) else v) for k, v in kw.items())))
        if key not in self._cache:
            if len(self._cache) > 4000:
                self._cache.clear()
            self._cache[key] = inst(freq, dur, self.rng, **kw)
        return self._cache[key]

    def sec(self, pos):
        """Beat position -> seconds, with swing on the off-beat eighths."""
        frac = pos - math.floor(pos)
        if self.swing and abs(frac - 0.5) < 1e-6:
            pos += self.swing * 0.25
        return pos * self.beat

    def add(self, start, samples, vol=1.0):
        if vol == 0.0 or len(samples) == 0:
            return
        x = samples * vol
        N = len(self.buf)
        s = int(round(start * RATE))
        if not self.loop:
            end = min(N, s + len(x))
            if s < N:
                self.buf[s:end] += x[: end - s]
            return
        s %= N
        i = 0
        while i < len(x):
            chunk = min(len(x) - i, N - s)
            self.buf[s: s + chunk] += x[i: i + chunk]
            i += chunk
            s = 0

    def note(self, inst, pos, dur, pitch, vol, legato=0.92, **kw):
        freq = note_freq(pitch) if isinstance(pitch, str) else float(pitch)
        samples = self.render(inst, freq, max(0.03, dur * self.beat * legato), **kw)
        self.add(self.sec(pos), samples, vol)

    def hit(self, name, pos, vol=1.0, pitch=None):
        self.add(self.sec(pos), drum(name, self.rng, pitch), vol)

    def bar_pos(self, bar):
        return bar * self.bpb


# ---------------------------------------------------------------------------
# Pattern helpers
# ---------------------------------------------------------------------------

def melody(tr, inst, bars_, start_bar, vol, legato=0.92, octave=0, fx=None, unison=None, gliss=False, **kw):
    """Plays bars of (dur, note). fx=(delay, feedback, repeats) adds an echo per note."""
    pos = tr.bar_pos(start_bar)
    for bar in bars_:
        for dur, n in bar:
            if n is not None:
                freq = note_freq(n) * (2.0 ** octave)
                extra = dict(kw)
                if gliss:
                    extra["glide_from"] = tr.prev_freq
                samples = tr.render(inst, freq, max(0.03, dur * tr.beat * legato), **extra)
                if fx:
                    samples = echo(samples, *fx)
                tr.add(tr.sec(pos), samples, vol)
                if unison:
                    for u_inst, u_oct, u_vol in unison:
                        tr.add(tr.sec(pos), tr.render(u_inst, freq * (2.0 ** u_oct), max(0.03, dur * tr.beat * legato)), vol * u_vol)
                tr.prev_freq = freq
            pos += dur


def chords(tr, inst, names, start_bar, vol, octave=3, length=1.0, **kw):
    """One sustained chord per bar (length in bars)."""
    for i, name in enumerate(names):
        for n in chord_notes(name, octave):
            tr.note(inst, tr.bar_pos(start_bar + i), tr.bpb * length, n, vol, legato=0.98, **kw)


def chord_stabs(tr, inst, names, start_bar, vol, positions, octave=3, dur=0.4, **kw):
    for i, name in enumerate(names):
        for p in positions:
            for n in chord_notes(name, octave):
                tr.note(inst, tr.bar_pos(start_bar + i) + p, dur, n, vol, **kw)


def arp(tr, inst, names, start_bar, vol, step=0.5, pattern="up", octave=4, length=0.9, spread=1, **kw):
    for i, name in enumerate(names):
        notes = chord_notes(name, octave)
        if spread > 1:
            notes = notes + [name_of(midi_of(n) + 12) for n in notes][: spread * len(notes) - len(notes)]
        if pattern == "updown":
            order = notes + notes[-2:0:-1]
        elif pattern == "down":
            order = notes[::-1]
        elif pattern == "broken":
            order = [notes[0], notes[2 % len(notes)], notes[1], notes[2 % len(notes)]]
        elif pattern == "random":
            order = list(tr.rng.choice(notes, size=max(4, int(tr.bpb / step))))
        else:
            order = notes
        k = 0
        p = 0.0
        while p < tr.bpb - 1e-6:
            tr.note(inst, tr.bar_pos(start_bar + i) + p, step * length, order[k % len(order)], vol, legato=1.0, **kw)
            k += 1
            p += step


def bass(tr, inst, names, start_bar, vol, style="roots", octave=2, **kw):
    for i, name in enumerate(names):
        notes = chord_notes(name, octave)
        root, third, fifth = notes[0], notes[1], notes[2]
        up = name_of(midi_of(root) + 12)
        b7 = name_of(midi_of(root) + 10)
        t0 = tr.bar_pos(start_bar + i)
        if style == "roots":
            for b in range(tr.bpb):
                tr.note(inst, t0 + b, 0.9, root if b % 2 == 0 else fifth, vol, **kw)
        elif style == "eighths":
            for e in range(tr.bpb * 2):
                n = root if e % 4 != 3 else fifth
                if e == tr.bpb * 2 - 1:
                    n = up
                tr.note(inst, t0 + e * 0.5, 0.42, n, vol, **kw)
        elif style == "pump16":
            for e in range(tr.bpb * 4):
                n = root if e % 8 != 7 else up
                tr.note(inst, t0 + e * 0.25, 0.22, n, vol * (1.0 if e % 2 == 0 else 0.75), **kw)
        elif style == "halftime":
            for p, n in ((0, root), (1.75, root), (2.5, root), (3.5, fifth)):
                tr.note(inst, t0 + p, 0.6 if p != 0 else 1.5, n, vol, **kw)
        elif style == "synco":
            for p, n in ((0, root), (0.75, root), (1.5, b7), (2.0, root), (2.75, fifth), (3.5, b7)):
                tr.note(inst, t0 + p, 0.4, n, vol, **kw)
        elif style == "walk":
            seqn = [root, third, fifth, name_of(midi_of(root) + 9)] if i % 2 == 0 else [root, fifth, third, fifth]
            for b in range(tr.bpb):
                tr.note(inst, t0 + b, 0.85, seqn[b % len(seqn)], vol, **kw)
        elif style == "bounce":
            for b in range(tr.bpb):
                tr.note(inst, t0 + b, 0.45, root if b % 2 == 0 else fifth, vol, **kw)
                tr.note(inst, t0 + b + 0.5, 0.3, up if b % 2 == 0 else fifth, vol * 0.6, **kw)
        elif style == "waltz":
            tr.note(inst, t0, 1.2, root, vol, **kw)
        elif style == "68":
            tr.note(inst, t0, 2.5, root, vol, **kw)
            tr.note(inst, t0 + 3, 2.0, fifth if i % 2 == 0 else root, vol * 0.85, **kw)
        elif style == "drone":
            tr.note(inst, t0, tr.bpb, root, vol, legato=1.02, **kw)
        elif style == "whole":
            tr.note(inst, t0, tr.bpb, root, vol, legato=0.97, **kw)
        elif style == "ostinato":
            pat = [root, root, root, name_of(midi_of(root) + 3), root, root, b7, root]
            for e, n in enumerate(pat[: tr.bpb * 2]):
                tr.note(inst, t0 + e * 0.5, 0.4, n, vol, **kw)
        elif style == "march":
            for p, n in ((0, root), (1, root), (2, fifth), (3, fifth), (3.5, root)):
                tr.note(inst, t0 + p, 0.45, n, vol, **kw)
        elif style == "five":
            for p, n in ((0, root), (1.5, fifth), (2.5, root), (4, b7)):
                tr.note(inst, t0 + p, 0.9, n, vol, **kw)


def drums(tr, start_bar, nbars, style, vol=1.0, fills=True, crash_every=8):
    for i in range(nbars):
        bar = start_bar + i
        t0 = tr.bar_pos(bar)
        last = fills and crash_every and ((bar + 1) % crash_every == 0)
        if crash_every and bar % crash_every == 0 and style not in ("none", "pastoral", "snow", "waltz", "hand", "sky"):
            tr.hit("crash", t0, 0.35 * vol)
        if style == "rock":
            for p in (0, 2, 2.5):
                tr.hit("kick", t0 + p, 0.9 * vol)
            for p in (1, 3):
                tr.hit("snare", t0 + p, 0.75 * vol)
            for e in range(8):
                tr.hit("hat", t0 + e * 0.5, (0.32 if e % 2 == 0 else 0.2) * vol)
        elif style == "fast":
            for p in (0, 1, 2, 3, 3.5):
                tr.hit("kick", t0 + p, 0.85 * vol)
            for p in (1, 3):
                tr.hit("snare", t0 + p, 0.7 * vol)
            for e in range(16):
                tr.hit("hat", t0 + e * 0.25, (0.3 if e % 4 == 0 else 0.14) * vol)
        elif style == "drive":
            for p in (0, 1.5, 2, 3.5):
                tr.hit("kick", t0 + p, 0.9 * vol)
            for p in (1, 3):
                tr.hit("snare", t0 + p, 0.8 * vol)
            for e in range(8):
                tr.hit("hat", t0 + e * 0.5, (0.3 if e % 2 == 0 else 0.18) * vol)
            tr.hit("timpani", t0, 0.5 * vol, pitch=65.4)
            tr.hit("timpani", t0 + 2, 0.4 * vol, pitch=65.4)
        elif style == "halftime":
            tr.hit("bigkick", t0, 1.0 * vol)
            tr.hit("bigkick", t0 + 1.75, 0.6 * vol)
            tr.hit("snare", t0 + 2, 0.85 * vol)
            for e in range(8):
                tr.hit("hat", t0 + e * 0.5, (0.28 if e % 2 == 0 else 0.15) * vol)
            tr.hit("hat", t0 + 3.75, 0.12 * vol)
        elif style == "swing":
            for p in (0, 2.5):
                tr.hit("kick", t0 + p, 0.8 * vol)
            for p in (1, 3):
                tr.hit("snare", t0 + p, 0.6 * vol)
            tr.hit("rim", t0 + 1.5, 0.3 * vol)
            for e in range(8):
                tr.hit("ride", t0 + e * 0.5, (0.28 if e % 2 == 0 else 0.16) * vol)
        elif style == "electro":
            for p in (0, 2):
                tr.hit("kick", t0 + p, 0.8 * vol)
            for p in (1, 3):
                tr.hit("clicksnare", t0 + p, 0.6 * vol)
            for e in range(8):
                tr.hit("hat", t0 + e * 0.5 + 0.5, 0.2 * vol)
            tr.hit("ohat", t0 + 2.5, 0.12 * vol)
        elif style == "soft":
            tr.hit("kick", t0, 0.6 * vol)
            tr.hit("kick", t0 + 2.5, 0.4 * vol)
            for p in (1, 3):
                tr.hit("brush", t0 + p, 0.45 * vol)
            for e in range(8):
                tr.hit("hat", t0 + e * 0.5, (0.18 if e % 2 == 0 else 0.1) * vol)
        elif style == "pastoral":            # 6/8: beats are eighths
            tr.hit("kick", t0, 0.6 * vol)
            tr.hit("kick", t0 + 3, 0.4 * vol)
            for e in range(6):
                tr.hit("shaker", t0 + e, (0.3 if e % 3 == 0 else 0.16) * vol)
            tr.hit("tamb", t0 + 3, 0.3 * vol)
        elif style == "waltz":               # 3/4
            tr.hit("kick", t0, 0.45 * vol)
            tr.hit("tamb", t0 + 1, 0.22 * vol)
            tr.hit("tamb", t0 + 2, 0.2 * vol)
            tr.hit("shaker", t0 + 1.5, 0.12 * vol)
            tr.hit("shaker", t0 + 2.5, 0.12 * vol)
        elif style == "hand":                # djembe groove
            for p, n, v in ((0, "djembe_bass", 1.0), (0.5, "djembe_tone", 0.5), (1, "djembe_slap", 0.8), (1.5, "djembe_tone", 0.5),
                            (2, "djembe_bass", 0.9), (2.5, "djembe_bass", 0.6), (3, "djembe_slap", 0.8), (3.5, "djembe_tone", 0.6), (3.75, "djembe_slap", 0.4)):
                tr.hit(n, t0 + p, v * vol)
            for e in range(16):
                tr.hit("shaker", t0 + e * 0.25, (0.14 if e % 4 == 0 else 0.07) * vol)
        elif style == "forest":
            tr.hit("tom", t0, 0.55 * vol, pitch=110.0)
            tr.hit("tom", t0 + 2.5, 0.35 * vol, pitch=150.0)
            tr.hit("woodblock", t0 + 1.5, 0.3 * vol)
            tr.hit("woodblock", t0 + 3, 0.25 * vol)
            tr.hit("shaker", t0 + 3.5, 0.15 * vol)
        elif style == "march":
            for p in (0, 2):
                tr.hit("kick", t0 + p, 0.75 * vol)
            for p in (1, 3):
                tr.hit("snare", t0 + p, 0.7 * vol)
            for p in (1.5, 2.5, 3.5, 3.75):
                tr.hit("snare", t0 + p, 0.28 * vol)
            tr.hit("timpani", t0, 0.55 * vol, pitch=58.3)
        elif style == "war":
            for p, v in ((0, 1.0), (1, 0.7), (2, 0.9), (3, 0.7), (1.5, 0.45), (3.5, 0.5)):
                tr.hit("taiko", t0 + p, v * vol)
            for p in (1, 3):
                tr.hit("snare", t0 + p, 0.5 * vol)
            for p in (0.5, 1.5, 2.5, 3.5):
                tr.hit("snare", t0 + p, 0.22 * vol)
            tr.hit("timpani", t0, 0.6 * vol, pitch=73.4)
        elif style == "coliseum":
            tr.hit("stomp", t0, 1.0 * vol)
            tr.hit("stomp", t0 + 1, 0.9 * vol)
            tr.hit("clap", t0 + 2, 0.9 * vol)
            tr.hit("taiko", t0 + 2, 0.5 * vol)
            tr.hit("kick", t0 + 3.5, 0.5 * vol)
            for e in range(8):
                tr.hit("hat", t0 + e * 0.5, (0.22 if e % 2 == 0 else 0.12) * vol)
        elif style == "playful":
            tr.hit("kick", t0, 0.6 * vol)
            tr.hit("kick", t0 + 2.5, 0.45 * vol)
            for p in (1, 3):
                tr.hit("clap", t0 + p, 0.5 * vol)
            for e in range(8):
                tr.hit("shaker", t0 + e * 0.5, (0.3 if e % 2 == 0 else 0.18) * vol)
            tr.hit("woodblock", t0 + 1.5, 0.3 * vol)
            tr.hit("woodblock", t0 + 3.5, 0.3 * vol)
        elif style == "void":                # 5/4
            tr.hit("bigkick", t0, 0.9 * vol)
            tr.hit("bigkick", t0 + 2.5, 0.7 * vol)
            tr.hit("metal", t0 + 1, 0.5 * vol, pitch=620.0)
            tr.hit("metal", t0 + 3.5, 0.4 * vol, pitch=870.0)
            tr.hit("clicksnare", t0 + 4, 0.4 * vol)
            for e in range(10):
                tr.hit("hat", t0 + e * 0.5, (0.2 if e % 2 == 0 else 0.1) * vol)
        elif style == "tension":
            for p in (0, 1, 2, 3):
                tr.hit("kick", t0 + p, 0.8 * vol)
            tr.hit("snare", t0 + 1, 0.6 * vol)
            tr.hit("snare", t0 + 3, 0.7 * vol)
            for e in range(16):
                tr.hit("hat", t0 + e * 0.25, (0.26 if e % 4 == 0 else 0.12) * vol)
            tr.hit("timpani", t0, 0.5 * vol, pitch=55.0)
            tr.hit("timpani", t0 + 2.5, 0.35 * vol, pitch=55.0)
        elif style == "ominous":
            tr.hit("timpani", t0, 0.8 * vol, pitch=49.0)
            tr.hit("timpani", t0 + 2.5, 0.4 * vol, pitch=49.0)
            tr.hit("bigkick", t0 + 3, 0.5 * vol)
        if last:
            fill(tr, bar, style, vol)


def fill(tr, bar, style, vol):
    t0 = tr.bar_pos(bar)
    if style in ("rock", "fast", "drive", "tension", "coliseum", "electro", "playful"):
        for k in range(8):
            tr.hit("tom" if k < 6 else "snare", t0 + tr.bpb - 2 + k * 0.25, (0.35 + 0.06 * k) * vol, pitch=[180, 180, 150, 150, 120, 120][k] if k < 6 else None)
    elif style in ("march", "war", "halftime", "ominous"):
        roll(tr, t0 + tr.bpb - 2, 2.0, "snare", 0.15 * vol, 0.6 * vol)
        tr.hit("timpani", t0 + tr.bpb - 1, 0.6 * vol, pitch=65.4)
    elif style in ("hand",):
        for k in range(8):
            tr.hit("djembe_tone" if k % 2 == 0 else "djembe_slap", t0 + tr.bpb - 2 + k * 0.25, (0.4 + 0.05 * k) * vol)
    elif style in ("swing",):
        for k in range(6):
            tr.hit("snare", t0 + tr.bpb - 1.5 + k * 0.25, (0.25 + 0.06 * k) * vol)


def roll(tr, pos, dur_beats, name, v0, v1, spacing=0.125, pitch=None):
    steps = int(dur_beats / spacing)
    for k in range(steps):
        tr.hit(name, pos + k * spacing, v0 + (v1 - v0) * k / max(1, steps - 1), pitch=pitch)


def bed(tr, kind, vol, phrase_bars=8):
    """A continuous background (crowd, wind) that is periodic in the loop length."""
    n = len(tr.buf)
    t = np.arange(n) / RATE
    noise = tr.rng.uniform(-1, 1, n)
    L = n / RATE
    if kind == "crowd":
        x = lp(noise, 1400, 1) * 0.8 + lp(noise, 300, 1) * 0.6
        mod = 0.65 + 0.2 * np.sin(TAU * 2 * t / L) + 0.15 * np.sin(TAU * 7 * t / L + 1.3)
        bar_s = tr.bpb * tr.beat
        phrase = np.exp(-((t % (phrase_bars * bar_s)) / 0.9) ** 2 * 0.5)
        x *= mod + 0.9 * phrase
    elif kind == "wind":
        x = bp(noise, 250, 1400, 1)
        mod = 0.55 + 0.35 * np.sin(TAU * 3 * t / L) + 0.15 * np.sin(TAU * 11 * t / L + 2.0)
        x *= mod
    elif kind == "rumble":
        x = lp(noise, 120, 2)
        x *= 0.6 + 0.4 * np.sin(TAU * 5 * t / L)
    else:
        raise KeyError(kind)
    tr.add(0.0, norm(x), vol)


def circular(fn, x, loop, warm=2.0):
    """Runs a causal filter over a loop with its state warmed up by the loop's own tail,
    so the first sample follows the last one seamlessly."""
    if not loop:
        return fn(x)
    w = min(len(x), int(warm * RATE))
    return fn(np.concatenate([x[-w:], x]))[w:]


def reverb(x, loop, mix=0.2, taps=((0.031, 0.62), (0.047, 0.5), (0.073, 0.42), (0.109, 0.3)), orders=3, tone=4200):
    wet = np.zeros_like(x)
    for delay, gain in taps:
        d = int(delay * RATE)
        g = 1.0
        for k in range(1, orders + 1):
            g *= gain
            wet += np.roll(x, k * d) * g      # circular: the tail wraps into the loop start
    wet = circular(lambda y: lp(y, tone), wet, loop)
    return x + wet * mix


TARGET_RMS_DB = -14.5


def master(tr, mix_reverb=0.18, tone=4200, drive=1.25):
    x = circular(lambda y: hp(y, 28.0), tr.buf, tr.loop)
    x = reverb(x, tr.loop, mix_reverb, tone=tone)
    x = np.tanh(norm(x) * drive) / math.tanh(drive)
    # Equal loudness across the set (pads are dense, drums are peaky): RMS to the target,
    # then a soft ceiling so the peaky tracks still cannot clip.
    rms = math.sqrt(float(np.mean(x * x))) + 1e-9
    x = x * (10 ** (TARGET_RMS_DB / 20.0) / rms)
    over = np.abs(x) > 0.9
    x[over] = np.sign(x[over]) * (0.9 + 0.08 * np.tanh((np.abs(x[over]) - 0.9) / 0.08))
    if not tr.loop:                      # a jingle ends when its tail has faded
        loud = np.nonzero(np.abs(x) > 0.002)[0]
        x = x[: min(len(x), (loud[-1] if len(loud) else len(x)) + int(0.15 * RATE))]
    return x


# ---------------------------------------------------------------------------
# The compositions
# ---------------------------------------------------------------------------

INFO = {}


def track(name, mood, key, meter):
    def deco(fn):
        INFO[name] = {"fn": fn, "mood": mood, "key": key, "meter": meter}
        return fn
    return deco


@track("title", "heroic, hopeful: brass theme over strings, plucked arps and rock drums", "D major", "4/4 112")
def title():
    tr = Track("title", 112, 32, seed=11)
    A = prog("D A Bm G D A G A")
    B = prog("Bm G D A Bm G Em A")
    mel_a = bars("F#5:1 A5:1 D6:2 | C#6:1 A5:1 E5:2 | B5:1 A5:1 F#5:1 D5:1 | G5:1.5 A5:.5 B5:2 | A5:1 D6:1 F#6:1.5 E6:.5 | E6:1 C#6:1 A5:2 | B5:1 D6:1 G6:1 F#6:1 | E6:3 C#6:1")
    mel_b = bars("D6:.5 E6:.5 F#6:1 A6:1 F#6:1 | E6:1 C#6:1 E6:2 | D6:1 F#6:1 B6:1 A6:1 | G6:1 F#6:1 E6:1 D6:1 | F#6:1 A6:1 D7:2 | A6:1 E6:1 A6:2 | B6:1 G6:1 D6:1 B5:1 | E6:2 E5:2")
    for s, names in enumerate([A, A, B, A]):
        sb = s * 8
        chords(tr, strings, names, sb, 0.09 + 0.02 * s, octave=3)
        arp(tr, pluck, names, sb, 0.16, step=0.5, pattern="updown", octave=4)
        bass(tr, synth_bass, names, sb, 0.5, "eighths", octave=2)
        drums(tr, sb, 8, "rock", 0.9 if s else 0.7)
    melody(tr, pluck, mel_a, 0, 0.3, octave=0)
    melody(tr, brass, mel_a, 8, 0.36)
    melody(tr, brass, mel_b, 16, 0.36, unison=[(strings, -1, 0.5)])
    melody(tr, brass, mel_a, 24, 0.38, unison=[(brass, -1, 0.45)])
    return master(tr, 0.16)


@track("town", "cosy village waltz: flute over lute oom-pah-pah, light tambourine", "G major", "3/4 132")
def town():
    tr = Track("town", 132, 48, bpb=3, seed=12)
    A = prog("G G C D G Em C D")
    B = prog("Em Bm C G Am D G D")
    mel_a = bars("D5:1 G5:1 B5:1 | A5:2 G5:1 | E5:1 G5:1 C6:1 | B5:2 A5:1 | G5:1 B5:1 D6:1 | E6:2 D6:1 | C6:1 B5:1 A5:1 | G5:3", 3)
    mel_b = bars("E5:1 G5:1 B5:1 | D6:2 B5:1 | C6:1 E6:1 D6:1 | B5:2 G5:1 | A5:1 C6:1 E6:1 | F#6:2 D6:1 | B5:1 A5:1 F#5:1 | G5:2 -:1", 3)
    for s, names in enumerate([A, A, B, A, B, A]):
        sb = s * 8
        bass(tr, lute, names, sb, 0.42, "waltz", octave=2)
        chord_stabs(tr, lute, names, sb, 0.2, (1, 2), octave=3, dur=0.5)
        chords(tr, strings, names, sb, 0.05 if s else 0.0, octave=4)
        drums(tr, sb, 8, "waltz", 0.8, fills=False, crash_every=0)
    melody(tr, lute, mel_a, 0, 0.3)
    melody(tr, flute, mel_a, 8, 0.3)
    melody(tr, flute, mel_b, 16, 0.3)
    melody(tr, flute, mel_a, 24, 0.3, unison=[(lute, 0, 0.5)])
    melody(tr, flute, mel_b, 32, 0.32, unison=[(glock, 1, 0.25)])
    melody(tr, flute, mel_a, 40, 0.32, unison=[(lute, 0, 0.5)])
    return master(tr, 0.2)


@track("meadow", "bright pastoral 6/8: flute tune, harp arps, shaker and tambourine", "C major", "6/8 132")
def meadow():
    tr = Track("meadow", 132, 24, bpb=6, seed=13)
    A = prog("C F G C Am F G C")
    B = prog("F C G Am F G C C")
    mel_a = bars("E5:1 G5:1 C6:1 B5:2 G5:1 | A5:1 F5:1 A5:1 G5:3 | D5:1 G5:1 B5:1 A5:2 G5:1 | E5:3 C5:3 | A5:1 C6:1 E6:1 D6:2 C6:1 | A5:1 F5:1 A5:1 C6:3 | B5:1 D6:1 G6:1 F6:2 D6:1 | C6:6", 6)
    mel_b = bars("A5:1 C6:1 F6:1 E6:2 C6:1 | G5:1 C6:1 E6:1 D6:3 | B5:1 D6:1 G6:1 F6:2 D6:1 | E6:1 C6:1 A5:1 C6:3 | F6:1 E6:1 D6:1 C6:2 A5:1 | G5:1 B5:1 D6:1 F6:3 | E6:1 G5:1 C6:1 E6:2 D6:1 | C6:6", 6)
    for s, names in enumerate([A, B, A]):
        sb = s * 8
        arp(tr, pluck, names, sb, 0.18, step=1.0, pattern="broken", octave=4, length=1.0)
        bass(tr, pizz, names, sb, 0.5, "68", octave=2)
        chords(tr, strings, names, sb, 0.07, octave=4)
        drums(tr, sb, 8, "pastoral", 0.9, fills=False, crash_every=0)
    melody(tr, flute, mel_a, 0, 0.32)
    melody(tr, flute, mel_b, 8, 0.32, unison=[(glock, 1, 0.22)])
    melody(tr, flute, mel_a, 16, 0.34, unison=[(pluck, 0, 0.5)])
    return master(tr, 0.2)


@track("dark_forest", "mysterious: marimba ostinato, low flute with echo, toms and woodblock", "E minor", "4/4 96")
def dark_forest():
    tr = Track("dark_forest", 96, 32, seed=14)
    A = prog("Em Csus2 D Em Em C Am B")
    B = prog("Am Em C B Am Em D B")
    mel_a = bars("B4:2 E5:1 G5:1 | F#5:3 E5:1 | D5:2 F#5:1 A5:1 | G5:4 | B4:2 E5:1 G5:1 | B5:3 A5:1 | C6:1 B5:1 A5:1 E5:1 | D#5:4")
    mel_b = bars("C5:1 E5:1 A5:2 | G5:2 E5:2 | E5:1 G5:1 C6:2 | B5:2 D#5:2 | A5:1 C6:1 E6:2 | D6:2 B5:2 | A5:1 F#5:1 D5:1 F#5:1 | D#5:2 -:2")
    for s, names in enumerate([A, A, B, A]):
        sb = s * 8
        arp(tr, marimba, names, sb, 0.26, step=0.5, pattern="updown", octave=3, spread=2)
        bass(tr, pizz, names, sb, 0.55, "halftime", octave=2)
        chords(tr, pad, names, sb, 0.09, octave=3, cutoff=800)
        drums(tr, sb, 8, "forest", 0.9, fills=False, crash_every=0)
    melody(tr, flute, mel_a, 8, 0.3, octave=-1, fx=(0.3125, 0.4, 3), breath=0.2)
    melody(tr, flute, mel_b, 16, 0.3, octave=-1, fx=(0.3125, 0.4, 3), breath=0.2)
    melody(tr, flute, mel_a, 24, 0.3, octave=0, fx=(0.3125, 0.45, 3), unison=[(glock, 0, 0.12)])
    return master(tr, 0.3, tone=3200)


@track("desert", "dorian caravan: oud-like pluck with grace notes, reed lead, djembe groove, drone", "D dorian", "4/4 104")
def desert():
    tr = Track("desert", 104, 32, seed=15)
    A = prog("Dm Dm C Dm Dm F C Dm")
    B = prog("Am C G Dm Am C G Dm")
    mel_a = bars("D5:1 F5:.5 E5:.5 D5:1 A4:1 | D5:1.5 E5:.5 F5:1 E5:1 | G5:1 F5:.5 E5:.5 D5:1 C5:1 | D5:3 -:1 | A5:1 G5:.5 F5:.5 E5:1 F5:1 | G5:1.5 A5:.5 B5:1 A5:1 | G5:1 F5:.5 E5:.5 D5:1 C5:1 | D5:3 -:1")
    mel_b = bars("A5:1.5 B5:.5 C6:1 A5:1 | G5:1 F5:.5 G5:.5 A5:2 | E5:1 G5:.5 F5:.5 E5:1 D5:1 | C5:1 D5:1 E5:2 | F5:1 G5:.5 F5:.5 E5:1 D5:1 | C5:1.5 D5:.5 E5:1 C5:1 | D5:1 F5:.5 E5:.5 D5:1 C5:1 | D5:4")

    def ornamented(bars_):
        out = []
        for bar in bars_:
            nb = []
            for d, n in bar:
                if n is not None and d >= 1.0:
                    nb.append((0.125, name_of(midi_of(n) + 2)))
                    nb.append((d - 0.125, n))
                else:
                    nb.append((d, n))
            out.append(nb)
        return out

    for s, names in enumerate([A, A, B, A]):
        sb = s * 8
        bass(tr, sub, names, sb, 0.5, "drone", octave=2)
        bass(tr, lute, names, sb, 0.3, "roots", octave=2)
        chord_stabs(tr, lute, names, sb, 0.14, (1.5, 3.5), octave=4, dur=0.3)
        drums(tr, sb, 8, "hand", 0.9, crash_every=0)
    melody(tr, koto, ornamented(mel_a), 0, 0.34)
    melody(tr, koto, ornamented(mel_a), 8, 0.34, unison=[(reed, 0, 0.3)])
    melody(tr, reed, mel_b, 16, 0.3, legato=0.98)
    melody(tr, koto, ornamented(mel_a), 24, 0.34, unison=[(reed, 0, 0.3)])
    return master(tr, 0.2)


@track("snow", "slow and still: glockenspiel melody, choir and pad, sub bass, twinkles, no drums", "A major", "4/4 72")
def snow():
    tr = Track("snow", 72, 24, seed=16)
    A = prog("A E F#m D A E D E")
    B = prog("F#m D A E F#m D Bm E")
    mel_a = bars("C#6:2 E6:1 A6:1 | G#6:3 E6:1 | F#6:2 A6:1 C#7:1 | B6:4 | A6:1 E6:1 C#6:2 | B5:2 G#5:2 | A5:1 B5:1 D6:1 C#6:1 | B5:4")
    mel_b = bars("A6:1.5 F#6:.5 C#6:2 | D6:1 F#6:1 A6:2 | E6:1 C#6:1 A5:2 | B5:2 G#5:1 E5:1 | F#5:1 A5:1 C#6:2 | D6:2 F#6:2 | B5:1 D6:1 F#6:1 D6:1 | E6:4")
    for s, names in enumerate([A, B, A]):
        sb = s * 8
        chords(tr, pad, names, sb, 0.12, octave=3, cutoff=900)
        chords(tr, choir, names, sb, 0.08 if s else 0.04, octave=4)
        bass(tr, sub, names, sb, 0.5, "whole", octave=2)
        arp(tr, glass, names, sb, 0.07, step=1.0 / 3.0, pattern="up", octave=5, spread=2)
    melody(tr, glock, mel_a, 0, 0.3)
    melody(tr, glock, mel_b, 8, 0.3, unison=[(choir, -1, 0.4)])
    melody(tr, glock, mel_a, 16, 0.3, unison=[(flute, 0, 0.3)])
    for bar in range(24):
        for k in range(2):
            p = tr.bar_pos(bar) + tr.rng.uniform(0, 4)
            n = ["A6", "C#7", "E7", "B6", "F#7"][int(tr.rng.integers(5))]
            tr.note(glass, p, 0.5, n, 0.08)
    return master(tr, 0.35, tone=5200, drive=1.1)


@track("volcano", "driving: low brass ostinato, timpani, double kick, minor brass theme", "F minor", "4/4 140")
def volcano():
    tr = Track("volcano", 140, 40, seed=17)
    A = prog("Fm Fm Db Eb Fm Fm Db C")
    B = prog("Bbm Fm Db C Bbm Fm Db C")
    mel_a = bars("F5:1 Ab5:1 C6:1.5 Bb5:.5 | Ab5:1 G5:1 F5:2 | Db5:1 F5:1 Ab5:1.5 G5:.5 | Eb5:2 G5:2 | F5:.5 F5:.5 Ab5:1 C6:1.5 Db6:.5 | C6:1 Bb5:1 Ab5:2 | Db6:1 C6:1 Bb5:1 Ab5:1 | G5:3 E5:1")
    mel_b = bars("Bb5:1 Db6:1 F6:2 | Eb6:1 C6:1 Ab5:2 | Db6:1 F6:1 Ab6:1.5 G6:.5 | E6:2 G6:2 | F6:.5 F6:.5 Db6:1 Bb5:2 | C6:1 Ab5:1 F5:2 | Db6:1 Eb6:1 F6:1 Ab6:1 | G6:2 E6:2")
    for s, names in enumerate([A, A, B, A, B]):
        sb = s * 8
        bass(tr, low_brass, names, sb, 0.42, "ostinato", octave=2)
        bass(tr, synth_bass, names, sb, 0.4, "eighths", octave=1, cutoff=300)
        chords(tr, strings, names, sb, 0.07, octave=3, bright=0.6)
        chord_stabs(tr, brass, names, sb, 0.12 if s else 0.0, (2.5,), octave=3, dur=0.3)
        drums(tr, sb, 8, "drive", 0.95)
    melody(tr, brass, mel_a, 8, 0.36)
    melody(tr, brass, mel_b, 16, 0.36)
    melody(tr, brass, mel_a, 24, 0.38, unison=[(low_brass, -1, 0.45)])
    melody(tr, brass, mel_b, 32, 0.38, unison=[(brass, 1, 0.3)])
    bed(tr, "rumble", 0.08)
    return master(tr, 0.14, drive=1.4)


@track("graveyard", "minor organ: pipe-organ lines over pedal, low choir, tolling bell, timpani", "D minor", "4/4 80")
def graveyard():
    tr = Track("graveyard", 80, 28, seed=18)
    A = prog("Dm Gm A Dm Bb Gm A A")
    B = prog("Dm C Bb A Dm Gm A7 Dm")
    mel_a = bars("D5:1 F5:1 A5:1.5 G5:.5 | F5:1 E5:1 D5:2 | C#5:1 E5:1 A5:2 | D5:4 | F5:1 D5:1 Bb5:2 | A5:1 G5:1 F5:1 E5:1 | C#5:2 E5:2 | A4:4")
    mel_b = bars("D6:.5 C#6:.5 D6:.5 E6:.5 F6:1 E6:1 | E6:.5 D6:.5 E6:.5 F6:.5 G6:1 E6:1 | F6:.5 E6:.5 D6:.5 C6:.5 Bb5:1 D6:1 | C#6:2 E6:2 | F6:1 A5:1 D6:2 | Bb5:1 D6:1 G5:2 | A5:1 C#6:1 E6:1 G6:1 | F6:1 E6:1 D6:2")
    intro = prog("Dm Dm Gm A")
    chords(tr, organ, intro, 0, 0.14, octave=3)
    bass(tr, organ, intro, 0, 0.3, "whole", octave=1)
    for s, names in enumerate([A, B, A]):
        sb = 4 + s * 8
        chords(tr, organ, names, sb, 0.13, octave=3)
        bass(tr, organ, names, sb, 0.32, "whole", octave=1)
        chords(tr, choir, names, sb, 0.07 if s else 0.0, octave=3, dark=True)
        drums(tr, sb, 8, "ominous", 0.6 if s else 0.0, fills=True)
    melody(tr, organ, mel_a, 4, 0.3, octave=0)
    melody(tr, organ, mel_b, 12, 0.3, octave=0, unison=[(organ, -1, 0.5)])
    melody(tr, organ, mel_a, 20, 0.32, octave=1, unison=[(organ, 0, 0.6)])
    for bar in range(0, 28, 2):
        tr.note(bell, tr.bar_pos(bar), 1.0, "D3", 0.22)
    return master(tr, 0.4, tone=3600, drive=1.1)


@track("swamp", "swampy shuffle: clav bass syncopation, muted lead, bubbles, swung drums", "G minor", "4/4 92 shuffle")
def swamp():
    tr = Track("swamp", 92, 28, swing=0.5, seed=19)
    A = prog("Gm Gm Cm Gm Gm Eb D7 Gm")
    B = prog("Cm Cm Gm Gm Eb D7 Gm D7")
    mel_a = bars("G4:.5 Bb4:.5 D5:1 F5:1 D5:1 | C5:.5 Bb4:.5 G4:2 -:1 | C5:.5 Eb5:.5 G5:1 F5:1 Eb5:1 | D5:1 Bb4:.5 G4:1.5 -:1 | G4:.5 Bb4:.5 D5:.5 F5:.5 G5:1 F5:1 | Eb5:.5 D5:.5 Bb4:2 -:1 | A4:.5 C5:.5 F#5:1 A5:1 F#5:1 | G5:1 D5:1 Bb4:1 G4:1")
    mel_b = bars("G5:.5 Eb5:.5 C5:1 Eb5:1 G5:1 | Bb5:.5 G5:.5 Eb5:2 -:1 | D5:.5 F5:.5 G5:1 Bb5:1 G5:1 | F5:.5 D5:.5 G4:2 -:1 | Eb5:.5 G5:.5 Bb5:1 G5:1 Eb5:1 | D5:.5 F#5:.5 A5:1 C6:1 A5:1 | G5:.5 Bb5:.5 D6:1 Bb5:1 G5:1 | F#5:1 A5:1 D5:2")
    intro = prog("Gm Gm Gm Gm")
    bass(tr, clav, intro, 0, 0.5, "synco", octave=2)
    drums(tr, 0, 4, "swing", 0.8, crash_every=0)
    for s, names in enumerate([A, B, A]):
        sb = 4 + s * 8
        bass(tr, clav, names, sb, 0.5, "synco", octave=2)
        bass(tr, sub, names, sb, 0.3, "halftime", octave=1)
        chord_stabs(tr, clav, names, sb, 0.12, (1.5, 3.5), octave=3, dur=0.25)
        drums(tr, sb, 8, "swing", 0.85)
    melody(tr, dark_lead, mel_a, 4, 0.24)
    melody(tr, dark_lead, mel_b, 12, 0.24, unison=[(marimba, 0, 0.4)])
    melody(tr, dark_lead, mel_a, 20, 0.26, unison=[(marimba, 1, 0.35)])
    for bar in range(28):
        for k in range(3):
            p = tr.bar_pos(bar) + 0.5 + tr.rng.integers(0, 4)
            f0 = tr.rng.uniform(300, 900)
            tr.add(tr.sec(p), theremin(f0 * 2.2, 0.12, tr.rng, glide_from=f0), 0.07)
    return master(tr, 0.22, tone=3000)


@track("storm", "fast arpeggios: 16th pulse synth, string pad, driving drums, brass lead, wind", "B minor", "4/4 160")
def storm():
    tr = Track("storm", 160, 48, seed=20)
    A = prog("Bm G D A Bm G Em F#")
    B = prog("G D A Bm G D Em F#")
    mel_a = bars("F#5:2 B5:2 | D6:2 B5:1 A5:1 | F#5:2 A5:2 | E5:3 C#5:1 | D5:2 F#5:2 | B5:2 D6:1 E6:1 | G5:2 E5:2 | F#5:4")
    mel_b = bars("B5:1 D6:1 G6:2 | F#6:2 D6:2 | E6:1 C#6:1 A5:2 | B5:3 D6:1 | G6:1 F#6:1 D6:2 | A5:2 F#5:2 | G5:1 B5:1 E6:2 | A#5:2 F#6:2")
    for s, names in enumerate([A, A, B, A, B, A]):
        sb = s * 8
        arp(tr, pulse_synth, names, sb, 0.2, step=0.25, pattern="updown", octave=4, spread=2, length=0.8)
        bass(tr, synth_bass, names, sb, 0.5, "pump16", octave=2)
        chords(tr, strings, names, sb, 0.08, octave=3)
        drums(tr, sb, 8, "fast", 0.6 if s == 0 else 0.95)
    melody(tr, brass, mel_a, 8, 0.34)
    melody(tr, brass, mel_b, 16, 0.34)
    melody(tr, brass, mel_a, 24, 0.36, unison=[(strings, 0, 0.5)])
    melody(tr, brass, mel_b, 32, 0.36, unison=[(strings, 0, 0.5)])
    melody(tr, brass, mel_a, 40, 0.38, octave=1, unison=[(brass, -1, 0.6)])
    bed(tr, "wind", 0.1)
    return master(tr, 0.14, drive=1.35)


@track("sky", "airy: lydian choir and pads, glass triplet arps, flute, soft shaker, no kit", "E lydian", "4/4 84")
def sky():
    tr = Track("sky", 84, 28, seed=21)
    A = prog("E F# B E C#m G#m F# B")
    B = prog("C#m B E F# C#m G#m F# E")
    mel_a = bars("G#5:2 B5:1 C#6:1 | A#5:3 F#5:1 | D#6:2 B5:2 | E6:4 | G#5:1 B5:1 E6:2 | D#6:2 B5:2 | A#5:1 C#6:1 F#5:2 | B5:4")
    mel_b = bars("C#6:2 E6:1 G#6:1 | F#6:3 D#6:1 | E6:2 B5:2 | A#5:3 C#6:1 | G#6:2 E6:2 | D#6:2 B5:2 | A#5:1 C#6:1 F#6:2 | E6:4")
    intro = prog("E F# E B")
    chords(tr, pad, intro, 0, 0.12, octave=3, cutoff=1400)
    arp(tr, glass, intro, 0, 0.09, step=1.0 / 3.0, pattern="updown", octave=5, spread=2)
    for s, names in enumerate([A, B, A]):
        sb = 4 + s * 8
        chords(tr, pad, names, sb, 0.12, octave=3, cutoff=1400)
        chords(tr, choir, names, sb, 0.08, octave=4)
        arp(tr, glass, names, sb, 0.09, step=1.0 / 3.0, pattern="updown", octave=5, spread=2)
        bass(tr, sub, names, sb, 0.45, "whole", octave=2)
        for b in range(8):
            for e in range(8):
                tr.hit("shaker", tr.bar_pos(sb + b) + e * 0.5, 0.1 if e % 2 == 0 else 0.06)
    melody(tr, flute, mel_a, 4, 0.3, fx=(0.357, 0.35, 3))
    melody(tr, flute, mel_b, 12, 0.3, fx=(0.357, 0.35, 3), unison=[(glock, 0, 0.18)])
    melody(tr, flute, mel_a, 20, 0.32, fx=(0.357, 0.35, 3), unison=[(choir, 0, 0.35)])
    return master(tr, 0.32, tone=5000, drive=1.1)


@track("abyss", "dark half-time: huge kick, sub bass, low choir, distorted lead, bells", "C# phrygian", "4/4 70")
def abyss():
    tr = Track("abyss", 70, 24, seed=22)
    A = prog("C#m C#m D D C#m C#m A D")
    B = prog("Bm C#m D C#m Bm A D C#m")
    mel_a = bars("C#5:3 D5:1 | E5:2 C#5:2 | -:1 F#5:1 D5:2 | C#5:4 | G#5:2 F#5:1 E5:1 | D5:3 E5:1 | C#5:2 A4:2 | D5:2 C#5:2")
    mel_b = bars("B4:2 D5:2 | E5:2 G#5:2 | A5:3 F#5:1 | E5:2 C#5:2 | F#5:1 D5:1 B4:2 | A4:2 C#5:2 | D5:2 F#5:2 | C#5:4")
    for s, names in enumerate([A, B, A]):
        sb = s * 8
        bass(tr, sub, names, sb, 0.6, "halftime", octave=1)
        chords(tr, pad, names, sb, 0.1, octave=3, cutoff=600)
        chords(tr, choir, names, sb, 0.1, octave=2, dark=True)
        drums(tr, sb, 8, "halftime", 1.0)
        for b in range(0, 8, 2):
            tr.note(bell, tr.bar_pos(sb + b) + 3.5, 1.0, chord_notes(names[b], 4)[0], 0.12)
    melody(tr, dark_lead, mel_a, 0, 0.28, legato=0.96)
    melody(tr, dark_lead, mel_b, 8, 0.28, legato=0.96, unison=[(choir, 0, 0.35)])
    melody(tr, dark_lead, mel_a, 16, 0.3, legato=0.96, unison=[(dark_lead, -1, 0.5)])
    return master(tr, 0.28, tone=2800, drive=1.4)


@track("void", "alien: whole-tone clusters in 5/4, theremin glides, metallic hits, chromatic bass", "whole-tone / chromatic", "5/4 110")
def void():
    tr = Track("void", 110, 28, bpb=5, seed=23)
    clusters = ["Cwt", "Dwt", "Cwt", "Dwt", "Ewt", "F#wt", "Ewt", "D#wt2"]
    mel_a = bars("E5:2 F#5:1 G#5:2 | A#5:3 G#5:2 | C6:2 A#5:1 F#5:2 | E5:5 | D5:2 E5:1 F#5:2 | G#5:3 A#5:2 | C6:2 E6:1 D6:2 | A#5:5", 5)
    mel_b = bars("G#5:3 C6:2 | D6:2 A#5:1 F#5:2 | E6:3 D6:2 | C6:5 | F#5:2 G#5:1 A#5:2 | C6:2 D6:1 E6:2 | F#6:3 D6:2 | G#5:5", 5)
    chroma = ["C2", "B1", "A#1", "A1", "G#1", "G1", "F#1", "F1"]
    for s in range(3):
        sb = 4 + s * 8
        chords(tr, pad, clusters, sb, 0.11, octave=4, cutoff=1600)
        arp(tr, glass, clusters, sb, 0.11, step=0.5, pattern="random", octave=5, spread=2)
        for b in range(8):
            tr.note(sub, tr.bar_pos(sb + b), 5.0, chroma[b], 0.5)
            tr.note(synth_bass, tr.bar_pos(sb + b) + 2.5, 1.0, chroma[b], 0.3, cutoff=350)
        drums(tr, sb, 8, "void", 0.9, fills=False, crash_every=0)
    intro = ["Cwt", "Dwt", "Cwt", "D#wt2"]
    chords(tr, pad, intro, 0, 0.1, octave=4, cutoff=1600)
    arp(tr, glass, intro, 0, 0.1, step=0.5, pattern="random", octave=5, spread=2)
    for b in range(4):
        tr.note(sub, tr.bar_pos(b), 5.0, chroma[b], 0.45)
    melody(tr, theremin, mel_a, 4, 0.3, legato=1.0, gliss=True)
    melody(tr, theremin, mel_b, 12, 0.3, legato=1.0, gliss=True, unison=[(glass, 1, 0.25)])
    melody(tr, theremin, mel_a, 20, 0.3, legato=1.0, gliss=True, unison=[(dark_lead, -1, 0.3)])
    for bar in range(28):
        if bar % 3 == 0:
            f0 = 2400.0 if bar % 2 else 600.0
            tr.add(tr.sec(tr.bar_pos(bar) + 2), theremin(f0 / 3.0, 1.1, tr.rng, glide_from=f0), 0.1)
    return master(tr, 0.3, tone=5200, drive=1.2)


@track("tower", "rising tension: 16th bass, tremolo strings and brass stabs climbing a semitone every 8 bars", "A minor rising", "4/4 128")
def tower():
    tr = Track("tower", 128, 36, seed=24)
    motif = bars("A4:1 C5:1 E5:2 | D5:1 C5:1 B4:2 | F5:1 E5:1 D5:1 C5:1 | E5:4 | A4:1 E5:1 A5:2 | G#5:1 A5:1 B5:2 | C6:1 B5:1 A5:1 G#5:1 | E5:4")
    base = prog("Am Am F E Am Am F E")
    intro = prog("Am Am Am Am")
    bass(tr, synth_bass, intro, 0, 0.5, "pump16", octave=2)
    drums(tr, 0, 4, "tension", 0.6, fills=True, crash_every=4)
    for s in range(4):
        sb = 4 + s * 8
        names = [name_of(midi_of(chord_notes(c, 3)[0]) + s) [:-1] + ("m" if c.endswith("m") else "") + "/3" for c in base]
        bass(tr, synth_bass, names, sb, 0.5, "pump16", octave=2)
        chords(tr, strings, names, sb, 0.1, octave=3, bright=0.8)
        chord_stabs(tr, brass, names, sb, 0.14 + 0.03 * s, (0, 2.5), octave=3, dur=0.35)
        arp(tr, pulse_synth, names, sb, 0.08 + 0.03 * s, step=0.25, pattern="up", octave=5)
        drums(tr, sb, 8, "tension", 0.85 + 0.05 * s)
        melody(tr, strings, transpose(motif, s), sb, 0.3 + 0.02 * s, unison=[(brass, 0, 0.35 + 0.1 * s)])
        roll(tr, tr.bar_pos(sb + 7) + 2, 2.0, "snare", 0.1, 0.7)
        roll(tr, tr.bar_pos(sb + 7) + 2, 2.0, "timpani", 0.1, 0.6, spacing=0.25, pitch=55.0 * 2 ** (s / 12.0))
    return master(tr, 0.16, drive=1.35)


@track("dawn_forest", "hopeful: strings and flute theme answered by brass, harp arps, brushed drums", "F major", "4/4 108")
def dawn_forest():
    tr = Track("dawn_forest", 108, 32, seed=25)
    A = prog("F C Dm Bb F C Bb C")
    B = prog("Dm Bb F C Dm Bb Gm C")
    mel_a = bars("A5:1 C6:1 F6:2 | E6:1 C6:1 G5:2 | D6:1 F6:1 A6:1.5 G6:.5 | F6:4 | A5:1 C6:1 F6:1 A6:1 | G6:1 E6:1 C6:2 | D6:1 F6:1 Bb5:1 D6:1 | C6:3 -:1")
    mel_b = bars("D6:2 F6:1 A6:1 | Bb6:2 F6:2 | A6:1 F6:1 C6:2 | E6:2 G6:2 | F6:1 A6:1 D7:2 | Bb6:2 D6:2 | G6:1 Bb6:1 D7:1 Bb6:1 | C7:2 E6:2")
    for s, names in enumerate([A, A, B, A]):
        sb = s * 8
        chords(tr, strings, names, sb, 0.1 + 0.02 * s, octave=3)
        arp(tr, pluck, names, sb, 0.15, step=0.5, pattern="up", octave=4, spread=2)
        bass(tr, pizz, names, sb, 0.5, "roots", octave=2)
        drums(tr, sb, 8, "soft", 0.0 if s == 0 else 0.9, crash_every=0)
    melody(tr, flute, mel_a, 0, 0.3)
    melody(tr, flute, mel_a, 8, 0.3, unison=[(strings, 0, 0.4)])
    melody(tr, brass, mel_b, 16, 0.3, octave=-1, unison=[(strings, 0, 0.5)])
    melody(tr, flute, mel_a, 24, 0.32, unison=[(brass, -1, 0.35), (glock, 0, 0.15)])
    return master(tr, 0.22, tone=5000)


@track("crystal_valley", "glassy: 16th glass arps, bell melody, lydian pads, soft electronic drums", "Eb lydian", "4/4 120")
def crystal_valley():
    tr = Track("crystal_valley", 120, 36, seed=26)
    A = prog("Eb F Gm Bb Eb F Cm Bb")
    B = prog("Gm F Eb Bb Gm F Cm F")
    mel_a = bars("G5:1 Bb5:1 Eb6:2 | A5:1 C6:1 F6:2 | D6:1 Bb5:1 G5:2 | F5:1 D5:1 Bb5:2 | G5:1 Bb5:1 Eb6:1 G6:1 | F6:1 C6:1 A5:2 | Eb6:1 D6:1 C6:1 Bb5:1 | D6:4")
    mel_b = bars("Bb5:1 D6:1 G6:2 | A6:1 F6:1 C6:2 | G6:1 Eb6:1 Bb5:2 | D6:1 F6:1 Bb6:2 | G6:1 D6:1 Bb5:1 G5:1 | F5:1 A5:1 C6:2 | Eb6:1 G6:1 C7:1 Bb6:1 | A6:4")
    intro = prog("Eb F Eb F")
    arp(tr, glass, intro, 0, 0.16, step=0.25, pattern="updown", octave=5, spread=2, length=1.0)
    chords(tr, pad, intro, 0, 0.1, octave=3, cutoff=1500)
    for s, names in enumerate([A, B, A, B]):
        sb = 4 + s * 8
        arp(tr, glass, names, sb, 0.16, step=0.25, pattern="updown", octave=5, spread=2, length=1.0)
        chords(tr, pad, names, sb, 0.1, octave=3, cutoff=1500)
        bass(tr, synth_bass, names, sb, 0.4, "halftime", octave=2, cutoff=400)
        drums(tr, sb, 8, "electro", 0.0 if s == 0 else 0.8, crash_every=0)
    melody(tr, glock, mel_a, 4, 0.3)
    melody(tr, glock, mel_b, 12, 0.3, unison=[(flute, 0, 0.3)])
    melody(tr, glock, mel_a, 20, 0.32, unison=[(pad, 0, 0.3)])
    melody(tr, glock, mel_b, 28, 0.32, unison=[(flute, 0, 0.3), (glass, 1, 0.3)])
    return master(tr, 0.3, tone=6000, drive=1.1)


@track("sky_citadel", "regal march: brass fanfares, timpani, snare rolls, strings, cymbals", "Bb major", "4/4 96")
def sky_citadel():
    tr = Track("sky_citadel", 96, 32, seed=27)
    A = prog("Bb Eb F Bb Gm Eb F Bb")
    B = prog("Eb Bb F Gm Eb Bb Cm F")
    mel_a = bars("Bb4:.75 Bb4:.25 D5:1 F5:2 | Bb5:1.5 A5:.5 G5:1 F5:1 | Eb5:.75 Eb5:.25 G5:1 Bb5:2 | F5:4 | G5:1 Bb5:1 D6:1.5 C6:.5 | Bb5:1 G5:1 Eb5:2 | F5:.75 F5:.25 A5:1 C6:1 Eb6:1 | D6:3 -:1")
    mel_b = bars("Eb6:1 D6:1 Bb5:2 | D6:1 C6:1 A5:2 | F5:.75 F5:.25 A5:1 C6:2 | D6:2 Bb5:2 | Eb6:.75 Eb6:.25 G6:1 Bb6:2 | F6:1 D6:1 Bb5:2 | C6:1 Eb6:1 G6:1 Eb6:1 | F6:4")
    for s, names in enumerate([A, B, A, B]):
        sb = s * 8
        chords(tr, strings, names, sb, 0.1, octave=3)
        bass(tr, low_brass, names, sb, 0.4, "march", octave=2)
        chord_stabs(tr, brass, names, sb, 0.1, (1, 3), octave=4, dur=0.25)
        drums(tr, sb, 8, "march", 0.9)
    melody(tr, brass, mel_a, 0, 0.36, unison=[(brass, -1, 0.4)])
    melody(tr, brass, mel_b, 8, 0.36, unison=[(strings, 0, 0.45)])
    melody(tr, brass, mel_a, 16, 0.38, octave=1, unison=[(brass, 0, 0.6)])
    melody(tr, brass, mel_b, 24, 0.38, unison=[(brass, -1, 0.5), (glock, 1, 0.12)])
    return master(tr, 0.2, drive=1.3)


@track("eclipse_realm", "ominous: low choir chant, tolling bells, tritone brass, timpani, harmonic minor", "G harmonic minor", "4/4 76")
def eclipse_realm():
    tr = Track("eclipse_realm", 76, 28, seed=28)
    A = prog("Gm Gm Eb D Gm Cm D Gm")
    B = prog("Cm Gm Eb D Cm Gm Ab D")
    mel_a = bars("G4:2 Bb4:1 D5:1 | Eb5:3 D5:1 | C5:2 Bb4:1 A4:1 | F#4:4 | G4:1 D5:1 G5:2 | F#5:1 Eb5:1 D5:2 | C5:1 Bb4:1 A4:1 Bb4:1 | G4:4")
    mel_b = bars("C5:2 Eb5:1 G5:1 | Bb5:3 A5:1 | G5:2 Eb5:2 | F#5:3 A5:1 | G5:1 Eb5:1 C5:2 | D5:2 Bb4:2 | Ab4:2 C5:2 | F#4:2 D5:2")
    intro = prog("Gm Gm Gm Gm")
    chords(tr, choir, intro, 0, 0.12, octave=2, dark=True)
    bass(tr, sub, intro, 0, 0.4, "whole", octave=1)
    for s, names in enumerate([A, B, A]):
        sb = 4 + s * 8
        chords(tr, choir, names, sb, 0.12, octave=2, dark=True)
        chords(tr, pad, names, sb, 0.08, octave=3, cutoff=700)
        bass(tr, sub, names, sb, 0.45, "whole", octave=1)
        drums(tr, sb, 8, "ominous", 0.9)
        for b in range(8):
            root = chord_notes(names[b], 3)[0]
            if b % 2 == 1:
                tr.note(low_brass, tr.bar_pos(sb + b) + 2, 1.5, root, 0.16)
                tr.note(low_brass, tr.bar_pos(sb + b) + 2, 1.5, name_of(midi_of(root) + 6), 0.14)
    melody(tr, low_brass, mel_a, 4, 0.3, legato=0.97, unison=[(choir, 0, 0.35)])
    melody(tr, strings, mel_b, 12, 0.3, legato=0.97, unison=[(low_brass, -1, 0.4)])
    melody(tr, brass, mel_a, 20, 0.3, octave=1, legato=0.97, unison=[(low_brass, 0, 0.4), (choir, 0, 0.3)])
    for bar in range(0, 28, 2):
        tr.note(bell, tr.bar_pos(bar), 1.0, "G3" if bar % 4 == 0 else "D3", 0.2)
    return master(tr, 0.38, tone=3400, drive=1.15)


@track("lotus_sanctum", "serene then heroic: koto, bells and flute, then brass, strings and drums", "A major pentatonic", "4/4 88")
def lotus_sanctum():
    tr = Track("lotus_sanctum", 88, 32, seed=29)
    A = prog("A F#m D E A F#m D E")
    B = prog("A E F#m D A E D E")
    mel_a = bars("E5:1 F#5:1 A5:2 | B5:1 A5:1 F#5:2 | E5:1 C#5:1 E5:1 F#5:1 | A5:4 | C#6:1 B5:1 A5:1 F#5:1 | E5:2 F#5:2 | A5:1 B5:1 C#6:1 E6:1 | B5:4")
    mel_b = bars("A5:1 C#6:1 E6:2 | F#6:1 E6:1 C#6:2 | B5:1 C#6:1 E6:1 F#6:1 | E6:4 | A6:1 F#6:1 E6:1 C#6:1 | B5:2 C#6:2 | E6:1 F#6:1 A6:1 B6:1 | A6:4")
    for s in range(2):
        sb = s * 8
        arp(tr, koto, A, sb, 0.16, step=0.5, pattern="broken", octave=4, length=0.9)
        chords(tr, pad, A, sb, 0.1, octave=3, cutoff=1200)
        bass(tr, sub, A, sb, 0.4, "whole", octave=2)
        for b in range(8):
            tr.hit("woodblock", tr.bar_pos(sb + b) + 2, 0.12)
    melody(tr, koto, mel_a, 0, 0.32)
    melody(tr, flute, mel_a, 8, 0.3, unison=[(glock, 0, 0.18)])
    for s in range(2):
        sb = 16 + s * 8
        chords(tr, strings, B, sb, 0.12, octave=3)
        bass(tr, low_brass, B, sb, 0.4, "roots", octave=2)
        arp(tr, koto, B, sb, 0.12, step=0.5, pattern="broken", octave=4)
        drums(tr, sb, 8, "drive" if s else "rock", 0.85)
    melody(tr, brass, mel_b, 16, 0.36, unison=[(strings, 0, 0.45)])
    melody(tr, brass, mel_b, 24, 0.38, octave=0, unison=[(brass, -1, 0.45), (glock, 1, 0.15)])
    for bar in range(0, 16, 4):
        tr.note(bell, tr.bar_pos(bar), 1.0, "A4", 0.14)
    return master(tr, 0.26, tone=5000)


@track("drowned_abyss", "deep sea: sonar glass pings with echo, dark choir swells, sub drone, slow war drums, low brass leviathan theme", "F# dorian", "4/4 74")
def drowned_abyss():
    tr = Track("drowned_abyss", 74, 28, seed=33)
    A = prog("F#m F#m E B F#m D E C#m")
    B = prog("Bm F#m D E Bm A C# C#")
    mel_a = bars("F#4:2 A4:1 C#5:1 | B4:3 A4:1 | G#4:2 E4:2 | D#5:4 | F#5:1.5 E5:.5 C#5:2 | D5:2 B4:2 | E5:1 D#5:1 B4:1 G#4:1 | C#5:4")
    mel_b = bars("B4:2 D5:1 F#5:1 | A5:3 G#5:1 | F#5:2 D5:2 | E5:3 B4:1 | D5:1 F#5:1 B5:2 | A5:2 E5:2 | F5:2 G#5:2 | C#6:4")
    intro = prog("F#m F#m F#m F#m")
    chords(tr, choir, intro, 0, 0.11, octave=2, dark=True)
    bass(tr, sub, intro, 0, 0.42, "whole", octave=1)
    for s, names in enumerate([A, B, A]):
        sb = 4 + s * 8
        chords(tr, choir, names, sb, 0.11, octave=2, dark=True)
        chords(tr, pad, names, sb, 0.08, octave=3, cutoff=800)
        bass(tr, sub, names, sb, 0.45, "whole", octave=1)
        drums(tr, sb, 8, "ominous", 0.85 if s else 0.6)
        arp(tr, glass, names, sb, 0.07, step=1.0, pattern="up", octave=5, length=0.6)
    melody(tr, low_brass, mel_a, 4, 0.3, legato=0.97, unison=[(choir, 0, 0.3)])
    melody(tr, strings, mel_b, 12, 0.28, legato=0.97, unison=[(low_brass, -1, 0.4)])
    melody(tr, brass, mel_a, 20, 0.3, legato=0.97, unison=[(low_brass, -1, 0.45), (glass, 1, 0.12)])
    # Sonar pings: a glass note every two bars, echoing into the deep.
    for bar in range(0, 28, 2):
        p = tr.bar_pos(bar) + 0.5
        ping = echo(glass(note_freq("C#6" if bar % 4 == 0 else "F#5"), 1.2, tr.rng), 0.42, 0.45, repeats=4)
        tr.add(tr.sec(p), ping, 0.12)
    bed(tr, "rumble", 0.08)
    return master(tr, 0.4, tone=3000, drive=1.1)


@track("pvp", "coliseum: crowd bed, stomp-stomp-clap, taiko, staccato brass riff, chant hits", "E minor", "4/4 136")
def pvp():
    tr = Track("pvp", 136, 40, seed=30)
    A = prog("Em Em C D Em Em C B")
    B = prog("Am C Em D Am C B B")
    mel_a = bars("E5:.5 E5:.5 G5:1 B5:1 -:1 | E5:.5 E5:.5 G5:1 A5:1 -:1 | C6:1 B5:.5 G5:.5 E5:2 | D5:1 F#5:1 A5:2 | E5:.5 E5:.5 G5:1 B5:1 -:1 | E6:.5 E6:.5 D6:1 B5:1 -:1 | C6:1 E6:1 G6:1 E6:1 | D#6:2 B5:2")
    mel_b = bars("A5:1 C6:1 E6:2 | G6:1 E6:1 C6:2 | B5:1 G5:1 E5:2 | F#5:1 A5:1 D6:2 | A5:.5 A5:.5 C6:1 E6:1 -:1 | G6:.5 G6:.5 E6:1 C6:1 -:1 | B5:1 D#6:1 F#6:1 B6:1 | D#6:2 F#6:2")
    intro = prog("Em Em Em Em Em Em Em B")
    drums(tr, 0, 8, "coliseum", 0.9)
    bass(tr, synth_bass, intro, 0, 0.45, "halftime", octave=2)
    for s, names in enumerate([A, B, A, B]):
        sb = 8 + s * 8
        bass(tr, synth_bass, names, sb, 0.5, "synco", octave=2)
        chord_stabs(tr, brass, names, sb, 0.12, (2.0,), octave=3, dur=0.3)
        chords(tr, choir, [names[b] for b in range(8)], sb, 0.0, octave=3)
        for b in range(8):
            for n in chord_notes(names[b], 3):
                tr.note(choir, tr.bar_pos(sb + b), 0.9, n, 0.1)
        drums(tr, sb, 8, "coliseum", 1.0)
    melody(tr, brass, mel_a, 8, 0.36, legato=0.8)
    melody(tr, brass, mel_b, 16, 0.36, legato=0.85, unison=[(strings, 0, 0.4)])
    melody(tr, brass, mel_a, 24, 0.38, legato=0.8, unison=[(brass, -1, 0.5)])
    melody(tr, brass, mel_b, 32, 0.38, legato=0.85, unison=[(brass, 1, 0.3), (strings, 0, 0.4)])
    bed(tr, "crowd", 0.16)
    return master(tr, 0.18, drive=1.35)


@track("guildwar", "war drums and brass fanfares in fifths, snare rolls, low string ostinato", "D dorian", "4/4 120")
def guildwar():
    tr = Track("guildwar", 120, 36, seed=31)
    A = prog("Dm Dm Bb C Dm Dm Gm A")
    B = prog("Bb F Gm A Bb C Dm A")
    mel_a = bars("D5:1.5 D5:.5 F5:1 A5:1 | D6:2 C6:1 A5:1 | Bb5:1.5 Bb5:.5 D6:1 F6:1 | E6:2 C6:2 | D6:1.5 D6:.5 A5:1 F5:1 | D5:2 F5:1 A5:1 | G5:1 Bb5:1 D6:1 G6:1 | E6:2 C#6:2")
    mel_b = bars("F6:1 D6:1 Bb5:2 | A5:1 C6:1 F6:2 | G6:1 F6:1 D6:1 Bb5:1 | A5:2 C#6:2 | D6:1.5 D6:.5 F6:1 Bb6:1 | A6:1 G6:1 E6:2 | F6:1 D6:1 A5:1 D6:1 | C#6:2 E6:2")
    drums(tr, 0, 4, "war", 0.9, fills=True, crash_every=4)
    for s, names in enumerate([A, B, A, B]):
        sb = 4 + s * 8
        bass(tr, strings, names, sb, 0.3, "eighths", octave=2, bright=0.5)
        bass(tr, sub, names, sb, 0.4, "roots", octave=1)
        chords(tr, strings, names, sb, 0.08, octave=3)
        drums(tr, sb, 8, "war", 1.0)
        chord_stabs(tr, low_brass, names, sb, 0.14, (0, 1.5, 2), octave=2, dur=0.3)
    fifths = lambda b: transpose(b, -7)
    melody(tr, brass, mel_a, 4, 0.36)
    tr2 = fifths(mel_a)
    melody(tr, brass, tr2, 4, 0.22)
    melody(tr, brass, mel_b, 12, 0.36, unison=[(strings, 0, 0.4)])
    melody(tr, brass, fifths(mel_b), 12, 0.22)
    melody(tr, brass, mel_a, 20, 0.38, unison=[(low_brass, -1, 0.5)])
    melody(tr, brass, fifths(mel_a), 20, 0.24)
    melody(tr, brass, mel_b, 28, 0.38, octave=0, unison=[(brass, 1, 0.3), (low_brass, -1, 0.5)])
    melody(tr, brass, fifths(mel_b), 28, 0.24)
    return master(tr, 0.2, drive=1.4)


@track("arena", "light and playful: marimba staccato, bouncy bass, claps and woodblock, whistle", "C major", "4/4 124 swing")
def arena():
    tr = Track("arena", 124, 36, swing=0.4, seed=32)
    A = prog("C F G C Am F G C")
    B = prog("F G Em Am F G C G")
    mel_a = bars("C5:.5 E5:.5 G5:1 E5:.5 C5:.5 -:1 | F5:.5 A5:.5 C6:1 A5:1 -:1 | D5:.5 F5:.5 B5:1 G5:1 -:1 | C6:1 G5:.5 E5:.5 C5:2 | A4:.5 C5:.5 E5:1 C5:.5 A4:.5 -:1 | F5:.5 A5:.5 C6:1 F5:1 -:1 | G5:.5 B5:.5 D6:1 F6:1 D6:1 | E6:1 C6:1 -:2")
    mel_b = bars("A5:.5 C6:.5 F6:1 C6:1 -:1 | G5:.5 B5:.5 D6:1 B5:1 -:1 | E5:.5 G5:.5 B5:1 G5:1 -:1 | A5:.5 C6:.5 E6:1 C6:1 -:1 | F6:1 C6:.5 A5:.5 F5:1 -:1 | G6:1 D6:.5 B5:.5 G5:1 -:1 | E6:.5 G6:.5 C7:1 G6:1 E6:1 | D6:1 B5:1 G5:2")
    intro = prog("C C G C")
    bass(tr, pizz, intro, 0, 0.5, "bounce", octave=2)
    drums(tr, 0, 4, "playful", 0.8, crash_every=0)
    for s, names in enumerate([A, B, A, B]):
        sb = 4 + s * 8
        bass(tr, pizz, names, sb, 0.5, "bounce", octave=2)
        chord_stabs(tr, marimba, names, sb, 0.12, (0.5, 1.5, 2.5, 3.5), octave=4, dur=0.2)
        drums(tr, sb, 8, "playful", 0.85, crash_every=0)
    melody(tr, marimba, mel_a, 4, 0.34)
    melody(tr, marimba, mel_b, 12, 0.34, unison=[(whistle, 0, 0.3)])
    melody(tr, marimba, mel_a, 20, 0.34, unison=[(whistle, 1, 0.25)])
    melody(tr, whistle, mel_b, 28, 0.3, unison=[(marimba, 0, 0.45)])
    return master(tr, 0.2, tone=5000)


@track("victory", "fanfare jingle (not looped): brass, timpani, cymbal", "Bb major", "4/4 128")
def victory():
    tr = Track("victory", 128, 4, seed=33, loop=False)
    fan = bars("Bb4:.5 Bb4:.5 Bb4:.5 Bb4:1.5 Gb4:1 | Ab4:1 Bb4:.5 Ab4:.5 Bb4:2 | D5:.5 F5:.5 Bb5:1 D6:2 | F6:4")
    melody(tr, brass, fan, 0, 0.4, legato=0.9, unison=[(brass, -1, 0.5)])
    melody(tr, strings, bars("Bb3:4 | Gb3:1 Ab3:3 | Bb3:4 | Bb3:4"), 0, 0.2)
    melody(tr, low_brass, bars("Bb2:2 Bb2:2 | Gb2:1 Ab2:3 | Bb2:2 F2:2 | Bb2:4"), 0, 0.4)
    for p in (0, 1, 2, 3, 4, 6, 8, 12):
        tr.hit("timpani", p, 0.6, pitch=58.3)
    roll(tr, 10, 2.0, "snare", 0.1, 0.7)
    tr.hit("crash", 12, 0.6)
    tr.hit("crash", 8, 0.4)
    for n in chord_notes("Bb", 4):
        tr.note(glock, 12, 2.0, n, 0.15)
    return master(tr, 0.25, drive=1.3)


@track("defeat", "defeat jingle (not looped): descending organ and low strings, one bell toll", "D minor", "4/4 72")
def defeat():
    tr = Track("defeat", 72, 3, seed=34, loop=False)
    melody(tr, organ, bars("A4:1 G4:1 F4:1 E4:1 | D4:1 C#4:3 | D4:4"), 0, 0.3, legato=0.98)
    melody(tr, strings, bars("F3:4 | A3:1 A3:3 | D3:4"), 0, 0.22)
    melody(tr, sub, bars("D2:4 | A1:4 | D2:4"), 0, 0.5)
    tr.note(bell, 8, 2.0, "D3", 0.25)
    tr.hit("timpani", 8, 0.5, pitch=36.7)
    return master(tr, 0.35, tone=3000, drive=1.1)


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def write_wav(path, samples):
    data = (np.clip(samples, -1.0, 1.0) * 32767).astype("<i2")
    with wavefile.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


def encode_ogg(wav_path, ogg_path):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav_path, "-ac", "1", "-ar", str(RATE),
                    "-c:a", "libvorbis", "-q:a", OGG_QUALITY, ogg_path], check=True)


def spectrogram_png(samples, path):
    from PIL import Image
    f, t, S = signal.spectrogram(samples, RATE, nperseg=1024, noverlap=512)
    S = 10 * np.log10(S + 1e-12)
    S = np.clip((S - S.max() + 80) / 80, 0, 1)
    img = (S[::-1] * 255).astype(np.uint8)
    im = Image.fromarray(img, "L").resize((min(1600, S.shape[1]), 320))
    im.save(path)


def render(names, spectro_dir=None):
    rows = []
    with tempfile.TemporaryDirectory() as tmp:
        for name in names:
            info = INFO[name]
            samples = info["fn"]()
            wav_path = os.path.join(tmp, name + ".wav")
            write_wav(wav_path, samples)
            ogg_path = os.path.join(MUSIC_DIR, name + ".ogg")
            encode_ogg(wav_path, ogg_path)
            if spectro_dir:
                os.makedirs(spectro_dir, exist_ok=True)
                spectrogram_png(samples, os.path.join(spectro_dir, name + ".png"))
            size = os.path.getsize(ogg_path)
            secs = len(samples) / RATE
            rows.append((name, info["key"], info["meter"], secs, size, info["mood"]))
            print("%-15s %-22s %-14s %6.1fs %7.1f KB  %s" % (name, info["key"], info["meter"], secs, size / 1024.0, info["mood"]), flush=True)
    return rows


if __name__ == "__main__":
    args = sys.argv[1:]
    spectro = None
    if "--spectrograms" in args:
        i = args.index("--spectrograms")
        spectro = args[i + 1]
        del args[i: i + 2]
    names = args or list(INFO.keys())
    os.makedirs(MUSIC_DIR, exist_ok=True)
    rows = render(names, spectro)
    total = sum(r[4] for r in rows)
    print("%d tracks, %.2f MB total" % (len(rows), total / 1024.0 / 1024.0))
