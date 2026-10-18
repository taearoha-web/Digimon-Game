"""Compose shots of tests/tools/chibi_look_preview.tscn into one captioned sheet.
usage: python3 tools/chibi_look_sheet.py OUT_DIR SET VIEW COLUMNS sheet.png [crop: x,y,w,h]
"""
import sys, os
from PIL import Image, ImageDraw, ImageFont

out_dir, set_name, view, cols, sheet = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5]
crop = tuple(int(v) for v in sys.argv[6].split(",")) if len(sys.argv) > 6 else None
captions = open(os.path.join(out_dir, "%s_%s.txt" % (set_name, view)), encoding="utf-8").read().split("\n")
shots = []
for i in range(len(captions)):
    im = Image.open(os.path.join(out_dir, "%s_%s_%d.png" % (set_name, view, i))).convert("RGB")
    if crop:
        x, y, w, h = crop
        im = im.crop((x, y, x + w, y + h))
    shots.append(im)
w, h = shots[0].size
font_path = os.path.join(os.path.dirname(__file__), "..", "assets", "fonts", "Mitr-Medium.ttf")
font = ImageFont.truetype(font_path, max(18, w // 14))
cap_h = int(font.size * 1.8)
rows = (len(shots) + cols - 1) // cols
img = Image.new("RGB", (cols * w, rows * (h + cap_h)), "white")
draw = ImageDraw.Draw(img)
for i, (shot, cap) in enumerate(zip(shots, captions)):
    x, y = (i % cols) * w, (i // cols) * (h + cap_h)
    img.paste(shot, (x, y))
    tw = draw.textlength(cap, font=font)
    draw.text((x + (w - tw) / 2, y + h + cap_h * 0.18), cap, fill="#2b2340", font=font)
img.save(sheet, optimize=True)
print(sheet, img.size)
