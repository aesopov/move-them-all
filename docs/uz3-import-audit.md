> Pre-import audit snapshot. The conversion is now implemented; see [the import guide](uz3-import.md) for current behavior and commands.

# UZ3 import audit

Parsed **105 source levels**, with **15120 cells**.

This is an extraction/compatibility audit, not a claim of faithful playable conversion.
The current campaign is unchanged. Coordinates are zero-based. Differences include intentional adaptations.

## Existing levels 1–16

| Level | Source name | Source-only entities | Manual-only items | Static collision differences | Transports |
|---|---|---:|---:|---:|---:|
| LEVEL001.UZ3 | Introductory Level I | 1 | 0 | 65 | 1 |
| LEVEL002.UZ3 | Introductory Level II | 0 | 0 | 95 | 0 |
| LEVEL003.UZ3 | Introductory Level III | 0 | 0 | 0 | 2 |
| LEVEL004.UZ3 | Introductory Level IV | 2 | 0 | 22 | 2 |
| LEVEL005.UZ3 | Introductory Level V | 0 | 0 | 24 | 0 |
| LEVEL006.UZ3 | The Bridge I | 0 | 0 | 6 | 0 |
| LEVEL007.UZ3 | The Bridge II | 0 | 0 | 34 | 0 |
| LEVEL008.UZ3 | Fun on the Beach I | 4 | 0 | 84 | 2 |
| LEVEL009.UZ3 | Fun on the Beach II | 1 | 0 | 81 | 0 |
| LEVEL010.UZ3 | Rainbow of Problems I | 0 | 0 | 0 | 0 |
| LEVEL011.UZ3 | Confinement I | 1 | 0 | 56 | 0 |
| LEVEL012.UZ3 | Key Quest I | 0 | 0 | 32 | 0 |
| LEVEL013.UZ3 | Key Quest II | 0 | 0 | 6 | 2 |
| LEVEL014.UZ3 | Empire Crisis I | 1 | 0 | 7 | 0 |
| LEVEL015.UZ3 | The Stack | 0 | 0 | 34 | 0 |
| LEVEL016.UZ3 | Confinement II | 4 | 1 | 59 | 3 |

## Compatibility findings

| Finding | Cells | Levels |
|---|---:|---:|
| bomb_gravity_policy | 12 | 6 |
| hazard_policy | 454 | 43 |
| immovable_entity | 23 | 16 |
| non_goal_match_group | 78 | 31 |
| transport_review | 113 | 47 |
| unmapped_entity_art | 332 | 82 |

Matching groups and sprites are not one-to-one in 7 levels.

## Conversion plan

- Keep raw flags, sprite codes, masks, and matching IDs in the intermediate representation. Extracted files preserve every byte (header, cells, trailer) and SHA-256.
- Use the obstacle flag for collision. Opacity and masks affect appearance, not solidity.
- Add per-item matching group, movability, and destructibility to the game schema/rules before faithful bulk conversion. Gravity overrides already exist.
- Translate source landing coordinates and direction codes into our pipe/teleport model. Review transport cases rather than guessing from sprite orientation.
- Keep deliberate policies: world 2 water, always-falling bombs, and blast-proof mover/arrow boxes. Record any override explicitly.
- Preserve our world art/themes; map original visual codes to our assets separately from mechanics.
- Validate and playtest converted drafts before replacing campaign levels. No solver is needed.

Goal interpretation follows `sdvig/src/levels/uz3LevelLoader.ts` (matching IDs below 10); this is an interpretation, not a separately verified original-game specification.
Full per-cell findings and source/manual coordinates are in `audit.json` beside the extracted files.

## Reproduce

```sh
python3 tools/audit_uz3.py /path/to/sdvig/public/uz3 --output /tmp/uz3-extracted
python3 tools/test_audit_uz3.py
```

Omit `--output` for a report only. Output is an intermediate format, not playable campaign JSON. The tool refuses output inside the campaign and refuses overwriting different files.

Validation on this dataset: all decoded shared fields match `sdvig/src/uz3Parser.ts` for all 105 files / 15,120 cells; header + column-major cells + trailer reconstruct each original byte-for-byte. Four synthetic regression tests cover coordinates, flags, malformed input, collision, and matching identities.

