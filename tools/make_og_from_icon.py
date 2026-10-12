"""Builds the 1200x630 link-preview image (assets/branding/og_image.png) from the
square home-screen art (assets/branding/home_icon_1024.png).

  python3 tools/make_og_from_icon.py

The art stays sharp and centred at full height; the side bands are the same art,
enlarged and blurred. package_web.py turns og_image.png into docs/play/og.jpg.
"""
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

SRC = "assets/branding/home_icon_1024.png"
OUT = "assets/branding/og_image.png"
W, H = 1200, 630

art = Image.open(SRC).convert("RGB")

# Background: art scaled to cover the card, blurred and slightly darkened.
scale = max(W / art.width, H / art.height)
bg = art.resize((round(art.width * scale), round(art.height * scale)), Image.LANCZOS)
left, top = (bg.width - W) // 2, (bg.height - H) // 2
bg = bg.crop((left, top, left + W, top + H)).filter(ImageFilter.GaussianBlur(28))
bg = ImageEnhance.Brightness(bg).enhance(0.72)

# Foreground: the art at full card height with softly rounded corners.
fg = art.resize((H, H), Image.LANCZOS)
mask = Image.new("L", (H * 4, H * 4), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, H * 4 - 1, H * 4 - 1), radius=H * 4 // 14, fill=255)
mask = mask.resize((H, H), Image.LANCZOS)
card = bg.copy()
card.paste(fg, ((W - H) // 2, 0), mask)
card.save(OUT)
print("wrote", OUT, card.size)
