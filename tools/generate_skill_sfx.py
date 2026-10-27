#!/usr/bin/env python3
"""Synthesised sound effects for the Defender's shield skills, the Assassin's
twin daggers, the Bard's lute, songs and drums, the Fairy Spirit and the star skills (original, simple waveforms; the helpers come from
generate_placeholder_audio.py). Each file is a short 22 kHz mono WAV under 40 KB.

  shield_bash   metal clang (shield edge hits)         shield_quake  ground thud + rumble
  shield_taunt  horn call + clang (provoke)            shield_throw  whoosh + ring (toss / rebound)
  shield_holy   bright choir chime (holy shield arts)  fairy_heal    sparkle chime
  fairy_twirl   soft bell flourish                     star_charge   rising shimmer (wind-up)
  star_release  big impact with a sub boom             star_beat     per-beat hit
  blade_swish   twin dagger swish + ting (cuts)        blade_throw   whistling knives (throws)
  shadow_vanish smoke puff + dark whoosh (vanish)      venom_hiss    bubbling hiss (poison)
  shadow_dark   deep reversed swell + boom (night arts)
  lute_strum    bright A-major lute strum (notes)      song_rise     strum + rising sung pad (songs)
  song_discord  tritone pluck + beating saws (discord) drum_boom     war-drum flam + deep kick (drums)

Usage: python3 tools/generate_skill_sfx.py    (writes audio/sfx/<name>.wav)
"""
import importlib.util
import math
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("gpa", os.path.join(HERE, "generate_placeholder_audio.py"))
gpa = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gpa)
R = gpa.RATE
tone, noise_burst, note_freq, sfx = gpa.tone, gpa.noise_burst, gpa.note_freq, gpa.sfx
MAX_BYTES = 40 * 1024


def metal(b, start, base, vol, decay=0.35, partials=((1.0, 1.0), (1.47, 0.7), (2.09, 0.5), (2.56, 0.4), (3.3, 0.25))):
    """Inharmonic ringing partials: a struck metal plate."""
    for ratio, amp in partials:
        tone(b, R, start, decay, base * ratio, "sine", vol * amp, a=0.002, d=decay * 0.3, s=0.35, r=decay * 0.6)


def shield_bash(b):
    noise_burst(b, R, 0.0, 0.14, 0.7, decay=34, lowpass=0.9)
    tone(b, R, 0.0, 0.12, 180, "sine", 0.6, 55, a=0.001, d=0.05, s=0.3, r=0.06)
    metal(b, 0.005, 1850, 0.32, decay=0.42)


def shield_quake(b):
    noise_burst(b, R, 0.0, 0.08, 0.6, decay=40, lowpass=0.5)     # crack
    tone(b, R, 0.0, 0.32, 95, "sine", 0.9, 32, a=0.001, d=0.1, s=0.5, r=0.18)   # thud
    noise_burst(b, R, 0.04, 0.85, 0.8, decay=4.5, lowpass=0.06)  # rumble
    tone(b, R, 0.1, 0.6, 48, "sine", 0.4, 30, a=0.05, d=0.2, s=0.6, r=0.3)


def shield_taunt(b):
    for det in (0.994, 1.0, 1.006):                               # horn call
        tone(b, R, 0.0, 0.5, 233 * det, "saw", 0.16, 311 * det, a=0.04, d=0.1, s=0.85, r=0.1, vibrato=0.01)
    tone(b, R, 0.0, 0.5, 116, "square", 0.12, 155, duty=0.4, a=0.04, d=0.1, s=0.8, r=0.1)
    noise_burst(b, R, 0.5, 0.1, 0.5, decay=40, lowpass=0.9)      # clang on the shield
    metal(b, 0.5, 1500, 0.3, decay=0.35)


def shield_throw(b):
    noise_burst(b, R, 0.0, 0.42, 0.55, decay=5.5, lowpass=0.18)  # whoosh
    noise_burst(b, R, 0.08, 0.3, 0.3, decay=9, lowpass=0.35)
    tone(b, R, 0.15, 0.6, 2200, "sine", 0.26, 2150, a=0.004, d=0.15, s=0.4, r=0.4)   # ring
    tone(b, R, 0.15, 0.5, 3310, "sine", 0.14, 3250, a=0.004, d=0.12, s=0.35, r=0.35)
    tone(b, R, 0.15, 0.3, 1100, "tri", 0.12, a=0.004, d=0.1, s=0.3, r=0.15)


