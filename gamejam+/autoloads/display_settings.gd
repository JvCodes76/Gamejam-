extends Node
## Window mode (windowed / fullscreen), VSync and pixel-perfect scaling (autoload "DisplaySettings").
## Saved in user://settings.cfg (section "display"). F11 or Alt+Enter toggles fullscreen anywhere.

signal changed()

enum WindowMode { WINDOWED, FULLSCREEN }

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "display"
const KEY_MODE: String = "window_mode"
const KEY_VSYNC: String = "vsync"
const KEY_PIXEL_PERFECT: String = "pixel_perfect"

const MODE_LABELS: Array[String] = ["Windowed", "Fullscreen"]

var _mode: WindowMode = WindowMode.WINDOWED
var _vsync: bool = true
var _pixel_perfect: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		return
	_load()
	# Browsers only allow fullscreen from a click/key press, so the web build always opens windowed
	if OS.has_feature("web"):
		_mode = WindowMode.WINDOWED
	_apply_all()


# F11 / Alt+Enter: quick windowed <-> fullscreen toggle
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F11 or (key.keycode == KEY_ENTER and key.alt_pressed):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


## True when the game runs inside the editor's Game tab: the window there belongs to the editor,
## so mode changes are saved but only take effect in a standalone run or export.
func is_window_locked() -> bool:
	return Engine.is_embedded_in_editor()


func get_mode() -> WindowMode:
	return _mode


func is_vsync_enabled() -> bool:
	return _vsync


func is_pixel_perfect() -> bool:
	return _pixel_perfect


func set_mode(mode: WindowMode) -> void:
	_mode = mode
	_apply_window()
	_save()
	print("[Display] - window mode: %s" % MODE_LABELS[mode])
	changed.emit()


func set_vsync(enabled: bool) -> void:
	_vsync = enabled
	_apply_vsync()
	_save()
	print("[Display] - vsync %s" % ("on" if enabled else "off"))
	changed.emit()


func set_pixel_perfect(enabled: bool) -> void:
	_pixel_perfect = enabled
	_apply_scaling()
	_save()
	print("[Display] - pixel perfect %s" % ("on" if enabled else "off"))
	changed.emit()


func toggle_fullscreen() -> void:
	set_mode(WindowMode.FULLSCREEN if _mode == WindowMode.WINDOWED else WindowMode.WINDOWED)


func _apply_all() -> void:
	_apply_window()
	_apply_vsync()
	_apply_scaling()


# Fullscreen is borderless at the monitor's native size (fast alt-tab); leaving it restores the
# previous window size (1280x720 by default, from the project settings)
func _apply_window() -> void:
	if is_window_locked():
		print("[Display] - running embedded in the editor: window mode saved but not applied")
		return
	get_window().mode = Window.MODE_FULLSCREEN if _mode == WindowMode.FULLSCREEN else Window.MODE_WINDOWED


func _apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _vsync else DisplayServer.VSYNC_DISABLED)


# Integer scaling keeps every pixel the same size (black bars on non-multiple sizes)
func _apply_scaling() -> void:
	get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if _pixel_perfect \
		else Window.CONTENT_SCALE_STRETCH_FRACTIONAL


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	# Any non-zero value is fullscreen (older saves also had 2 = exclusive fullscreen)
	var saved_mode: int = int(config.get_value(SECTION, KEY_MODE, WindowMode.WINDOWED))
	_mode = WindowMode.WINDOWED if saved_mode == 0 else WindowMode.FULLSCREEN
	_vsync = bool(config.get_value(SECTION, KEY_VSYNC, true))
	_pixel_perfect = bool(config.get_value(SECTION, KEY_PIXEL_PERFECT, false))


# Writes only these keys, keeping the other sections
func _save() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SECTION, KEY_MODE, int(_mode))
	if config.has_section_key(SECTION, "resolution"):
		config.erase_section_key(SECTION, "resolution") # left over from older versions
	config.set_value(SECTION, KEY_VSYNC, _vsync)
	config.set_value(SECTION, KEY_PIXEL_PERFECT, _pixel_perfect)
	var err: Error = config.save(SETTINGS_PATH)
	if err != OK:
		push_error("[Display] - failed to save settings (error %d)" % err)
