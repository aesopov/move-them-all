#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
src=assets/reference/markers
mkdir -p assets/overlays
colors=(red green yellow blue)
for i in 0 1 2 3; do
  x=$((i % 2 * 627))
  y=$((i / 2 * 627))
  for kind in keys locks; do
    bounds=$(magick "$src/${kind}_sheet.png" -crop "627x627+$x+$y" +repage -alpha extract -threshold 15% -format '%@' info:)
    if [[ "$kind" == keys ]]; then
      size=128; inner=104; dest="assets/items/key_${colors[$i]}.png"
    else
      size=64; inner=58; dest="assets/overlays/lock_${colors[$i]}.png"
    fi
    magick "$src/${kind}_sheet.png" -crop "627x627+$x+$y" +repage -crop "$bounds" +repage -resize "${inner}x${inner}" -gravity center -background none -extent "${size}x${size}" "$dest"
  done
done
bounds=$(magick "$src/goal_flag.png" -alpha extract -threshold 15% -format '%@' info:)
magick "$src/goal_flag.png" -crop "$bounds" +repage -resize 58x58 -gravity center -background none -extent 64x64 assets/overlays/goal_flag.png
magick montage assets/items/key_{red,green,yellow,blue}.png assets/overlays/lock_{red,green,yellow,blue}.png assets/overlays/goal_flag.png -tile 4x3 -geometry 128x128+8+8 -background '#243045' "$src/contact_sheet.png"
