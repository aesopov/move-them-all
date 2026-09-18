#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
src=assets/reference/expansion
mkdir -p assets/items assets/pipes
slice() {
  local bounds
  bounds=$(magick "$1" -crop "$2" +repage -alpha extract -threshold 15% -format '%@' info:)
  magick "$1" -crop "$2" +repage -crop "$bounds" +repage "${@:3}"
}
items=(weight weight_red block_red block_blue mover_green mover_red)
for i in 0 1 2 3 4 5; do
  slice "$src/items_sheet.png" "418x627+$((i%3*418))+$((i/3*627))" -resize 112x112 -gravity center -background none -extent 128x128 "assets/items/${items[$i]}.png"
done
colors=(red green yellow blue)
for i in 0 1 2 3; do
  slice assets/reference/markers/locks_sheet.png "627x627+$((i%2*627))+$((i/2*627))" -resize 112x112 -gravity center -background none -extent 128x128 "assets/items/padlock_${colors[$i]}.png"
done
pieces=(mouth straight elbow tee cross cap)
for i in 0 1 2 3 4 5; do
  slice "$src/pipes_sheet.png" "512x512+$((i%3*512))+$((i/3*512))" -channel A -fx 'u<0.15?0:u' +channel -resize '128x128!' "assets/pipes/pipe_${pieces[$i]}.png"
done
# Use the same tube cross-section everywhere: 116/128 = 90.6% diameter.
magick assets/pipes/pipe_straight.png -crop 1x128+64+0 +repage -resize '128x116!' -gravity center -background none -extent 128x128 -channel RGBA -fx '(u+u.p{i,h-1-j})/2' assets/pipes/pipe_straight.png
magick assets/pipes/pipe_cap.png -resize '128x116!' -gravity center -background none -extent 128x128 assets/pipes/pipe_cap.png
# Normalize painted junction necks to the common 90% port geometry.
warp() {
  local name=$1 a=$2 b=$3 c=$4 d=$5
  local sx="(i<6?i*$a/6:(i<=121?$a+(i-6)*($b-$a)/115:$b+(i-121)*(127-$b)/6))"
  local sy="(j<6?j*$c/6:(j<=121?$c+(j-6)*($d-$c)/115:$d+(j-121)*(127-$d)/6))"
  magick "assets/pipes/pipe_${name}.png" -channel RGBA -fx "u.p{$sx,$sy}" "assets/pipes/pipe_${name}.png"
}
warp elbow 11 127 0 122
warp tee 20 108 0 85
warp cross 38 90 26 90
# Every joint gets matching flat ports, without end rims or transparent gaps.
for entry in 'mouth:8' 'elbow:12' 'tee:14' 'cross:15' 'cap:8'; do
  name=${entry%:*}; mask=${entry#*:}
  for side in 0 1 2 3; do
    if (( (mask & (1 << side)) == 0 )); then continue; fi
    case "$side" in
      0) rotation=90; blend='max(0,1-j/18)';;
      1) rotation=0; blend='max(0,1-(127-i)/18)';;
      2) rotation=90; blend='max(0,1-(127-j)/18)';;
      3) rotation=0; blend='max(0,1-i/18)';;
    esac
    magick "assets/pipes/pipe_${name}.png" \( assets/pipes/pipe_straight.png -rotate "$rotation" \) -channel RGBA -fx "u+(v-u)*($blend)" "assets/pipes/pipe_${name}.png"
  done
  # Reassert exact boundary pixels after overlapping corner blends.
  for side in 0 1 2 3; do
    if (( (mask & (1 << side)) == 0 )); then continue; fi
    case "$side" in
      0) rotation=90; crop=128x1+0+0; at=+0+0;;
      1) rotation=0; crop=1x128+127+0; at=+127+0;;
      2) rotation=90; crop=128x1+0+127; at=+0+127;;
      3) rotation=0; crop=1x128+0+0; at=+0+0;;
    esac
    magick "assets/pipes/pipe_${name}.png" \( assets/pipes/pipe_straight.png -rotate "$rotation" -crop "$crop" +repage \) -geometry "$at" -compose Copy -composite "assets/pipes/pipe_${name}.png"
  done
done
magick montage assets/items/{weight,weight_red,block_red,block_blue,mover_green,mover_red}.png -tile 3x2 -geometry 128x128+8+8 -background '#243045' "$src/items_preview.png"
magick montage assets/pipes/pipe_{mouth,straight,elbow,tee,cross,cap}.png -tile 3x2 -geometry 128x128+0+0 -background '#243045' "$src/pipes_preview.png"
