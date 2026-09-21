#!/usr/bin/env python3
"""Generate the bundled UI font. Requires fonttools; original font is retained.
Regenerate after adding translations. All supported Latin/Cyrillic characters
are retained; other coverage follows the game's text. Custom text uses OS fallback.
"""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools import subset

ROOT = Path(__file__).resolve().parents[1]

def main():
    characters = set(range(0x20, 0x250)) | set(range(0x300, 0x530))
    for folder, extensions in [('localization', {'.csv'}), ('scripts', {'.gd'}), ('scenes', {'.tscn'}), ('levels', {'.json'})]:
        for path in (ROOT / folder).rglob('*'):
            if path.suffix in extensions: characters.update(map(ord, path.read_text()))
    font = TTFont(ROOT / 'assets/fonts/Andika-Regular.ttf', recalcTimestamp=False)
    options = subset.Options()
    options.name_IDs = ['*']
    options.name_legacy = True
    options.name_languages = ['*']
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=characters)
    subsetter.subset(font)
    # Distinguish the modified font, retaining copyright/license names and text.
    for record in font['name'].names:
        if record.nameID in (1, 3, 4, 6, 16, 17):
            text = 'MergeUI-Regular' if record.nameID == 6 else ('Regular' if record.nameID == 17 else 'Merge UI Regular')
            record.string = text.encode(record.getEncoding())
    destination = ROOT / 'assets/fonts/MergeUI.ttf'
    font.save(destination)
    print(f'{destination.name}: {destination.stat().st_size / 1024:.0f} KiB, {len(font.getBestCmap())} characters')

if __name__ == '__main__': main()
