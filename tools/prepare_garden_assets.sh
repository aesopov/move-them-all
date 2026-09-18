#!/usr/bin/env bash
# Slice generated sheets and downscale the original art. Requires ImageMagick.
set -euo pipefail
cd "$(dirname "$0")/.."
src=assets/reference/garden
# Find the visible silhouette without discarding soft alpha on the actual art.
slice() {
  local bounds
  bounds=$(magick "$1" -crop "$2" +repage -alpha extract -threshold 15% -format '%@' info:)
  magick "$1" -crop "$2" +repage -crop "$bounds" +repage "${@:3}"
}
names=(pyramid cube torus sphere cone)
for i in 0 1 2 3 4; do
  x=$((i * 1983 / 5))
  end=$(((i + 1) * 1983 / 5))
  slice "$src/items_sheet.png" "$((end-x))x793+$x+0" -resize 112x112 -gravity center -background none -extent 128x128 "assets/items/${names[$i]}.png"
done
slice "$src/pipes_sheet.png" 543x724+0+0 -resize '128x108!' -gravity center -background none -extent 128x128 assets/tiles/skins/pipe_straight.png
slice "$src/pipes_sheet.png" 543x724+543+0 -resize '128x128!' assets/tiles/skins/pipe_elbow.png
slice "$src/pipes_sheet.png" 543x724+1086+0 -resize '128x128!' assets/tiles/skins/pipe_ball.png
slice "$src/pipes_sheet.png" 543x724+1629+0 -resize '128x128!' assets/tiles/skins/pipe_block.png
for name in floor_a floor_b; do
  magick "$src/$name.png" -resize 128x128 "assets/tiles/garden/$name.png"
done
magick "$src/brick.png" -resize 128x128 assets/tiles/skins/brick.png
magick "$src/background.png" -resize '1920x1080!' assets/backgrounds/garden.png
