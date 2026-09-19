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
