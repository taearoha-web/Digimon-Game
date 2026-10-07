#!/usr/bin/env python3
"""Heroic, fight-ready music: brass-like leads, driving drums, power-chord
rhythm and string pads. Re-renders title / field / forest / battle (original,
synthesised from simple waveforms).  Usage: python3 tools/generate_heroic_music.py
"""
import importlib.util
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("gpa", os.path.join(HERE, "generate_placeholder_audio.py"))
gpa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gpa)
R = gpa.MUSIC_RATE
tone, noise_burst, note_freq = gpa.tone, gpa.noise_burst, gpa.note_freq
random.seed(777)


def seq(notes):
    out, pos = [], 0.0
    for dur, n in notes:
        out.append((pos, dur, n))
        pos += dur
    return out


def bar_sum(bars):
    for i, b in enumerate(bars):
        total = sum(d for d, _ in b)
        assert abs(total - 4.0) < 1e-6, "bar %d sums to %s: %s" % (i, total, b)


def brass(buf, start, dur, freq, vol):
    """Two slightly detuned saws with a swell: a bright brass lead."""
    tone(buf, R, start, dur, freq * 0.997, "saw", vol * 0.5, a=0.025, d=0.08, s=0.8, r=0.06, vibrato=0.004)
    tone(buf, R, start, dur, freq * 1.003, "saw", vol * 0.5, a=0.025, d=0.08, s=0.8, r=0.06, vibrato=0.004)
    tone(buf, R, start, dur, freq, "square", vol * 0.25, duty=0.35, a=0.02, d=0.08, s=0.7, r=0.06)


def render(bpm, chords, section_bars, melodies, gallop=False, sixteenth_hat=False, arp=False, lead_vol=0.2):
    """chords: per-bar triads (len 8, repeated). melodies: one list of bars per section."""
    beat = 60.0 / bpm
    total_bars = 8 * len(melodies)
    buf = [0.0] * int((total_bars * 4 * beat + 1.0) * R)
    for bar in range(total_bars):
        chord = chords[bar % 8]
        section = bar // 8
        t0 = bar * 4 * beat
        root = note_freq(chord[0])
        fifth = root * 1.5
        # --- bass: pumping eighths (galloping in the battle theme)
        for e in range(8):
            f = root / 2 if (e % 4 != 3) else fifth / 2
            if gallop and e % 2 == 1:
                f = root
            tone(buf, R, t0 + e * beat * 0.5, beat * 0.42, f, "saw", 0.16, a=0.003, d=0.06, s=0.5, r=0.03)
            tone(buf, R, t0 + e * beat * 0.5, beat * 0.42, f / 2, "sine", 0.22, a=0.003, d=0.05, s=0.7, r=0.03)
        # --- rhythm "guitar": palm-muted power chords
        for e in range(8):
            if e % 2 == 0 or section > 0:
                for f in (root, fifth, root * 2):
                    tone(buf, R, t0 + e * beat * 0.5, beat * 0.3, f, "square", 0.035, duty=0.3, a=0.002, d=0.04, s=0.4, r=0.03)
        # --- strings pad (builds in later sections)
        pad_vol = 0.03 + 0.012 * section
        for n in chord:
            tone(buf, R, t0, beat * 4.0, note_freq(n), "tri", pad_vol, a=0.25, d=0.2, s=0.8, r=0.3)
            tone(buf, R, t0, beat * 4.0, note_freq(n) * 2.003, "saw", pad_vol * 0.35, a=0.35, d=0.2, s=0.8, r=0.3)
        # --- sparkling arpeggio in the last section
        if arp and section >= 1:
            for s in range(8):
                n = chord[s % 3]
                tone(buf, R, t0 + s * beat * 0.5, beat * 0.3, note_freq(n) * 2, "tri", 0.045, a=0.003, d=0.05, s=0.4, r=0.05)
        # --- drums
        for b in range(4):
            bt = t0 + b * beat
            kick = (b in (0, 2)) or (gallop and b == 3)
            if kick:
                tone(buf, R, bt, 0.16, 160, "sine", 0.7, 42, a=0.001, d=0.06, s=0.3, r=0.06)
            if gallop and b in (1, 3):
                tone(buf, R, bt + beat * 0.75, 0.14, 160, "sine", 0.5, 42, a=0.001, d=0.06, s=0.3, r=0.06)
            if b in (1, 3):
                noise_burst(buf, R, bt, 0.16, 0.42, decay=20, lowpass=0.8)
                tone(buf, R, bt, 0.08, 200, "tri", 0.25, 120, a=0.001, d=0.04, s=0.2, r=0.03)
            steps = 4 if sixteenth_hat else 2
            for h in range(steps):
                noise_burst(buf, R, bt + h * beat / steps, 0.03, 0.09 if h else 0.13, decay=90, lowpass=0.97)
        # crash at the start of each section, tom/snare fill into the next
        if bar % 8 == 0:
            noise_burst(buf, R, t0, 1.3, 0.28, decay=3.0, lowpass=0.9)
        if bar % 8 == 7:
            for k in range(8):
                ft = t0 + 3 * beat + k * beat / 8
                noise_burst(buf, R, ft, 0.07, 0.30, decay=35, lowpass=0.8)
                tone(buf, R, ft, 0.08, 240 - k * 14, "sine", 0.3, 120, a=0.001, d=0.03, s=0.3, r=0.03)
    # --- melody
    for s, bars in enumerate(melodies):
        bar_sum(bars)
        pos = s * 8 * 4.0
        for bar in bars:
            for dur, n in bar:
                if n is not None:
                    brass(buf, pos * beat, dur * beat * 0.95, note_freq(n), lead_vol)
                    if s == len(melodies) - 1:
                        # final pass: add a low octave for a huge unison
                        tone(buf, R, pos * beat, dur * beat * 0.95, note_freq(n) / 2, "saw", lead_vol * 0.35, a=0.02, d=0.08, s=0.7, r=0.05)
                pos += dur
    return buf[: int(total_bars * 4 * beat * R)]


