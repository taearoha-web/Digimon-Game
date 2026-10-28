#!/usr/bin/env python3
"""Packages the Godot Web export for static hosts with small file-size limits.

Takes the export in build/web/ (made with the "Web" preset) and writes
build/web_artifact/ with:
  index.html          our own shell (tools/web/artifact_shell.html)
  index.js, index.audio.worklet.js   Godot's loader (mobile keyboard compatibility)
  engine.*.gz.wasm, game.*.gz.wasm   gzip copies of index.wasm / index.pck,
                                     inflated in the browser (".wasm" only so
                                     hosts with a file-type allowlist serve them)
                                     Large gzip streams are split into ordered
                                     parts, each no larger than 16 MiB.

The shell intercepts Godot's fetch() of index.wasm / index.pck and serves the
inflated data, so no server-side compression or special headers are needed.

With --pages DIR it also writes a standalone site (full HTML document with a
web-app manifest and iOS home-screen tags) for GitHub Pages, e.g. docs/play.
Opened from an iPhone home-screen icon it runs fullscreen.

The site is an installable, fully offline web app: sw.js (tools/web/sw.js
with this build's id and file list baked in) caches every file needed to boot
and play in one cache per build, and tools/web/offline.js fills that cache in
the background and offers new builds. A _headers file gives Cloudflare the
cache policy (sw.js / the page always revalidate; content-named files are
immutable); hosting/accounts/server/static.js applies the same policy when the
Worker serves a file itself.

Usage:
  godot --headless --path . --export-release "Web" build/web/index.html
  python3 tools/package_web.py [--pages docs/play]
"""
import gzip
import hashlib
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
## Where the site is published (link previews need absolute image URLs).
PAGES_URL = "https://taearoha-web.github.io/Digimon-Game/play/"
DESCRIPTION = "Toon Tale ผจญภัย ARPG แนวการ์ตูน 10 อาชีพ เล่นบนมือถือได้ทันที ไม่ต้องติดตั้ง"
BRANDING = os.path.join(ROOT, "assets", "branding")
PACKED = {  # Godot file -> (published gzip name, MIME of the inflated data)
    "index.wasm": ("engine.gz.wasm", "application/wasm"),
    "index.pck": ("game.gz.wasm", "application/octet-stream"),
}
MAX_PART_BYTES = 16 * 1024 * 1024
# The loader's fonts, published with the page so text keeps its look offline.
# (family, file in assets/fonts, weight range the file covers)
FONTS = [
    ("Fredoka", "Fredoka-Variable.ttf", "300 700"),
    ("Mitr", "Mitr-Medium.ttf", "400 500"),
    ("Noto Sans Thai", "NotoSansThai-Variable.ttf", "100 900"),
]
SW_TEMPLATE = os.path.join(ROOT, "tools", "web", "sw.js")
THEME = "#0c1230"
## Not needed to play (link previews only); everything else is cached offline.
NOT_PRECACHED = {"index.html", "sw.js", "og.jpg", "_headers"}
## Content-addressed names: a different content always gets a different name.
CONTENT_NAMED = re.compile(r"\.[0-9a-f]{8,}\.|\?v=[0-9a-f]{8,}$")


def write_packed(data: bytes, out_name: str, output_dir: str,
                 part_bytes: int = MAX_PART_BYTES):
    """Split one gzip stream, not separately compressed files, for small hosts.

    A small export retains its existing string filename manifest format. Large
    exports use an ordered list; the browser feeds those bytes into one inflater.
    The caller includes the complete payload's content hash in every filename.
    """
    if part_bytes < 1:
        raise ValueError("part_bytes must be positive")
    compressed = gzip.compress(data, compresslevel=9, mtime=0)
    split = len(compressed) > part_bytes
    names = []
    for index, start in enumerate(range(0, len(compressed), part_bytes), 1):
        name = out_name.replace(".gz", ".part%03d.gz" % index) if split else out_name
        with open(os.path.join(output_dir, name), "wb") as f:
            f.write(compressed[start:start + part_bytes])
        names.append(name)
    return names if split else names[0], len(compressed)


