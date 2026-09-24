#!/usr/bin/env python3
"""Convert original UZ3 puzzles to our themed JSON levels; no solver or image dependency.

Default is a dry run. --write requires a destination. The existing first sixteen
levels are excluded unless --start is explicitly changed. Input direction codes
are not the same enum as output codes: 1/2/3=up/down/vertical, 4/5=left/right.
This is established by the entrance sprites and known levels 4, 8, 13, and 16.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
from audit_uz3 import parse, is_entity, COLORS
from theme_level_items import apply as apply_theme_items

THEMES = ['jungle', 'waterfall', 'desert', 'ice', 'ruins', 'cave', 'volcano', 'swamp', 'sky', 'crystal', 'nexus']
SHAPES = dict(zip(range(200, 210), ['cube', 'sphere', 'torus', 'pyramid', 'cone', 'weight', 'weight_red', 'balloon', 'bubble', 'bomb']))
INPUTS = {0: ['up', 'right', 'down', 'left'], 1: ['up'], 2: ['down'], 3: ['up', 'down'], 4: ['left'], 5: ['right']}
OPPOSITE = {'up': 'down', 'down': 'up', 'left': 'right', 'right': 'left'}
# Art-only fallback vocabulary. Matching always uses the original piece ID.
GROUP_ART = ['crystal', 'plant', 'star', 'shell', 'cube', 'pyramid', 'torus', 'sphere', 'cone']
PROTECTED = {'mover_green', 'mover_red', 'block_blue', 'block_red'}


def sprite_number(code):
    if len(code) == 3 and code.isdigit():
        return int(code)
    if len(code) == 3 and code[0] in '!@#$%^' and code[1:].isdigit():
        return ('!@#$%^'.index(code[0]) + 1) * 100 + int(code[1:])
    return None


def item_type(c):
    if c['key']:
        return 'key_' + COLORS[c['key']]
    # Background texture belongs to the cell, not to an object under a lock.
    lock_only = not any(c[k] for k in ('movable', 'destructible', 'pieceId', 'key', 'falls', 'raises'))
    if c['lock'] and lock_only and (c['foreground'] == 'non' or c['teleport']):
        return 'padlock'
    if c['pieceId'] == 666:
        return 'bomb'
    code = sprite_number(c['foreground'])
    if code in SHAPES:
        return SHAPES[code]
    # The mask identifies the symbol independently of the underlying colour.
    if c['fgMask'] == '015':
        return 'mover_red' if code in (107, 120) or c['foreground'] == 't12' else 'mover_green'
    if c['fgMask'] == '021':
        return 'block_red' if code in (107, 120) or c['foreground'] == 't12' else 'block_blue'
    if code == 124:
        return 'rock'
    if not c['movable'] and c['destructible']:
        return 'rock'
    if code is not None and 600 <= code < 700:
        return 'plant'
    if c['pieceId'] > 0:
        return GROUP_ART[(c['pieceId'] - 1) % len(GROUP_ART)]
    return 'crate'


def convert(level, number):
    theme = THEMES[(number - 1) // 10]
    terrain = [['.'] * 12 for _ in range(12)]
    skins = [['.'] * 12 for _ in range(12)]
    items, pipes, teleports, notes = [], [], [], []
    def note(c, reason):
        notes.append({'cell': [c['x'], c['y']], 'reason': reason})
    for c in level['cells']:
        x, y = c['x'], c['y']
        entity = is_entity(c)
        fg = sprite_number(c['foreground'])
        bg = sprite_number(c['background'])
        if not entity and not c['teleport']:
            if c['obstacle'] == '1':
                terrain[y][x] = '#'
                if (fg is not None and 500 <= fg <= 511) or (bg is not None and 500 <= bg <= 511):
                    skins[y][x] = 'p'
            elif c['acid']:
                terrain[y][x] = 'l' if theme == 'volcano' else ('a' if theme == 'swamp' else 'w')
        if entity:
            kind = item_type(c)
            group = c['pieceId'] if c['pieceId'] != 666 else 0
            if kind.startswith('key_') or kind in ('mover_green', 'mover_red', 'bomb', 'padlock'):
                group = 0
            aim = c['pieceId'] < 10 and (c['destructible'] or c['pieceId'] > 0)
            item = dict(type=kind, x=x, y=y, aim=bool(aim),
                        gravity='bubble' if c['raises'] else ('fall' if c['falls'] else 'none'),
                        movable=c['movable'], destructible=c['destructible'], match_group=group,
                        source_sprite=c['foreground'])
            if c['lock']: item['lock'] = COLORS[c['lock']]
            if kind in PROTECTED:
                item['destructible'] = False
                if c['destructible']: note(c, 'Arrow/mover/alert box protected from blasts')
                if kind.startswith('mover_') and c['pieceId']: note(c, 'Mover protected from matching')
            if not c['movable'] and c['destructible'] and kind == 'rock':
                item['visual'] = 'cracked_stone'
            # Source IDs label every imported matching group, so even abstract
            # artwork and identical sprites with different IDs remain readable.
            if group > 0: item['match_label'] = str(group)
            if fg not in SHAPES and kind not in PROTECTED and not c['key'] and kind not in ('padlock', 'bomb'):
                note(c, f"Themed entity art: {c['foreground']} -> {kind}")
            items.append(item)
        if c['teleport']:
            if entity and kind != 'padlock':
                raise ValueError(f"{level['source']} ({x},{y}): movable/locked transport needs a dedicated override")
            code = c['teleportInput']
            if code not in INPUTS:
                raise ValueError(f"{level['source']} ({x},{y}): unknown input direction code {code}")
            target = [c['teleX'], c['teleY']]
            if not all(0 <= value < 12 for value in target):
                raise ValueError(f"{level['source']} ({x},{y}): invalid destination {target}")
            entry = INPUTS[code]
            if code == 0:
                teleports.append(dict(x=x, y=y, to=target, strict=True))
            else:
                pipes.append(dict(x=x, y=y, to=target, destination='cell',
                                  enter=entry, mouth=OPPOSITE[entry[0]]))
            if level['cells'][target[1] * 12 + target[0]]['obstacle'] == '1' and not is_entity(level['cells'][target[1] * 12 + target[0]]):
                note(c, 'Destination is source solid terrain; transport remains blocked until available')
    # Arrival-only endpoints have no active teleport flag in UZ3. Keep them
    # visible without creating a return route or changing floor movement.
    marked = {(t['x'], t['y']) for t in teleports + pipes}
    for entrance in list(teleports):
        x, y = entrance['to']
        if (x, y) not in marked and terrain[y][x] == '.':
            teleports.append(dict(x=x, y=y))
            marked.add((x, y))
    result = dict(version=2, name=level['name'], theme=theme, imported=True,
                  moves=level['targetMoves'] or 20, time=level['targetTime'] or 180,
                  terrain=[''.join(row) for row in terrain], items=items, pipes=pipes, teleports=teleports,
                  source=dict(format='UZ3', file=level['source'], number=number, sha256=level['sha256']))
    if any('p' in row for row in skins): result['skins'] = [''.join(row) for row in skins]
    return apply_theme_items(result), notes


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('source', type=Path)
    ap.add_argument('--start', type=int, default=17)
    ap.add_argument('--end', type=int, default=105)
    ap.add_argument('--output', type=Path)
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--replace', action='store_true', help='Replace existing destination levels (explicitly)')
    ap.add_argument('--report', type=Path)
    args = ap.parse_args()
    if not 1 <= args.start <= args.end <= 105: ap.error('Expected a range within 1–105')
    if args.write and args.output is None: ap.error('--write requires --output')
    outputs, report = [], []
    # Parse and convert every input before writing anything.
    for number in range(args.start, args.end + 1):
        path = args.source / f'LEVEL{number:03d}.UZ3'
        try:
            result, notes = convert(parse(path.read_bytes(), path.name), number)
        except (ValueError, OSError) as exc:
            ap.error(str(exc))
        relative = Path(f'world_{(number - 1) // 10 + 1:02d}') / f'level_{(number - 1) % 10 + 1:02d}.json'
        body = json.dumps(result, indent='\t', ensure_ascii=False) + '\n'
        outputs.append((relative, body))
        report.append(dict(number=number, path=str(relative), items=len(result['items']),
                           goals=sum(i['aim'] for i in result['items']), transports=len(result['pipes']) + sum('to' in t for t in result['teleports']),
                           exit_markers=sum('to' not in t for t in result['teleports']), notes=notes))
    if args.write:
        for relative, body in outputs:
            path = args.output / relative
            if path.exists() and path.read_text() != body and not args.replace:
                ap.error(f'Existing level differs: {path}; use --replace or a draft directory')
        for relative, body in outputs:
            path = args.output / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            temporary = path.with_suffix('.json.tmp')
            temporary.write_text(body)
            temporary.replace(path)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(f"{'Wrote' if args.write else 'Validated'} {len(outputs)} levels ({args.start}–{args.end}); "
          f"{sum(r['items'] for r in report)} items, {sum(r['transports'] for r in report)} transports.")


if __name__ == '__main__':
    main()
