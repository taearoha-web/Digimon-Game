# Toon Tale home-screen artwork

`home_icon_1024.png` is the original illustrated cover generated for Toon Tale.
Keep it as the source for web app icons; `tools/make_branding.py` generates the
older render-based artwork and must not overwrite this illustration.

Run `python3 tools/package_web.py --pages docs/play` after a Web export to make
the opaque square 180 px Apple touch icon and 192/512 px web app icons. The
packager includes an artwork hash in their URLs so new installs fetch new art.
iOS applies rounded corners itself. Existing home-screen shortcuts may need to
be removed and added again in Safari to update Apple's saved icon.