def project_version() -> str:
    with open(os.path.join(ROOT, "project.godot"), encoding="utf-8") as f:
        m = re.search(r'^config/version="([^"]+)"', f.read(), re.M)
    return m.group(1) if m else "0"


def main() -> None:
    with open(os.path.join(SRC, "index.html"), encoding="utf-8") as f:
        exported = f.read()
    config = json.loads(re.search(r"const GODOT_CONFIG = (\{.*?\});", exported).group(1))
    # The shell owns a bounded backbuffer, avoiding full 3x Retina rendering.
    # CSS still fills the window; Godot maps input through its canvas rectangle.
    config["canvasResizePolicy"] = 0
    config["ensureCrossOriginIsolationHeaders"] = False

    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT)
    for name in ("index.js", "index.audio.worklet.js"):
        if name == "index.js":
            with open(os.path.join(SRC, name), encoding="utf-8") as f:
                loader = f.read()
            # Godot 4.3 assigns the nonstandard lowercase property. Use the
            # DOM inputMode property so numeric LineEdits open a number pad
            # on iPhone instead of silently falling back to a text keyboard.
            loader = loader.replace("elem.inputmode=", "elem.inputMode=")
            with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
                f.write(loader)
        else:
            shutil.copy(os.path.join(SRC, name), os.path.join(OUT, name))

    packed = {}
    build_ids = []
    for name, (out_name, mime) in PACKED.items():
        with open(os.path.join(SRC, name), "rb") as f:
            data = f.read()
        # A content hash in the file name busts browser / home-screen caches on every new build.
        digest = hashlib.sha1(data).hexdigest()[:8]
        out_name = out_name.replace(".gz", ".%s.gz" % digest)
        build_ids.append(digest)
        names, size = write_packed(data, out_name, OUT)
        packed[name] = [names, size, mime]

    total = sum(p[1] for p in packed.values())
    with open(SHELL, encoding="utf-8") as f:
        shell = f.read()
    # Version account UI assets independently of the Godot pack, so fixes also
    # reach installed home-screen apps without replacing their local saves.
    for source_name, placeholder in [("accounts.js", "__ACCOUNTS_JS__"),
                                      ("session.js", "__SESSION_JS__"),
                                      ("offline.js", "__OFFLINE_JS__"),
                                      ("accounts.css", "__ACCOUNTS_CSS__")]:
        source = os.path.join(ROOT, "tools", "web", source_name)
        with open(source, "rb") as f:
            data = f.read()
        digest = hashlib.sha256(data).hexdigest()[:12]
        name, extension = os.path.splitext(source_name)
        published_name = "%s.%s%s" % (name, digest, extension)
        with open(os.path.join(OUT, published_name), "wb") as f:
            f.write(data)
        shell = shell.replace(placeholder, published_name)
    faces = []
    for family, file_name, weights in FONTS:
        with open(os.path.join(ROOT, "assets", "fonts", file_name), "rb") as f:
            data = f.read()
        published_name = "font-%s.%s.ttf" % (re.sub(r"[^a-z0-9]+", "-", family.lower()), hashlib.sha256(data).hexdigest()[:12])
        with open(os.path.join(OUT, published_name), "wb") as f:
            f.write(data)
        faces.append('@font-face{font-family:"%s";src:url("%s") format("truetype");font-weight:%s;font-style:normal;font-display:swap}'
                     % (family, published_name, weights))
    shell = shell.replace("__FONT_FACES__", "".join(faces))
    shell = (shell.replace("__GODOT_CONFIG__", json.dumps(config))
             .replace("__PACKED__", json.dumps(packed))
             .replace("__TOTAL_MB__", "%.0f" % (total / 1048576))
             .replace("__VERSION__", "%s · build %s" % (project_version(), build_ids[-1])))
    with open(os.path.join(OUT, "index.html"), "w", encoding="utf-8") as f:
        # No service worker for the plain static copy: offline.js stays passive.
        f.write(shell.replace("__FULLSCREEN_NOTE__", NOTE_ARTIFACT).replace("__OFFLINE__", "null"))

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
    # Keep the approved home-screen artwork as the durable source. The older
    # render-based branding tool may regenerate icon_512.png, but must not replace
    # the custom illustration used for iPhone / PWA installs.
    from PIL import Image
    icon_source = os.path.join(BRANDING, "home_icon_1024.png")
    if not os.path.isfile(icon_source):
        icon_source = os.path.join(BRANDING, "icon_512.png")
    with open(icon_source, "rb") as f:
        icon_hash = hashlib.sha256(f.read()).hexdigest()[:12]
    icon = Image.open(icon_source).convert("RGB")
    if icon.width != icon.height:
        raise ValueError("Home-screen icon source must be square: " + icon_source)
    # iOS supplies its own rounded mask. Publish opaque, square PNGs and change
    # their URLs whenever the artwork changes so new installs avoid stale art.
    icon_urls = {}
    for name, size in [("icon.png", 192), ("apple-touch-icon.png", 180), ("icon-512.png", 512)]:
        icon.resize((size, size), Image.LANCZOS).save(os.path.join(pages_dir, name), optimize=True)
        icon_urls[name] = f"{name}?v={icon_hash}"
    # Maskable: Android crops icons to its own shape. Keep the art inside the
    # central 80% safe zone over a blurred, enlarged copy of itself.
    from PIL import ImageFilter
    for name, size in [("icon-maskable-192.png", 192), ("icon-maskable-512.png", 512)]:
        back = icon.resize((size, size), Image.LANCZOS).filter(ImageFilter.GaussianBlur(size / 16))
        inner = round(size * 0.8)
        back.paste(icon.resize((inner, inner), Image.LANCZOS), ((size - inner) // 2, (size - inner) // 2))
        back.save(os.path.join(pages_dir, name), optimize=True)
        icon_urls[name] = f"{name}?v={icon_hash}"
    Image.open(os.path.join(BRANDING, "og_image.png")).convert("RGB").save(os.path.join(pages_dir, "og.jpg"), quality=88, optimize=True)
    with open(os.path.join(pages_dir, "og.jpg"), "rb") as f:
        og_hash = hashlib.sha256(f.read()).hexdigest()[:12]
    manifest = {
        "id": "./",
        "name": TITLE,
        "short_name": "Toon Tale",
        "description": DESCRIPTION,
        "lang": "th",
        "dir": "ltr",
        "start_url": "./",
        "scope": "./",
        # Standalone everywhere; browsers that can (Android) hide the status bar too.
        "display": "standalone",
        "display_override": ["fullscreen", "standalone"],
        # project.godot: window/handheld/orientation=4 (sensor landscape).
        "orientation": "landscape",
        "background_color": THEME,
        "theme_color": THEME,
        "categories": ["games", "entertainment"],
        "icons": [
            {"src": icon_urls["icon.png"], "sizes": "192x192", "type": "image/png", "purpose": "any"},
            {"src": icon_urls["icon-512.png"], "sizes": "512x512", "type": "image/png", "purpose": "any"},
            {"src": icon_urls["icon-maskable-192.png"], "sizes": "192x192", "type": "image/png", "purpose": "maskable"},
            {"src": icon_urls["icon-maskable-512.png"], "sizes": "512x512", "type": "image/png", "purpose": "maskable"},
            {"src": icon_urls["apple-touch-icon.png"], "sizes": "180x180", "type": "image/png", "purpose": "any"},
        ],
    }
    manifest_text = json.dumps(manifest, ensure_ascii=False, indent=2)
    with open(os.path.join(pages_dir, "manifest.webmanifest"), "w", encoding="utf-8") as f:
        f.write(manifest_text)
    manifest_url = "manifest.webmanifest?v=" + hashlib.sha256(manifest_text.encode("utf-8")).hexdigest()[:12]
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
        '<meta name="apple-mobile-web-app-title" content="Toon Tale">\n'
        '<meta name="theme-color" content="#0c1230">\n'
        f'<link rel="manifest" href="{manifest_url}">\n'
        f'<link rel="apple-touch-icon" sizes="180x180" href="{icon_urls["apple-touch-icon.png"]}">\n'
        f'<link rel="icon" type="image/png" sizes="192x192" href="{icon_urls["icon.png"]}">\n'
        # What chat apps (LINE, Facebook, Discord...) show for a shared link.
        f'<meta name="description" content="{DESCRIPTION}">\n'
        f'<meta property="og:title" content="{TITLE}">\n'
        f'<meta property="og:description" content="{DESCRIPTION}">\n'
        '<meta property="og:type" content="website">\n'
        f'<meta property="og:url" content="{PAGES_URL}">\n'
        f'<meta property="og:image" content="{PAGES_URL}og.jpg?v={og_hash}">\n'
        '<meta property="og:image:width" content="1200">\n'
        '<meta property="og:image:height" content="630">\n'
        '<meta name="twitter:card" content="summary_large_image">\n'
        f'<meta name="twitter:image" content="{PAGES_URL}og.jpg?v={og_hash}">\n'
        '<style>body{margin:0}[hidden]{display:none!important}</style>\n'
    )
    shell = shell.replace("Your browser does not support the canvas tag.", "เบราว์เซอร์นี้เปิดเกมไม่ได้ ลองเปิดด้วย Safari หรือ Chrome")
    page = head + shell[:split] + "</head>\n<body>\n" + shell[split:] + "\n</body>\n</html>\n"
    referenced = {url.split("?")[0]: url for url in list(icon_urls.values()) + [manifest_url]}
    write_offline(pages_dir, page, referenced)


def precache_list(pages_dir: str, referenced: dict) -> list:
    """[url, bytes, content-named, core] for every published file the game needs."""
    files = [["./", 0, False, True]]
    for name in sorted(os.listdir(pages_dir)):
        if name in NOT_PRECACHED or not os.path.isfile(os.path.join(pages_dir, name)):
            continue
        url = referenced.get(name, name)
        files.append([url, os.path.getsize(os.path.join(pages_dir, name)),
                      bool(CONTENT_NAMED.search(url)), not name.endswith(".gz.wasm")])
    return files


def write_offline(pages_dir: str, page: str, referenced: dict) -> None:
    """index.html + sw.js sharing one build id, and Cloudflare's _headers."""
    files = precache_list(pages_dir, referenced)
    offline = {"build": "__BUILD__", "files": files, "total": sum(f[1] for f in files)}
    page = page.replace("__OFFLINE__", json.dumps(offline, separators=(",", ":")))
    # The build id covers every cached byte, so any change makes a new cache.
    digest = hashlib.sha256(page.encode("utf-8"))
    for url, *_ in files[1:]:
        with open(os.path.join(pages_dir, url.split("?")[0]), "rb") as f:
            digest.update(("\n%s %s" % (url, hashlib.sha256(f.read()).hexdigest())).encode("utf-8"))
    build = digest.hexdigest()[:12]
    with open(os.path.join(pages_dir, "index.html"), "w", encoding="utf-8") as f:
        f.write(page.replace("__BUILD__", build))
    with open(SW_TEMPLATE, encoding="utf-8") as f:
        worker = f.read()
    worker = (worker.replace("__BUILD__", build)
              .replace("__PRECACHE__", json.dumps(files, separators=(",", ":"))))
    with open(os.path.join(pages_dir, "sw.js"), "w", encoding="utf-8") as f:
        f.write(worker)
    # Cloudflare Workers static assets read this file (GitHub Pages ignores it).
    # Keep it in step with hosting/accounts/server/static.js.
    with open(os.path.join(pages_dir, "_headers"), "w", encoding="utf-8") as f:
        f.write(HEADERS)
    print("offline build %s: %d files, %.1f MB cached" % (build, len(files), offline["total"] / 1048576))


HEADERS = """/sw.js
  Cache-Control: no-cache, no-store, must-revalidate
  Service-Worker-Allowed: /
/
  Cache-Control: no-cache
/index.html
  Cache-Control: no-cache
/manifest.webmanifest
  Cache-Control: no-cache
/index.js
  Cache-Control: no-cache
/index.audio.worklet.js
  Cache-Control: no-cache
/*.gz.wasm
  Cache-Control: public, max-age=31536000, immutable, no-transform
/accounts.*
  Cache-Control: public, max-age=31536000, immutable
/session.*
  Cache-Control: public, max-age=31536000, immutable
/offline.*
  Cache-Control: public, max-age=31536000, immutable
/font-*
  Cache-Control: public, max-age=31536000, immutable
  Access-Control-Allow-Origin: *
"""


if __name__ == "__main__":
    main()
