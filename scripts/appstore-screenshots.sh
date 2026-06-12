#!/usr/bin/env bash
#
# appstore-screenshots.sh
# Turn a folder of raw screenshots into App Store-compliant images for every
# required device size. Each image is scaled to FIT (no stretching) and
# letterboxed with Murmur's background colour to hit the exact pixel dimensions.
#
# Usage:
#   ./scripts/appstore-screenshots.sh <source-folder>
#   ./scripts/appstore-screenshots.sh ~/Desktop/murmur-shots
#
# Output goes to "<source-folder>/appstore/<device>/".
#
# Prefers ImageMagick (best result: clean letterbox) if installed
# (`brew install imagemagick`); otherwise falls back to the built-in `sips`
# so it works on a stock Mac with nothing to install.
#

set -euo pipefail

SRC="${1:-.}"
BG_HEX="1A1714"          # Murmur background (no '#'); used to pad without distortion
OUT="$SRC/appstore"

# Apple App Store screenshot specs (portrait): "<folder> <width> <height>".
# 6.9" and 13" are the required slots; 6.5" is kept since it has its own slot.
TARGETS=(
  "iphone-6.9 1290 2796"   # 6.9" iPhone (16 Pro Max)
  "iphone-6.5 1242 2688"   # 6.5" iPhone (11 Pro Max / XS Max)
  "ipad-13 2064 2752"      # 13" iPad Pro (covers 12.9"/11" via auto-scaling)
)

if [[ ! -d "$SRC" ]]; then
  echo "Source folder not found: $SRC" >&2
  exit 1
fi

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

for target in "${TARGETS[@]}"; do
  read -r folder _w _h <<<"$target"
  mkdir -p "$OUT/$folder"
done

shopt -s nullglob nocaseglob
count=0
for img in "$SRC"/*.png "$SRC"/*.jpg "$SRC"/*.jpeg "$SRC"/*.heic; do
  [[ -e "$img" ]] || continue
  name="$(basename "${img%.*}")"
  for target in "${TARGETS[@]}"; do
    read -r folder w h <<<"$target"
    fit_pad "$img" "$w" "$h" "$OUT/$folder/${name}.png"
  done
  echo "  ✓ $name"
  count=$((count + 1))
done

if [[ $count -eq 0 ]]; then
  echo "No images (.png/.jpg/.jpeg/.heic) found in: $SRC" >&2
  exit 1
fi

echo ""
echo "Done — $count image(s) → $OUT"
for target in "${TARGETS[@]}"; do
  read -r folder w h <<<"$target"
  printf '  %-12s %sx%s  (%s)\n' "$folder" "$w" "$h" "$OUT/$folder"
done
$have_magick || echo "(used built-in sips; for cleaner letterboxing: brew install imagemagick)"
