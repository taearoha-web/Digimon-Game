#!/usr/bin/env python3
"""Packages the Godot Web export for static hosts with small file-size limits.

Takes the export in build/web/ (made with the "Web" preset) and writes
build/web_artifact/ with:
  index.html          our own shell (tools/web/artifact_shell.html)
  index.js, index.audio.worklet.js   Godot's loader (unchanged)
  engine.gz.wasm, game.gz.wasm       gzip copies of index.wasm / index.pck,
                                     inflated in the browser (".wasm" only so
                                     hosts with a file-type allowlist serve them)

The shell intercepts Godot's fetch() of index.wasm / index.pck and serves the
inflated data, so no server-side compression or special headers are needed.

With --pages DIR it also writes a standalone site (full HTML document with a
web-app manifest and iOS home-screen tags) for GitHub Pages, e.g. docs/play.
Opened from an iPhone home-screen icon it runs fullscreen.

Usage:
  godot --headless --path . --export-release "Web" build/web/index.html
  python3 tools/package_web.py [--pages docs/play]
"""
import gzip
import json
import os
import re
import shutil
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "build", "web")
OUT = os.path.join(ROOT, "build", "web_artifact")
SHELL = os.path.join(ROOT, "tools", "web", "artifact_shell.html")
NOTE_ARTIFACT = "บน iPhone หน้านี้ขยายเต็มจอไม่ได้ (ข้อจำกัดของ Apple) · หมุนเครื่องเป็นแนวนอนเพื่อให้เห็นเกมมากที่สุด"
NOTE_PAGES = "iPhone: กดปุ่มแชร์ → \"เพิ่มไปยังหน้าจอโฮม\" แล้วเปิดเกมจากไอคอน จะเล่นได้เต็มจอ"
TITLE = "Toon Tale"
PACKED = {  # Godot file -> (published gzip name, MIME of the inflated data)
    "index.wasm": ("engine.gz.wasm", "application/wasm"),
    "index.pck": ("game.gz.wasm", "application/octet-stream"),
}


def project_version() -> str:
    with open(os.path.join(ROOT, "project.godot"), encoding="utf-8") as f:
        m = re.search(r'^config/version="([^"]+)"', f.read(), re.M)
    return m.group(1) if m else "0"


def main() -> None:
    with open(os.path.join(SRC, "index.html"), encoding="utf-8") as f:
        exported = f.read()
    config = json.loads(re.search(r"const GODOT_CONFIG = (\{.*?\});", exported).group(1))
    # Canvas follows the window size; skip the cross-origin-isolation service
    # worker (single-threaded build, and hosts may not allow service workers).
    config["canvasResizePolicy"] = 2
    config["ensureCrossOriginIsolationHeaders"] = False

    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT)
    for name in ("index.js", "index.audio.worklet.js"):
        shutil.copy(os.path.join(SRC, name), os.path.join(OUT, name))

    packed = {}
    for name, (out_name, mime) in PACKED.items():
        with open(os.path.join(SRC, name), "rb") as f:
            data = f.read()
        with open(os.path.join(OUT, out_name), "wb") as f:
            f.write(gzip.compress(data, compresslevel=9, mtime=0))
        packed[name] = [out_name, os.path.getsize(os.path.join(OUT, out_name)), mime]

    total = sum(p[1] for p in packed.values())
    with open(SHELL, encoding="utf-8") as f:
        shell = f.read()
    shell = (shell.replace("__GODOT_CONFIG__", json.dumps(config))
             .replace("__PACKED__", json.dumps(packed))
             .replace("__TOTAL_MB__", "%.0f" % (total / 1048576))
             .replace("__VERSION__", project_version()))
    with open(os.path.join(OUT, "index.html"), "w", encoding="utf-8") as f:
        f.write(shell.replace("__FULLSCREEN_NOTE__", NOTE_ARTIFACT))

    for name in sorted(os.listdir(OUT)):
        print("%-24s %8.1f KB" % (name, os.path.getsize(os.path.join(OUT, name)) / 1024))
    print("total download: %.1f MB" % (total / 1048576))

    if "--pages" in sys.argv:
        pages_dir = os.path.join(ROOT, sys.argv[sys.argv.index("--pages") + 1])
        write_pages_site(pages_dir, shell.replace("__FULLSCREEN_NOTE__", NOTE_PAGES))
        print("GitHub Pages site written to", os.path.relpath(pages_dir, ROOT))


def write_pages_site(pages_dir: str, shell: str) -> None:
    """Standalone site: full document + manifest + icons (installable, fullscreen)."""
    shutil.rmtree(pages_dir, ignore_errors=True)
    shutil.copytree(OUT, pages_dir)
    shutil.copy(os.path.join(SRC, "index.apple-touch-icon.png"), os.path.join(pages_dir, "apple-touch-icon.png"))
    shutil.copy(os.path.join(SRC, "index.icon.png"), os.path.join(pages_dir, "icon.png"))
    manifest = {
        "name": TITLE,
        "short_name": "Tamer",
        "start_url": ".",
        "scope": ".",
        "display": "fullscreen",
        "orientation": "landscape",
        "background_color": "#0c1230",
        "theme_color": "#0c1230",
        "icons": [
            {"src": "icon.png", "sizes": "128x128", "type": "image/png"},
            {"src": "apple-touch-icon.png", "sizes": "180x180", "type": "image/png"},
        ],
    }
    with open(os.path.join(pages_dir, "manifest.webmanifest"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    # The shell starts with <title>/<link>/<style>; those go into <head>.
    split = shell.index("<canvas")
    head = (
        '<!doctype html>\n<html lang="th">\n<head>\n'
        '<meta charset="utf-8">\n'
        # Cover the whole screen (otherwise a home-screen app on iPhone is
        # shifted down and clipped); the game keeps its buttons clear of the
        # notch using the safe-area insets (window.godotSafeArea).
        '<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no, viewport-fit=cover">\n'
        '<meta name="apple-mobile-web-app-capable" content="yes">\n'
        '<meta name="mobile-web-app-capable" content="yes">\n'
        '<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">\n'
        '<meta name="apple-mobile-web-app-title" content="Tamer">\n'
        '<meta name="theme-color" content="#0c1230">\n'
        '<link rel="manifest" href="manifest.webmanifest">\n'
        '<link rel="apple-touch-icon" href="apple-touch-icon.png">\n'
        '<link rel="icon" href="icon.png">\n'
        '<style>body{margin:0}[hidden]{display:none!important}</style>\n'
    )
    page = head + shell[:split] + "</head>\n<body>\n" + shell[split:] + "\n</body>\n</html>\n"
    with open(os.path.join(pages_dir, "index.html"), "w", encoding="utf-8") as f:
        f.write(page)


if __name__ == "__main__":
    main()
