#!/bin/sh
# Regenerates all worlds in parallel. Usage: tools/generate_all.sh [seed]
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
cd "$(dirname "$0")/.."
SEED=${1:-12345}
for w in 1 2 3 4 5 6 7 8 9 10 11; do
  "$GODOT" --headless --script res://tools/generate_levels.gd -- --world=$w --seed=$SEED > "/tmp/mta_gen_$w.log" 2>&1 &
done
wait
cat /tmp/mta_gen_*.log | grep -E "level_|ERROR"
