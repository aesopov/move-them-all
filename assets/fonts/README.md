# Game fonts

- **Lapsus Pro Bold**: titles, headings, and buttons. The original OTF is bundled unchanged.
- **Andika Regular**: longer text, descriptions, counters, and other UI labels. `MergeUI.ttf` is a compact subset, renamed to respect Andika's reserved font names.

Both fonts use the SIL Open Font License 1.1, permit commercial embedding, and
cover every character in all seven current translation catalogs, including
Russian and Turkish. No system or network font fallback is needed for those texts.

Sources:
- https://www.1001fonts.com/lapsus-pro-font.html
- https://www.1001fonts.com/andika-font.html

Licenses are preserved in `OFL-LapsusPro.txt` and `OFL-Andika.txt` and included in
exports. Original source files are retained. Full `Andika-Regular.ttf` is excluded
from exports; regenerate its roughly 154 KiB UI subset with:

```
python3 tools/subset_ui_font.py
```

This requires fonttools. The build's glyph gate checks both body and display
fonts with system fallback disabled. `tools/test_localization.gd` checks layouts.
Previously evaluated Noto Sans and Inglobal files are not used by the theme and
are excluded from the Web export.
