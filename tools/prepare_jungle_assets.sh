#!/usr/bin/env bash
# Slice the Jungle terrain sheet and resize the scenic background.
set -euo pipefail
cd "$(dirname "$0")/.."
src=assets/reference/jungle
mkdir -p assets/tiles/jungle assets/backgrounds
names=(floor_a floor_b wall wall_cracked)
for i in 0 1 2 3; do
  x=$((i % 2 * 627))
  y=$((i / 2 * 627))
  crop="627x627+$x+$y"
  bounds=$(magick "$src/tiles_sheet.png" -crop "$crop" +repage -alpha extract -threshold 15% -format '%@' info:)
  magick "$src/tiles_sheet.png" -crop "$crop" +repage -crop "$bounds" +repage -resize '124x124!' -gravity center -background none -extent 128x128 "assets/tiles/jungle/${names[$i]}.png"
done
magick "$src/background.png" -resize '1920x1080!' assets/backgrounds/jungle.png
magick montage assets/tiles/jungle/{floor_a,floor_b,wall,wall_cracked}.png -tile 2x2 -geometry 128x128+0+0 -background '#162820' "$src/contact_sheet.png"
