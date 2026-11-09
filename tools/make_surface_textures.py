# Builds assets/textures/surfaces/surface_detail.jpg: the toon detail layers of the world's
# surfaces (see shaders/surface_detail.gdshaderinc and SurfaceKit), from Poly Haven CC0 1k
# diffuse JPGs (sources and hashes in assets/textures/surfaces/SOURCE.json).
#   python3 -I tools/make_surface_textures.py <dir with the downloaded jpgs> <out.jpg> [size]
# Each layer is simplified for the cartoon look: brightness normalised and posterised into
# soft bands, most of the colour taken out (the zone's own colours tint it in the shader),
# and centred on mid grey (0.5), so the shader can multiply by 2 * texel and keep the
# painted colour on average. The layers are stacked vertically (one Texture2DArray).
import json
import sys

import numpy as np
from PIL import Image, ImageFilter

# layer: (source asset, contrast per sigma, chroma kept, simplify px, posterise step in sigma)
# `simplify` smooths the photo into broad shapes before the bands are cut: large for the
# organic floors (grass clumps, pebbles, sand ripples), small where the pattern is the
# point (cobbles, wall stones, roof tiles, planks).
LAYERS = [
    ("leafy_grass", 0.15, 0.25, 3.4, 0.9),          # 0 grass
    ("forest_ground_04", 0.15, 0.35, 2.0, 0.8),     # 1 dirt path
    ("sand_01", 0.12, 0.30, 2.0, 0.7),              # 2 sand
    ("cobblestone_floor_01", 0.16, 0.25, 1.0, 0.7),  # 3 cobble
    ("japanese_stone_wall", 0.16, 0.20, 1.0, 0.7),   # 4 stone wall (ishigaki)
    ("grey_roof_tiles_02", 0.17, 0.15, 0.8, 0.7),    # 5 roof tiles
    ("hinoki_planks", 0.15, 0.25, 0.9, 0.7),        # 6 wood planks
    ("rock_01", 0.13, 0.20, 3.6, 0.9),              # 7 rock grain
]


def tile_filter(img: Image.Image, f) -> Image.Image:
    """Applies a PIL filter with wrap-around edges so the texture keeps tiling."""
    w, h = img.size
    big = Image.new(img.mode, (w * 3, h * 3))
    for i in range(3):
        for j in range(3):
            big.paste(img, (i * w, j * h))
    return big.filter(f).crop((w, h, 2 * w, 2 * h))


def gray(a: np.ndarray) -> Image.Image:
    return Image.fromarray((np.clip(a, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8))


def layer(path: str, size: int, contrast: float, chroma: float, simplify: float, step: float) -> np.ndarray:
    img = Image.open(path).convert("RGB").resize((size, size), Image.LANCZOS)
    img = tile_filter(img, ImageFilter.MedianFilter(5))
    rgb = np.asarray(tile_filter(img, ImageFilter.GaussianBlur(simplify * 0.5))).astype(np.float32) / 255.0
    lum = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    # Remove the large-scale lighting gradient of the photo: the shader adds its own
    # broad variation, and a soft blotch in one corner of a tile would show as a grid.
    low = np.asarray(tile_filter(gray(lum), ImageFilter.GaussianBlur(size / 8))).astype(np.float32) / 255.0
    flat = lum - low
    # Broad shapes first (the photo's grit would read as noise on a cartoon floor).
    flat = (np.asarray(tile_filter(gray(flat + 0.5), ImageFilter.GaussianBlur(simplify))).astype(np.float32) / 255.0) - 0.5
    sigma = max(float(flat.std()), 1e-3)
    z = np.clip(flat / sigma, -2.2, 2.2)
    # Posterise into flat bands `step` sigma apart, clean the band outlines with a median
    # and soften them by a pixel, like painted shapes.
    q = np.round(z / step) * step
    q = 0.5 + q * contrast
    q = np.asarray(tile_filter(gray(q), ImageFilter.MedianFilter(5))).astype(np.float32) / 255.0
    hue = rgb / np.maximum(lum[..., None], 0.05)
    hue = np.clip(hue, 0.5, 1.8)
    hue = hue / np.maximum((hue @ np.array([0.299, 0.587, 0.114], np.float32))[..., None], 1e-3)
    tint = 1.0 + (hue - 1.0) * chroma
    out = np.clip(q[..., None] * tint, 0.0, 1.0)
    im = Image.fromarray((out * 255.0 + 0.5).astype(np.uint8))
    im = tile_filter(im, ImageFilter.GaussianBlur(0.7))
    arr = np.asarray(im).astype(np.float32) / 255.0
    # Re-centre exactly on mid grey so the average multiplier is 1.
    arr = arr - arr.reshape(-1, 3).mean(0) + 0.5
    return np.clip(arr, 0.0, 1.0)


def main() -> None:
    src, out = sys.argv[1], sys.argv[2]
    size = int(sys.argv[3]) if len(sys.argv) > 3 else 512
    stack = [layer("%s/%s.jpg" % (src, name), size, c, ch, b, s) for name, c, ch, b, s in LAYERS]
    strip = np.concatenate(stack, axis=0)
    img = Image.fromarray((strip * 255.0 + 0.5).astype(np.uint8))
    if out.endswith(".jpg"):
        img.save(out, quality=90, subsampling=0, optimize=True)
    else:
        img.save(out, optimize=True)
    print(json.dumps({"out": out, "size": size, "layers": [name for name, *_ in LAYERS]}))


if __name__ == "__main__":
    main()
