# Optional zoom controls

On mobile, toggle the **+/−** button in the bottom toolbar. On any screen, the pause menu also offers **Zoom controls: on/off** and **Reset zoom**. The preference is saved locally and applies to subsequent levels.

- Pinch to zoom from 1× to 4×; drag to pan. When zoomed in, releasing a moving drag glides briefly with gradual deceleration. Touch again to stop; edges, reset, and rotation also stop the glide. The board clips inside its viewport while the HUD stays fixed.
- Tap a piece, then a destination in the same row or column. Tap the selected piece again to deselect it; for bombs, the second tap detonates it.
- Each step runs the normal game rules. Commands stop at obstacles, the destination, destruction, or displacement by gravity/transport. There is no pathfinding or automatic turn.
- A transport entrance stops a longer command. Tapping the entrance itself explicitly permits entering it, then ends the command.
- Each command is one gesture for undo and the existing move-count policy.
- Desktop equivalents: mouse wheel/trackpad pinch zoom, drag pan, click selection/destination.
- Rotation and disabling the mode reset the camera. The Info panel contains localized instructions.

Validation: `tools/test_touch_controls.gd` covers movement and gesture boundaries; `tools/test_mobile.gd` covers portrait/landscape layouts and legacy touch dragging. Physical-device browser testing remains useful for platform-specific gesture handling.
