#!/usr/bin/env bash
#
# appstore-screenshots.sh
# Turn a folder of raw screenshots into App Store-compliant images for both
# iPhone and iPad. Each image is scaled to FIT (no stretching) and letterboxed
# with Murmur's background colour to hit the exact required pixel dimensions.
#
# Usage:
#   ./scripts/appstore-screenshots.sh <source-folder>
#   ./scripts/appstore-screenshots.sh ~/Desktop/murmur-shots
#
# Output goes to "<source-folder>/appstore/iphone" and ".../ipad".
#
# Prefers ImageMagick (best result: clean letterbox) if installed
# (`brew install imagemagick`); otherwise falls back to the built-in `sips`
# so it works on a stock Mac with nothing to install.
#

set -euo pipefail

SRC="${1:-.}"
BG_HEX="1A1714"          # Murmur background (no '#'); used to pad without distortion
OUT="$SRC/appstore"

# Apple App Store screenshot specs (portrait):
IPHONE_W=1290; IPHONE_H=2796   # 6.9" iPhone (covers 6.7"/6.5" via auto-scaling)
IPAD_W=2064;   IPAD_H=2752     # 13" iPad (covers 12.9"/11" via auto-scaling)

if [[ ! -d "$SRC" ]]; then
  echo "Source folder not found: $SRC" >&2
  exit 1
fi

mkdir -p "$OUT/iphone" "$OUT/ipad"

have_magick=false
if command -v magick >/dev/null 2>&1; then have_magick=true; fi

# fit_pad <input> <W> <H> <output>
fit_pad() {
  local input="$1" w="$2" h="$3" output="$4"
  if $have_magick; then
    magick "$input" -resize "${w}x${h}" \
      -background "#${BG_HEX}" -gravity center -extent "${w}x${h}" \
      -alpha remove -alpha off "$output"
  else
    # sips fallback: copy, scale longest side to the target height (portrait),
    # then pad/crop to the exact box. Strips alpha by flattening onto the colour.
    cp "$input" "$output"
    sips -Z "$h" "$output" >/dev/null
    sips --padToHeightWidth "$h" "$w" --padColor "$BG_HEX" "$output" >/dev/null
  fi
}

shopt -s nullglob nocaseglob
count=0
for img in "$SRC"/*.png "$SRC"/*.jpg "$SRC"/*.jpeg "$SRC"/*.heic; do
  [[ -e "$img" ]] || continue
  name="$(basename "${img%.*}")"
  fit_pad "$img" "$IPHONE_W" "$IPHONE_H" "$OUT/iphone/${name}.png"
  fit_pad "$img" "$IPAD_W"   "$IPAD_H"   "$OUT/ipad/${name}.png"
  echo "  ✓ $name"
  count=$((count + 1))
done

if [[ $count -eq 0 ]]; then
  echo "No images (.png/.jpg/.jpeg/.heic) found in: $SRC" >&2
  exit 1
fi

echo ""
echo "Done — $count image(s) → $OUT"
echo "  iPhone 6.9\":  ${IPHONE_W}x${IPHONE_H}  ($OUT/iphone)"
echo "  iPad 13\":     ${IPAD_W}x${IPAD_H}  ($OUT/ipad)"
$have_magick || echo "(used built-in sips; for cleaner letterboxing: brew install imagemagick)"
