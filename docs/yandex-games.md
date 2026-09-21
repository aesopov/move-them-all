# Yandex Games release

Build from the repository root:

```sh
python3 tools/build_yandex.py --godot /Applications/Godot.app/Contents/MacOS/Godot
```

Upload `export/yandex/merge-them-all.zip` to the Yandex Games draft. `index.html`
is at its root. The ZIP contains all hashed world packs and both audio worklets.
It deliberately omits duplicate `.gz` files, build reports and unused old packs.
The build rejects archives exceeding 100,000,000 bytes unpacked.
Normal website builds still use `tools/build_web.py` and do not load Yandex SDK.

The platform serves `/sdk.js`. The vendored JavaScript adapter comes from
[YandexGamesSDK4Godot](https://github.com/ineedmypills/YandexGamesSDK4Godot),
pinned with its MIT license under `web/yandex/vendor`. We use its browser bridge
without its optional editor/plugin, ads, payment or account modules.

SDK initialization completes before Godot starts, so the first menu uses
`environment.i18n.lang`, as required by
[rule 2.14](https://yandex.ru/dev/games/doc/ru/requirements/2/14).
Supported locales: ru, en, es, pt_BR, fr, de. Portuguese variants map to pt_BR;
unsupported languages use English. An explicitly saved player language overrides
automatic selection. Native and ordinary website builds retain device detection.

LoadingAPI.ready is emitted after the welcome screen has had two layout frames.
GameplayAPI tracks active levels, pause, completion, and leaving a level. SDK
pause events and browser focus loss stop the scene tree and mute audio; resume
restores the previous mute setting only when both pause causes have cleared.
The browser Quit button is hidden.

## Publishing materials

`publishing/yandex/` contains:
- `store-copy.md` and `.json`: six localized listings, validated character limits.
- `icon-512.png`: 512×512 opaque PNG.
- `cover-800x470.png`: 800×470 opaque PNG.
- `screenshot-landscape-01.png`, `-02.png`: 1280×720 actual gameplay.
- `screenshot-portrait-01.png`, `-02.png`: 720×1280 actual gameplay.
- `gameplay-landscape.mp4`, `gameplay-portrait.mp4`: actual gameplay recordings.
- Artwork originals and generation prompts for future edits.

Use desktop + mobile platforms, both orientations, the six supported languages,
and puzzle/logic categories. Cloud saves are not implemented: progress remains
in browser storage. Ads and purchases are not enabled by this integration.

Media dimensions/durations and ZIP budget follow the
[official draft requirements](https://yandex.ru/dev/games/doc/ru/console/add-new-game/draft).
No materials or build have been submitted to the developer console.

## Validation

Local exported-browser tests use a mocked SDK response (Russian SDK language
with English browser language), verify ready/start/stop/resume, and load actual
world packs. Packaging tests check audio worklets, SDK ordering and relative
world assets. Localization tests cover all six catalogs.

Final verification must happen in the Yandex draft environment with the real
SDK: language preview, cold/warm loading, audio pause/resume, portrait/landscape,
and progress retention. Local mocks cannot certify platform moderation.
For local real-SDK testing use the official SDK dev proxy; `/sdk.js` is supplied
by Yandex and intentionally is not included in the ZIP.

## Updating the displayed name manually

Keep `project.godot` config/name as the internal project identifier to preserve the existing native save directory. Change the Title label in `scenes/welcome.tscn` and the corresponding row in `localization/messages.csv`. Current key: `Pair Up`, English: `Pair Up`, Russian: `Найди пару`; other supported locales use `Pair Up` until a localized name is chosen. `scripts/ui/locale.gd` applies the localized window/browser title. `tools/build_web.py` sets the initial HTML title. Then run the build command above and upload the new ZIP. Turkish currently has a localized cover only, not an in-game catalog.
