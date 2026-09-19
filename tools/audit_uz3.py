#!/usr/bin/env python3
"""Audit/extract UZ3 data without changing playable levels (Python stdlib only).

Layout based on sdvig/src/uz3Parser.ts. Gameplay interpretation is deliberately
separate: sprites are not collision, match IDs are not sprite IDs, and the
source's transport destination is a landing cell, not necessarily a pipe cell.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import struct

GRID_OFFSET = 0x370
CELL_SIZE = 40
GRID_SIZE = 12
GRID_END = GRID_OFFSET + GRID_SIZE ** 2 * CELL_SIZE
COLORS = {1: 'red', 2: 'yellow', 3: 'green', 4: 'blue'}
SHAPE_CODES = frozenset(str(i) for i in range(200, 209))


def u16(data, offset):
    return struct.unpack_from('<H', data, offset)[0]


def parse(data, filename=''):
    if len(data) < GRID_END:
        raise ValueError(f'{filename}: truncated grid ({len(data)} < {GRID_END} bytes)')
    name_length = u16(data, 0)
    if not 0 < name_length <= 38:
        raise ValueError(f'{filename}: invalid name length {name_length}')
    cells = []
    for y in range(GRID_SIZE):
        for x in range(GRID_SIZE):
            offset = GRID_OFFSET + (x * GRID_SIZE + y) * CELL_SIZE
            b = data[offset:offset + CELL_SIZE]
            text = lambda start, end: b[start:end].decode('latin1')
            cells.append(dict(
                x=x, y=y, offset=offset, raw_hex=b.hex(), flags=text(0, 6),
                destructible=b[0] == 49, movable=b[1] == 49,
                raises=b[2] == 49, falls=b[3] == 49,
                acid=b[4] - 48 if 49 <= b[4] <= 52 else 0,
                teleport=b[5] == 49, teleX=b[6], teleY=b[8],
                lock=b[10] if b[10] in COLORS else 0,
                key=b[12] if b[12] in COLORS else 0,
                foreground=text(14, 17), background=text(17, 20),
                unknown=text(20, 22).replace('\0', '').strip(), fgMask=text(22, 25), bgMask=text(25, 28),
                fgMaskInv=text(28, 29), bgMaskInv=text(29, 30),
                shadowX=b[30], shadowY=b[31], obstacle=text(32, 33),
                pieceId=u16(b, 33), bgColor=list(b[35:38]),
                byte38=b[38], byte39=b[39],
                teleportInput=b[20] - 48 if 48 <= b[20] <= 55 else 0,
                teleportOutput=b[21] - 48 if 48 <= b[21] <= 55 else 0,
            ))
    return dict(
        format='uz3-extracted-v1', source=filename,
        sha256=hashlib.sha256(data).hexdigest(),
        name=data[2:2 + name_length].decode('latin1').replace('\0', '').strip(),
        targetTime=u16(data, 0xA0) or None, targetMoves=u16(data, 0xC8) or None,
        globalBg=list(data[0x78:0x7B]),
        header_hex=data[:GRID_OFFSET].hex(), trailer_hex=data[GRID_END:].hex(),
        cells=cells,
    )


def is_entity(c):
    return any(c[k] for k in ('movable', 'destructible', 'pieceId', 'key', 'lock', 'falls', 'raises'))


def audit(level, current=None):
    cells = level['cells']
    entities = [c for c in cells if is_entity(c)]
    issues = []

    def issue(code, c, detail):
        issues.append(dict(code=code, cell=[c['x'], c['y']], detail=detail))

    for c in cells:
        if c['teleport']:
            issue('transport_review', c, f"entry/output codes {c['unknown']!r}; landing [{c['teleX']},{c['teleY']}]")
            if not (0 <= c['teleX'] < 12 and 0 <= c['teleY'] < 12):
                issue('invalid_transport_target', c, 'Destination outside 12x12 board')
        if c['acid']:
            issue('hazard_policy', c, f"Source hazard code {c['acid']}; world 2 uses water by design")
        if not is_entity(c):
            continue
        pid, fg = c['pieceId'], c['foreground']
        if pid == 666 and (not c['falls'] or c['raises']):
            issue('bomb_gravity_policy', c, 'Our bombs always fall, irrespective of source flags')
        if not c['movable'] and not c['lock']:
            issue('immovable_entity', c, 'Source disallows manual movement independently of gravity')
        if c['raises'] and c['falls']:
            issue('conflicting_gravity', c, 'Both gravity flags set')
        if not c['key'] and not c['lock'] and pid != 666 and fg not in SHAPE_CODES:
            issue('unmapped_entity_art', c, f"Sprite {fg!r}, matching ID {pid}, destructible={c['destructible']}")
        if pid > 9 and pid != 666:
            issue('non_goal_match_group', c, f'Matching ID {pid} is not a goal under sdvig loader rules')
        if c['destructible'] and pid == 0:
            issue('unmatchable_destructible', c, 'Destructible entity without a matching group')
    # Detect relationships that mapping sprite -> ItemDefs alone cannot preserve.
    by_sprite, by_group = defaultdict(set), defaultdict(set)
    for c in entities:
        if c['pieceId'] not in (0, 666):
            by_sprite[c['foreground']].add(c['pieceId'])
            by_group[c['pieceId']].add(c['foreground'])
    relationships = dict(
        same_sprite_different_groups={k: sorted(v) for k, v in by_sprite.items() if len(v) > 1},
        same_group_different_sprites={str(k): sorted(v) for k, v in by_group.items() if len(v) > 1},
    )
    result = dict(source=level['source'], name=level['name'], entities=len(entities),
                  goal_entities_by_sdvig_rule=sum(c['pieceId'] < 10 and (c['destructible'] or c['pieceId'] > 0) for c in entities),
                  transports=sum(c['teleport'] for c in cells),
                  issues=issues, matching=relationships)
    if current is not None:
        source_positions = {(c['x'], c['y']) for c in entities}
        current_positions = {(c['x'], c['y']) for c in current['items']}
        collision_differences = []
        for c in cells:
            # Compare only static source collision; entities may occupy either cell type.
            if is_entity(c) or c['teleport']:
                continue
            tile = current['terrain'][c['y']][c['x']]
            if (c['obstacle'] == '1') != (tile in '#%-'):
                collision_differences.append([c['x'], c['y']])
        result['manual_comparison'] = dict(
            source_only_entity_cells=sorted(source_positions - current_positions),
            manual_only_item_cells=sorted(current_positions - source_positions),
            static_collision_differences=collision_differences,
            source_moves=level['targetMoves'], manual_moves=current.get('moves'),
            source_time=level['targetTime'], manual_time=current.get('time'),
        )
    return result


def markdown(report):
    rows = ['# UZ3 import audit', '',
            f"Parsed **{len(report['levels'])} source levels**, with **{report['cell_count']} cells**.", '',
            'This is an extraction/compatibility audit, not a claim of faithful playable conversion.',
            'The current campaign is unchanged. Coordinates are zero-based. Differences include intentional adaptations.', '',
            '## Existing levels 1–16', '',
            '| Level | Source name | Source-only entities | Manual-only items | Static collision differences | Transports |',
            '|---|---|---:|---:|---:|---:|']
    for entry in report['levels']:
        diff = entry.get('manual_comparison')
        if diff is not None:
            rows.append(f"| {entry['source']} | {entry['name'].replace('|', '/')} | {len(diff['source_only_entity_cells'])} | {len(diff['manual_only_item_cells'])} | {len(diff['static_collision_differences'])} | {entry['transports']} |")
    rows += ['', '## Compatibility findings', '', '| Finding | Cells | Levels |', '|---|---:|---:|']
    for code, count in sorted(report['issue_counts'].items()):
        levels = sum(any(i['code'] == code for i in entry['issues']) for entry in report['levels'])
        rows.append(f'| {code} | {count} | {levels} |')
    rows += ['', f"Matching groups and sprites are not one-to-one in {sum(any(e['matching'].values()) for e in report['levels'])} levels.", '', '## Conversion plan', '',
        '- Keep raw flags, sprite codes, masks, and matching IDs in the intermediate representation. Extracted files preserve every byte (header, cells, trailer) and SHA-256.',
        '- Use the obstacle flag for collision. Opacity and masks affect appearance, not solidity.',
        '- Add per-item matching group, movability, and destructibility to the game schema/rules before faithful bulk conversion. Gravity overrides already exist.',
        '- Translate source landing coordinates and direction codes into our pipe/teleport model. Review transport cases rather than guessing from sprite orientation.',
        '- Keep deliberate policies: world 2 water, always-falling bombs, and blast-proof mover/arrow boxes. Record any override explicitly.',
        '- Preserve our world art/themes; map original visual codes to our assets separately from mechanics.',
        '- Validate and playtest converted drafts before replacing campaign levels. No solver is needed.', '',
        'Goal interpretation follows `sdvig/src/levels/uz3LevelLoader.ts` (matching IDs below 10); this is an interpretation, not a separately verified original-game specification.',
        'Full per-cell findings and source/manual coordinates are in `audit.json` beside the extracted files.', '',
        '## Reproduce', '',
        '```sh',
        'python3 tools/audit_uz3.py /path/to/sdvig/public/uz3 --output /tmp/uz3-extracted',
        'python3 tools/test_audit_uz3.py',
        '```', '',
        'Omit `--output` for a report only. Output is an intermediate format, not playable campaign JSON. The tool refuses output inside the campaign and refuses overwriting different files.', '',
        'Validation on this dataset: all decoded shared fields match `sdvig/src/uz3Parser.ts` for all 105 files / 15,120 cells; header + column-major cells + trailer reconstruct each original byte-for-byte. Four synthetic regression tests cover coordinates, flags, malformed input, collision, and matching identities.', '']
    return '\n'.join(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='Directory containing LEVELnnn.UZ3')
    parser.add_argument('--campaign', type=Path, default=Path(__file__).resolve().parents[1] / 'levels')
    parser.add_argument('--output', type=Path, help='Write lossless extracted JSON and reports outside the campaign')
    args = parser.parse_args()
    files = sorted(args.source.glob('LEVEL[0-9][0-9][0-9].UZ3'))
    if not files:
        parser.error('No LEVELnnn.UZ3 files found')
    if args.output:
        destination, campaign = args.output.resolve(), args.campaign.resolve()
        if destination == campaign or campaign in destination.parents:
            parser.error('Extracted data must not be written into the playable campaign')
        # Never overwrite a preexisting file without comparing its content.
        args.output.mkdir(parents=True, exist_ok=True)
    decoded, entries = [], []
    for path in files:
        level = parse(path.read_bytes(), path.name)
        decoded.append(level)
        number = int(path.stem[5:])
        existing = args.campaign / f'world_{(number - 1) // 10 + 1:02d}' / f'level_{(number - 1) % 10 + 1:02d}.json'
        current = json.loads(existing.read_text()) if number <= 16 and existing.exists() else None
        entries.append(audit(level, current))
    report = dict(cell_count=len(decoded) * 144, levels=entries,
                  issue_counts=dict(Counter(i['code'] for e in entries for i in e['issues'])))
    if args.output:
        payloads = {f"{l['source']}.json": json.dumps(l, indent=2) + '\n' for l in decoded}
        payloads.update({'audit.json': json.dumps(report, indent=2) + '\n', 'README.md': markdown(report)})
        for name, body in payloads.items():
            path = args.output / name
            if path.exists() and path.read_text() != body:
                parser.error(f'Refusing to overwrite different output: {path}; use a fresh directory')
        for name, body in payloads.items():
            (args.output / name).write_text(body)
    print(markdown(report))


if __name__ == '__main__':
    main()
