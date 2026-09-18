# Mobile layout and portrait art

The game selects portrait artwork automatically when its viewport is taller than it is wide. All eleven worlds have dedicated portrait images in `assets/backgrounds/portrait`; landscape assets remain available. Exact generation prompts are in `generation_prompts.md` and the complete art preview is `catalog.png`.

Narrow screens use a compact header, bottom Undo/Restart/Pause controls, and an Info dialog containing level goals and item descriptions. The board fits the available rectangle without changing level coordinates. Menus reflow, modal content scrolls, and device safe-area insets protect the game controls and menus. Orientation follows the device. A single touch controls dragging; additional fingers and emulated mouse duplicates are ignored, and cancellation cannot trigger a bomb. Backgrounding pauses the game.

Validation on the desktop Godot runtime covers portrait phone/tablet sizes, narrow landscape, desktop, rotation without resetting state, touch drag/undo/cancellation, and modal bounds. Run:

```
godot --headless --path . --script tools/test_mobile.gd
godot --path . --script tools/preview_mobile.gd
godot --path . --script tools/preview_mobile_art.gd
```

This is the responsive game and asset implementation, not a signed mobile release. Android/iOS export presets, application identifiers, signing, physical-device safe-area/touch checks, and performance/memory profiling still need platform release validation. No Android or iOS device was used for these checks.

Safe-area integration follows [Godot DisplayServer](https://docs.godotengine.org/en/stable/classes/class_displayserver.html#class-displayserver-method-get-display-safe-area); viewport scaling follows [Godot multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).
