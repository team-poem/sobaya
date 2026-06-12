# SVG Visual Verification

macOS `qlmanage -t` thumbnails are unreliable for checking SVG artwork —
output lands on a square canvas with surprising scaling and cropping, which
misreads as broken artwork.

**Pattern:** render at exact size with headless Chrome, then view the PNG:

```sh
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless \
  --disable-gpu --screenshot=/tmp/out.png --window-size=1200,320 \
  "file:///abs/path/file.svg"
```

**Evidence:** plan 01, banner.svg check — qlmanage suggested the right half
of the banner was missing; Chrome rendered the full correct artwork.

See also: [[principles/prove-it-works]]
