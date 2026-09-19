# Localization

Seven supported languages: English (`en`), Spanish (`es`), Brazilian Portuguese (`pt_BR`), French (`fr`), German (`de`), Simplified Chinese (`zh_CN`), and Russian (`ru`).

`messages.csv` is the editable source of truth. Godot imports it into the seven `.translation` resources listed in `project.godot`. Keep the source, import configuration and generated translation resources together. Use `tr()` before interpolating parameters in scripts; ordinary Control labels translate automatically. Internal item IDs, terrain IDs, saved progress, and custom level contents stay unchanged. The title “Merge Them All” remains the brand name in all languages.

The Locale autoload runs before App. First launch uses the device locale. Regional variants map to their supported language; all Portuguese variants use Brazilian Portuguese and all Chinese variants use Simplified Chinese. Unsupported languages use English. The welcome screen language selector saves an explicit choice or Automatic mode to `user://language.cfg`, separate from progress. Changing it reloads only the welcome screen. Invalid saved values revert to Automatic. `-- --locale=ru` is a session-only debug override.

The bundled Noto Sans SC variable font covers the catalog's Latin, Cyrillic and Chinese characters without relying on installed system fonts. Its weight is set to 500 using the numeric OpenType `wght` tag. Source: [Google Fonts Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc). The SIL Open Font License is included in `assets/fonts/OFL-NotoSansSC.txt`.

Validation:

```
python3 tools/check_localization.py
godot --headless --path . --script tools/test_localization.gd
godot --path . --script tools/preview_localization.gd
```

The automated checks cover catalog completeness, format placeholders, all built-in level titles, font glyph coverage with system fallback disabled, locale mapping, preference persistence, portrait scenes, result dialogs and rotation. Preview output goes to `/tmp/locale_*.png`. Existing mobile, drag, rule and editor tests also apply. Translations were authored for this implementation; independent native-speaker review has not been performed.

Godot references: [Internationalizing games](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html), [TranslationServer](https://docs.godotengine.org/en/stable/classes/class_translationserver.html), [FontVariation](https://docs.godotengine.org/en/stable/classes/class_fontvariation.html).
