# Yandex Games release

First install the custom Web release template using the one-time
[template build instructions](web-streaming.md#smaller-release-template-and-backgrounds).
It is generated locally and is not stored in Git.

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
Supported locales: ru, en, es, pt_BR, fr, de, tr. Portuguese variants map to pt_BR;
unsupported languages use English. Yandex builds always use the SDK language,
ignore saved language preferences, and hide the welcome-screen language selector.
Native and ordinary website builds retain device detection and manual selection.

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

Keep `project.godot` config/name as the internal project identifier to preserve the existing native save directory. Change the Title label in `scenes/welcome.tscn` and the corresponding row in `localization/messages.csv`. Current key: `Pair Up`, English: `Pair Up`, Russian: `Найди пару`, Turkish: `Eşini Bul`; other supported locales use `Pair Up` until a localized name is chosen. `scripts/ui/locale.gd` applies the localized window/browser title. `tools/build_web.py` sets the initial HTML title. Then run the build command above and upload the new ZIP. Turkish includes a complete in-game catalog and localized cover.

## Development-only level designer

The welcome and level-selection screens expose the Level Designer only in debug
builds. Release builds also reject the editor scene route and omit custom designer
levels from the level catalogue. The editor remains available when running the
project in Godot or exporting a debug build.

## Campaign progress and free skips

Release builds unlock the campaign in order. Completing or skipping a level unlocks
its successor. Up to five skipped levels can remain unfinished at a time. Completing
a skipped level awards its normal score and restores one free skip. Replaying it
again does not restore additional skips.
Skipped levels remain selectable and are marked separately from completed levels.
Use Pause → Skip level, then confirm. The final campaign level cannot be skipped.
Debug builds retain unrestricted level access. No purchases are implemented yet.

Progress schema v1 stores `scores` (best score by level path) and `skipped` (unique
paths ever skipped). Unlocks and the remaining allowance are derived from these
values: only skipped paths with no completion score consume a slot. Existing saves
automatically gain the correct allowance without a migration. Skipping alone never
records a level as completed.

The Yandex release uses `ysdk.getPlayer()`, `player.getData(['pairUpProgress'])`,
and `player.setData({pairUpProgress: ...}, true)` without requesting profile access
or showing a sign-in dialog. Initialization attempts to load progress before Godot
starts, with a bounded wait. A per-player localStorage journal preserves pending
changes. Failed reads never trigger a write until a successful read has been merged;
failed writes retry. Writes are serialized and throttled. Scores merge by maximum,
skips by set union. Concurrent offline sessions may spend their cached allowances;
reconciliation retains skip history and counts only unfinished skipped levels,
clamping the remaining allowance to zero.
Future paid credits must use verified purchase fulfillment, not a writable local
balance.

The legacy Godot save is imported once per browser. Non-Yandex builds keep using
`user://progress.json`, with automatic migration from the old score-only dictionary.
SDK/cloud tests: `node tools/test_yandex_progress.cjs`. Progression tests:
`godot --headless --path . --script tools/test_progress.gd`.
