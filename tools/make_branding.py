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
title = font(FREDOKA, 120)
outlined(d, (44, 150), "Toon", title, (255, 214, 102), (40, 24, 60), 10)
outlined(d, (44, 278), "Tale", title, (255, 255, 255), (40, 24, 60), 10)
tag = font(MITR, 36, bold=False)
outlined(d, (50, 432), "ผจญภัย ARPG แนวการ์ตูน", tag, (255, 255, 255), (20, 20, 50), 4)
outlined(d, (50, 482), "เล่นบนมือถือได้ทันที", tag, (190, 232, 255), (20, 20, 50), 4)
og.save(OUT + "og_image.png")
print("wrote", OUT + "icon_512.png", OUT + "og_image.png")
