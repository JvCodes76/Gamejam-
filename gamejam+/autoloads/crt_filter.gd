extends CanvasLayer
## Full-screen CRT post-process filter drawn above everything (autoload "CrtFilter").
## Enabled flag and intensity are saved in user://settings.cfg (section "graphics").

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "graphics"
const KEY_ENABLED: String = "crt_enabled"
const KEY_INTENSITY: String = "crt_intensity"
const SHADER: Shader = preload("res://assets/shaders/crt.gdshader")

var _enabled: bool = false
var _intensity: float = 0.5
var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = 128 # above every menu/HUD layer
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)
	_load()
	_apply()


func is_enabled() -> bool:
	return _enabled


func get_intensity() -> float:
	return _intensity


func set_enabled(enabled: bool) -> void:
	if enabled == _enabled:
		return
	_enabled = enabled
	_apply()
	_save()
	print("[CRT] - filter %s" % ("on" if enabled else "off"))


## Intensity in 0..1, applied live. Call save_settings() to persist (the settings menu does it on close).
func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	_apply()


func save_settings() -> void:
	_save()


func _apply() -> void:
	_rect.visible = _enabled and _intensity > 0.0
	_material.set_shader_parameter("intensity", _intensity)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		_enabled = bool(config.get_value(SECTION, KEY_ENABLED, false))
		_intensity = clampf(float(config.get_value(SECTION, KEY_INTENSITY, 0.5)), 0.0, 1.0)


# Writes only these keys, keeping the other sections
func _save() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SECTION, KEY_ENABLED, _enabled)
	config.set_value(SECTION, KEY_INTENSITY, _intensity)
	var err: Error = config.save(SETTINGS_PATH)
	if err != OK:
		push_error("[CRT] - failed to save settings (error %d)" % err)
