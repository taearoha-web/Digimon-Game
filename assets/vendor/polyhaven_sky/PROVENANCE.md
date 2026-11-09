# Painted sky clouds (`assets/sky/painted_clouds.png`)

| Field | Value |
|---|---|
| Source asset | "Kloofendal 48d Partly Cloudy (Pure Sky)" by Greg Zaal (original) and Jarod Guest (sky edits), Poly Haven |
| Source page | https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky |
| Downloaded file | https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/kloofendal_48d_partly_cloudy_puresky_2k.hdr (2048x1024 Radiance HDR) |
| License | CC0 1.0 Universal (public domain dedication), https://polyhaven.com/license |
| Downloaded | 2026-11-08 |

## What was done to it

The HDR itself is not in the repository (and no EXR/HDR ships in the build). Only a
derived, stylised cloud mask is kept:

1. Cloud coverage from "whiteness" (red / blue ratio): grey and white clouds against the
   blue sky.
2. Coverage blurred and quantised into two soft painted steps (a wispy rim and a solid
   body); a two-tone toon shade (bright tops, lilac-grey bellies) from the cloud's own
   log-luminance.
3. Faded out toward the horizon, nothing below it; premultiplied into RGB (the
   ProceduralSkyMaterial adds `sky_cover.rgb * a`), saved as a 2048x1024 PNG, then downscaled to 1024x512.
4. Imported VRAM-compressed (S3TC / ETC2, about 256 KB each), no mipmaps.

The script used was a short NumPy/Pillow conversion run outside the repository; the
steps above are all it did.
