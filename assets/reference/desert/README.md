# Desert Temple — World 3

Shared art for levels 21–30, loaded automatically by the existing `desert` theme.

- `assets/backgrounds/desert.png`: amber-lit temple ruins with a quiet center.
- `assets/tiles/desert/floor_a.png`, `floor_b.png`: dark sandstone cell faces.
- `wall.png`, `wall_cracked.png`: solid and breakable sandstone obstacles.
- `wall_2x1_a.png`, `wall_2x1_b.png`: horizontal two-cell variants.
- `wall_1x2_a.png`, `wall_1x2_b.png`: vertical two-cell variants.

Generated using the original jungle wall/floor silhouettes as style references.
Existing items, rules and level layouts are unchanged.

Preview every terrain asset:

```sh
godot --path . --script tools/preview_world_art.gd -- --theme=desert
```

In-game preview:

```sh
godot --path . -- --level=res://levels/world_03/level_02.json --screenshot=res://assets/reference/desert/level_22.png --frames=10
```
