#!/usr/bin/env python3
"""Author the Toon Tale skill medallions. Standard-library only; no remote art.

Each entry is an intentional illustration, not a color/hash variation of a
generic skill type. Coordinates use a 256-unit canvas, rasterized by Godot at
192px once on import. The game loads only the cached textures it needs.
"""
from pathlib import Path
from math import sin, cos, pi
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/icons/skills"
PALETTES = {
    "steel": ("142a49", "41778e", "9bd8e5", "fff1c0"),
    "ember": ("351429", "bc3e48", "ff8b48", "fff1a6"),
    "gold": ("282042", "a16b38", "ffd16f", "fff8d7"),
    "wind": ("0e343e", "227c78", "81efcc", "edffda"),
    "forest": ("143734", "38875c", "9ae77a", "fff5b3"),
    "frost": ("162948", "367ab1", "89e8ff", "f4ffff"),
    "arcane": ("271c4b", "7146a3", "c8a3ff", "fff0d5"),
    "rose": ("331e45", "ac508d", "ffa9d8", "fff5df"),
    "storm": ("23244e", "6754b7", "bbbdff", "fff7b0"),
    "earth": ("302b34", "997149", "e7b76c", "fff2c4"),
    "night": ("120c26", "4a2d82", "9a6bff", "f1e6ff"),
    "blood": ("2a0a1c", "8a1f45", "ff4f7b", "ffe3ec"),
    "venom": ("102a26", "3a6b3a", "8be260", "f4ffd9"),
    "royal": ("2a1418", "8a1a2a", "e8b64a", "fff4d0"),
    "darkforce": ("140a28", "4a1f8a", "8a4dff", "f0e2ff"),
    "melody": ("2a0f22", "8a2a5e", "ff8fcf", "ffe6f4"),
    "dissonance": ("1a0b2e", "5a2a9a", "b07aff", "f4e8ff"),
    "lament": ("141a3a", "3d5aa8", "8fb8ff", "eef3ff"),
    # God-tier (300-star) skills: each wears its skill's signature hue (StarSkillArt.COLORS).
    "god_ember": ("3a0f12", "b0381a", "ff7a1f", "fff2b0"),
    "god_lime": ("12301a", "4a9a2a", "b6ff3a", "fbffe0"),
    "god_cyan": ("0a1f4a", "1f78b8", "2ae8ff", "f0ffff"),
    "god_cosmos": ("120a3a", "4a36b0", "8a6cff", "f4f0ff"),
    "god_holy": ("3a1f3a", "b0784a", "ffe04a", "ffffff"),
    "god_jade": ("0a2e2e", "1f9a78", "2fffb0", "f0fff8"),
    "god_azure": ("0e1a48", "2a5ab8", "4a8cff", "fff4c8"),
    "god_blood": ("1a0420", "8a1235", "ff2a5a", "ffe0ea"),
    "god_abyss": ("1a0630", "5a1fa0", "a03cff", "ffd88a"),
    "god_rose": ("2a0a3a", "a02a8a", "ff5ad8", "fff0fb"),
}


def path(d, fill="url(#main)", stroke="#151c35", width=3.5, extra=""):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round" {extra}/>'


def ellipse(x, y, rx, ry=None, fill="url(#main)", stroke="#151c35", width=3):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{rx if ry is None else ry}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'


def line(d, color="url(#light)", width=5):
    # Object-bounding-box gradients have zero area on a perfectly vertical
    # arrow shaft. User-space stroke gradients keep those details visible.
    if color.startswith("url(#"):
        color = color.replace(")", "_stroke)")
    return path(d, "none", color, width)


def group(body, x=0, y=0, scale=1, rotate=0, opacity=1):
    return f'<g transform="translate({x} {y}) rotate({rotate}) scale({scale})" opacity="{opacity}">{body}</g>'


def star(x=0, y=0, size=18):
    return group(path("M0 -22 L6 -6 L22 0 L6 6 L0 22 L-6 6 L-22 0 L-6 -6Z", "url(#light)", "none"), x, y, size / 22)


def blade(kind="sword"):
    if kind == "spear":
        return (path("M-4 -22 L4 -22 L4 79 L-4 79Z", "url(#gold)")
                + path("M0 -91 L22 -40 L9 -17 L-9 -17 L-22 -40Z", "url(#metal)")
                + path("M0 -80 L0 -20 L15 -42Z", "url(#main)", "none")
                + ellipse(0, -18, 8, 5, "url(#gold)"))
    if kind == "arrow":
        return (line("M0 -54 L0 65", "url(#gold)", 7)
                + path("M0 -87 L21 -40 L0 -49 L-21 -40Z", "url(#metal)")
                + path("M-3 39 L-23 58 L-23 82 L-3 67Z M3 39 L23 58 L23 82 L3 67Z", "url(#main)")
                + line("M0 -74 L0 -54", "#ffffff", 3))
    if kind == "axe":
        return (path("M-5 -59 L5 -59 L6 79 L-6 79Z", "url(#gold)")
                + path("M-4 -55 Q-29 -29 -57 -61 Q-70 -21 -49 4 Q-29 -13 -4 -9Z M4 -55 Q29 -29 57 -61 Q70 -21 49 4 Q29 -13 4 -9Z", "url(#metal)")
                + line("M-52 -48 Q-59 -22 -47 -7 M52 -48 Q59 -22 47 -7", "#ffffff", 4))
    if kind == "hammer":
        return (path("M-7 -21 L7 -21 L9 78 L-9 78Z", "url(#gold)")
                + path("M-53 -62 L-35 -74 L43 -74 L59 -56 L59 -12 L43 2 L-43 2 L-57 -15Z", "url(#metal)")
                + path("M-42 -60 L38 -60 L48 -48 L-42 -48Z", "#f4ffff", "none")
                + path("M-15 -55 L14 -55 L14 -13 L-15 -13Z", "url(#gold)"))
    body = path("M0 -88 L18 -60 L12 30 L-12 30 L-18 -60Z", "url(#metal)")
    body += path("M0 -81 L0 28 L12 28 L15 -58Z", "url(#main)", "none")
    body += path("M-35 23 Q0 34 35 23 L30 39 L7 38 L7 69 L-7 69 L-7 38 L-30 39Z", "url(#gold)")
    body += ellipse(0, 72, 10, 8, "url(#gold)") + ellipse(0, 31, 7, fill="url(#main)")
    return body


def shield(round_shield=False):
    if round_shield:
        return ellipse(0, 0, 66, fill="url(#gold)") + ellipse(0, 0, 55, fill="url(#main)") + ellipse(0, 0, 22, fill="url(#metal)") + star(0, 0, 16)
    return (path("M0 -75 Q30 -52 59 -56 L57 8 Q44 53 0 79 Q-44 53 -57 8 L-59 -56 Q-30 -52 0 -75Z", "url(#gold)")
            + path("M0 -58 Q24 -42 44 -44 L41 5 Q30 37 0 60 Q-30 37 -41 5 L-44 -44 Q-24 -42 0 -58Z")
            + path("M0 -50 L0 50 Q-29 25 -33 0 L-36 -35Z", "#ffffff", "none", extra='opacity=".19"')
            + star(0, -4, 27))


def flame():
    return (path("M-11 -81 C20 -43 39 -42 28 -10 Q56 -37 58 4 C76 50 40 76 0 74 C-53 77 -72 32 -53 3 Q-44 -20 -45 -41 Q-15 -33 -21 -3 C-1 -18 9 -44 -11 -81Z")
            + path("M0 -29 Q29 0 18 20 Q38 9 31 43 Q19 68 -1 62 Q-39 59 -29 29 Q-8 44 0 -29Z", "url(#light)", "none")
            + path("M-32 -5 Q-58 25 -40 45", "none", "#fff2cd", 4))


def meteor(fractured=False):
    result = path("M-62 -90 Q12 -63 56 -10 Q85 33 43 65 Q-9 91 -40 45 Q-59 10 -62 -90Z", "url(#main)")
    result += path("M-44 -66 L20 -9 L-6 4Z M-20 -78 L43 -18 L24 -8Z", "url(#light)", "none")
    result += path("M-21 -5 L5 -26 L42 -12 L62 14 L48 51 L12 68 L-21 52 L-37 25Z", "url(#rock)")
    result += path("M-21 -5 L5 -26 L21 2 L-5 18 L-37 25Z", "#956984", "none")
    result += line("M5 -22 L19 4 L-5 21 L7 49 L37 55 M19 4 L48 11 M-5 21 L-29 24", "url(#light)", 5 if fractured else 3)
    result += star(-31, -45, 9)
    return result


def crystal():
    return path("M0 -75 L32 -20 L22 52 L0 77 L-26 51 L-33 -18Z", "url(#main)") + path("M0 -75 L0 77 L-26 51 L-33 -18Z", "url(#metal)", "none") + line("M0 -59 L0 55", "#ffffff", 4)


def wings():
    half = path("M-6 20 Q-39 -8 -83 -60 Q-89 -16 -51 2 L-80 -6 Q-76 24 -38 32 L-62 31 Q-47 56 -16 43Z", "url(#metal)")
    half += line("M-73 -38 Q-53 -7 -18 19 M-61 8 L-27 30", "url(#main)", 5)
    return half + group(half, scale=1, rotate=0).replace('scale(1)', 'scale(-1 1)')


def crown():
    return (path("M-61 -43 L-34 -19 L0 -65 L32 -19 L62 -43 L50 43 Q0 59 -50 43Z", "url(#gold)")
            + path("M-45 23 Q0 35 45 23 L43 39 Q0 48 -43 39Z", "url(#light)", "none")
            + group(crystal(), 0, 0, .27) + ellipse(-36, -9, 6, fill="url(#main)") + ellipse(36, -9, 6, fill="url(#main)"))


