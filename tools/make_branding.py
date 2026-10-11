"""Builds the game icon and link-preview image from two in-game renders.

  godot --rendering-driver opengl3 --path . res://tests/tools/tour.tscn -- <dir> warrior logo
  python3 tools/make_branding.py <dir>/04_logo_square.png <dir>/05_logo_wide.png

Writes assets/branding/icon_512.png (home-screen / favicon) and
assets/branding/og_image.png (1200x630 preview shown when the link is shared).
"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

square_src, wide_src = sys.argv[1], sys.argv[2]
OUT = "assets/branding/"
FREDOKA = "assets/fonts/Fredoka-Variable.ttf"
MITR = "assets/fonts/Mitr-Medium.ttf"


def font(path, size, bold=True):
    f = ImageFont.truetype(path, size)
    if bold:
        try:
            f.set_variation_by_axes([650])
        except Exception:
            pass
    return f


def outlined(draw, xy, text, fnt, fill, outline, width):
    draw.text(xy, text, font=fnt, fill=fill, stroke_width=width, stroke_fill=outline)


def _star(draw, cx, cy, r, fill):
    """A four-point sparkle."""
    pts = []
    for k in range(8):
        a = k * 3.14159 / 4
        rr = r if k % 2 == 0 else r * 0.28
        import math
        pts.append((cx + math.sin(a) * rr, cy - math.cos(a) * rr))
    draw.polygon(pts, fill=fill)


def wordmark(text, size):
    """The game title as a sticker: gold-to-orange gradient letters, a glossy
    top highlight, a white inner rim, a thick plum outline, a soft drop shadow
    and a sparkle on the first letter. Returns an RGBA image."""
    scale = 2
    fnt = font(FREDOKA, size * scale)
    pad = int(size * 0.5) * scale
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    x0, y0, x1, y1 = probe.textbbox((0, 0), text, font=fnt, stroke_width=int(size * 0.16) * scale)
    w, h = x1 - x0 + pad * 2, y1 - y0 + pad * 2
    org = (pad - x0, pad - y0)

    def mask(stroke):
        m = Image.new("L", (w, h), 0)
        ImageDraw.Draw(m).text(org, text, font=fnt, fill=255, stroke_width=stroke, stroke_fill=255)
        return m

    outer = mask(int(size * 0.13) * scale)
    rim = mask(int(size * 0.045) * scale)
    fill = mask(0)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (w, h), (20, 6, 40, 0))
    shadow.putalpha(outer.point(lambda v: int(v * 0.6)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.08 * scale))
    out.alpha_composite(shadow, (0, int(size * 0.07) * scale))
    out.paste((70, 22, 92, 255), (0, 0), outer)
    out.paste((255, 250, 236, 255), (0, 0), rim)
    grad = Image.new("RGBA", (w, h))
    gd = ImageDraw.Draw(grad)
    top, bottom = org[1] + y0, org[1] + y1
    for y in range(h):
        t = min(max((y - top) / max(bottom - top, 1), 0.0), 1.0)
        c = (255, int(236 - 120 * t), int(120 - 90 * t), 255)
        gd.line([(0, y), (w, y)], fill=c)
    out.paste(grad, (0, 0), fill)
    # Glossy highlight over the top half of each letter.
    gloss = Image.new("L", (w, h), 0)
    ImageDraw.Draw(gloss).rectangle((0, 0, w, top + (bottom - top) * 0.42), fill=110)
    gloss = Image.composite(gloss, Image.new("L", (w, h), 0), fill)
    out.paste((255, 255, 255, 255), (0, 0), gloss)
    sd = ImageDraw.Draw(out)
    _star(sd, org[0] + x0 + size * 0.12 * scale, top + size * 0.06 * scale, size * 0.2 * scale, (255, 255, 255, 255))
    _star(sd, org[0] + x1 - size * 0.05 * scale, bottom - size * 0.1 * scale, size * 0.11 * scale, (255, 244, 200, 255))
    return out.resize((w // scale, h // scale), Image.LANCZOS)


# Icon: the hero's face and wings, a soft vignette and a thin gold rim.
src = Image.open(square_src).convert("RGB")
w, h = src.size
side = h - 10
left = int(w * 0.5 - side * 0.5) - 25
icon = src.crop((left, 5, left + side, 5 + side)).resize((512, 512), Image.LANCZOS)
shade = Image.new("L", (512, 512), 0)
ImageDraw.Draw(shade).ellipse((-90, -60, 602, 600), fill=255)
shade = shade.filter(ImageFilter.GaussianBlur(70))
dark = Image.new("RGB", (512, 512), (14, 18, 48))
icon = Image.composite(icon, dark, shade.point(lambda v: int(70 + v * 185 / 255)))
# The title along the bottom over a soft dark band.
band = Image.new("L", (512, 512), 0)
bd = ImageDraw.Draw(band)
for y in range(300, 512):
    bd.line([(0, y), (512, y)], fill=int(min(1.0, (y - 300) / 150) * 170))
icon = Image.composite(Image.new("RGB", (512, 512), (16, 12, 40)), icon, band)
mark = wordmark("Toon Tale", 96)
mark = mark.resize((452, int(mark.height * 452 / mark.width)), Image.LANCZOS)
icon = icon.convert("RGBA")
icon.alpha_composite(mark, ((512 - mark.width) // 2, 500 - mark.height))
icon = icon.convert("RGB")
d = ImageDraw.Draw(icon)
d.rounded_rectangle((6, 6, 505, 505), radius=96, outline=(255, 214, 102), width=10)
d.rounded_rectangle((16, 16, 495, 495), radius=88, outline=(255, 246, 214), width=3)
icon.save(OUT + "icon_512.png")

# Link preview: the village scene with the title on a soft dark band.
wide = Image.open(wide_src).convert("RGB")
ww, wh = wide.size
crop_h = int(ww * 630 / 1200)
top = (wh - crop_h) // 2
og = wide.crop((0, top, ww, top + crop_h)).resize((1200, 630), Image.LANCZOS)
band = Image.new("L", (1200, 630), 0)
bd = ImageDraw.Draw(band)
for x in range(1200):
    a = max(0, 210 - int(x * 0.45))
    bd.line([(x, 0), (x, 630)], fill=a)
og = Image.composite(Image.new("RGB", (1200, 630), (12, 18, 48)), og, band)
d = ImageDraw.Draw(og)
og = og.convert("RGBA")
for i, word in enumerate(["Toon", "Tale"]):
    mark = wordmark(word, 128)
    og.alpha_composite(mark, (12, 86 + i * 146))
og = og.convert("RGB")
d = ImageDraw.Draw(og)
tag = font(MITR, 36, bold=False)
outlined(d, (50, 448), "ผจญภัย ARPG แนวการ์ตูน", tag, (255, 255, 255), (20, 20, 50), 4)
outlined(d, (50, 498), "เล่นบนมือถือได้ทันที", tag, (190, 232, 255), (20, 20, 50), 4)
og.save(OUT + "og_image.png")
print("wrote", OUT + "icon_512.png", OUT + "og_image.png")
