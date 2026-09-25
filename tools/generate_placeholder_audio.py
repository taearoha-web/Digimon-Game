#!/usr/bin/env python3
"""Synthesises ORIGINAL placeholder audio for the prototype.

Everything here is generated from simple waveforms (no samples, no copyrighted
material). Output: audio/sfx/*.wav and audio/music/*.wav (mono, 16-bit).
Music files carry a WAV 'smpl' loop chunk so Godot imports them as loops.

Replace any file with final audio using the same name (see
docs/ASSET_REPLACEMENT.md). Usage:  python3 tools/generate_placeholder_audio.py
"""
import math
import os
import random
import struct
from array import array

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SFX_DIR = os.path.join(ROOT, "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "audio", "music")
RATE = 22050
MUSIC_RATE = 22050
TAU = math.tau
random.seed(1234)


# ---------------------------------------------------------------------------
# Synthesis helpers
# ---------------------------------------------------------------------------

def osc(kind, phase, duty=0.5):
    p = phase % 1.0
    if kind == "sine":
        return math.sin(TAU * p)
    if kind == "square":
        return 1.0 if p < duty else -1.0
    if kind == "tri":
        return 4.0 * abs(p - 0.5) - 1.0
    if kind == "saw":
        return 2.0 * p - 1.0
    if kind == "noise":
        return random.uniform(-1.0, 1.0)
    return 0.0


def env_adsr(t, dur, a=0.01, d=0.05, s=0.7, r=0.08):
    if t < a:
        return t / a if a > 0 else 1.0
    if t < a + d:
        return 1.0 - (1.0 - s) * ((t - a) / d)
    if t < dur - r:
        return s
    if t < dur:
        return s * max(0.0, (dur - t) / r) if r > 0 else 0.0
    return 0.0


def tone(buf, rate, start, dur, freq, kind="square", vol=0.3, freq_end=None, duty=0.5,
         a=0.005, d=0.05, s=0.7, r=0.06, vibrato=0.0):
    """Adds a note into buf (list of floats) starting at `start` seconds."""
    n0 = int(start * rate)
    n = int(dur * rate)
    if n0 + n > len(buf):
        buf.extend([0.0] * (n0 + n - len(buf)))
    phase = 0.0
    for i in range(n):
        t = i / rate
        f = freq if freq_end is None else freq + (freq_end - freq) * (t / dur)
        if vibrato:
            f *= 1.0 + vibrato * math.sin(TAU * 6.0 * t)
        phase += f / rate
        buf[n0 + i] += osc(kind, phase, duty) * env_adsr(t, dur, a, d, s, r) * vol


def noise_burst(buf, rate, start, dur, vol=0.3, decay=12.0, lowpass=0.5):
    n0 = int(start * rate)
    n = int(dur * rate)
    if n0 + n > len(buf):
        buf.extend([0.0] * (n0 + n - len(buf)))
    last = 0.0
    for i in range(n):
        t = i / rate
        x = random.uniform(-1.0, 1.0)
        last = last + lowpass * (x - last)
        buf[n0 + i] += last * math.exp(-decay * t) * vol


def note_freq(name):
    """'C4', 'F#3', 'Bb5' -> Hz."""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    semitone = names[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        semitone += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        semitone -= 1
        rest = rest[1:]
    octave = int(rest)
    midi = 12 * (octave + 1) + semitone
    return 440.0 * 2 ** ((midi - 69) / 12.0)


def write_wav(path, samples, rate, loop=False, gain=1.0):
    peak = max(1e-6, max(abs(x) for x in samples))
    scale = min(1.0, 0.92 / peak) * gain
    data = array("h", (int(max(-1.0, min(1.0, x * scale)) * 32767) for x in samples))
    raw = data.tobytes()
    chunks = b""
    fmt = struct.pack("<HHIIHH", 1, 1, rate, rate * 2, 2, 16)
    chunks += b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(raw)) + raw
    if loop:
        smpl = struct.pack("<9I", 0, 0, int(1e9 / rate), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(samples) - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


def sfx(name, builder, gain=1.0):
    buf = []
    builder(buf)
    fade = min(len(buf), int(0.01 * RATE))
    for i in range(fade):
        buf[-1 - i] *= i / fade
    write_wav(os.path.join(SFX_DIR, name + ".wav"), buf, RATE, gain=gain)


# ---------------------------------------------------------------------------
# Sound effects
# ---------------------------------------------------------------------------

def build_sfx():
    R = RATE
    sfx("ui_click", lambda b: tone(b, R, 0, 0.05, 1400, "square", 0.25, 1100, duty=0.25, r=0.03))
    sfx("ui_select", lambda b: tone(b, R, 0, 0.07, 900, "tri", 0.4, 1300, r=0.04))
    sfx("ui_confirm", lambda b: (tone(b, R, 0, 0.07, note_freq("E5"), "square", 0.22, duty=0.25),
                                 tone(b, R, 0.06, 0.12, note_freq("B5"), "square", 0.22, duty=0.25)))
    sfx("ui_cancel", lambda b: (tone(b, R, 0, 0.07, note_freq("G4"), "square", 0.2, duty=0.25),
                                tone(b, R, 0.06, 0.1, note_freq("D4"), "square", 0.2, duty=0.25)))
    sfx("ui_open", lambda b: tone(b, R, 0, 0.14, 500, "tri", 0.4, 1200, r=0.05))
    sfx("ui_error", lambda b: (tone(b, R, 0, 0.09, 220, "square", 0.25), tone(b, R, 0.1, 0.12, 180, "square", 0.25)))
    sfx("confirm_big", lambda b: [tone(b, R, i * 0.07, 0.2, note_freq(n), "square", 0.2, duty=0.3)
                                  for i, n in enumerate(["C5", "E5", "G5", "C6"])])
    sfx("dialogue_blip", lambda b: tone(b, R, 0, 0.035, 700, "square", 0.12, 760, duty=0.3, r=0.02))
    sfx("quest_start", lambda b: [tone(b, R, i * 0.09, 0.22, note_freq(n), "tri", 0.4)
                                  for i, n in enumerate(["G4", "C5", "E5"])])
    sfx("quest_update", lambda b: [tone(b, R, i * 0.08, 0.16, note_freq(n), "tri", 0.4)
                                   for i, n in enumerate(["E5", "G5"])])
    sfx("quest_complete", lambda b: [tone(b, R, i * 0.1, 0.35 if i == 4 else 0.14, note_freq(n), "square", 0.2, duty=0.3)
                                     for i, n in enumerate(["C5", "E5", "G5", "E5", "C6"])])
    sfx("save", lambda b: [tone(b, R, i * 0.06, 0.12, note_freq(n), "sine", 0.4) for i, n in enumerate(["A5", "D6", "F#6"])])
    sfx("pickup", lambda b: [tone(b, R, i * 0.05, 0.12, note_freq(n), "square", 0.2, duty=0.2)
                             for i, n in enumerate(["B5", "E6", "G#6"])])
    sfx("heal", lambda b: [tone(b, R, i * 0.07, 0.3, note_freq(n), "sine", 0.35, vibrato=0.01)
                           for i, n in enumerate(["C5", "E5", "G5", "C6", "E6"])])
    sfx("portal", lambda b: (tone(b, R, 0, 0.9, 180, "sine", 0.35, 900, vibrato=0.04, r=0.3),
                             tone(b, R, 0, 0.9, 270, "tri", 0.2, 1350, r=0.3)))
    sfx("encounter", lambda b: [tone(b, R, i * 0.07, 0.07, 440 + i * 180, "square", 0.25, duty=0.5) for i in range(6)])
    sfx("hit_physical", lambda b: (noise_burst(b, R, 0, 0.18, 0.7, decay=22, lowpass=0.35),
                                   tone(b, R, 0, 0.12, 160, "sine", 0.5, 60, r=0.05)))
    sfx("hit_special", lambda b: (noise_burst(b, R, 0, 0.25, 0.5, decay=14, lowpass=0.6),
                                  tone(b, R, 0, 0.2, 700, "saw", 0.2, 200, r=0.08)))
    sfx("crit", lambda b: (noise_burst(b, R, 0, 0.3, 0.8, decay=10, lowpass=0.4),
                           tone(b, R, 0, 0.25, 1200, "square", 0.2, 300, r=0.1), tone(b, R, 0.02, 0.2, 90, "sine", 0.5, 40)))
    sfx("miss", lambda b: noise_burst(b, R, 0, 0.3, 0.35, decay=6, lowpass=0.9))
    sfx("buff", lambda b: [tone(b, R, i * 0.06, 0.12, 400 + i * 150, "tri", 0.4) for i in range(5)])
    sfx("debuff", lambda b: [tone(b, R, i * 0.06, 0.12, 900 - i * 140, "tri", 0.4) for i in range(5)])
    sfx("defend", lambda b: (tone(b, R, 0, 0.3, 300, "tri", 0.4, 320, r=0.15), tone(b, R, 0, 0.3, 450, "sine", 0.25)))
    sfx("item_use", lambda b: [tone(b, R, i * 0.05, 0.1, note_freq(n), "sine", 0.4) for i, n in enumerate(["G5", "B5", "D6"])])
    sfx("switch", lambda b: tone(b, R, 0, 0.25, 300, "square", 0.2, 900, duty=0.3, r=0.1))
    sfx("faint", lambda b: tone(b, R, 0, 0.6, 500, "square", 0.22, 90, duty=0.4, r=0.2))
    sfx("escape", lambda b: [noise_burst(b, R, i * 0.08, 0.08, 0.25, decay=30, lowpass=0.8) for i in range(5)])
    sfx("recruit", lambda b: [tone(b, R, i * 0.09, 0.3, note_freq(n), "tri", 0.4, vibrato=0.01)
                              for i, n in enumerate(["E5", "G#5", "B5", "E6"])])
    sfx("heart", lambda b: tone(b, R, 0, 0.12, note_freq("A5"), "sine", 0.35, note_freq("E6")))
    sfx("skill_start", lambda b: tone(b, R, 0, 0.12, 600, "square", 0.15, 1200, duty=0.2))
    sfx("fire", lambda b: (noise_burst(b, R, 0, 0.45, 0.6, decay=5, lowpass=0.25), tone(b, R, 0, 0.3, 200, "saw", 0.15, 90)))
    sfx("ice", lambda b: [tone(b, R, i * 0.04, 0.2, 1800 + random.uniform(-300, 300), "sine", 0.18) for i in range(8)])
    sfx("wind", lambda b: noise_burst(b, R, 0, 0.5, 0.45, decay=4, lowpass=0.12))
    sfx("thunder", lambda b: (noise_burst(b, R, 0, 0.5, 0.8, decay=7, lowpass=0.7), tone(b, R, 0, 0.2, 120, "square", 0.25, 60)))
    sfx("level_up", lambda b: [tone(b, R, i * 0.08, 0.4 if i == 5 else 0.12, note_freq(n), "square", 0.2, duty=0.25)
                               for i, n in enumerate(["C5", "D5", "E5", "G5", "A5", "C6"])])
    sfx("level_up_blip", lambda b: tone(b, R, 0, 0.1, note_freq("C6"), "square", 0.18, duty=0.25))
    sfx("skill_learned", lambda b: [tone(b, R, i * 0.07, 0.18, note_freq(n), "tri", 0.4) for i, n in enumerate(["D5", "A5", "D6"])])
    sfx("evolve_ready", lambda b: [tone(b, R, i * 0.12, 0.25, note_freq(n), "tri", 0.4, vibrato=0.02) for i, n in enumerate(["C5", "G5", "C6"])])
    sfx("evolve", lambda b: (tone(b, R, 0, 3.2, 110, "saw", 0.12, 880, r=0.5), tone(b, R, 0, 3.2, 220, "sine", 0.25, 1760, vibrato=0.03, r=0.5),
                             [tone(b, R, 2.6 + i * 0.08, 0.5, note_freq(n), "square", 0.15, duty=0.3) for i, n in enumerate(["C5", "E5", "G5", "C6"])]))
    sfx("cry_enemy", lambda b: tone(b, R, 0, 0.35, 380, "saw", 0.3, 520, vibrato=0.05, r=0.12))
    for name, (f0, f1, kind) in {"roar": (220, 140, "saw"), "howl": (300, 520, "tri"), "chirp": (1200, 1800, "sine"),
                                  "chime": (880, 1320, "sine"), "buzz": (180, 200, "square"), "grunt": (140, 100, "saw"),
                                  "squeak": (900, 1400, "square"), "small": (600, 800, "tri")}.items():
        sfx("cry_" + name, lambda b, f0=f0, f1=f1, kind=kind: tone(b, R, 0, 0.4, f0, kind, 0.3, f1, vibrato=0.04, r=0.12))


# ---------------------------------------------------------------------------
# Music (simple original chiptune loops)
# ---------------------------------------------------------------------------

def render_song(bpm, bars, chords, melody, bass_kind="tri", lead_kind="square", drums=True, swing=0.0, lead_duty=0.25,
                pad=True, lead_vol=0.16):
    beat = 60.0 / bpm
    length = bars * 4 * beat
    buf = [0.0] * int(length * MUSIC_RATE + 1)
    R = MUSIC_RATE
    for bar in range(bars):
        chord = chords[bar % len(chords)]
        t0 = bar * 4 * beat
        # Bass: root on beats 1 and 3, fifth on 2 and 4.
        root = note_freq(chord[0])
        for b in range(4):
            f = root if b % 2 == 0 else root * 1.5
            tone(buf, R, t0 + b * beat, beat * 0.9, f / 2, bass_kind, 0.28, a=0.005, d=0.08, s=0.6, r=0.05)
        # Arpeggio pad.
        if pad:
            for s in range(8):
                n = chord[s % len(chord)]
                tone(buf, R, t0 + s * beat * 0.5, beat * 0.45, note_freq(n), "tri", 0.07, a=0.01, d=0.1, s=0.5, r=0.08)
        if drums:
            for b in range(4):
                bt = t0 + b * beat
                if b % 2 == 0:
                    tone(buf, R, bt, 0.12, 120, "sine", 0.45, 45, a=0.001, d=0.05, s=0.3, r=0.05)
                else:
                    noise_burst(buf, R, bt, 0.12, 0.22, decay=25, lowpass=0.7)
                noise_burst(buf, R, bt + beat * 0.5 + swing * beat, 0.04, 0.08, decay=60, lowpass=0.95)
    # Melody: list of (beat_position, length_in_beats, note)
    for pos, dur, n in melody:
        if n is None:
            continue
        tone(buf, R, pos * beat, dur * beat * 0.92, note_freq(n), lead_kind, lead_vol, duty=lead_duty, a=0.005, d=0.06, s=0.75,
             r=0.05, vibrato=0.006)
    return buf[: int(length * R)]


def seq(notes, start=0.0):
    """[(dur, note), ...] -> [(pos, dur, note)]"""
    out = []
    pos = start
    for dur, n in notes:
        out.append((pos, dur, n))
        pos += dur
    return out


def build_music():
    # Title: gentle, hopeful (C major), 96 BPM, 8 bars x2.
    title_chords = [["C4", "E4", "G4"], ["A3", "C4", "E4"], ["F3", "A3", "C4"], ["G3", "B3", "D4"]]
    title_mel = seq([(1, "E5"), (1, "G5"), (2, "C6"), (1, "B5"), (1, "A5"), (2, "E5"),
                     (1, "F5"), (1, "A5"), (1, "C6"), (1, "A5"), (2, "G5"), (2, None),
                     (1, "E5"), (1, "G5"), (2, "C6"), (1, "D6"), (1, "C6"), (2, "A5"),
                     (1, "F5"), (1, "E5"), (1, "D5"), (1, "B4"), (4, "C5")] * 2)
    write_wav(os.path.join(MUSIC_DIR, "title.wav"), render_song(96, 16, title_chords, title_mel, drums=False, lead_kind="tri", lead_vol=0.22), MUSIC_RATE, loop=True)

    # Field: bouncy adventure (G major), 112 BPM, 16 bars.
    field_chords = [["G3", "B3", "D4"], ["E3", "G3", "B3"], ["C4", "E4", "G4"], ["D4", "F#4", "A4"]]
    field_mel = seq([(0.5, "D5"), (0.5, "G5"), (1, "B5"), (0.5, "A5"), (0.5, "G5"), (1, "E5"),
                     (0.5, "E5"), (0.5, "G5"), (1, "B5"), (1, "A5"), (1, None),
                     (0.5, "C5"), (0.5, "E5"), (1, "G5"), (0.5, "A5"), (0.5, "G5"), (1, "E5"),
                     (0.5, "F#5"), (0.5, "A5"), (1, "D6"), (1, "C6"), (1, "A5")] * 4)
    write_wav(os.path.join(MUSIC_DIR, "field.wav"), render_song(112, 16, field_chords, field_mel, swing=0.08), MUSIC_RATE, loop=True)

    # Battle: driving (A minor), 150 BPM, 16 bars.
    battle_chords = [["A3", "C4", "E4"], ["F3", "A3", "C4"], ["G3", "B3", "D4"], ["E3", "G#3", "B3"]]
    battle_mel = seq([(0.5, "A5"), (0.5, "E5"), (0.5, "A5"), (0.5, "C6"), (1, "B5"), (1, "A5"),
                      (0.5, "F5"), (0.5, "A5"), (0.5, "C6"), (0.5, "F6"), (2, "E6"),
                      (0.5, "D6"), (0.5, "B5"), (0.5, "G5"), (0.5, "B5"), (1, "D6"), (1, "C6"),
                      (0.5, "B5"), (0.5, "G#5"), (0.5, "E5"), (0.5, "G#5"), (2, "B5")] * 4)
    write_wav(os.path.join(MUSIC_DIR, "battle.wav"), render_song(150, 16, battle_chords, battle_mel, bass_kind="square", lead_duty=0.3, lead_vol=0.14), MUSIC_RATE, loop=True)

    # Victory fanfare (not looped).
    R = MUSIC_RATE
    buf = []
    for i, (t, d, n) in enumerate([(0, 0.15, "C5"), (0.15, 0.15, "C5"), (0.3, 0.15, "C5"), (0.45, 0.45, "C5"), (0.9, 0.45, "Ab4"),
                                   (1.35, 0.45, "Bb4"), (1.8, 0.3, "C5"), (2.1, 0.15, "Bb4"), (2.25, 1.2, "C5")]):
        tone(buf, R, t, d, note_freq(n), "square", 0.2, duty=0.3)
        tone(buf, R, t, d, note_freq(n) / 2, "tri", 0.25)
    write_wav(os.path.join(MUSIC_DIR, "victory.wav"), buf, R)

    # Defeat jingle.
    buf = []
    for t, d, n in [(0, 0.4, "E5"), (0.4, 0.4, "D5"), (0.8, 0.4, "C5"), (1.2, 1.2, "B4")]:
        tone(buf, R, t, d, note_freq(n), "tri", 0.3, vibrato=0.01)
        tone(buf, R, t, d, note_freq(n) / 2, "sine", 0.2)
    write_wav(os.path.join(MUSIC_DIR, "defeat.wav"), buf, R)


if __name__ == "__main__":
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUSIC_DIR, exist_ok=True)
    build_sfx()
    build_music()
    total = 0
    for d in (SFX_DIR, MUSIC_DIR):
        for f in sorted(os.listdir(d)):
            if f.endswith(".wav"):
                total += os.path.getsize(os.path.join(d, f))
    print("audio generated, total %.1f KB" % (total / 1024))
