#!/usr/bin/env python3
"""Synthesised sound effects for the Defender's shield skills, the Fairy Spirit
and the star skills (original, simple waveforms; the helpers come from
generate_placeholder_audio.py). Each file is a short 22 kHz mono WAV under 40 KB.

  shield_bash   metal clang (shield edge hits)         shield_quake  ground thud + rumble
  shield_taunt  horn call + clang (provoke)            shield_throw  whoosh + ring (toss / rebound)
  shield_holy   bright choir chime (holy shield arts)  fairy_heal    sparkle chime
  fairy_twirl   soft bell flourish                     star_charge   rising shimmer (wind-up)
  star_release  big impact with a sub boom             star_beat     per-beat hit

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


SOUNDS = {
    "shield_bash": shield_bash, "shield_quake": shield_quake, "shield_taunt": shield_taunt,
    "shield_throw": shield_throw, "shield_holy": shield_holy, "fairy_heal": fairy_heal,
    "fairy_twirl": fairy_twirl, "star_charge": star_charge, "star_release": star_release, "star_beat": star_beat,
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