def face(kind):
    if kind == "frog":
        return (ellipse(-31, -33, 28) + ellipse(31, -33, 28) + ellipse(0, 12, 65, 49)
                + ellipse(0, 31, 43, 24, "url(#light)", "none")
                + ellipse(-29, -28, 14, 19, "#fcffec") + ellipse(29, -28, 14, 19, "#fcffec")
                + ellipse(-27, -27, 6, 10, "#142b36", "none") + ellipse(27, -27, 6, 10, "#142b36", "none")
                + line("M-22 21 Q0 37 22 21", "#2d5860", 4))
    if kind == "dragon":
        return (path("M-38 -28 L-53 -71 L-18 -48 L9 -73 L27 -46 L58 -66 L48 -20 Q75 -10 62 33 L21 70 L-35 47 L-62 8Z")
                + path("M-36 -24 L-52 -59 L-22 -43 M23 -45 L49 -56 L40 -25", "url(#gold)")
                + path("M-13 7 Q10 -5 43 13 L42 37 L10 50 L-26 31Z", "url(#light)")
                + path("M-41 -5 L-17 0 L-24 13 L-39 8Z M9 -7 L35 -18 L32 2 L16 6Z", "#18213c")
                + ellipse(-28, 0, 3, 5, "#fffad1", "none") + ellipse(25, -6, 3, 5, "#fffad1", "none")
                + line("M0 29 L24 26", "#3b4050", 4))
    wolf = kind == "wolf"
    body = path("M-52 -58 L-23 -38 Q0 -48 23 -38 L52 -58 L49 -3 Q67 27 35 54 L0 74 L-35 54 Q-67 27 -49 -3Z" if wolf else "M-59 -52 L-25 -34 Q0 -43 25 -34 L59 -52 L53 -7 Q74 41 34 61 Q0 80 -34 61 Q-74 41 -53 -7Z")
    body += path("M-45 -36 L-28 -24 L-43 -15Z M45 -36 L28 -24 L43 -15Z", "#edb0b3", "none")
    body += path("M-35 17 Q0 49 35 17 L24 45 L0 61 L-24 45Z", "url(#metal)", "none")
    body += ellipse(-23, 3, 9, 13, "#18213b", "none") + ellipse(23, 3, 9, 13, "#18213b", "none")
    body += ellipse(-25, -2, 3, fill="#ffffff", stroke="none") + ellipse(21, -2, 3, fill="#ffffff", stroke="none")
    body += path("M-8 29 Q0 22 8 29 L0 38Z", "#20263e", "none")
    if not wolf:
        body += line("M-41 22 L-63 17 M-41 31 L-65 34 M41 22 L63 17 M41 31 L65 34", "url(#light)", 3)
    return body


def bird(phoenix=False):
    result = wings() + path("M-11 -37 Q-4 -57 14 -45 L30 -33 L11 -25 Q-7 -2 14 16 L4 47 L-13 70 L-12 38 Q-35 3 -11 -37Z", "url(#gold)")
    result += ellipse(5, -39, 3, fill="#172239", stroke="none")
    if phoenix:
        result += path("M-10 24 Q-59 61 -45 88 Q-5 66 -4 41 Q12 86 43 83 Q40 51 8 23Z", "url(#main)")
    return result


def leaf():
    return path("M-37 52 Q-77 -20 48 -71 Q82 30 -37 52Z") + line("M-45 65 L31 -44 M-17 29 L-33 -5 M2 9 L31 10", "url(#light)", 4)


def tree(ancient=False):
    result = path("M-12 15 L-20 56 L-57 81 L-9 63 L0 87 L13 61 L54 82 L23 47 L15 -13Z", "url(#gold)")
    result += ellipse(-36, -9, 38, 35) + ellipse(35, -10, 40, 37) + ellipse(0, -39, 47, 40)
    result += path("M-59 -15 Q-52 -44 -29 -38 M-26 -56 Q2 -76 25 -52", "none", "url(#light)", 6)
    if ancient:
        result += path("M-25 0 L-32 48 L-8 63 L24 48 L25 -11 L3 -27Z", "url(#rock)")
        result += path("M-20 12 L-4 17 L-13 23Z M6 16 L21 7 L18 21Z", "url(#light)", "none")
        result += line("M-8 39 L10 36", "url(#light)", 3)
    return result


def flower():
    result = ""
    petal = path("M0 14 Q-35 -5 0 -62 Q35 -5 0 14Z", "url(#metal)")
    for a in range(0, 360, 60):
        result += group(petal, rotate=a)
    return result + ellipse(0, 0, 19, fill="url(#gold)") + ellipse(-4, -5, 7, fill="url(#light)", stroke="none")


def heart():
    return path("M0 -32 C-56 -88 -93 -6 -47 36 L0 76 L47 36 C93 -6 56 -88 0 -32Z") + line("M-48 -15 Q-48 -39 -24 -36", "#fff7e0", 7)


def eye():
    return path("M-77 0 Q0 -78 77 0 Q0 78 -77 0Z", "url(#metal)") + ellipse(0, 0, 31) + ellipse(0, 0, 14, 22, "#1e2440") + ellipse(-10, -12, 8, fill="#ffffff", stroke="none")


def bolt():
    return path("M12 -83 L-53 8 L-8 8 L-29 81 L57 -22 L10 -22 L32 -83Z", "url(#light)") + path("M12 -70 L-28 -1 L6 -1 L-10 44 L39 -12 L0 -12Z", "#ffffff", "none")


def orb():
    return ellipse(0, 0, 56, fill="url(#orb)") + ellipse(-16, -23, 19, 10, "#fffdf4", "none") + path("M-42 19 Q-23 58 19 40", "none", "url(#light)", 5)


def sigil():
    return ellipse(0, 0, 76, 53, "none", "url(#main)", 4) + ellipse(0, 0, 63, 42, "none", "url(#light)", 2) + line("M0 -44 L54 22 L-54 22Z M0 44 L-54 -22 L54 -22Z", "url(#main)", 3)


def vortex():
    return (path("M-81 -38 Q-63 -75 19 -64 Q87 -49 70 -25 Q49 -4 -38 -10 Q-73 -13 -65 4 Q-56 20 15 14 Q69 8 55 30 Q42 48 -18 44 Q-44 42 -30 57 Q-7 74 16 54 Q14 88 -15 81 Q-55 70 -48 48 Q-78 27 -69 10 Q-96 -12 -81 -38Z")
            + line("M-64 -40 Q-21 -69 56 -38 M-47 2 Q-4 15 45 2 M-25 44 L25 41", "url(#light)", 6))


def slash():
    return path("M-84 56 Q-61 -70 84 -63 Q-1 -39 -27 12 Q-39 27 -84 56Z", "url(#light)") + path("M-84 56 Q-20 -33 84 -63 Q-24 -15 -84 56Z", "url(#main)", "none")


def ground():
    return (ellipse(0, 45, 90, 25, "none", "url(#main)", 7)
            + path("M-77 41 L-58 14 L-30 25 L-8 -3 L9 25 L36 10 L60 32 L76 50 L17 42 L-2 75 L-15 38 L-60 58Z", "url(#rock)")
            + line("M-61 39 L-19 31 L0 45 L-2 65 M0 45 L33 32 L63 40", "url(#light)", 5))


def crack():
    return path("M-59 -55 L-28 -18 L-45 -6 L-4 24 L-23 50 L-7 86 L10 41 L27 11 L-10 -15 L4 -26Z", "url(#light)")


def ray():
    return (path("M-12 -103 L12 -103 L25 65 L-25 65Z", "url(#main)", "none")
            + path("M-3 -103 L3 -103 L10 65 L-10 65Z", "url(#light)", "none") + star(0, 54, 40))


def cloud():
    return path("M-57 31 C-96 26 -83 -24 -54 -21 C-48 -67 16 -70 28 -29 C76 -43 90 20 56 31Z", "url(#metal)") + line("M-61 -8 Q-44 -7 -42 -30 M-27 -41 Q-3 -51 12 -32", "#ffffff", 5)


def hand(prayer=False):
    single = path("M-5 71 L-35 53 Q-43 16 -30 -20 L-13 -61 Q-1 -76 1 -57 L-7 -15 L5 -51 Q14 -61 19 -48 L11 -4 L25 -23 Q39 -32 40 -17 L25 25 L4 51Z", "url(#metal)")
    if prayer:
        return group(single, -10, 0, .9, -12) + group(single, 10, 0, .9, 12).replace('scale(0.9)', 'scale(-0.9 0.9)')
    return single


