"""Check translation completeness, placeholder safety, and built-in level titles."""
import csv
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
with (root / 'localization/messages.csv').open() as f:
    rows = list(csv.reader(f))
assert rows[0] == ['keys', 'en', 'es', 'pt_BR', 'fr', 'de', 'ru']
keys = set()
for row in rows[1:]:
    assert len(row) == 7 and all(row), row
    assert row[0] not in keys, f'Duplicate key: {row[0]}'
    keys.add(row[0])
    placeholders = re.findall(r'%(?:\d+)?[dsf]', row[0])
    for locale, text in zip(rows[0][1:], row[1:]):
        assert re.findall(r'%(?:\d+)?[dsf]', text) == placeholders, (locale, row[0])
for path in (root / 'levels').glob('world_*/*.json'):
    assert json.loads(path.read_text())['name'] in keys, path
for path in (root / 'scripts').rglob('*.gd'):
    for key in re.findall(r'\b(?:tr|translate)\("([^"\n]+)"\)', path.read_text()):
        assert key in keys, (path, key)
print(f'{len(keys)} messages × 6 languages; placeholders and level titles verified')