def shield_holy(b):
    for i, n in enumerate(["C5", "E5", "G5", "C6"]):
        f = note_freq(n)
        for det in (0.996, 1.004):
            tone(b, R, i * 0.03, 0.8 - i * 0.03, f * det, "tri", 0.1, a=0.06, d=0.2, s=0.7, r=0.3, vibrato=0.006)
        tone(b, R, i * 0.03, 0.8 - i * 0.03, f * 2, "sine", 0.05, a=0.08, d=0.2, s=0.6, r=0.3, vibrato=0.006)
    for i, n in enumerate(["E6", "G6", "C7", "E7"]):
        tone(b, R, 0.08 + i * 0.05, 0.5, note_freq(n), "sine", 0.1, a=0.003, d=0.1, s=0.3, r=0.35)


def fairy_heal(b):
    for i, n in enumerate(["E6", "G#6", "B6", "E7", "G#7"]):
        tone(b, R, i * 0.06, 0.4, note_freq(n), "sine", 0.22, a=0.003, d=0.08, s=0.45, r=0.3)
        tone(b, R, i * 0.06, 0.3, note_freq(n) * 2.76, "sine", 0.04, a=0.003, d=0.05, s=0.2, r=0.2)
    noise_burst(b, R, 0.0, 0.4, 0.05, decay=8, lowpass=0.98)


def fairy_twirl(b):
    for i, n in enumerate(["A5", "C#6", "E6", "A6", "E6", "C#6"]):
        f = note_freq(n)
        tone(b, R, i * 0.09, 0.35, f, "tri", 0.16, a=0.003, d=0.08, s=0.4, r=0.25)
        tone(b, R, i * 0.09, 0.25, f * 2.76, "sine", 0.03, a=0.003, d=0.05, s=0.2, r=0.15)
    tone(b, R, 0.5, 0.35, 880, "sine", 0.14, 1760, a=0.02, d=0.1, s=0.5, r=0.15, vibrato=0.02)


def star_charge(b):
    tone(b, R, 0.0, 0.88, 220, "saw", 0.08, 1760, a=0.1, d=0.2, s=0.9, r=0.1, vibrato=0.01)
    tone(b, R, 0.0, 0.88, 330, "sine", 0.18, 2640, a=0.1, d=0.2, s=0.9, r=0.1, vibrato=0.01)
    for i in range(16):
        f = 800 * 2 ** (i / 8.0)
        tone(b, R, 0.05 + i * 0.045, 0.12, f, "sine", 0.12 + 0.01 * i, a=0.002, d=0.04, s=0.4, r=0.06)
    noise_burst(b, R, 0.3, 0.55, 0.12, decay=2, lowpass=0.9)


def star_release(b):
    noise_burst(b, R, 0.0, 0.5, 0.85, decay=9, lowpass=0.55)
    tone(b, R, 0.0, 0.7, 75, "sine", 0.95, 28, a=0.001, d=0.15, s=0.6, r=0.3)        # sub boom
    tone(b, R, 0.0, 0.18, 420, "square", 0.25, 110, duty=0.4, a=0.001, d=0.08, s=0.3, r=0.08)
    for i, n in enumerate(["E6", "B6", "E7"]):
        tone(b, R, 0.03 + i * 0.04, 0.45, note_freq(n), "sine", 0.12, a=0.002, d=0.1, s=0.3, r=0.3)
    noise_burst(b, R, 0.1, 0.7, 0.3, decay=5, lowpass=0.08)


def star_beat(b):
    noise_burst(b, R, 0.0, 0.16, 0.6, decay=28, lowpass=0.6)
    tone(b, R, 0.0, 0.12, 900, "square", 0.18, 300, duty=0.35, a=0.001, d=0.05, s=0.3, r=0.05)
    tone(b, R, 0.0, 0.18, 130, "sine", 0.6, 48, a=0.001, d=0.06, s=0.4, r=0.08)
    tone(b, R, 0.02, 0.2, note_freq("B6"), "sine", 0.08, a=0.002, d=0.05, s=0.3, r=0.12)