OBJECTS = {
    "sword": blade(), "spear": blade("spear"), "arrow": blade("arrow"),
    "axe": blade("axe"), "hammer": blade("hammer"), "shield": shield(), "buckler": shield(True),
    "flame": flame(), "meteor": meteor(), "broken_meteor": meteor(True), "crystal": crystal(),
    "wings": wings(), "crown": crown(), "cat": face("cat"), "wolf": face("wolf"),
    "frog": face("frog"), "dragon": face("dragon"), "hawk": bird(), "phoenix": bird(True),
    "leaf": leaf(), "tree": tree(), "treant": tree(True), "flower": flower(),
    "heart": heart(), "eye": eye(), "bolt": bolt(), "orb": orb(), "sigil": sigil(),
    "vortex": vortex(), "slash": slash(), "ground": ground(), "crack": crack(), "ray": ray(),
    "cloud": cloud(), "hand": hand(), "prayer": hand(True),
    "cross": path("M-14 -70 L14 -70 L14 -20 L55 -20 L55 8 L14 8 L14 70 L-14 70 L-14 8 L-55 8 L-55 -20 L-14 -20Z", "url(#gold)") + star(0, -4, 20),
    "hourglass": path("M-44 -68 L44 -68 L38 -41 L8 -2 L38 38 L44 68 L-44 68 L-38 38 L-8 -2 L-38 -41Z", "url(#metal)") + path("M-29 -38 L29 -38 L0 -5Z M0 14 L28 47 L-28 47Z", "url(#main)", "none") + line("M-45 -66 L45 -66 M-45 65 L45 65", "url(#gold)", 11),
    "book": path("M0 -49 Q-33 -69 -66 -52 L-66 55 Q-33 43 0 61 Q33 43 66 55 L66 -52 Q33 -69 0 -49Z", "url(#gold)") + path("M-7 -40 Q-33 -52 -55 -41 L-55 41 Q-33 34 -7 48Z M7 -40 Q33 -52 55 -41 L55 41 Q33 34 7 48Z", "url(#metal)") + line("M-43 -19 L-19 -15 M-43 0 L-19 5 M20 -14 L45 -20 M20 5 L45 0", "url(#main)", 5),
    "skull": path("M-57 -13 C-67 -90 67 -90 57 -13 L42 17 L38 56 L-38 56 L-42 17Z", "url(#metal)") + ellipse(-24, -6, 17, 19, "#282139") + ellipse(24, -6, 17, 19, "#282139") + path("M0 10 L-10 28 L10 28Z", "#282139", "none") + line("M-16 40 L-16 55 M0 40 L0 55 M16 40 L16 55", "#282139", 4),
    "helmet": path("M-57 29 L-54 -27 Q0 -88 54 -27 L57 29 L34 66 L14 47 L14 6 L-14 6 L-14 47 L-34 66Z", "url(#metal)") + path("M-38 -16 L-12 -3 L-16 14 L-41 2Z M38 -16 L12 -3 L16 14 L41 2Z", "#18213a", "none") + path("M-6 -53 L0 -88 L9 -52 L7 -3 L-7 -3Z", "url(#gold)"),
    "spirit": path("M-30 61 Q-61 25 -35 -11 Q-42 -53 1 -73 Q52 -47 35 -8 Q60 16 38 51 L20 35 L3 69 L-11 43Z") + ellipse(-14, -7, 7, 12, "#fffbe4", "none") + ellipse(14, -7, 7, 12, "#fffbe4", "none") + ellipse(0, 28, 12, 8, "url(#light)", "none"),
    "mushroom": path("M-16 8 L16 8 L23 71 Q0 86 -23 71Z", "url(#metal)") + path("M-74 12 Q-70 -71 0 -73 Q70 -71 74 12 Q0 37 -74 12Z") + ellipse(-30, -24, 15, 13, "url(#light)", "none") + ellipse(19, -44, 11, fill="url(#light)", stroke="none") + ellipse(42, -3, 9, fill="url(#light)", stroke="none"),
    "boot": path("M-39 -66 L19 -66 L17 -6 L50 13 Q69 27 61 53 Q19 77 -43 57 L-45 20Z", "url(#metal)") + path("M-33 -60 L11 -60 L11 -41 L-33 -41Z M-38 44 Q15 61 61 36 L61 54 Q18 77 -43 58Z", "url(#gold)") + line("M-9 -30 L15 -24 M-12 -9 L13 -4", "url(#main)", 5),
    "bow": path("M-39 -79 Q53 -47 21 0 Q54 51 -39 81 L-28 63 Q14 37 3 1 Q13 -40 -27 -61Z", "url(#gold)") + line("M-36 -72 L-4 0 L-36 72", "url(#metal)", 3),
    "dagger": path("M0 -78 Q14 -46 11 14 L-11 14 Q-14 -46 0 -78Z", "url(#metal)") + path("M0 -70 L0 12 L9 12 Q11 -40 0 -70Z", "url(#main)", "none") + path("M-30 14 Q0 26 30 14 L26 26 L-26 26Z", "url(#gold)") + path("M-6 26 L6 26 L7 56 L-7 56Z", "url(#rock)") + ellipse(0, 60, 8, 7, "url(#gold)"),
    "moon": path("M22 -72 A74 74 0 1 0 22 72 A58 58 0 1 1 22 -72Z", "url(#light)") + line("M-30 -46 Q-52 0 -30 46", "#ffffff", 3),
    "smoke": ellipse(-38, 12, 30, 23, "url(#rock)", "#151c35", 2.5) + ellipse(38, 14, 30, 22, "url(#rock)", "#151c35", 2.5) + ellipse(0, -10, 40, 33, "url(#rock)", "#151c35", 2.5) + line("M-46 6 Q-36 -6 -24 4 M-8 -22 Q6 -34 18 -20 M28 10 Q40 0 50 12", "url(#light)", 3),
    "drop": path("M0 -70 Q42 -10 34 26 Q24 62 0 62 Q-24 62 -34 26 Q-42 -10 0 -70Z") + path("M-14 8 Q-20 30 -6 42", "none", "#ffffff", 5),
    "mask": path("M-56 -10 Q-58 -76 0 -80 Q58 -76 56 -10 Q54 46 0 74 Q-54 46 -56 -10Z", "url(#rock)") + path("M-40 -6 Q0 -26 40 -6 L36 22 Q0 40 -36 22Z", "#1c1530") + path("M-30 2 L-8 6 L-12 14 L-30 10Z M30 2 L8 6 L12 14 L30 10Z", "url(#light)", "none"),
    "chalice": path("M-44 -57 L44 -57 Q49 -2 10 17 L9 51 L36 63 L36 72 L-36 72 L-36 63 L-9 51 L-10 17 Q-49 -2 -44 -57Z", "url(#gold)") + ellipse(0, -55, 43, 12, "url(#main)") + star(0, -15, 17),
}


OBJECTS["twin"] = group(OBJECTS["dagger"], -18, 6, .8, 32) + group(OBJECTS["dagger"], 18, 6, .8, -32)
# The Dark Lord's scepter (an orb in a crown on a short royal shaft) and his raven.
OBJECTS["scepter"] = (path("M-5 -20 L5 -20 L6 78 L-6 78Z", "url(#gold)") + ellipse(0, 82, 9, 8, "url(#gold)")
                      + ellipse(0, -44, 24, 24, "url(#orb)") + path("M-26 -54 L-20 -78 L-9 -62 L0 -84 L9 -62 L20 -78 L26 -54Z", "url(#gold)")
                      + path("M-24 -24 Q0 -12 24 -24 L20 -14 Q0 -4 -20 -14Z", "url(#gold)"))
OBJECTS["raven"] = (path("M-82 -10 Q-40 -46 -8 -14 Q-2 -34 10 -36 Q26 -38 30 -24 L46 -20 L30 -14 Q34 0 22 12 Q60 -36 84 -14 Q60 4 34 22 L40 56 L18 40 L4 60 L-4 38 Q-50 24 -82 -10Z", "url(#rock)")
                    + ellipse(18, -24, 4, 4, "#ff3a4a", "none") + line("M-66 -10 Q-40 -26 -16 -6 M60 -14 Q40 -2 28 14", "url(#light)", 3))
# The Bard: a lute, notes, a clef, a stave, a lyre and a war drum.
OBJECTS["note"] = (group(ellipse(0, 0, 27, 19, "url(#main)"), -16, 50, 1, -22)
                   + path("M5 46 L5 -72 L15 -72 L15 42Z", "url(#gold)")
                   + path("M15 -72 Q50 -52 46 -18 Q42 6 30 16 Q40 -10 32 -30 Q24 -44 15 -44Z", "url(#gold)")
                   + line("M-34 44 Q-28 36 -16 38", "#ffffff", 4))
OBJECTS["notes"] = (group(ellipse(0, 0, 23, 16, "url(#main)"), -40, 52, 1, -22) + group(ellipse(0, 0, 23, 16, "url(#main)"), 36, 38, 1, -22)
                    + path("M-26 46 L-26 -48 L-17 -50 L-17 44Z", "url(#gold)") + path("M50 32 L50 -64 L59 -66 L59 30Z", "url(#gold)")
                    + path("M-26 -50 L59 -68 L59 -48 L-26 -30Z", "url(#gold)")
                    + line("M-56 46 Q-50 40 -40 42", "#ffffff", 4))
OBJECTS["treble"] = (line("M8 82 Q-8 92 -18 80 Q-24 66 -8 62 Q8 62 6 78 L4 -64 Q4 -92 20 -86 Q32 -76 20 -54 L-26 -4 Q-48 22 -28 44 Q-8 62 18 48 Q36 34 24 12 Q12 -4 -6 6 Q-20 18 -4 32", "url(#gold)", 10)
                     + line("M4 -64 Q4 -88 18 -84", "#ffffff", 3) + ellipse(-12, 72, 8, fill="url(#gold)"))
OBJECTS["stave"] = "".join(line(f"M-88 {y - 4} Q-44 {y - 20} 0 {y - 4} Q44 {y + 12} 88 {y - 4}", "url(#light)", 3.2) for y in (-32, -16, 0, 16, 32))
OBJECTS["lute"] = (path("M0 -8 Q46 -6 48 38 Q48 84 0 88 Q-48 84 -48 38 Q-46 -6 0 -8Z", "url(#gold)")
                   + path("M0 2 Q36 4 38 38 Q38 76 0 78 Q-38 76 -38 38 Q-36 4 0 2Z", "url(#main)")
                   + ellipse(0, 30, 14, None, "#1c1030", "url(#light)", 3)
                   + path("M-16 62 L16 62 L14 69 L-14 69Z", "url(#rock)")
                   + path("M-7 -8 L-6 -72 L6 -72 L7 -8Z", "url(#rock)")
                   + path("M-6 -72 L6 -72 L-14 -94 L-25 -88Z", "url(#gold)")
                   + line("M-9 -82 L-18 -78 M-15 -88 L-24 -84", "url(#light)", 3)
                   + line("M-3 -70 L-4 64 M0 -70 L0 64 M3 -70 L4 64", "#fff8e8", 1.6))
