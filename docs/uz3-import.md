# Original-level import

The campaign now contains 105 numbered levels. Levels 1–16 retain their curated JSON and decoration scenes. Levels 17–105 are generated from the original UZ3 files with our eleven world themes. Two existing custom levels are separate from the numbered campaign.

## Reproduce

Python 3 and the original `LEVEL001.UZ3` … `LEVEL105.UZ3` files are needed to regenerate data. Playing the game requires neither Python nor the original files.

```sh
# Validate conversion without changing levels.
python3 tools/import_uz3.py /path/to/sdvig/public/uz3

# Generate drafts in a separate directory.
python3 tools/import_uz3.py /path/to/sdvig/public/uz3 \
  --output /tmp/uz3-drafts --write --report /tmp/uz3-notes.json

# Regenerate the imported campaign. Deliberately overwrites levels 17–105.
python3 tools/import_uz3.py /path/to/sdvig/public/uz3 \
  --output levels --write --replace --report docs/uz3-import-notes.json

# Compare the original first sixteen without replacing the curated campaign.
python3 tools/import_uz3.py /path/to/sdvig/public/uz3 \
  --start 1 --end 16 --output /tmp/uz3-first16 --write
```

All inputs are converted before any level is written. Different existing files require `--replace`; malformed records, unknown entry codes, and unsupported movable transports fail explicitly. Each level carries its source filename, number, and SHA-256. The original parser-compatible lossless extraction remains available through `tools/audit_uz3.py`.

## Gameplay fields

Version 2 adds optional per-item fields. Missing fields retain the behavior of existing hand-built levels.

| Field | Meaning |
|---|---|
| `match_group` | Positive source ID defines matching independently of art; zero disables matching. Omitted means match by item type. |
| `movable` | Whether the player can move the item. False does not cancel gravity. |
| `destructible` | Whether bomb contact/blasts can destroy it. Locked items remain protected. Matching is independent. |
| `gravity` | Existing `none`, `fall`, or `bubble` override. Bombs respect source gravity flags; bombs without an override fall by default. |
| `match_label` | Small group-number badge to make matching identities visible even when art differs. |
| `visual` | `cracked_stone` displays destructible fixed objects with the current world's cracked-stone art. |

The fields survive serialization, editor saves, and undo. The importer derives collision from the obstacle flag, never from sprite opacity. Masks `015` and `021` identify mover and exclamation boxes independently of their underlying tile colour. Source lock IDs are translated by name (source yellow/green ordering differs from our enum).

## Transport conversion

A pipe with `destination: "cell"` targets an exact landing cell. Its `enter` array lists **movement directions**, not the side the mouth faces. A piece moving right enters a left-facing mouth. Arrivals stop at the destination without an extra step or an immediate second teleport. Occupied or solid destinations block entry; landing in a liquid destroys an unlocked piece.

Observed source input codes: `0` all directions (teleport), `1` up, `2` down, `3` up/down, `4` left, `5` right. These differ from the output-code enum. The input mapping is inferred from known source entrance orientations and cases in levels 4, 8, 13, and 16; the older TypeScript loader's shared input/output enum was not copied. Unknown codes are rejected. Explicit destination coordinates determine landing; output codes do not add a step beyond that position.

Legacy linked-mouth pipes and the custom Level 16 elbow behavior remain unchanged. Arrival-only teleport endpoints have a visible marker but no return route. A standalone lock can sit over a floor background; that background does not create a box beneath it. A locked source teleporter is represented by a removable padlock occupying its cell. Level 92 contains a source route whose destination is solid; it is preserved as a blocked route, not silently redirected.

## Intentional adaptations

- Existing world art replaces original bitmaps, masks, and decorative scenery. Original pixels are not bundled.
- World 2 uses water. Other imported hazards use the world's liquid style: lava in Volcano, acid in Acid Swamp, water elsewhere.
- Bombs respect source gravity flags; bombs without an override fall by default. Existing blast radius, matching, and surrounding rules remain in use.
- Mover boxes never match. Movers and exclamation boxes are blast-proof; exclamation boxes can still match their source group.
- Per-item gravity follows source flags, including falling/rising keys.
- Goals follow the `sdvig` loader's interpretation of source piece IDs below 10. Non-goal matching groups are preserved.
- Original level names and bonus targets are retained. Titles and new help text have translations in all six supported languages.

Art substitutions and mechanical policy overrides are listed per cell in `uz3-import-notes.json`. These imports preserve source gameplay data within the above policies; they are not a pixel-perfect recreation of the original visuals.

## Validation

```sh
python3 tools/test_audit_uz3.py
python3 tools/test_import_uz3.py
godot --headless --path . --script tools/test_rules.gd
godot --headless --path . --script tools/test_imported_rules.gd
godot --headless --path . --script tools/test_imported_campaign.gd
godot --headless --path . --script tools/validate_levels.gd
```

The extraction was checked against the TypeScript parser for all 105 files / 15,120 cells and reconstructs each source file byte-for-byte. Gameplay regression tests cover independent match groups, gravity on immovable objects, bomb protection/contact, direct pipe entry and exact landings, blocked exits, liquid arrivals, and save/undo roundtrips. The campaign smoke check exercises every initially legal action (918 actions across the 89 imported levels) and verifies occupancy consistency afterward. It does not search for solutions or establish that every full puzzle is winnable. Full-level playtesting remains necessary.