def blade_swish(b):
    for k, start in enumerate((0.0, 0.09)):                      # two daggers, one after the other
        noise_burst(b, R, start, 0.16, 0.55, decay=16, lowpass=0.3 + 0.1 * k)
        tone(b, R, start + 0.05, 0.22, 3900 - 500 * k, "sine", 0.12, 3700 - 500 * k, a=0.002, d=0.06, s=0.3, r=0.12)
        tone(b, R, start + 0.05, 0.18, 5300 - 600 * k, "sine", 0.05, a=0.002, d=0.05, s=0.2, r=0.1)
    tone(b, R, 0.0, 0.1, 260, "sine", 0.25, 120, a=0.001, d=0.04, s=0.3, r=0.04)


def blade_throw(b):
    for k in range(3):                                            # knives whistle past
        start = k * 0.07
        tone(b, R, start, 0.26, 2600 + 300 * k, "sine", 0.11, 1500 + 200 * k, a=0.01, d=0.06, s=0.6, r=0.12)
        noise_burst(b, R, start, 0.22, 0.3, decay=11, lowpass=0.22)
    noise_burst(b, R, 0.26, 0.06, 0.4, decay=50, lowpass=0.8)      # thunk
    metal(b, 0.26, 2400, 0.12, decay=0.25)


def shadow_vanish(b):
    noise_burst(b, R, 0.0, 0.5, 0.7, decay=6, lowpass=0.08)       # smoke puff
    noise_burst(b, R, 0.0, 0.1, 0.35, decay=30, lowpass=0.6)
    tone(b, R, 0.02, 0.45, 520, "sine", 0.16, 90, a=0.01, d=0.1, s=0.6, r=0.2, vibrato=0.01)
    tone(b, R, 0.1, 0.4, 1240, "tri", 0.05, 620, a=0.04, d=0.1, s=0.4, r=0.2)


def venom_hiss(b):
    noise_burst(b, R, 0.0, 0.7, 0.45, decay=3.5, lowpass=0.85)    # hiss
    for i in range(6):                                            # bubbles
        f = 300 + random.random() * 500
        tone(b, R, 0.05 + i * 0.09, 0.08, f, "sine", 0.12, f * 1.8, a=0.002, d=0.03, s=0.3, r=0.03)


def shadow_dark(b):
    tone(b, R, 0.0, 0.42, 70, "saw", 0.14, 140, a=0.35, d=0.02, s=0.9, r=0.03)   # reversed swell
    noise_burst(b, R, 0.0, 0.42, 0.12, decay=0.6, lowpass=0.12)
    noise_burst(b, R, 0.42, 0.34, 0.7, decay=10, lowpass=0.35)   # release
    tone(b, R, 0.42, 0.42, 82, "sine", 0.8, 30, a=0.001, d=0.15, s=0.5, r=0.2)
    for i, n in enumerate(["D5", "F5", "A#5"]):
        tone(b, R, 0.44 + i * 0.03, 0.3, note_freq(n), "tri", 0.07, a=0.005, d=0.1, s=0.3, r=0.18)


def pluck(b, start, dur, freq, vol, bright=0.8, damp=1.6, k=10):
    """A plucked string: additive partials 1/k^(1/bright), each fading faster than the last
    (the zone-music lute timbre, stdlib only, no random)."""
    n0, n = int(start * R), int(dur * R)
    if n0 + n > len(b):
        b.extend([0.0] * (n0 + n - len(b)))
    parts = [(i, (1.0 / i ** (1.0 / bright)), (2.2 + 1.6 * i) * damp) for i in range(1, k + 1) if freq * i < R * 0.45]
    norm = sum(a for _, a, _ in parts)
    tail = int(0.04 * R)
    for s in range(n):
        t = s / R
        v = sum(a * math.exp(-d * t) * math.sin(2 * math.pi * freq * i * t) for i, a, d in parts)
        att = min(1.0, t / 0.0015)
        rel = min(1.0, (n - s) / tail)
        b[n0 + s] += v / norm * vol * att * rel


def lute_strum(b):
    """A bright three-string strum (A major, low to high), pick ticks and the body knock."""
    for i, nm in enumerate(["E4", "A4", "C#5", "E5"]):
        noise_burst(b, R, i * 0.018, 0.012, 0.18, decay=220, lowpass=0.9)
        pluck(b, i * 0.018, 0.46 - i * 0.018, note_freq(nm), 0.52, bright=0.85, damp=1.4)
    tone(b, R, 0.0, 0.07, 190, "sine", 0.32, 120, a=0.001, d=0.03, s=0.3, r=0.03)
    pluck(b, 0.09, 0.36, note_freq("A5"), 0.24, bright=1.1, damp=1.8)


