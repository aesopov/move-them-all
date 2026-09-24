"""Apply campaign art substitutions without changing item behavior.

Only substitute ordinary, non-gravitating default types. Imported behavior
and matching overrides are retained. Destinations are unused in these worlds
before substitution, so handcrafted type-based groups cannot merge together.
"""
import json
from pathlib import Path

REPLACEMENTS = {
    'jungle': {'sphere': 'crystal'},
    'waterfall': {'pyramid': 'crystal'},
    'desert': {'pyramid': 'crystal', 'torus': 'cube'},
    'ice': {'pyramid': 'crystal'},
    'cave': {'pyramid': 'crystal'},
    'swamp': {'pyramid': 'crystal'},
    'sky': {'star': 'cube'},
}


def apply(level):
    replacements = REPLACEMENTS.get(level.get('theme'), {})
    for item in level.get('items', []):
        item['type'] = replacements.get(item['type'], item['type'])
    return level


if __name__ == '__main__':
    changed = []
    for path in sorted(Path('levels').glob('world_*/*.json')):
        original = path.read_text()
        level = json.loads(original)
        before = json.dumps(level)
        apply(level)
        if json.dumps(level) != before:
            path.write_text(json.dumps(level, indent='\t', ensure_ascii=False) + '\n')
            changed.append(str(path))
    print('\n'.join(changed))
    print(f'Updated {len(changed)} levels')