def title():
    chords = [["D4", "F#4", "A4"], ["A3", "C#4", "E4"], ["B3", "D4", "F#4"], ["G3", "B3", "D4"],
              ["D4", "F#4", "A4"], ["A3", "C#4", "E4"], ["G3", "B3", "D4"], ["A3", "C#4", "E4"]]
    a = [[(1, "F#5"), (1, "A5"), (2, "D6")], [(1, "C#6"), (1, "A5"), (2, "E5")], [(1, "B5"), (1, "A5"), (1, "F#5"), (1, "D5")],
         [(1.5, "G5"), (0.5, "A5"), (2, "B5")], [(1, "A5"), (1, "D6"), (1.5, "F#6"), (0.5, "E6")], [(1, "E6"), (1, "C#6"), (2, "A5")],
         [(1, "B5"), (1, "D6"), (1, "G6"), (1, "F#6")], [(3, "E6"), (1, "C#6")]]
    b = [[(0.5, "D6"), (0.5, "E6"), (1, "F#6"), (1, "A6"), (1, "F#6")], [(1, "E6"), (1, "C#6"), (2, "E6")], [(1, "D6"), (1, "F#6"), (1, "B6"), (1, "A6")],
         [(1, "G6"), (1, "F#6"), (1, "E6"), (1, "D6")], [(1, "F#6"), (1, "A6"), (2, "D7")], [(1, "A6"), (1, "E6"), (2, "A6")],
         [(1, "B6"), (1, "G6"), (1, "D6"), (1, "B5")], [(2, "E6"), (2, "E5")]]
    return render(116, chords, 8, [a, b, a], arp=True, lead_vol=0.19)


def field():
    chords = [["G3", "B3", "D4"], ["D4", "F#4", "A4"], ["E4", "G4", "B4"], ["C4", "E4", "G4"],
              ["G3", "B3", "D4"], ["D4", "F#4", "A4"], ["C4", "E4", "G4"], ["D4", "F#4", "A4"]]
    a = [[(1.5, "G5"), (0.5, "A5"), (1, "B5"), (1, "D6")], [(1.5, "C6"), (0.5, "B5"), (1, "A5"), (1, "F#5")],
         [(1.5, "G5"), (0.5, "B5"), (1, "E6"), (1, "D6")], [(1, "C6"), (1, "B5"), (1, "G5"), (1, "E5")],
         [(1.5, "G5"), (0.5, "A5"), (1, "B5"), (1, "D6")], [(1, "E6"), (1, "D6"), (1, "C6"), (1, "A5")],
         [(1, "G5"), (1, "C6"), (1, "E6"), (1, "G6")], [(2, "F#6"), (1, "E6"), (1, "D6")]]
    b = [[(1, "D6"), (1, "G6"), (1.5, "G6"), (0.5, "F#6")], [(1, "F#6"), (1, "A6"), (2, "F#6")],
         [(1, "E6"), (1, "G6"), (1, "B6"), (1, "G6")], [(1, "G6"), (1, "E6"), (2, "C6")],
         [(1, "B5"), (1, "D6"), (1, "G6"), (1, "B6")], [(1.5, "A6"), (0.5, "F#6"), (1, "D6"), (1, "A5")],
         [(1, "G6"), (1, "E6"), (1, "C6"), (1, "E6")], [(2, "F#6"), (1, "A5"), (1, "D6")]]
    return render(132, chords, 8, [a, b, a], arp=True, sixteenth_hat=False, lead_vol=0.2)


