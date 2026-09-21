class_name LevelAssets
extends Node
## Content-addressed world packs. Native/editor exports remain self-contained.
const MANIFEST := "res://asset_packs.json"
const CACHE := "user://asset_packs"
static var mounted := {}
static var active: LevelAssets
var background := false
var requested_theme := ""
var cancelled := false
var progress: Label
var error_text := ""

func ensure_theme(theme: String, download_only := false) -> bool:
	background = download_only
	requested_theme = theme
	while is_instance_valid(active):
		if download_only: return true # Speculative requests never queue behind gameplay.
		if active.background and active.requested_theme != theme: active.cancelled = true
		await get_tree().process_frame
	active = self
	var result := await _prepare(theme, download_only)
	active = null
	return result

func _prepare(theme: String, download_only: bool) -> bool:
	if not FileAccess.file_exists(MANIFEST): return true
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not manifest is Dictionary or not manifest.get("themes", {}).has(theme):
		error_text = tr("Could not load level assets.")
		return false
	var entry: Dictionary = manifest.themes[theme]
	if mounted.has(entry.sha256): return true
	DirAccess.make_dir_recursive_absolute(CACHE)
	var local := CACHE.path_join(str(entry.file).get_file())
	if FileAccess.file_exists(local) and FileAccess.get_sha256(local) != entry.sha256:
		DirAccess.remove_absolute(local)
	if not FileAccess.file_exists(local):
		var http := HTTPRequest.new()
		add_child(http)
		http.timeout = 120
		# Browser fetch already decodes Content-Encoding before exposing bytes.
		http.accept_gzip = not OS.has_feature("web")
		var base := ""
		if OS.has_feature("web"):
			base = str(JavaScriptBridge.eval("new URL('.', window.location.href).href"))
		else:
			# Used by exported-pack integration tests.
			base = OS.get_environment("ASSET_PACK_BASE_URL")
		if base == "":
			error_text = tr("Could not load level assets.")
			http.queue_free()
			return false
		var completed: Array = []
		http.request_completed.connect(func(result, status, headers, body): completed.append([result, status, headers, body]))
		var err := http.request(base + str(entry.file))
		if err == OK:
			while completed.is_empty():
				if cancelled:
					http.cancel_request()
					http.queue_free()
					return false
				if progress:
					progress.text = tr("Loading level assets…") + " %d%%" % clampi(int(100.0 * http.get_downloaded_bytes() / maxf(1, entry.bytes)), 0, 100)
				await get_tree().process_frame
		http.queue_free()
		if err == OK and not completed.is_empty() and completed[0][0] == HTTPRequest.RESULT_SUCCESS and completed[0][1] == 200:
			var download := FileAccess.open(local + ".part", FileAccess.WRITE)
			if download:
				download.store_buffer(completed[0][3])
				download.close()
		if err != OK or completed.is_empty() or completed[0][0] != HTTPRequest.RESULT_SUCCESS or completed[0][1] != 200 or FileAccess.get_sha256(local + ".part") != entry.sha256:
			push_warning("Asset download failed: request=%s response=%s checksum=%s" % [err, completed[0].slice(0, 2) if not completed.is_empty() else [], FileAccess.get_sha256(local + ".part")])
			DirAccess.remove_absolute(local + ".part")
			error_text = tr("Could not load level assets.")
			return false
		var rename_error := DirAccess.rename_absolute(local + ".part", local)
		if rename_error != OK:
			push_warning("Asset cache rename failed: %s" % rename_error)
			error_text = tr("Could not load level assets.")
			return false
	if OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
	if download_only: return true # Keep decoded textures out of memory until entry.
	if not ProjectSettings.load_resource_pack(local, false):
		push_warning("Asset pack mount failed: " + local)
		DirAccess.remove_absolute(local)
		error_text = tr("Could not load level assets.")
		return false
	mounted[entry.sha256] = true
	AssetLib.clear_missing()
	# Decode ahead of drawing, yielding between textures to keep loading UI responsive.
	for asset in entry.assets:
		if progress: progress.text = tr("Preparing level…")
		AssetLib.texture(asset)
		await get_tree().process_frame
	return true
