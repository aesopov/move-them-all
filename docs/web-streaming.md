# Web asset streaming

In Godot, choose **Project → Tools → Build optimized Web release**. The editor reports completion and writes progress to `export/web-build.log`. Alternatively, build with:

```sh
python3 tools/build_web.py --godot /Applications/Godot.app/Contents/MacOS/Godot
```

Publish **all of `export/web/`, including `packs/`**. Exporting Web directly from the Godot export dialog produces a standalone build in **`export/standalone/`**, so it cannot overwrite the optimized release by default. The split build is an additional packaging step, not a change to native exports.

The build uses Godot's exported ZIP as its source of truth, partitions the imported resources and their remaps, and uses `PCKPacker` to create a bootstrap pack and 12 theme packs. Every exported file is retained exactly once. Shared items, UI, a compact font, level definitions, baked pipe shapes, and small menu background previews remain in the bootstrap. Theme tiles and other backgrounds load when entering that theme. Portrait and landscape art share a pack so rotation never waits for a download.

Each theme pack has a content-hashed filename and a full SHA-256 in the bundled manifest. Before switching scenes, the loader reuses a verified local cache or downloads the pack, verifies it, mounts it, and decodes its textures a frame at a time. Failure leaves the current scene intact and offers Retry and Back. Missing-resource cache entries are cleared after mounting. A loading screen replaces incomplete board rendering. Editor theme previews also request missing packs.

