# Yandex Games release

First install the custom Web release template using the one-time
[template build instructions](web-streaming.md#smaller-release-template-and-backgrounds).
It is generated locally and is not stored in Git.

Build from the repository root:

```sh
./tools/build_yandex.sh
```

The script detects Godot on PATH or in the standard macOS application location.
Use `GODOT=/path/to/godot ./tools/build_yandex.sh` to override it. Python 3 is required.
For the website, run `./tools/build_web.sh`: it prepares `export/web/` and
`export/merge-them-all-web.zip`, with gzip files and only the current world packs in the ZIP.
Both scripts work from any current directory when invoked by their path.

Upload `export/yandex/merge-them-all.zip` to the Yandex Games draft. `index.html`
is at its root. The ZIP contains all hashed world packs and both audio worklets.
It deliberately omits duplicate `.gz` files, build reports and unused old packs.
The build rejects archives exceeding 100,000,000 bytes unpacked.
Normal website builds still use `tools/build_web.py` and do not load Yandex SDK.

The platform serves `/sdk.js`. The vendored JavaScript adapter comes from
[YandexGamesSDK4Godot](https://github.com/ineedmypills/YandexGamesSDK4Godot),
pinned with its MIT license under `web/yandex/vendor`. We use its browser bridge
without its optional editor/plugin, ads, payment or account modules. Our own
`purchases.js` uses the official SDK directly for purchases.

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
and puzzle/logic categories. Progress and purchase credits use Yandex cloud saves
with the recovery behavior below. Ads are not enabled by this integration.

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
Debug builds retain unrestricted level access. Purchases are available only in
the Yandex package; use a release build to test level locking.

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
Paid skips are separate from this free-skip history and use the SDK receipt ledger
described below; the local progress journal cannot grant paid credits.

The legacy Godot save is imported once per browser. Non-Yandex builds keep using
`user://progress.json`, with automatic migration from the old score-only dictionary.
SDK/cloud tests: `node tools/test_yandex_progress.cjs`. Progression tests:
`godot --headless --path . --script tools/test_progress.gd`.


## In-app purchases

The products in `localization/yandex-purchases.csv` use the imported console IDs:

- `skips_5`: five single-use credits, consumed after free slots are exhausted.
- `unlock_world_01` through `unlock_world_11`: permanent access to every level in the named world.
- `unlock_all_levels`: permanent access to all current and future campaign levels.

The release loads `purchases.js` and `shop.js` before `platform.js`. Recovery starts
on **every game launch**, independently of opening the shop. It also runs before
checkout, before paid spending, after reconnect/focus, and after a failed checkout
response. Failed operations retry after 30 seconds. Godot startup is not held up
by the purchase service. Shop controls stay unavailable until recovery succeeds.
The player can close the shop while recovery is pending.

Recovery follows the [official purchase SDK documentation](https://yandex.ru/dev/games/doc/ru/sdk/sdk-purchases#check-purchases):

1. Initialize `getPayments({signed: false})`, acquire the player, and read the cloud ledger.
2. Call `getPurchases()` and restore permanent entitlements without consuming them.
3. For each `skips_5` receipt, save its unique `purchaseToken` to `pairUpPurchasesV1`
   with `player.setData(..., true)`. Each receipt represents five numbered credit slots.
4. Only after that save succeeds, call `consumePurchase(token)`. If the token was
   already saved, retry consumption without granting credits again.

A failed read never overwrites cloud purchases. A failed write never consumes a
receipt. A failed consumption leaves the receipt available for retry. A lost save
acknowledgment is resolved by rereading the ledger, so the receipt is not credited
twice. Unknown product IDs remain untouched. An account change clears the purchase
view and asks the player to reload before using the new account's purchases.

Spending a credit records its slot and level path together in the same cloud save.
That record restores both the reduced balance and skipped-level access after a
crash, even if the normal progression save did not run. Completing a paid-skipped
level does not refund a free slot or a paid credit. Purchase ownership never awards
completion scores or automatically unlocks neighboring worlds. Completing or
skipping a level opens its immediate successor, including across a purchased
world boundary, even if earlier worlds remain unfinished. Skips are offered only
when the next level is locked. Unlock-all removes redundant skip
and world offers; naturally unlocked worlds are not offered for sale.

Shop entry points: the level-selection Shop button, each locked world's button,
and Pause → Get extra skips when free skips are exhausted. The shop uses the
SDK catalog's localized title, description, price and currency image, plus the
three bundled purchase icons. Its controls support all seven game languages.
Opening it pauses gameplay and audio until both shop and SDK pause causes clear.
Ordinary web/native builds do not load or show the shop.

This is the SDK-supported **client-side** fulfillment flow, not a trusted economy
server. Paid operations require a successful cloud read/write. Writes are queued
and Web Locks serialize cooperating tabs on the same browser. Yandex player data
has no cross-device compare-and-swap: simultaneous spending or fulfillment on
separate devices is not transactionally protected. A signed-receipt backend with
an atomic ledger is needed for tamper resistance and strict multi-device monetary
consistency; do not put the signing secret in the client.

Validation:

```sh
node tools/test_yandex_purchases.cjs
node tools/test_yandex_progress.cjs
python3 tools/test_yandex_package.py
python3 tools/check_localization.py
godot --headless --path . --script tools/test_progress.gd
godot --headless --path . --script tools/test_localization.gd
./tools/build_yandex.sh
```

Before publishing, test with the real SDK in the Yandex draft: cancel checkout;
buy each product type; reload immediately after payment; disconnect during
fulfillment and reconnect; verify pending skip receipts disappear only after
credits are saved; restore permanent purchases on another device; spend a paid
skip after using five free skips. Local tests use a mocked SDK and make no real
charges. The ZIP does not include the mock SDK or a signing secret.
