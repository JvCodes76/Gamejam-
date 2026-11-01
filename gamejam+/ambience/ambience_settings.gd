class_name AmbienceSettings
extends RefCounted
## Persistent "Atmosphere effects" toggle (night lighting, fog, ambient particles and drop shadows).
## Saved in user://settings.cfg (section "graphics"); every change is announced on EventBus.ambience_toggled.

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "graphics"
const KEY: String = "atmosphere_effects"

static var _enabled: bool = true
static var _loaded: bool = false


## Returns true if the atmosphere effects are on (reads the saved value the first time).
static func is_enabled() -> bool:
	_ensure_loaded()
	return _enabled


## Turns the atmosphere effects on or off, saves the choice and notifies the levels.
static func set_enabled(enabled: bool) -> void:
	_ensure_loaded()
	if enabled == _enabled:
		return
	_enabled = enabled
	_save()
	print("[Ambience] - atmosphere effects %s" % ("on" if enabled else "off"))
	EventBus.ambience_toggled.emit(enabled)


# Reads the saved value once (missing file or key = on)
static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		_enabled = bool(config.get_value(SECTION, KEY, true))


# Writes only this key, keeping the other sections (audio volumes)
static func _save() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SECTION, KEY, _enabled)
	var err: Error = config.save(SETTINGS_PATH)
	if err != OK:
		push_error("[Ambience] - failed to save settings (error %d)" % err)
