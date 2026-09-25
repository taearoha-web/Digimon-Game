#!/usr/bin/env python3
"""Writes the original placeholder item icons (SVG) into assets/icons/items/.

Each icon is a simple hand-designed vector shape; replace any file with final
art using the same file name (see docs/ASSET_REPLACEMENT.md).
"""
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons", "items")
HEAD = '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">'
BG = '<circle cx="48" cy="48" r="44" fill="{bg}" opacity="0.28"/>'

ICONS = {
    "small_patch": ("#5ad17a", '<rect x="22" y="30" width="52" height="36" rx="12" fill="#5ad17a" stroke="#eafff0" stroke-width="4"/>'
                    '<path d="M48 38v20M38 48h20" stroke="#ffffff" stroke-width="7" stroke-linecap="round"/>'),
    "medium_patch": ("#34b8f0", '<rect x="16" y="24" width="64" height="48" rx="14" fill="#34b8f0" stroke="#e6f8ff" stroke-width="4"/>'
                     '<path d="M48 34v28M34 48h28" stroke="#ffffff" stroke-width="8" stroke-linecap="round"/>'),
    "sp_capsule": ("#8a6bff", '<rect x="18" y="34" width="60" height="28" rx="14" fill="#8a6bff" stroke="#efe9ff" stroke-width="4"/>'
                   '<rect x="48" y="36" width="28" height="24" rx="12" fill="#c7b8ff"/>'
                   '<path d="M40 38l-6 11h8l-5 10" fill="none" stroke="#ffffff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>'),
    "reboot_chip": ("#ffc93c", '<g stroke="#ffe7a3" stroke-width="4" stroke-linecap="round"><path d="M34 18v10M48 18v10M62 18v10M34 68v10M48 68v10M62 68v10M18 34h10M18 48h10M18 62h10M68 34h10M68 48h10M68 62h10"/></g>'
                    '<rect x="26" y="26" width="44" height="44" rx="8" fill="#ffc93c" stroke="#fff4d6" stroke-width="3"/>'
                    '<path d="M58 44a11 11 0 1 1-4-8" fill="none" stroke="#7a5200" stroke-width="5" stroke-linecap="round"/><path d="M56 30l0 8-8 0" fill="none" stroke="#7a5200" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>'),
    "full_recovery_disk": ("#ff7aa2", '<circle cx="48" cy="48" r="30" fill="#ff7aa2" stroke="#ffe6ee" stroke-width="4"/><circle cx="48" cy="48" r="8" fill="#ffe6ee"/>'
                           '<path d="M48 22v10M48 64v10M22 48h10M64 48h10" stroke="#ffffff" stroke-width="5" stroke-linecap="round"/>'),
    "friend_treat": ("#ff9a3d", '<circle cx="48" cy="50" r="28" fill="#e98c3a" stroke="#ffe2c4" stroke-width="4"/>'
                     '<g fill="#6b3a12"><circle cx="38" cy="42" r="4"/><circle cx="56" cy="40" r="4"/><circle cx="48" cy="56" r="4"/><circle cx="60" cy="58" r="3"/><circle cx="36" cy="60" r="3"/></g>'
                     '<path d="M40 24c4-6 12-6 16 0" fill="none" stroke="#ff5a6e" stroke-width="4" stroke-linecap="round"/>'),
    "evo_shard": ("#34e0ff", '<path d="M48 12L70 40L48 84L26 40Z" fill="#34e0ff" stroke="#e6fbff" stroke-width="4" stroke-linejoin="round"/>'
                  '<path d="M26 40h44M48 12l-8 28 8 44 8-44z" fill="none" stroke="#ffffff" stroke-width="2.5" stroke-linejoin="round" opacity="0.8"/>'),
    "data_fragment": ("#35d6ff", '<path d="M48 16l28 14v32L48 78 20 62V30z" fill="#1d8fd1" stroke="#e6fbff" stroke-width="4" stroke-linejoin="round"/>'
                      '<path d="M20 30l28 14 28-14M48 44v34" fill="none" stroke="#9cefff" stroke-width="3.5" stroke-linejoin="round"/>'
                      '<text x="36" y="40" font-size="12" font-family="monospace" fill="#ffffff">01</text>'),
    "training_badge": ("#ffc93c", '<circle cx="48" cy="44" r="26" fill="#ffc93c" stroke="#fff4d6" stroke-width="4"/>'
                       '<path d="M36 66l-6 20 18-8 18 8-6-20" fill="#ff7a3d" stroke="#ffe0c7" stroke-width="3" stroke-linejoin="round"/>'
                       '<path d="M48 30l4.5 9 10 1.4-7.2 7 1.7 9.9L48 52.6l-9 4.7 1.7-9.9-7.2-7 10-1.4z" fill="#ffffff"/>'),
    "gate_pass": ("#e36bff", '<rect x="14" y="26" width="68" height="44" rx="10" fill="#b44ee0" stroke="#fbe8ff" stroke-width="4"/>'
                  '<circle cx="34" cy="48" r="9" fill="none" stroke="#ffffff" stroke-width="4"/><path d="M43 48h26M61 48v8M67 48v6" stroke="#ffffff" stroke-width="4" stroke-linecap="round"/>'),
}

os.makedirs(OUT, exist_ok=True)
for name, (bg, body) in ICONS.items():
    with open(os.path.join(OUT, name + ".svg"), "w") as f:
        f.write(HEAD + BG.format(bg=bg) + body + "</svg>\n")
print("wrote", len(ICONS), "item icons")
