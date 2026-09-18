# New pieces from the handcrafted World 1 levels

Implemented in d44859b, 9bc4a6d and 1810ceb. Runtime sprites are 128x128 RGBA.

| Item | Visual |
|---|---|
| `weight` | Blue heavy downward-arrow metal block on a low grey plinth |
| `weight_red` | Same weight in coral red |
| `block_red`, `block_blue` | Glossy rounded-square blocks with bold dark `!` |
| `mover_green`, `mover_red` | Dark green/red blocks with contrasting blue four-way arrows |
| `padlock` | Uses `padlock_red`, `padlock_green`, `padlock_yellow`, `padlock_blue` according to its lock color |

The six new pieces retain the silhouettes and symbols from their procedural art.
Padlocks reuse the existing generated lock designs, exported from the original sheet at
item resolution rather than enlarging the small overlay PNGs.

Exact prompts and source sheets: `assets/reference/expansion/`.
Rebuild: `bash tools/prepare_expansion_assets.sh`.