def forest():
    chords = [["E3", "G3", "B3"], ["C4", "E4", "G4"], ["D4", "F#4", "A4"], ["E3", "G3", "B3"],
              ["E3", "G3", "B3"], ["C4", "E4", "G4"], ["B3", "D#4", "F#4"], ["E3", "G3", "B3"]]
    a = [[(1, "E5"), (0.5, "G5"), (0.5, "B5"), (2, "E6")], [(1, "D6"), (1, "C6"), (1, "B5"), (1, "G5")],
         [(1, "A5"), (0.5, "B5"), (0.5, "A5"), (1, "F#5"), (1, "D5")], [(2, "B5"), (2, "G5")],
         [(1, "E5"), (0.5, "G5"), (0.5, "B5"), (2, "E6")], [(1, "G6"), (1, "E6"), (1, "C6"), (1, "E6")],
         [(1, "F#6"), (1, "D#6"), (1, "B5"), (1, "D#6")], [(3, "E6"), (1, "B5")]]
    b = [[(0.5, "B5"), (0.5, "E6"), (1, "G6"), (1, "B6"), (1, "G6")], [(1, "E6"), (1, "G6"), (2, "E6")],
         [(1, "F#6"), (1, "A6"), (1, "F#6"), (1, "D6")], [(1, "G6"), (1, "E6"), (2, "B5")],
         [(1, "E5"), (0.5, "G5"), (0.5, "B5"), (2, "E6")], [(1, "G6"), (1, "E6"), (1, "C6"), (1, "E6")],
         [(1, "F#6"), (1, "D#6"), (1, "B5"), (1, "D#6")], [(3, "E6"), (1, "B5")]]
    return render(124, chords, 8, [a, b, a], sixteenth_hat=True, lead_vol=0.2)


def battle():
    chords = [["A3", "C4", "E4"], ["F3", "A3", "C4"], ["C4", "E4", "G4"], ["G3", "B3", "D4"],
              ["A3", "C4", "E4"], ["F3", "A3", "C4"], ["G3", "B3", "D4"], ["E3", "G#3", "B3"]]
    a = [[(0.5, "A5"), (0.5, "A5"), (0.5, "C6"), (0.5, "E6"), (1, "A6"), (1, "E6")],
         [(0.5, "F6"), (0.5, "F6"), (0.5, "E6"), (0.5, "C6"), (1, "A5"), (1, "C6")],
         [(0.5, "E6"), (0.5, "G6"), (0.5, "E6"), (0.5, "C6"), (1, "G6"), (1, "E6")],
         [(0.5, "D6"), (0.5, "G5"), (0.5, "B5"), (0.5, "D6"), (2, "G6")],
         [(0.5, "A5"), (0.5, "A5"), (0.5, "C6"), (0.5, "E6"), (1, "A6"), (1, "E6")],
         [(0.5, "A6"), (0.5, "F6"), (0.5, "C6"), (0.5, "F6"), (1, "A6"), (1, "F6")],
         [(0.5, "G6"), (0.5, "D6"), (0.5, "B5"), (0.5, "D6"), (1, "G6"), (1, "B6")],
         [(0.5, "E6"), (0.5, "G#6"), (0.5, "B6"), (0.5, "G#6"), (2, "E6")]]
    b = [[(1, "E6"), (0.5, "E6"), (0.5, "A6"), (1, "C7"), (1, "A6")], [(1, "C7"), (0.5, "A6"), (0.5, "F6"), (2, "A6")],
         [(1, "G6"), (0.5, "G6"), (0.5, "E6"), (1, "C6"), (1, "E6")], [(1, "D6"), (1, "B5"), (1, "G5"), (1, "B5")],
         [(1, "A6"), (0.5, "C7"), (0.5, "A6"), (1, "E6"), (1, "A6")], [(1, "C7"), (1, "A6"), (1, "F6"), (1, "A6")],
         [(0.5, "B6"), (0.5, "G6"), (0.5, "D6"), (0.5, "G6"), (2, "B6")], [(1, "G#6"), (1, "E6"), (2, "B6")]]
    return render(168, chords, 8, [a, b, a], gallop=True, sixteenth_hat=True, arp=True, lead_vol=0.21)


if __name__ == "__main__":
    out = os.path.join(gpa.MUSIC_DIR)
    for name, fn in [("title", title), ("field", field), ("forest", forest), ("battle", battle)]:
        samples = fn()
        gpa.write_wav(os.path.join(out, name + ".wav"), samples, R, loop=True)
        print(name, "%.1fs" % (len(samples) / R))
