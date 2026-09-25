#!/usr/bin/env python3
"""Collects every player-facing English string (the translation keys).

Sources:
  * GDScript string literals in gameplay/UI folders (developer-only lines such
    as push_warning/print are skipped, as are ids, paths and node names)
  * text fields of data resources in res://data (names, descriptions,
    dialogue, quests, NPCs, shops, maps, customization options...)
  * display names placed in zone scenes (area triggers, signposts)
  * element names from the type chart ("fire" -> "Fire")

Usage:
  python3 tools/i18n_extract.py            # print keys missing from i18n/th.po
  python3 tools/i18n_extract.py --all      # print every key
Exit code 1 when translations are missing (used as a check).
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
CODE_DIRS = ["ui", "scenes", "systems", "characters", "maps", "digimon", "vfx"]
# Files that only contain ids, mesh-part names, colours and animation names.
SKIP_FILES = {
    "placeholder_digimon_factory.gd", "procedural_animator.gd", "chibi_avatar.gd",
    "starter_zone_builder.gd", "data_forest_builder.gd", "zone_builder_base.gd",
    "audio_manager.gd", "data_registry.gd", "input_setup.gd", "l10n.gd",
}
DEV_LINE = re.compile(r"push_warning|push_error|printerr|print\(|print_verbose|assert\(|@export_file|@export_group|"
                      r"@export_category|@export_subgroup|get_node|has_node|find_child|add_to_group|is_in_group|"
                      r"\.name = |set_meta|get_meta|has_meta|load\(|preload\(|connect\(\"|emit_signal")
LITERAL = re.compile(r'(?<![&^\w])"((?:[^"\\]|\\.)*)"')
DATA_FIELDS = re.compile(r'^(display_name|description|digimon_type|hint|title|summary|text|speaker|greeting) = "((?:[^"\\]|\\.)*)"', re.M)
DATA_DICT_NAME = re.compile(r'"name": "((?:[^"\\]|\\.)*)"')
TAGLINE = re.compile(r'^"\w+": "((?:[^"\\]|\\.)*)",?$', re.M)
SCENE_FIELDS = re.compile(r'^(display_name|title) = "((?:[^"\\]|\\.)*)"', re.M)


def unescape(s: str) -> str:
    return s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8") if "\\" in s else s


def is_ui_text(t: str) -> bool:
    if not re.search(r"[A-Za-z]", unescape(t)):
        return False
    if t.startswith(("res://", "user://")) or "://" in t:
        return False
    if re.fullmatch(r"[a-z0-9_./:%\-]+", t):          # ids, paths, sfx names
        return False
    if re.fullmatch(r"[A-Za-z0-9_]+(/[A-Za-z0-9_%]+)+", t):  # node paths
        return False
    if re.fullmatch(r"\*\.\w+", t):                      # file filters
        return False
    if re.fullmatch(r"[0-9a-fA-F]{6}", t):               # hex colours
        return False
    if re.fullmatch(r"[A-Z][A-Za-z0-9]*(_%?[a-z%]+)+", t):  # generated node names
        return False
    return True


def code_strings() -> dict:
    found = {}
    for d in CODE_DIRS:
        for dp, _, files in os.walk(os.path.join(ROOT, d)):
            for f in files:
                if not f.endswith(".gd") or f in SKIP_FILES:
                    continue
                path = os.path.join(dp, f)
                rel = os.path.relpath(path, ROOT)
                for n, line in enumerate(open(path, encoding="utf-8"), 1):
                    stripped = line.strip()
                    if stripped.startswith("#") or DEV_LINE.search(line):
                        continue
                    for m in LITERAL.finditer(line):
                        t = m.group(1)
                        after = line[m.end():m.end() + 2]
                        if after.startswith(":") and " " not in t:
                            continue  # dictionary key
                        if is_ui_text(t):
                            found.setdefault(unescape(t), "%s:%d" % (rel, n))
    return found


def data_strings() -> dict:
    found = {}
    for dp, _, files in os.walk(os.path.join(ROOT, "data")):
        for f in files:
            if not f.endswith(".tres"):
                continue
            path = os.path.join(dp, f)
            rel = os.path.relpath(path, ROOT)
            src = open(path, encoding="utf-8").read()
            for m in DATA_FIELDS.finditer(src):
                if m.group(2).strip() and not re.fullmatch(r"\{\w+\}", m.group(2)):
                    found.setdefault(unescape(m.group(2)), rel)
            if "customization_catalog" in f:
                for m in DATA_DICT_NAME.finditer(src):
                    found.setdefault(unescape(m.group(1)), rel)
            if "starter_roster" in f:
                for m in TAGLINE.finditer(src):
                    found.setdefault(unescape(m.group(1)), rel)
            if "type_chart" in f:
                for m in re.finditer(r'^"(\w+)": \{', src, re.M):
                    found.setdefault(m.group(1).capitalize(), rel)
    for dp, _, files in os.walk(os.path.join(ROOT, "maps")):
        for f in files:
            if f.endswith(".tscn"):
                path = os.path.join(dp, f)
                for m in SCENE_FIELDS.finditer(open(path, encoding="utf-8").read()):
                    found.setdefault(unescape(m.group(2)), os.path.relpath(path, ROOT))
    return found


def po_keys(path: str) -> set:
    keys = set()
    if not os.path.exists(path):
        return keys
    text = open(path, encoding="utf-8").read()
    for block in text.split("\n\n"):
        m = re.search(r'^msgid ((?:".*"\n?)+)', block, re.M)
        s = re.search(r'^msgstr ((?:".*"\n?)+)', block, re.M)
        if not m or not s:
            continue
        msgid = "".join(re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1)))
        msgstr = "".join(re.findall(r'"((?:[^"\\]|\\.)*)"', s.group(1)))
        if msgid and msgstr:
            keys.add(unescape(msgid))
    return keys


def main() -> int:
    keys = {}
    keys.update(code_strings())
    keys.update(data_strings())
    ignore_path = os.path.join(ROOT, "i18n", "untranslated.txt")
    ignore = set()
    if os.path.exists(ignore_path):
        ignore = {l.rstrip("\n").replace("\\n", "\n") for l in open(ignore_path, encoding="utf-8") if l.strip() and not l.startswith("#")}
    if "--all" in sys.argv:
        for k, where in sorted(keys.items(), key=lambda kv: kv[1]):
            print("%s\t%s" % (where, k.replace("\n", "\\n")))
        return 0
    translated = po_keys(os.path.join(ROOT, "i18n", "th.po"))
    missing = {k: w for k, w in keys.items() if k not in translated and k not in ignore}
    for k, where in sorted(missing.items(), key=lambda kv: kv[1]):
        print("%s\t%s" % (where, k.replace("\n", "\\n")))
    print("%d keys, %d missing" % (len(keys), len(missing)), file=sys.stderr)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