OBJECTS["lyre"] = (path("M-30 64 Q-58 30 -46 -10 Q-38 -40 -58 -64 Q-30 -70 -26 -40 Q-22 -6 -14 30 L-12 64Z", "url(#gold)")
                   + path("M30 64 Q58 30 46 -10 Q38 -40 58 -64 Q30 -70 26 -40 Q22 -6 14 30 L12 64Z", "url(#gold)")
                   + path("M-46 -42 L46 -42 L44 -32 L-44 -32Z", "url(#gold)")
                   + path("M-40 60 Q0 76 40 60 L38 76 Q0 90 -38 76Z", "url(#main)")
                   + line("M-18 -32 L-18 64 M-6 -32 L-6 66 M6 -32 L6 66 M18 -32 L18 64", "#fff8e8", 2.5)
                   + ellipse(0, -37, 7, fill="url(#orb)"))
OBJECTS["drum"] = (path("M-58 -24 L58 -24 L52 54 Q0 70 -52 54Z", "url(#gold)")
                   + line("M-54 -16 L-36 50 L-18 -14 L0 58 L18 -14 L36 50 L54 -16", "url(#main)", 4)
                   + ellipse(0, -24, 58, 16, "url(#light)")
                   + line("M-62 -78 L14 -30 M62 -78 L-14 -30", "url(#gold)", 8)
                   + line("M-58 -76 L-30 -58 M58 -76 L30 -58", "#ffffff", 2.5)
                   + ellipse(-64, -80, 9, fill="url(#light)") + ellipse(64, -80, 9, fill="url(#light)"))


def o(name, x=0, y=0, s=1, a=0, opacity=1):
    return group(OBJECTS[name], x, y, s, a, opacity)


def ring(s=1, y=0):
    return group(ellipse(0, 0, 82, 53, "none", "url(#main)", 7) + ellipse(0, 0, 70, 44, "none", "url(#light)", 2), y=y, scale=s)


def wind():
    return line("M-85 -26 Q-53 -50 12 -37 Q72 -24 69 -53 M-74 3 Q-30 -15 45 -1 M-53 37 Q3 66 83 30", "url(#main)", 6)


def rays(n=8):
    return "".join(group(path("M-4 -58 L0 -100 L4 -58Z", "url(#light)", "none"), rotate=i*360/n) for i in range(n))


def fan(item, n, spread=100, s=.57, y=10):
    return "".join(o(item, y=y, s=s, a=-spread/2+i*spread/max(1,n-1)) for i in range(n))


def rain(item, n=3, s=.46):
    return "".join(o(item, x=-55+i*110/max(1,n-1), y=8+(i%2)*24, s=s, a=165) for i in range(n))


def chain():
    return "".join(group(ellipse(0,0,15,23,"none","url(#gold)",7), -57+i*28,-37+i*18,.85,-40 if i%2 else 40) for i in range(5))


def thorns():
    return line("M-62 75 Q-82 34 -50 14 Q-11 4 -29 -38 Q-51 -84 -16 -94 M60 75 Q89 27 55 14 Q26 0 45 -42", "url(#main)", 9) + path("M-49 12 L-75 -4 L-56 26 M-26 -28 L-8 -48 L-24 -8 M52 11 L76 -11 L66 30", "url(#light)", "none")


def snow():
    return "".join(group(line("M0 0 L0 -75 M0 -44 L-17 -59 M0 -44 L17 -59", "url(#light)", 7), rotate=i*60) for i in range(6))


def feathers():
    return o("leaf",-46,4,.55,-45)+o("leaf",44,-1,.55,40)


RECIPES = {}


def add(family, entries):
    for skill, palette, picture in entries:
        assert skill not in RECIPES, skill
        RECIPES[skill] = (family, palette, picture)


