#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
src=assets/reference/transport
mkdir -p assets/pipes assets/teleports
slice() {
  local bounds
  bounds=$(magick "$1" -crop "$2" +repage -alpha extract -threshold 5% -format '%@' info:)
  magick "$1" -crop "$2" +repage -crop "$bounds" +repage -resize "$3" -gravity center -background none -extent 128x128 "$4"
}
slice "$src/pipes_sheet.png" 724x724+0+0 '124x100!' assets/pipes/pipe_mouth.png
slice "$src/pipes_sheet.png" 724x724+724+0 '128x78!' assets/pipes/pipe_straight.png
slice "$src/pipes_sheet.png" 724x724+1448+0 '124x124!' assets/pipes/pipe_elbow.png
slice "$src/teleports_sheet.png" 887x887+0+0 '112x112!' assets/teleports/teleport_base.png
slice "$src/teleports_sheet.png" 887x887+887+0 120x120 assets/teleports/teleport_swirl.png
# The user's thicker modular revision supersedes the original three pipe sprites.
if [[ -f assets/reference/expansion/pipes_sheet.png ]]; then
  bash tools/prepare_expansion_assets.sh
fi
magick montage assets/pipes/pipe_{mouth,straight,elbow}.png assets/teleports/teleport_{base,swirl}.png -tile 3x2 -geometry 128x128+8+8 -background '#243045' "$src/contact_sheet.png"
