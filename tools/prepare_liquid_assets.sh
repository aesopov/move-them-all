#!/usr/bin/env bash
# Slice and apply the seamless-edge filter requested in prompts/04_liquids.md.
set -euo pipefail
cd "$(dirname "$0")/.."
src=assets/reference/liquids
mkdir -p assets/liquids
for kind in water lava acid; do
  magick "$src/${kind}_sheet.png" -crop 887x887+0+0 +repage -resize 128x128 "assets/liquids/${kind}_surface.png"
  magick "$src/${kind}_sheet.png" -crop 887x887+887+0 +repage -resize 128x128 -alpha off "assets/liquids/${kind}_body.png"
  # Symmetric edge blending: opposing boundary pixels become exactly equal.
  for part in surface body; do
    file="assets/liquids/${kind}_${part}.png"
    magick "$file" -channel RGBA -fx 'u+(u.p{w-1-i,j}-u)*max(0,1-min(i,w-1-i)/10)/2' "$file"
  done
  magick "assets/liquids/${kind}_body.png" -fx 'u+(u.p{i,h-1-j}-u)*max(0,1-min(j,h-1-j)/10)/2' "assets/liquids/${kind}_body.png"
  # Join surface bottom to the body's first row without altering the wave.
  magick "assets/liquids/${kind}_surface.png" \( "assets/liquids/${kind}_body.png" -alpha set \) -channel RGBA -fx 'u+(v.p{i,0}-u)*max(0,(j-(h-13))/12)' "assets/liquids/${kind}_surface.png"
  # Remove any one-byte rounding differences after alpha-aware filtering.
  magick "assets/liquids/${kind}_surface.png" \( +clone -crop 1x128+0+0 +repage \) -geometry +127+0 -compose Copy -composite "assets/liquids/${kind}_surface.png"
done
