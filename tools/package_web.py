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

Usage:
  godot --headless --path . --export-release "Web" build/web/index.html
  python3 tools/package_web.py
"""
import gzip
import json
import os
import re
import shutil

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "build", "web")
OUT = os.path.join(ROOT, "build", "web_artifact")
SHELL = os.path.join(ROOT, "tools", "web", "artifact_shell.html")
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
        f.write(shell)

    for name in sorted(os.listdir(OUT)):
        print("%-24s %8.1f KB" % (name, os.path.getsize(os.path.join(OUT, name)) / 1024))
    print("total download: %.1f MB" % (total / 1048576))


if __name__ == "__main__":
    main()
