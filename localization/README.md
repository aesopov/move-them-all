# Localization

Seven supported languages: English (`en`), Spanish (`es`), Brazilian Portuguese (`pt_BR`), French (`fr`), German (`de`), Turkish (`tr`), and Russian (`ru`).

`messages.csv` is the editable source of truth. Godot imports it into the seven `.translation` resources listed in `project.godot`. Keep the source, import configuration and generated translation resources together. Use `tr()` before interpolating parameters in scripts; ordinary Control labels translate automatically. Internal item IDs, terrain IDs, saved progress, and custom level contents stay unchanged. The display title is “Pair Up”, “Найди пару” in Russian, and “Eşini Bul” in Turkish. Internal project identifiers stay unchanged.

The Locale autoload runs before App. First launch uses the device locale. Regional variants map to their supported language; all Portuguese variants use Brazilian Portuguese and Turkish regional variants use Turkish. Unsupported languages use English. The welcome screen language selector saves an explicit choice or Automatic mode to `user://language.cfg`, separate from progress. Changing it reloads only the welcome screen. Invalid saved values revert to Automatic. `-- --locale=ru` is a session-only debug override outside Yandex. On Yandex, the SDK language takes priority over saved preferences and debug overrides, and the selector is hidden.

The theme uses Lapsus Pro Bold for titles and buttons and a renamed Andika Regular subset (`MergeUI.ttf`) for body text. Both cover all seven catalogs, including Russian and Turkish. See [font sources, licenses, and regeneration](../assets/fonts/README.md). Full Andika is excluded from exports; both SIL licenses are included.

Validation:

```
python3 tools/check_localization.py
godot --headless --path . --script tools/test_localization.gd
godot --path . --script tools/preview_localization.gd
```

The automated checks cover catalog completeness, format placeholders, all built-in level titles, font glyph coverage with system fallback disabled, locale mapping, preference persistence, portrait scenes, result dialogs and rotation. Preview output goes to `/tmp/locale_*.png`. Existing mobile, drag, rule and editor tests also apply. Translations were authored for this implementation; independent native-speaker review has not been performed.

Godot references: [Internationalizing games](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html), [TranslationServer](https://docs.godotengine.org/en/stable/classes/class_translationserver.html), [FontVariation](https://docs.godotengine.org/en/stable/classes/class_fontvariation.html).
