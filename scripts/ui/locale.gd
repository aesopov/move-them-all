extends Node
## Language preference is independent of progress and never changes level data.
const CODES := ["en", "es", "pt_BR", "fr", "de", "ru"]
const NAMES := ["English", "Español", "Português (Brasil)", "Français", "Deutsch", "Русский"]
const SETTINGS_PATH := "user://language.cfg"
var preference := "auto"

func _ready() -> void:
	preference = read_preference(SETTINGS_PATH)
	apply()
	# A session-only override for screenshots/tests; never writes a preference.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--locale="):
			TranslationServer.set_locale(resolve(arg.get_slice("=", 1)))
			_update_title()

func resolve(device_locale: String) -> String:
	var language := device_locale.replace("-", "_").to_lower().get_slice("_", 0)
	match language:
		"pt": return "pt_BR"
		"en", "es", "fr", "de", "ru": return language
	return "en"

func apply() -> void:
	TranslationServer.set_locale(resolve(Platform.language() if not Platform.language().is_empty() else OS.get_locale()) if preference == "auto" else preference)

	_update_title()

func _update_title() -> void:
	var title := tr("Pair Up")
	get_window().title = title
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("document").title = title

func read_preference(path: String) -> String:
	var settings := ConfigFile.new()
	if settings.load(path) != OK:
		return "auto"
	var code := str(settings.get_value("language", "locale", "auto"))
	return code if code == "auto" or code in CODES else "auto"

func select(code: String, path := SETTINGS_PATH) -> Error:
	if code != "auto" and not code in CODES:
		return ERR_INVALID_PARAMETER
	var settings := ConfigFile.new()
	settings.set_value("language", "locale", code)
	var error := settings.save(path)
	if error != OK:
		return error
	preference = code
	apply()
	return OK
