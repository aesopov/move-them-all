#!/usr/bin/env bash
# Prepare the generated core item sheet. Requires ImageMagick.
set -euo pipefail
cd "$(dirname "$0")/.."
src=assets/reference/core/items_sheet.png
names=(crystal plant star shell crate rock bubble balloon bomb)
xs=(0 430 825 1254)
ys=(0 450 815 1254)
for i in 0 1 2 3 4 5 6 7 8; do
  col=$((i % 3))
  row=$((i / 3))
  x=${xs[$col]}
  y=${ys[$row]}
  w=$((${xs[$((col+1))]} - x))
  h=$((${ys[$((row+1))]} - y))
  crop="${w}x${h}+${x}+${y}"
  bounds=$(magick "$src" -crop "$crop" +repage -alpha extract -threshold 15% -format '%@' info:)
  magick "$src" -crop "$crop" +repage -crop "$bounds" +repage -resize 104x104 -gravity center -background none -extent 128x128 "assets/items/${names[$i]}.png"
done
magick montage assets/items/{crystal,plant,star,shell,crate,rock,bubble,balloon,bomb}.png -tile 3x3 -geometry 128x128+10+10 -background '#243045' assets/reference/core/contact_sheet.png