# Each scene is authored against ClassData's actual effect, not its old icon key.
add("vagabond", [
    ("power_strike", "steel", o("slash",s=.83)+o("sword",s=.93,a=34)),
    ("round_slash", "gold", ring()+o("slash",s=.8,a=145)+o("sword",s=.77,a=-33)),
    ("second_wind", "wind", wind()+o("heart",s=.68)+o("leaf",48,44,.35,25)),
])
add("warrior", [
    ("raving","ember",o("slash",-13,-15,.9)+o("slash",9,25,.83)+o("sword",14,-2,.84,30)),
    ("impact","gold",rays(7)+o("hammer",s=.84,a=-32)+star(43,45,25)),
    ("triple_impact","ember",fan("sword",3,68,.75)),
    ("brutal_swing","ember",ring()+o("axe",s=.92,a=30)+o("slash",s=.8,a=125)),
    ("roar","gold",rays(9)+o("wolf",s=.82)+ring(.56,54)),
    ("rage_of_zecram","ember",o("flame",s=1.14)+o("axe",s=.77,a=-27)),
    ("concentration","gold",ring(.86)+o("eye",s=.87)+star(0,-57,14)),
    ("avenging_crash","rose",o("ground",y=20,s=.84)+o("sword",-4,-5,1.0,-138)),
    ("swift_axe","wind",wind()+o("axe",s=.85,a=33)+o("leaf",-40,44,.35,-40)),
    ("bone_crash","earth",o("ground",y=18)+o("hammer",-7,-20,.78,-27)+o("skull",48,33,.28)),
    ("destroyer","ember",o("crack",s=1.1)+o("sword",s=1.04,a=35)+star(44,-50,19)),
    ("berserker","ember",o("flame",s=1.05)+o("helmet",y=17,s=.85)+o("axe",-56,17,.35,-25)),
    ("sword_blast","gold",o("slash",s=1.09,a=30)+o("sword",-18,22,.8,45)),
    ("holy_valor","gold",o("wings",s=1.12)+o("shield",y=10,s=.68)+o("sword",s=.69)),
    ("cyclone_strike","ember",o("vortex",s=1.05)+o("sword",s=.83,a=-20)),
    ("brandish","ember",o("slash",-3,-25,1.0,15)+o("sword",-3,22,.96,71)),
    ("double_crash","steel",o("ground",y=23,s=.93)+o("sword",-23,-15,.8,-155)+o("sword",23,-15,.8,155)),
    ("piercing","steel",o("shield",42,20,.48)+o("sword",-2,-4,1.04,43)+star(28,21,22)),
    ("drastic_spirit","storm",o("wings",s=1.06)+o("helmet",y=13,s=.79)+star(0,-65,17)),
    ("grand_cross","gold",o("slash",s=1.1,a=5)+o("slash",s=1.1,a=-85)+o("sword",-19,6,.76,-34)+o("sword",19,6,.76,34)),
    ("sword_of_justice","gold",rays(10)+o("wings",y=-12,s=.82)+o("sword",s=1.09)),
    ("godly_shield","gold",rays(12)+o("shield",y=8,s=1.02)+o("crown",0,-63,.36)),
    ("divine_piercing","gold",fan("sword",5,175,.76)),
    ("triumph_of_valhalla","gold",o("wings",s=1.2)+o("crown",s=.89)+o("sword",0,32,.48,180)),
    ("gladiator","ember",o("flame",s=1.18)+o("sword",-28,-6,.96,-36)+o("sword",28,-6,.96,36)+o("helmet",0,19,.67)),
])
add("archer", [
    ("wind_arrow","wind",wind()+o("arrow",s=1.02,a=33)),
    ("perfect_aim","gold",ring(.83)+o("eye",s=.61)+o("arrow",s=.94,a=44)),
    ("scout_hawk","earth",o("hawk",s=.92)+o("eye",0,48,.37)),
    ("arrow_of_rage","ember",fan("arrow",3,53,.93)),
    ("avalanche","wind",o("cloud",0,-51,.63)+rain("arrow",4,.57)),
    ("elemental_shot","ember",o("flame",s=.99,a=35)+o("arrow",s=1.04,a=35)),
    ("golden_falcon","gold",rays(8)+o("hawk",s=1.03)+o("crown",0,-57,.32)),
    ("bomb_shot","ember",o("orb",22,26,.64)+o("arrow",-14,-16,.94,-40)+star(48,-6,17)),
    ("perforation","steel",o("buckler",23,28,.59)+o("arrow",-3,-5,1.06,38)+o("crack",22,23,.33,80)),
    ("recall_wolverine","earth",o("wolf",-31,4,.73,-13)+o("wolf",34,23,.63,13)),
    ("phoenix_shot","ember",o("phoenix",s=1.06)+o("arrow",0,-7,.82)),
    ("dionic_sight","gold",o("wings",s=1.12)+o("eye",s=.79)+o("crown",0,-55,.35)),
    ("lethal_sight","rose",o("eye",s=.9)+o("arrow",s=1.08,a=27)+o("skull",-45,47,.28)),
    ("fierce_wind","wind",wind()+fan("arrow",5,103,.85)),
    ("force_of_nature","forest",thorns()+o("treant",-26,6,.65)+o("wolf",37,31,.62)),
    ("ensnare","forest",thorns()+rain("arrow",3,.54)+ring(.65,36)),
    ("hurricane","wind",wind()+o("vortex",s=1.08)+o("leaf",43,39,.33,45)),
    ("arrow_of_thunder","storm",chain()+o("bolt",s=.9)+o("arrow",-6,7,.92,38)),
    ("tempest","storm",o("vortex",s=1.1)+rain("arrow",3,.59)),
    ("lightning_arrow","storm",o("bolt",-22,-10,.94,15)+o("arrow",12,1,1.03,39)+star(47,-46,16)),
    ("phoenix_rain","ember",o("phoenix",0,-27,.85)+rain("arrow",3,.57)),
    ("spirit_of_wind","wind",o("wings",s=1.1)+o("spirit",s=.85)+wind()),
    ("dragon_shot","ember",fan("arrow",5,107,.85)+o("dragon",0,32,.6)),
    ("meteor_arrow","ember",o("meteor",s=1.05)+o("arrow",s=1.17,a=-43)+o("ground",0,54,.6)),
])
add("mage", [
    ("agony","arcane",chain()+o("skull",s=.83)+star(37,-47,13)),
    ("fire_bolt","ember",o("flame",s=.93,a=43)+o("orb",26,25,.47)),
    ("zenith","frost",o("wings",y=20,s=.88)+o("crown",0,-7,.89)+star(0,-80,13)),
    ("fire_ball","ember",o("flame",s=1.15)+o("orb",0,20,.73)),
    ("watornado","frost",o("vortex",s=1.13)+o("orb",0,-47,.29)),
    ("enchant_weapon","arcane",ring()+o("sword",s=.94,a=23)+o("crystal",-45,22,.35,-25)+star(55,8,15)),
    ("dead_ray","arcane",o("ray",s=1.02,a=40)+o("skull",-41,47,.35)),
    ("energy_shield","frost",ring(.98)+o("shield",s=.93)+o("orb",0,-7,.26)),
    ("diastrophism","earth",o("ground",y=13,s=1.05)+o("crystal",-32,-24,.49,-24)+o("crystal",21,-35,.57,18)),
    ("spirit_elemental","frost",o("sigil",y=58,s=.88)+o("spirit",0,-6,1.02)+o("orb",-57,12,.19)+o("orb",57,-13,.19)),
    ("dancing_sword","arcane",ring(1.05,21)+o("sword",-42,-1,.71,-25)+o("sword",0,-19,.85)+o("sword",42,-1,.71,25)),
    ("flame_wave","ember",o("flame",-46,13,.64,-26)+o("flame",0,-8,.93)+o("flame",47,13,.64,26)+o("slash",0,47,.89,180)),
    ("distortion","arcane",ring(1.06)+group(ring(.77),rotate=70)+o("orb",s=.53)+o("crack",s=.56,a=27)),
    ("fire_elemental","ember",o("flame",s=1.15)+o("spirit",0,14,.76)+o("orb",-57,38,.22)+o("orb",57,27,.22)),
    ("meteo","ember",o("meteor",s=1.06)+ring(.8,62)),
    ("silraphim","rose",o("wings",s=1.15)+o("shield",0,16,.61)+o("crown",0,-36,.51)),
    ("slow_speed","frost",o("sigil",s=.99)+o("hourglass",s=.94)+o("crystal",49,40,.36,-30)),
    ("vague","arcane",o("spirit",-36,2,.8,opacity=.45)+o("spirit",31,-6,.8,opacity=.7)+o("spirit",0,14,.83)),
    ("thunder_storm","storm",o("cloud",0,-48,.79)+o("bolt",-32,18,.65,14)+o("bolt",24,26,.79,-6)),
    ("hell_meteor","ember",chain()+o("meteor",s=1.14)+o("flame",0,-65,.46)+o("skull",22,26,.29)),
    ("ice_storm","frost",o("vortex",s=1.08)+o("crystal",-37,9,.65,-27)+o("crystal",8,-12,.79,8)+o("crystal",47,30,.45,25)+group(snow(),y=-54,scale=.25)),
    ("spirit_burst","rose",rays(11)+o("spirit",s=.86)+o("crystal",-64,17,.27,-50)+o("crystal",55,-38,.27,40)),
    ("magic_overdrive","arcane",o("book",0,38,.91)+o("bolt",0,-23,.7)+o("crystal",-54,-28,.4,-20)+o("crystal",54,-28,.4,20)),
    ("judgment_ray","gold",o("wings",0,-47,.71)+o("ray",s=1.08)+ring(.67,59)),
    ("armageddon","ember",o("ground",0,45,.96)+o("broken_meteor",-10,-18,1.01)+o("crystal",-60,27,.29,-58)+o("crystal",68,12,.33,46)+o("crystal",37,74,.24,70)+star(-38,62,17)),
])
add("priest", [
    ("holy_bolt","gold",o("ray",s=.83,a=42)+o("cross",-24,21,.6)),
    ("healing","rose",o("heart",s=.95)+o("cross",0,3,.41)+star(52,-45,13)),
    ("multi_spark","gold",star(-45,-38,27)+star(40,-44,31)+star(42,38,27)+star(-41,41,24)+ring(.59)),
    ("holy_mind","gold",feathers()+o("eye",s=.84)+o("cross",0,-52,.32)),
    ("divine_lightning","gold",o("cloud",0,-57,.6)+o("bolt",s=.91)+o("cross",46,45,.3)),
    ("holy_reflection","rose",o("shield",s=.86)+o("slash",-4,-8,1.02,55)+star(38,-42,22)),
    ("grand_healing","rose",o("wings",s=1.07)+o("heart",s=.76)+o("cross",0,7,.43)),
    ("vigor_ball","gold",o("orb",s=1.04)+o("cross",s=.5)+wind()),
    ("extinction","gold",rays(10)+o("skull",s=.85)+o("cross",0,6,.91,32)),
    ("virtual_life","rose",o("hand",-29,29,.65,-23)+o("heart",15,-28,.7)+o("leaf",46,37,.37,23)),
    ("glacial_spike","frost",o("ground",y=42,s=.91)+fan("crystal",3,53,.84)),
    ("resurrection","gold",o("wings",s=1.17)+o("cross",0,9,.86)+star(0,-78,17)),
    ("summon_muspell","gold",o("sigil",y=59,s=.83)+o("spirit",s=1.02)+o("crown",0,-64,.35)),
    ("regeneration_field","forest",o("sigil",y=48,s=1.02)+o("flower",0,-13,.91)+o("cross",0,-12,.28)),
    ("chain_lightning","storm",chain()+o("bolt",-31,-16,.74)+o("bolt",32,21,.66)),
    ("blessing_aura","gold",ring(1.13)+o("cross",s=.81)+o("flower",0,50,.42)),
    ("judgement_light","gold",o("eye",0,-48,.52)+o("ray",0,21,.88)+o("cross",-49,17,.27)),
    ("hand_of_god","gold",rays(8)+o("hand",s=1.11)+star(29,-19,26)),
    ("heaven_light","gold",o("cloud",0,-55,.76)+fan("ray",3,49,.68,19)),
    ("divine_judgment","gold",o("wings",0,-24,.9)+o("sword",-29,6,.85,-26)+o("cross",24,7,.87)),
    ("prayer","rose",ring(.94)+o("prayer",s=.88)+star(0,-76,17)),
    ("seraphim_wrath","gold",o("wings",0,-39,1.02)+o("wings",0,7,.82)+o("sword",s=1.09)+o("crown",0,-58,.4)),
    ("holy_rain_big","gold",o("cloud",0,-64,.67)+rain("cross",3,.53)+ring(.82,62)),
    ("miracle","rose",o("wings",s=1.13)+o("chalice",s=.91)+o("heart",0,-66,.32)),
    ("last_judgement","gold",rays(12)+o("wings",0,-30,1.18)+o("cross",s=1.08)+o("book",0,62,.45)),
])
add("summoner", [
    ("thorn_shot","forest",o("leaf",s=.94,a=28)+o("spear",s=.82,a=35)),
    ("spirit_cat","arcane",o("sigil",y=63,s=.75)+o("cat",s=1.05)+star(46,-62,15)),
    ("forest_blessing","forest",feathers()+o("heart",s=.67)+o("flower",0,-40,.38)),
    ("vine_lash","forest",thorns()+o("slash",s=.97,a=21)+o("leaf",-32,34,.5,-43)),
    ("entangle","forest",thorns()+o("boot",s=.82)+ring(.74,34)),
    ("wolf_pack","forest",o("sigil",y=60,s=.83)+o("wolf",-32,-1,.78,-12)+o("wolf",35,17,.72,12)),
    ("regrowth","forest",o("ground",y=47,s=.72)+o("leaf",-23,-10,.64,-32)+o("leaf",23,-23,.68,24)+o("heart",0,37,.39)),
    ("spore_burst","forest",o("mushroom",s=.92)+o("orb",-64,-34,.2)+o("orb",55,-49,.23)+o("orb",64,35,.16)),
    ("giant_frog","forest",o("leaf",-39,46,.42,-25)+o("frog",s=1.07)+o("crown",0,-60,.3)),
    ("beast_rage","ember",o("flame",s=1.07)+o("wolf",y=15,s=.9)),
    ("thorn_storm","forest",thorns()+o("vortex",s=.99)+rain("spear",3,.48)),
    ("forest_guardian","forest",o("tree",s=1.04)+o("shield",0,31,.58)),
    ("life_bloom","rose",feathers()+o("flower",s=1.14)+o("heart",0,8,.35)),
    ("nature_wrath","forest",thorns()+o("bolt",s=.94)+o("leaf",-36,35,.48,-32)),
    ("alpha_wolves","gold",o("wolf",-47,9,.57,-12)+o("wolf",43,19,.57,12)+o("wolf",0,5,.88)+o("crown",0,-60,.36)),
    ("earth_shatter","earth",o("ground",y=26,s=1.14)+o("crack",0,-31,.71)+o("crystal",-50,-10,.44,-28)),
    ("ancient_treant","forest",o("sigil",y=62,s=.92)+o("treant",s=1.09)),
    ("spirit_link","forest",chain()+o("cat",-42,-19,.63)+o("heart",37,27,.61)),
    ("sylvan_ray","forest",thorns()+o("ray",s=.99,a=28)+o("flower",-39,51,.38)),
    ("world_tree","forest",ring(1.13,6)+o("tree",s=1.13)+star(0,-77,18)+o("orb",-53,13,.13)+o("orb",48,-6,.13)),
    ("fairy_spirit","rose",o("wings",s=1.08)+o("heart",0,6,.52)+o("orb",0,-4,.3)+star(-46,-58,14)+star(50,-50,12)+star(0,70,10)),
    ("gaia_blessing","forest",o("hand",-34,33,.6,-24)+o("hand",37,32,.6,28)+o("orb",0,-9,.84)+o("tree",0,-8,.53)),
    ("primal_legion","forest",o("wolf",-49,-11,.55,-16)+o("frog",45,12,.55,10)+o("cat",-16,38,.58)+o("hawk",0,-43,.64)),
    ("cataclysm","earth",o("ground",y=36,s=1.09)+o("flame",-41,-9,.69,-24)+o("crystal",16,-24,.89,17)+o("bolt",51,11,.53)),
    ("elder_dragon","gold",o("wings",s=1.17)+o("dragon",s=1.04)+o("crown",0,-63,.41)+o("orb",0,57,.24)),
])
add("lancer", [
    ("thrust","steel",o("spear",s=1.13,a=34)+star(36,-52,21)),
    ("stagger","earth",o("ground",y=37,s=.83)+o("spear",0,-7,1.06,-145)),
    ("focus","steel",o("eye",s=.73)+o("spear",s=1.02)+ring(.71)),
    ("skewer","steel",o("buckler",26,16,.58)+o("spear",-8,-7,1.15,44)+star(27,19,18)),
    ("whirl","wind",ring()+o("spear",s=1.08,a=-41)+o("slash",s=.98,a=150)),
    ("charge_dash","steel",wind()+o("spear",s=1.17,a=60)+o("boot",-39,38,.44,21)),
    ("wind_stance","wind",o("leaf",-33,-12,.75,-20)+o("spear",27,5,1.01,16)+wind()),
    ("impale","ember",o("crack",s=.99)+o("spear",s=1.14,a=-144)+star(25,46,23)),
    ("spear_wave","frost",o("slash",s=1.14,a=42)+o("spear",-20,17,.92,38)),
    ("iron_resolve","steel",o("shield",s=.94)+o("spear",-48,1,.7)+o("spear",48,1,.7)),
    ("spinning_pike","wind",o("vortex",s=1.04)+o("spear",s=1.11,a=59)),
    ("hook_strike","steel",o("slash",s=1.09,a=-37)+o("spear",s=1.02,a=14)+chain()),
    ("war_cry","gold",rays(7)+o("helmet",s=.88)+o("spear",-44,2,.66,-24)),
    ("dragon_tooth","ember",o("dragon",0,30,.7)+o("spear",s=1.14,a=26)),
    ("typhoon_spear","wind",o("vortex",s=1.05)+fan("spear",3,74,.87)),
    ("lancer_rush","steel",wind()+o("spear",-22,12,1.02,50)+o("spear",17,-20,.95,50)),
    ("vanguard_strike","gold",o("shield",-21,16,.77)+o("spear",20,-1,1.17,35)+star(48,-57,16)),
    ("sky_pierce","frost",o("cloud",0,-42,.94)+o("spear",0,9,1.22)+star(0,-84,19)),
    ("dragon_stance","ember",o("dragon",s=.97)+o("shield",0,48,.47)),
    ("dragon_lance","ember",o("flame",s=1.15,a=30)+o("spear",s=1.2,a=30)+o("dragon",-28,29,.46)),
    ("gale_cyclone","wind",o("vortex",s=1.14)+fan("spear",5,137,.69,9)),
    ("valkyrie_blessing","gold",o("wings",s=1.16)+o("helmet",s=.69)+o("spear",-47,8,.76,-16)),
    ("gungnir","gold",rays(10)+o("spear",s=1.22,a=26)+o("crown",-29,33,.39)),
    ("heaven_rend","frost",o("cloud",0,-60,.75)+o("crack",s=1.13)+o("spear",s=1.1,a=30)+star(-42,46,26)),
    ("ragnarok_lance","ember",o("ground",y=47,s=.98)+o("wings",0,-13,1.16)+o("spear",s=1.26)+o("dragon",0,36,.47)+rays(6)),
])