def song_rise(b):
    """A song begins: a soft strum, a rising sung pad (D5 -> G5) over a G major chord, then
    a music-box sparkle climbing to the top."""
    for i, nm in enumerate(["G3", "D4", "G4", "B4"]):
        pluck(b, i * 0.03, 0.8 - i * 0.03, note_freq(nm), 0.3, bright=0.8, damp=1.0)
    for det in (0.995, 1.005):
        tone(b, R, 0.05, 0.75, note_freq("D5") * det, "tri", 0.14, note_freq("G5") * det, a=0.28, d=0.1, s=0.85, r=0.25, vibrato=0.012)
        tone(b, R, 0.05, 0.75, note_freq("B4") * det, "sine", 0.11, note_freq("D5") * det, a=0.3, d=0.1, s=0.8, r=0.25, vibrato=0.01)
    for i, nm in enumerate(["G5", "B5", "D6", "G6", "B6"]):
        pluck(b, 0.32 + i * 0.07, 0.42 - i * 0.04, note_freq(nm), 0.18, bright=1.3, damp=2.2)
    noise_burst(b, R, 0.0, 0.82, 0.035, decay=1.5, lowpass=0.97)


def song_discord(b):
    """An out-of-tune clash: a tritone pluck, beating detuned saws, a bent-down whine and grit."""
    pluck(b, 0.0, 0.55, note_freq("C5"), 0.42, bright=0.9, damp=1.2)
    pluck(b, 0.012, 0.55, note_freq("F#5"), 0.4, bright=0.9, damp=1.2)
    for f in (311.0, 329.0, 349.0):
        tone(b, R, 0.02, 0.5, f, "saw", 0.07, f * 0.94, a=0.02, d=0.1, s=0.7, r=0.2, vibrato=0.03)
    tone(b, R, 0.05, 0.42, 880, "sine", 0.14, 600, a=0.01, d=0.1, s=0.6, r=0.18, vibrato=0.025)
    noise_burst(b, R, 0.0, 0.3, 0.3, decay=9, lowpass=0.35)


def drum_boom(b):
    """A war drum: a flam (grace hit then the main hit), a deep pitch-dropping kick, the skin
    slap and a short room rumble."""
    tone(b, R, 0.0, 0.14, 150, "sine", 0.26, 70, a=0.001, d=0.05, s=0.3, r=0.06)
    noise_burst(b, R, 0.0, 0.05, 0.16, decay=60, lowpass=0.4)
    tone(b, R, 0.06, 0.42, 118, "sine", 0.48, 42, a=0.001, d=0.12, s=0.55, r=0.22)
    tone(b, R, 0.06, 0.18, 230, "tri", 0.15, 110, a=0.001, d=0.06, s=0.3, r=0.08)
    noise_burst(b, R, 0.06, 0.12, 0.32, decay=30, lowpass=0.3)
    noise_burst(b, R, 0.1, 0.48, 0.16, decay=5.5, lowpass=0.05)


SOUNDS = {
    "shield_bash": shield_bash, "shield_quake": shield_quake, "shield_taunt": shield_taunt,
    "shield_throw": shield_throw, "shield_holy": shield_holy, "fairy_heal": fairy_heal,
    "fairy_twirl": fairy_twirl, "star_charge": star_charge, "star_release": star_release, "star_beat": star_beat,
    "blade_swish": blade_swish, "blade_throw": blade_throw, "shadow_vanish": shadow_vanish, "venom_hiss": venom_hiss,
    "shadow_dark": shadow_dark,
    "lute_strum": lute_strum, "song_rise": song_rise, "song_discord": song_discord, "drum_boom": drum_boom,
}


if __name__ == "__main__":
    random.seed(4242)
    os.makedirs(gpa.SFX_DIR, exist_ok=True)
    for name, builder in SOUNDS.items():
        sfx(name, builder)
        path = os.path.join(gpa.SFX_DIR, name + ".wav")
        size = os.path.getsize(path)
        assert size <= MAX_BYTES, "%s is %d bytes" % (name, size)
        print("%-14s %5.1f KB" % (name, size / 1024.0))
