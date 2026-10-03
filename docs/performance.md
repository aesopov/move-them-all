# Performance baseline and first optimization pass

Measured locally with Godot 4.7.1 on 2026-09-19.

- Web PCK before: 258,549,772 bytes (246.6 MiB).
- Web PCK after the asset changes: 67,058,548 bytes (64.0 MiB), 74.1% smaller.
- Export retains all 172 game PNG resources, including every world and both background orientations. An isolated mounted-pack audit found no missing PNGs and no reference directory.
- Source PNGs are unchanged. Terrain imports are limited to 256 pixels, or 512 for multi-cell stones. Full-resolution source art remains available for future reimports.
- Export excludes development references, tools, prompts, and previous export output. It still exports all runtime resources, including dynamically loaded art.

In an idle Level 1-4 sample over 180 frames, the background, terrain, and pipe-overlay draw callbacks each ran 179 times before this change and zero times afterward. Animated effects still redraw every frame. This measures script drawing work, not GPU draw calls or an overall CPU percentage. Native scene startup measurements do not establish browser cold-load speed; download, decompression, font initialization, and device performance still matter.

Run the rendering benchmark and invalidation checks with a graphical renderer (not headless):

```sh
godot --path . --script tools/benchmark_idle.gd
```

The check verifies idle caching, continued effect animation, hover updates, board refresh, obstacle-break redraw, and background resize invalidation. Run it without simultaneous imports or exports. The process-time metric includes frame scheduling overhead and is not a CPU profiler.

For the next pass, profile an exported build on the target phone/browser, separating network download time, engine startup, menu-to-level loading, and idle CPU. Use those measurements before changing the asset-loading architecture or reducing background resolution.

## Streaming and pipe preparation (second pass)

The optional split web build (`tools/build_web.py`) reduces the bootstrap PCK
from 64.61 MiB to about 24.98 MiB. Twelve theme packs range from 0.84 to
4.51 MiB and load before entering their levels. Fonts and menu/shared resources
remain in the bootstrap; the separate engine WASM is unchanged. See
[web-streaming.md](web-streaming.md) for deployment and caching requirements.

In a local headless run, preparing 16 canonical pipe shapes took 1,216.9 ms
with procedural generation and 12.9 ms loading the baked shapes. The baked run
created zero procedural cache entries. This is a local CPU preparation comparison,
not a whole-level or mobile browser load-time measurement. Pipe geometry, joins,
fixed lighting, and cache tests still pass.

An exported Chromium/WebGL test at 480×854 downloaded one desert pack on a cold
visit and made zero theme-pack requests after a page reload in the same browser
context. The loaded theme was visually checked. Browser storage eviction or
private browsing restrictions may require future downloads.

## Screen-on idle investigation (2026-10-03)

User reported overnight battery depletion with the game visible and screen on.
The game has ongoing goal/item/effect animations and no inactivity timeout.
There is no explicit FPS cap in project.godot. The Yandex adapter pauses the
scene tree on SDK/focus pause, but an untouched foreground game remains active.

Measured the native Godot 4.7.1 Compatibility renderer on Apple M1 using
world_01/level_04, test-play mode (no progress writes), after 3 seconds of warmup.
Each phase had another 1-second settling period and a 12-second sample. CPU is
the delta of process user+system CPU time divided by elapsed wall time; 100%
means one CPU core. Music was enabled; the paused phase used the existing
Platform._set_platform_pause(true), which also pauses audio.

| Temporary test condition | Actual FPS | CPU (% of one core) |
| --- | ---: | ---: |
| Untouched gameplay, existing settings | 118.7 | 33.2 |
| Untouched gameplay, Engine.max_fps = 30 | 23.7 | 15.1 |
| Scene/audio paused, Engine.max_fps = 15 | 13.3 | 7.7 |

These are short native desktop samples, not phone/browser measurements, GPU
utilization, or battery-life estimates. Differences combine scheduling, rendering
and (for the last phase) pause effects. No production power settings were changed.
The existing rendering benchmark also passed: zero static background/terrain/pipe
redraw callbacks in 180 frames, but 179 animated-effect redraws.

Recommended next change: cap active rendering, add an inactivity-triggered
low-power pause with explicit resume, and verify screen-sleep/wake-lock behavior
in the actual Yandex mobile host. Test on the target phone before claiming a
battery-life improvement. A frame cap alone cannot remove screen-on power use.

### Implemented power policy

Active rendering now has a 60 FPS ceiling. After 180 seconds without mouse,
touch, or key input, Platform saves the current run, ends any board drag, pauses
the scene tree and music, and displays the existing localized Pause/Resume UI.
Resume preserves the music stream and respects independent SDK, focus, suspension,
shop and advertisement pause causes. Paused rendering is capped at 10 FPS with
Godot low-processor mode enabled; unchanged frames need not be redrawn.

The keep-screen-on project setting is disabled. Actual display sleep still depends
on browser/platform wake locks and device settings; it is not guaranteed by this
change for the Yandex host. No texture, resolution or visual-quality setting changed.

Validation: `tools/test_power_saving.gd` covers the inactivity threshold, music
position, render settings, explicit resume and overlapping pause causes. The music
suite passes, and the Russian pause overlay was visually checked at 390×844.
Phone battery-life measurements remain necessary.