add("defender", [
    ("shield_bash","steel",o("slash",s=.86,a=-30)+o("shield",14,4,.9,-18)),
    ("brace","steel",ring(.8,40)+o("shield",s=1.02)),
    ("shield_slam","gold",rays(8)+o("shield",s=.88,a=12)+star(46,-50,20)+star(-48,40,14)),
    ("provoke","ember",rays(9)+o("shield",-14,6,.78,-10)+o("eye",34,-40,.42)),
    ("ground_quake","earth",o("ground",y=38,s=.96)+o("crack",0,30,.7)+o("shield",0,-22,.7,180)),
    ("shield_toss","steel",o("vortex",s=.92)+o("buckler",8,-6,.72,30)+wind()),
    ("iron_wall","steel",o("shield",-40,8,.62)+o("shield",40,8,.62)+o("shield",0,-4,.78)),
    ("bulwark_charge","steel",wind()+o("shield",14,0,.86,24)+o("boot",-44,44,.42,18)),
    ("thorn_guard","ember",thorns()+o("shield",s=.84)),
    ("quake_slam","earth",o("crack",s=1.06)+o("shield",0,-16,.74,180)+star(-50,50,18)+star(52,46,16)),
    ("aegis_strike","gold",o("slash",s=1.1,a=40)+o("shield",-6,6,.86,-28)+rays(5)),
    ("guardian_oath","gold",o("hand",-40,32,.55,-22)+o("shield",0,-6,.8)+o("heart",0,-6,.3)),
    ("shield_wave","frost",o("ray",s=1.04,a=90)+o("shield",-36,4,.66,-12)),
    ("shockwave_wall","frost",ring(1.05)+ring(.7)+o("shield",s=.74)),
    ("titan_quake","earth",o("ground",y=42,s=1.08)+o("crack",0,18,.95)+o("hammer",0,-30,.6,180)+o("shield",-44,-36,.42)),
    ("bastion_crush","steel",o("crack",0,24,.9)+o("shield",0,-10,.98,180)+o("slash",s=.7,a=90)),
    ("rebound_storm","frost",o("vortex",s=1.04)+o("buckler",-52,-30,.42,-20)+o("buckler",50,-26,.42,20)+o("buckler",0,40,.46)),
    ("grand_provoke","ember",rays(12)+o("helmet",s=.7)+o("shield",-46,20,.5,-14)+o("shield",46,20,.5,14)),
    ("unbreakable","gold",o("crystal",0,-4,.9)+o("shield",s=.92,opacity=.9)+star(0,-70,18)),
    ("holy_rampart","gold",rays(10)+ring(.95,30)+o("shield",-44,0,.5)+o("shield",44,0,.5)+o("shield",0,-10,.66)),
    ("judgment_shield","gold",o("cross",0,-44,.6)+o("shield",0,12,.86)+o("ray",s=.8,a=0)),
    ("aegis_of_ages","gold",o("wings",s=1.1)+o("shield",0,4,.76)+o("hourglass",0,-62,.3)),
    ("meteor_shield","ember",o("meteor",-30,-30,.7,30)+o("shield",18,20,.8,-20)+o("ground",y=58,s=.8)),
    ("sanctuary_wall","gold",o("crown",0,-56,.44)+o("shield",-36,10,.6)+o("shield",36,10,.6)+o("orb",0,22,.4)),
    ("world_bastion","gold",o("ground",y=46,s=1.04)+o("wings",0,-20,1.0)+o("shield",0,0,.92)+o("crown",0,-66,.36)+rays(6)),
])