Godot supports [mounting PCK resources at runtime](https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html). On Web, the loader saves in `user://`, then requests [persistent filesystem synchronization](https://docs.godotengine.org/en/stable/classes/class_javascriptbridge.html#class-javascriptbridge-method-force-fs-sync). Browser storage can still be cleared or evicted; in that case the pack downloads again. Cached resources are not an offline guarantee for the entire game.

## Hosting

- Serve packs on the same origin/path as the exported HTML; relative deployment under a subdirectory is supported.
- Hashed `packs/*` can use `Cache-Control: public, max-age=31536000, immutable`.
- Revalidate `index.html`, `index.js`, and `index.pck` so a deployment cannot mix an old manifest and new assets. An example `_headers` file is generated for hosts that support that format.
- Deploy atomically and retain older hashed packs while old sessions might reference them. The build intentionally does not delete older packs in the output directory.
- Enable HTTP Brotli/gzip for `.wasm`, `.js`, and `.pck` on your host. The engine WASM download is separate from PCK size and is not reduced by splitting artwork.
- The checked-in export preset remains standalone. Use the build command above for streaming deployments.

## Pipes

Procedural textures previously included board position and length in cache keys and ran per-pixel geometry/noise in draw callbacks. Runtime drawing now uses 36 baked neutral shapes with the same tinting and lighting; stretches reuse a canonical texture. This avoids generating new images after layout, rotation, or zoom. Long segments stretch the material grain slightly. The procedural generator remains the source of truth and fallback for development:

```sh
godot --headless --path . --script tools/bake_pipes.gd
godot --headless --path . --editor --quit
```

Regenerate after editing pipe geometry/material. `tools/test_pipe_art.gd` checks geometry, lighting, joins, and that all tested runtime shapes use baked assets.

## Checks

- `python3 -m unittest discover -s tools -p 'test_web_split.py'`
- `godot --headless --path . --script tools/test_pipe_art.gd`
- `godot --headless --path . --script tools/test_mobile.gd`
- In a browser: open a level on a cold cache, reload it, visit another world, and block a pack request to exercise Retry/Back. Check network traffic and the console, not only the loading animation.

Validated the exported build in Chromium/WebGL at 480×854: a cold desert level requested one pack, reloading requested none, and blocking then retrying a waterfall pack restored the complete pipe-heavy level. Native pack mounting and theme-texture lookup also passed. These checks are not a measurement on physical mobile hardware.


## Compressed delivery and Yandex Object Storage

The build now generates deterministic `.gz` files for the engine, scripts, base
pack, and world packs. `build-report.json` records original hashes and raw/compressed
sizes. It refuses bootstrap packs larger than 10 MiB to catch a broken split.

Preview compressed delivery locally with `make serve-web`, then open
`http://127.0.0.1:8766/`. This is a development server, not production hosting.

For the Yandex bucket, install/configure AWS CLI for your account and inspect the
upload plan first:

```sh
python3 tools/upload_web.py --bucket merge-them-all
python3 tools/upload_web.py --bucket merge-them-all --upload
```

The second command publishes. The helper verifies the build hashes and gzip
contents, uploads compressed bytes under the original object names (for example,
`index.wasm.gz` as `index.wasm`), sets `Content-Encoding: gzip` and the correct
`Content-Type`, and uploads HTML last. It keeps older hashed world packs and never
deletes objects or changes bucket permissions. Publishing is not an atomic bucket
swap; existing sessions should be considered when deploying engine changes.

A `_headers` text file alone does not configure Yandex object metadata. Uploading
`.gz` siblings alongside raw objects also does not make browsers request them.
Use the helper's metadata settings or equivalent settings in your upload tool.

Observed on the live site on September 20, 2026 (Moscow): `index.wasm` was
39,513,091 bytes, served as `application/octet-stream`, without Content-Encoding;
`index.pck` was 67,801,600 bytes, also uncompressed. The rebuilt bootstrap is about
24.98 MiB raw / 22.59 MiB gzip, and WASM is 37.68 MiB raw / 9.59 MiB gzip. Combined
initial PCK + engine transfer drops from about 102 MiB to 32 MiB after deployment;
world packs are additional when first used. These are byte counts, not promised
load times.

Compressed-delivery validation: Chromium loaded the gzip bootstrap, engine, and theme pack successfully; a cold visit requested one pack and reload requested zero. The Web HTTPRequest disables its own gzip decoder because browser fetch has already decoded the response. Delivery tests also verify MIME/encoding headers, gzip refusal fallback, upload metadata, and stale-file rejection.


## Smaller cold start (September 20)

The new bootstrap is **7.33 MiB raw / 5.00 MiB gzip**, down from 24.98 / 22.59.
Together with the unchanged 9.59 MiB gzip engine, startup transfer is now about
**14.6 MiB**, down from 32.2 MiB (55% smaller). The engine is now the largest
remaining download; a custom 2D-only Godot template is the next major opportunity.

`assets/fonts/MergeUI.ttf` is a 210 KiB static medium-weight subset derived from
NotoSansSC, with original license/name credits retained. It contains every current
translation and game text character plus supported Latin/Cyrillic ranges. The
original font remains in the source project and is excluded from exports. System
fallback remains enabled for custom text outside this subset. The build checks
translation glyph coverage with system fallback disabled and fails on missing
glyphs. After adding new translated characters, regenerate it:

```sh
python3 -m venv /tmp/merge-font-tools
/tmp/merge-font-tools/bin/pip install -r tools/requirements-fonts.txt
/tmp/merge-font-tools/bin/python tools/subset_ui_font.py
```

Welcome and level-select screens use 640-pixel menu previews. They do not request
full-size world artwork. Full-resolution portrait/landscape backgrounds now live
in every world's pack, including waterfall and nexus. Regenerate previews with:

```sh
godot --headless --path . --script tools/bake_menu_backgrounds.gd
```

Menu previews are an intentional quality/download tradeoff; in-level backgrounds
and source artwork are unchanged. Cold level entry still downloads its world pack
(roughly 1.7–4.5 MiB), then reuses it on later visits. These figures describe file
sizes, not a guaranteed time on any connection.

## Background preloading and startup screen

After one second on the welcome screen, App preloads the theme pack for the
first unfinished built-in level (using saved scores). On a world's last level,
it preloads the first level's theme in the following world. Completed campaigns
and custom levels do not trigger speculative downloads.

LevelAssets serializes downloads. Foreground entry into the same theme waits for
and reuses the in-flight preload; entry into another theme cancels the speculative
request. Other speculative requests are dropped while a download is active.
Preloading validates and persists the pack but does not mount or decode textures.
Failures do not show gameplay dialogs; foreground entry can retry normally.

`web/loading/shell.html` is the Godot Web custom shell for both export types.
It embeds a small WebP icon, CSS background, translated title/loading label,
engine byte-progress bar, failure details and retry button. The Yandex packager
inserts SDK scripts after the loader markup; its language updates after SDK init.
The loader fades away after engine startup. Native startup is unchanged.

Validation: `godot --headless --path . --script tools/test_asset_preload.gd` checks
preload/foreground scheduling, same-theme reuse ordering and cancellation.