add("assassin", [
    ("twin_fang","night",o("slash",-10,-12,.8)+o("twin",0,4,.92)),
    ("shadow_veil","night",o("smoke",0,24,1.0)+o("mask",0,-14,.62)+wind()),
    ("venom_edge","venom",o("dagger",-8,0,.95,24)+o("drop",42,-36,.38)+o("drop",-44,40,.28)),
    ("shadow_step","night",wind()+o("boot",-38,40,.44,18)+o("dagger",22,-8,.86,40)+o("smoke",-50,30,.45)),
    ("blade_flurry","night",ring()+o("dagger",0,0,.86)+o("dagger",0,0,.86,120)+o("dagger",0,0,.86,240)),
    ("fan_of_knives","night",fan("dagger",5,110,.8,30)+star(0,-70,12)),
    ("killing_focus","blood",ring(.86)+o("eye",s=.82)+o("dagger",0,52,.4,90)),
    ("backstab","blood",o("mask",-20,-6,.7)+o("dagger",30,10,.9,-150)+star(44,-48,16)),
    ("smoke_bomb","night",o("smoke",0,10,1.15)+o("orb",0,-40,.32)+rays(7)),
    ("night_raid","night",o("moon",30,-40,.5)+o("slash",-10,10,.82,20)+o("slash",12,-6,.7,-150)+o("dagger",-30,30,.5,40)),
    ("crimson_cut","blood",o("slash",s=1.05,a=-20)+o("dagger",10,4,.86,-40)+o("drop",-46,44,.26)),
    ("shadow_clone","night",o("smoke",0,52,.8)+o("mask",-34,0,.56,0,.45)+o("mask",34,0,.56,0,.45)+o("mask",0,-6,.7)),
    ("phantom_daggers","blood",o("ray",s=.7,a=90,opacity=.6)+o("dagger",-40,0,.55,90)+o("dagger",0,0,.6,90)+o("dagger",40,0,.55,90)),
    ("deadly_venom","venom",o("smoke",0,22,1.05)+o("skull",0,-28,.5)+o("drop",46,-50,.3)),
    ("thousand_cuts","blood",ring(1.0)+ring(.62)+o("slash",s=.7,a=30)+o("slash",s=.7,a=210)+o("twin",0,0,.55)),
    ("throat_slit","blood",o("slash",0,-10,.9,170)+o("dagger",-14,14,.84,-60)+star(40,-40,14)),
    ("shadow_dance","night",o("moon",0,-6,.85)+fan("dagger",3,140,.42,-4)),
    ("death_mark","blood",o("sigil",s=.95)+o("skull",0,-4,.52)+o("crack",0,40,.4)),
    ("night_lord","night",rays(8)+o("moon",0,14,.7)+o("crown",0,-50,.5)),
    ("eclipse_fang","blood",o("orb",0,-30,.6)+o("moon",0,-30,.66)+o("twin",0,24,.8)),
    ("abyss_vortex","night",o("vortex",s=1.05)+o("dagger",0,0,.45,45)+star(-50,-50,16)),
    ("phantom_legion","night",o("wings",0,-10,1.05)+fan("dagger",7,150,.4,22)),
    ("midnight_execution","blood",o("ground",y=52,s=.9)+o("moon",0,-56,.5)+o("dagger",0,0,1.0,180)),
    ("shadow_sovereign","blood",o("wings",0,0,1.1)+o("mask",0,6,.62)+o("crown",0,-56,.36)),
    ("oblivion_requiem","night",rays(12)+o("vortex",s=.8,opacity=.85)+o("moon",0,0,.6)+fan("dagger",4,300,.38)),
])

add("darklord", [
    ("force","darkforce",o("scepter",-24,10,.8,20)+o("orb",30,-30,.5)+o("ray",30,-30,.5,-30)),
    ("critical_damage","royal",rays(8)+o("crown",0,-30,.66)+o("scepter",0,30,.5,0)),
    ("fire_burst","ember",o("flame",0,0,.95)+ring(.9,30)+star(40,-40,14)),
    ("summon","darkforce",o("sigil",s=1.0)+o("hand",-40,20,.42,-20)+o("hand",40,20,.42,20)+o("orb",0,-10,.36)),
    ("earthshake","royal",o("ground",y=50,s=1.0)+o("crack",0,30,.8)+o("scepter",0,-14,.72,180)),
    ("force_wave","darkforce",fan("ray",3,70,.6,20)+o("scepter",0,40,.5)),
    ("electric_spike","storm",o("spear",0,0,.85,180)+o("bolt",-34,-10,.6)+o("bolt",36,8,.5)),
    ("fire_scream","ember",o("flame",-30,10,.7)+o("flame",30,10,.7)+o("skull",0,-20,.48)),
    ("birds","darkforce",o("raven",-20,10,.6,-10)+o("raven",28,-26,.48,10)+o("raven",-24,-40,.4,-20)),
    ("chaos_strike","darkforce",o("slash",s=.95,a=-30)+o("scepter",8,4,.86,-40)),
    ("iron_defense","royal",o("shield",0,6,.92)+o("crown",0,-56,.4)),
    ("commanders_aura","royal",rays(10)+o("crown",0,-10,.72)+o("wings",0,10,.8,0,.6)),
    ("fire_blast","ember",o("meteor",0,0,.85,-30)+o("scepter",-40,40,.45,40)),
    ("plasma_storm","storm",o("cloud",0,-40,.9)+o("bolt",-30,20,.5)+o("bolt",10,26,.55)+o("bolt",40,14,.45)),
    ("chaotic_diseier","darkforce",fan("ray",6,140,.48,10)+o("orb",0,10,.42)),
    ("royal_crush","royal",o("scepter",0,-6,.95,180)+o("ground",y=58,s=.8)+star(-40,40,16)),
    ("thunder_lord","storm",o("crown",0,-56,.38)+o("bolt",0,10,.9)+ring(.8,40)),
    ("dark_comet","darkforce",o("meteor",0,0,1.0,30)+o("orb",30,30,.32)),
    ("lord_of_command","royal",o("crown",0,-40,.6)+o("shield",0,20,.6)+o("scepter",-46,20,.42,20)+o("scepter",46,20,.42,-20)),
    ("infernal_scream","ember",ring(1.0)+o("flame",0,10,.9)+o("skull",0,-36,.42)+rays(6)),
    ("chaos_sovereign","darkforce",o("vortex",s=.9,opacity=.8)+o("scepter",0,0,1.0,-20)+star(44,-44,16)),
    ("raven_storm","darkforce",o("vortex",s=.85,opacity=.6)+o("raven",0,-20,.6)+o("raven",-36,24,.42,-30)+o("raven",38,22,.42,30)),
    ("earth_dominion","royal",o("ground",y=46,s=1.04)+o("crack",0,26,.9)+o("crown",0,-46,.5)),
    ("emperors_command","royal",o("wings",0,0,1.1)+o("crown",0,-20,.6)+o("scepter",0,36,.42)),
    ("imperial_judgment","royal",rays(12)+o("crown",0,-50,.5)+o("bolt",-34,10,.5)+o("flame",34,14,.5)+o("orb",0,10,.42)),
])

add("bard", [
    ("staccato_shot", "melody", o("note", -10, 6, .8, -15) + o("ray", 34, -26, .45, 40) + star(40, -50, 12)),
    ("valor_march", "melody", o("boot", -14, 26, .55) + o("notes", 22, -30, .6, 10) + o("note", -46, -40, .4, -20)),
    ("resonance", "melody", ring(1.0, 34) + ring(.72, 34) + o("lute", 0, -10, .82, -24)),
    ("sorrow_note", "lament", o("drop", -38, -34, .4) + o("note", 8, 10, .82, -10) + o("drop", 46, 34, .3)),
    ("discord", "dissonance", o("note", -20, 0, .78, 25) + o("crack", 30, 10, .62, -10) + o("note", 40, -46, .36, -40, .7)),
    ("iron_ballad", "gold", o("shield", 0, 8, .9) + o("lyre", 0, 4, .46)),
    ("triad_chord", "melody", line("M-70 40 Q0 -20 70 40", "url(#light)", 4) + o("note", -46, 16, .5, -24) + o("note", 0, -10, .56) + o("note", 46, 16, .5, 24)),
    ("echo_chain", "frost", chain() + o("note", -54, -44, .36) + o("note", 0, 0, .38, 10) + o("note", 52, 40, .36, -10)),
    ("war_drum", "earth", o("ground", y=52, s=.9) + o("drum", 0, -8, .78) + o("crack", 0, 52, .5)),
    ("heartstring", "melody", line("M-80 62 L80 -62", "url(#light)", 4) + o("heart", 0, 6, .8) + o("note", 24, -16, .5, 30)),
    ("virtuoso", "melody", rays(10) + o("treble", 0, 2, .78) + star(44, -46, 16)),
    ("heroic_anthem", "gold", rays(12) + o("notes", 0, 10, .7) + o("orb", 0, -56, .32)),
    ("slumber_lullaby", "frost", o("moon", -18, -8, .8) + o("note", 42, -36, .38, 20) + o("note", 46, 26, .32, -10) + star(-50, -52, 10)),
    ("lament", "lament", o("cloud", 0, -46, .8) + o("drop", -40, 30, .32) + o("drop", 40, 30, .32) + o("note", 0, 34, .5, -15)),
    ("cascade", "melody", wind() + o("note", -50, -40, .36, -30) + o("note", -14, -10, .4, -10) + o("note", 22, 20, .42, 10) + o("note", 56, 48, .36, 30)),
    ("sanctuary_serenade", "gold", rays(8) + o("chalice", 0, 22, .7) + o("lyre", 0, -42, .42)),
    ("fortissimo", "melody", rays(12) + ring(.7, 0) + o("notes", 0, 0, .62, -8)),
    ("shattering_rhapsody", "storm", o("stave", 0, 0, 1.0) + o("bolt", 0, -4, .7)),
    ("maestro_fervor", "gold", o("flame", 0, 10, .8) + o("treble", 0, 6, .5) + star(42, -50, 14)),
    ("grand_dissonance", "dissonance", rays(8) + o("lyre", 0, 0, .84) + o("crack", 0, 4, .9)),
    ("aria_of_ruin", "melody", o("ray", 0, -10, .9) + o("treble", -30, 10, .58, -10) + star(38, 40, 16)),
    ("eternal_echo", "frost", ring(1.0) + o("note", 70, 0, .28) + o("note", 49, 33, .28) + o("note", 0, 46, .28) + o("note", -49, 33, .28)
                                         + o("note", -70, 0, .28) + o("note", -49, -33, .28) + o("note", 0, -46, .28) + o("note", 49, -33, .28)),
    ("thunder_crescendo", "storm", o("drum", 0, 22, .66) + o("bolt", -42, -36, .46) + o("bolt", 42, -36, .46, 10)),
    ("hymn_of_legends", "gold", rays(12) + o("lyre", 0, 12, .66) + o("crown", 0, -54, .38)),
    ("grand_finale", "melody", o("ground", y=60, s=.9) + o("ray", -50, -12, .5, -20) + o("ray", 50, -12, .5, 20) + o("lyre", 0, -4, .72) + star(0, -70, 12)),
])

# Star skills keep their own medallions beside the class catalogue (not part of its manifest).
STAR_RECIPES = {
    "umbral_lacerate": ("night", o("moon",0,-10,.9)+o("slash",0,0,.9,30)+o("slash",0,0,.9,210)+o("twin",0,20,.6)),
    "shadow_execution": ("blood", rays(10)+o("moon",0,-30,.6)+o("dagger",0,10,1.0,180)+star(-46,44,18)),
    "veil_of_night": ("night", o("wings",0,-10,.9,0,.5)+o("smoke",0,30,1.0)+o("mask",0,0,.55)+o("moon",-20,-46,.4)),
    "eclipse_requiem": ("night", o("ground",y=58,s=.85)+o("orb",0,-54,.48)+o("moon",0,-54,.54)+rain("dagger",4,.42)),
    "chaos_inferno": ("ember", o("ground",y=56,s=.9)+o("flame",-34,10,.6)+o("flame",34,10,.6)+o("scepter",0,0,.8,180)),
    "raven_sovereign": ("darkforce", rays(10)+o("raven",0,-6,.95)+o("crown",0,-56,.34)),
    "lords_dominion": ("royal", o("wings",0,0,1.0,0,.6)+o("crown",0,-20,.7)+o("shield",-40,30,.42)+o("shield",40,30,.42)),
    "imperial_cataclysm": ("royal", o("ground",y=58,s=.85)+o("crown",0,-56,.42)+rain("bolt",3,.5)+o("flame",0,30,.5)),
    "starlight_overture": ("melody", rays(10) + star(-40, -32, 16) + star(36, -46, 12) + star(8, 18, 14) + o("note", -14, 36, .4) + o("note", 46, 10, .34)),
    "heartbreak_sonata": ("melody", o("heart", 0, 0, .8) + o("stave", 0, 0, .8) + o("crack", 0, 0, .5)),
    "celestial_stage": ("gold", o("wings", 0, -10, .9, 0, .5) + o("ground", y=58, s=.9) + o("lyre", 0, -10, .8)),
    "cosmic_encore": ("dissonance", ring(.9, 40) + o("orb", -46, -46, .3) + o("orb", 52, 38, .22) + o("wings", 0, -6, .95) + o("lute", 0, -2, .58, -20)),
}

# God-tier (300-star) skills: the star medallion with a divine frame (document(god=True)).
GOD_RECIPES = {
    "divine_edict": ("god_ember", o("ground", y=62, s=.86) + o("crown", 0, -64, .4) + o("sword", 0, 4, 1.18, 180) + star(-48, 36, 15) + star(48, 36, 15)),
    "sunfall_volley": ("god_lime", rays(16) + o("orb", 0, -44, .52) + rain("arrow", 3, .5) + o("ground", y=64, s=.8)),
    "heavenrend_spear": ("god_cyan", o("cloud", 0, -60, .74) + o("crack", 0, 56, .72) + o("spear", 0, 4, 1.22, 180) + o("bolt", -50, -6, .42, -10) + o("bolt", 50, -6, .42, 10)),
    "astral_apocalypse": ("god_cosmos", group(ring(1.05), rotate=-28) + group(ring(.82), rotate=34) + o("orb", 0, 0, .5) + o("meteor", -46, -50, .36, 30) + star(50, 46, 14)),
    "seraphic_judgment": ("god_holy", rays(16) + o("wings", 0, -10, 1.16) + o("cross", 0, 6, .58) + o("orb", 0, -64, .24)),
    "celestial_dragon_emperor": ("god_jade", o("vortex", s=1.0, opacity=.55) + o("dragon", 0, 6, .92) + o("crown", 0, -64, .36)),
    "pantheon_bastion": ("god_azure", o("wings", 0, -8, 1.12, 0, .6) + o("shield", 0, 8, .92) + o("crown", 0, -68, .34) + star(-56, 52, 12) + star(56, 52, 12)),
    "death_gods_eclipse": ("god_blood", rays(12) + o("orb", 6, -30, .56) + o("moon", -4, -30, .62) + o("twin", 0, 34, .72)),
    "abyssal_throne": ("god_abyss", o("flame", 0, 44, .62) + o("crown", 0, -50, .62) + o("scepter", -44, 14, .6, -16) + o("bolt", 46, 12, .5, 10)),
    "divine_symphony": ("god_rose", rays(16) + o("lyre", 0, 4, .8) + o("crown", 0, -70, .3) + o("note", -54, -36, .34, -15) + o("note", 54, -36, .34, 15)),
}


def document(palette, picture, god=False):
    dark, mid, main, light = PALETTES[palette]
    defs = f'''<defs>
    <radialGradient id="back" cx=".38" cy=".25" r=".85"><stop stop-color="#{mid}"/><stop offset=".72" stop-color="#{dark}"/><stop offset="1" stop-color="#0c1328"/></radialGradient>
    <linearGradient id="main" x2=".8" y2="1"><stop stop-color="#{light}"/><stop offset=".38" stop-color="#{main}"/><stop offset="1" stop-color="#{mid}"/></linearGradient>
    <linearGradient id="light" x2=".5" y2="1"><stop stop-color="#ffffff"/><stop offset="1" stop-color="#{light}"/></linearGradient>
    <linearGradient id="metal" x2=".8" y2="1"><stop stop-color="#ffffff"/><stop offset=".36" stop-color="#d9edf3"/><stop offset="1" stop-color="#{main}"/></linearGradient>
    <linearGradient id="gold" x2=".4" y2="1"><stop stop-color="#fff5cb"/><stop offset=".4" stop-color="#efd18a"/><stop offset="1" stop-color="#a67643"/></linearGradient>
    <linearGradient id="rock" x2=".6" y2="1"><stop stop-color="#66566c"/><stop offset="1" stop-color="#252039"/></linearGradient>
    <radialGradient id="orb" cx=".32" cy=".23" r=".85"><stop stop-color="#ffffff"/><stop offset=".3" stop-color="#{light}"/><stop offset=".58" stop-color="#{main}"/><stop offset="1" stop-color="#{mid}"/></radialGradient>
    <linearGradient id="main_stroke" gradientUnits="userSpaceOnUse" x1="-64" y1="-80" x2="64" y2="80"><stop stop-color="#{light}"/><stop offset="1" stop-color="#{main}"/></linearGradient>
    <linearGradient id="light_stroke" gradientUnits="userSpaceOnUse" x1="-64" y1="-80" x2="64" y2="80"><stop stop-color="#ffffff"/><stop offset="1" stop-color="#{light}"/></linearGradient>
    <linearGradient id="gold_stroke" gradientUnits="userSpaceOnUse" x1="-64" y1="-80" x2="64" y2="80"><stop stop-color="#fff5cb"/><stop offset="1" stop-color="#d6ac60"/></linearGradient>
    <clipPath id="disc"><circle cx="128" cy="128" r="121"/></clipPath>
    </defs>'''
    body = '<circle cx="128" cy="128" r="123" fill="#101a30"/>'
    body += '<circle cx="128" cy="128" r="119" fill="url(#back)" stroke="url(#gold)" stroke-width="3"/>'
    body += f'<g clip-path="url(#disc)"><path d="M32 198 L172 13 L226 48 L74 233Z" fill="#{main}" opacity=".065"/>'
    body += '<ellipse cx="128" cy="208" rx="73" ry="14" fill="#081329" opacity=".35"/>'
    if god:
        # A divine aureole behind the picture: a gold ring and its long and short rays.
        body += group(rays(24), 128, 124, 1.12, 7.5, .42)
        body += f'<circle cx="128" cy="124" r="92" fill="none" stroke="#{light}" stroke-width="2.5" opacity=".55"/>'
    body += group(picture,128,124)
    body += group(star(0,0,6),44,74,opacity=.5) + group(star(0,0,4),210,162,opacity=.65)
    body += '</g><path d="M30 100 A101 101 0 0 1 115 25" fill="none" stroke="#ffefc5" stroke-width="2" opacity=".48"/>'
    if god:
        # The god frame: a second gold rim and eight gems round it.
        body += '<circle cx="128" cy="128" r="113" fill="none" stroke="url(#gold_stroke)" stroke-width="3" opacity=".9"/>'
        body += "".join(group(star(0, 0, 7), 128 + 113 * sin(i * pi / 4), 128 - 113 * cos(i * pi / 4)) for i in range(8))
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192" viewBox="0 0 256 256">{defs}{body}</svg>\n'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    source = (ROOT / 'data/class_data.gd').read_text()
    # Both regular and summon helpers are the actual runtime catalogue source.
    catalogue = re.findall(r'(?:_sk\(\w+,|sm\.call\()\s*"([a-z_]+)",\s*"([^"]+)"', source)
    assert len(catalogue) == 252, len(catalogue)
    assert set(RECIPES) == {s[0] for s in catalogue}, (set(RECIPES) ^ {s[0] for s in catalogue})
    scenes = [r[2] for r in RECIPES.values()]
    assert len(set(scenes)) == 252, "Duplicate illustration even before colors/backgrounds"
    names = dict(catalogue)
    manifest = []
    for skill, (family, palette, picture) in RECIPES.items():
        svg = document(palette,picture)
        (OUT / f'{skill}.svg').write_text(svg)
        manifest.append({'id':skill,'name':names[skill],'family':family,'palette':palette,
                         'art_sha256':hashlib.sha256(picture.encode()).hexdigest()})
    (ROOT / 'tools/skill_icon_catalogue.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for skill, (palette, picture) in STAR_RECIPES.items():
        (OUT / f'{skill}.svg').write_text(document(palette,picture))
    for skill, (palette, picture) in GOD_RECIPES.items():
        (OUT / f'{skill}.svg').write_text(document(palette,picture,god=True))
    print(f'Authored {len(manifest)} distinct skill illustrations; {sum(p.stat().st_size for p in OUT.glob("*.svg")):,} SVG bytes.')


if __name__ == '__main__':
    main()
