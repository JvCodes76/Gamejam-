extends CanvasLayer
## Settings screen in three tabs: Audio (volume sliders), Video (windowed/fullscreen, VSync,
## pixel-perfect scaling) and Effects (atmosphere toggle and CRT filter).
## Instantiated by the main menu and the pause menu; call open() to show it.

signal closed()

# Bus name -> label shown in the UI
const VOLUME_ROWS: Array[Dictionary] = [
	{"bus": &"Master", "label": "Master Volume"},
	{"bus": &"Music", "label": "Music Volume"},
	{"bus": &"SFX", "label": "SFX Volume"},
]

@onready var _tabs: TabContainer = $Conteudo/Painel/VBox/Abas
@onready var _audio_rows: VBoxContainer = $Conteudo/Painel/VBox/Abas/Audio
@onready var _video_rows: VBoxContainer = $Conteudo/Painel/VBox/Abas/Video
@onready var _effects_rows: VBoxContainer = $Conteudo/Painel/VBox/Abas/Efeitos
@onready var _botao_voltar: Button = $Conteudo/Painel/VBox/BotaoVoltar

var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _ambience_toggle: CheckButton
var _crt_toggle: CheckButton
var _crt_slider: HSlider
var _crt_value_label: Label
var _mode_option: OptionButton
var _vsync_toggle: CheckButton
var _pixel_perfect_toggle: CheckButton


func _ready() -> void:
	visible = false
	for row: Dictionary in VOLUME_ROWS:
		_build_row(row["bus"] as StringName, row["label"] as String)
	_build_display_controls()
	_build_ambience_toggle()
	_build_crt_controls()
	_tabs.set_tab_title(0, tr("Audio"))
	_tabs.set_tab_title(1, tr("Video"))
	_tabs.set_tab_title(2, tr("Effects"))
	DisplaySettings.changed.connect(_sync_display_controls)
	_botao_voltar.pressed.connect(close)
	_add_ui_sounds(_botao_voltar)
	print("[UI] - Settings menu ready")


func open() -> void:
	for bus: StringName in _sliders:
		var slider: HSlider = _sliders[bus]
		slider.set_value_no_signal(AudioManager.get_bus_volume(bus))
		_update_label(bus, slider.value)
	_ambience_toggle.set_pressed_no_signal(AmbienceSettings.is_enabled())
	_sync_crt_controls()
	_sync_display_controls()
	_tabs.current_tab = 0
	visible = true
	(_sliders[VOLUME_ROWS[0]["bus"]] as HSlider).grab_focus()
	print("[UI] - Settings opened")


func close() -> void:
	if not visible:
		return
	visible = false
	AudioManager.save_settings()
	CrtFilter.save_settings()
	closed.emit()
	print("[UI] - Settings closed")


# Consumes Esc / Start while open so the pause menu underneath does not toggle
func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()


func _build_row(bus: StringName, label_text: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = tr(label_text)
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(130, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_slider_changed.bind(bus))
	# Preview: play a click when the SFX slider is released so the level can be judged
	if bus == &"SFX":
		slider.drag_ended.connect(_on_sfx_drag_ended)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(36, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	_audio_rows.add_child(row)
	_sliders[bus] = slider
	_value_labels[bus] = value_label
	slider.set_value_no_signal(AudioManager.get_bus_volume(bus))
	_update_label(bus, slider.value)


# Night lighting, fog, particles and shadows on/off (applied live, also from the pause menu)
func _build_ambience_toggle() -> void:
	_ambience_toggle = CheckButton.new()
	_ambience_toggle.text = tr("Atmosphere effects")
	_ambience_toggle.tooltip_text = tr("Night lighting, fog, particles and shadows")
	_ambience_toggle.button_pressed = AmbienceSettings.is_enabled()
	_ambience_toggle.toggled.connect(_on_ambience_toggled)
	_effects_rows.add_child(_ambience_toggle)
	_add_ui_sounds(_ambience_toggle)


# CRT filter on/off plus an intensity slider (disabled while the filter is off)
func _build_crt_controls() -> void:
	_crt_toggle = CheckButton.new()
	_crt_toggle.text = tr("CRT filter")
	_crt_toggle.tooltip_text = tr("Scanlines, screen curvature and vignette")
	_crt_toggle.toggled.connect(_on_crt_toggled)
	_effects_rows.add_child(_crt_toggle)
	_add_ui_sounds(_crt_toggle)

	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = tr("CRT Intensity")
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)

	_crt_slider = HSlider.new()
	_crt_slider.min_value = 0.0
	_crt_slider.max_value = 1.0
	_crt_slider.step = 0.01
	_crt_slider.custom_minimum_size = Vector2(130, 0)
	_crt_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crt_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_crt_slider.value_changed.connect(_on_crt_intensity_changed)
	row.add_child(_crt_slider)

	_crt_value_label = Label.new()
	_crt_value_label.custom_minimum_size = Vector2(36, 0)
	_crt_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_crt_value_label)

	_effects_rows.add_child(row)
	_sync_crt_controls()


# Window mode, VSync and pixel-perfect scaling (applied live, saved by DisplaySettings)
func _build_display_controls() -> void:
	_mode_option = OptionButton.new()
	for i: int in DisplaySettings.MODE_LABELS.size():
		_mode_option.add_item(tr(DisplaySettings.MODE_LABELS[i]), i)
	_mode_option.item_selected.connect(_on_mode_selected)
	_video_rows.add_child(_labeled_row("Window Mode", _mode_option))
	_add_ui_sounds(_mode_option)

	_vsync_toggle = CheckButton.new()
	_vsync_toggle.text = tr("VSync")
	_vsync_toggle.tooltip_text = tr("Syncs the frame rate with the monitor to avoid tearing")
	_vsync_toggle.toggled.connect(DisplaySettings.set_vsync)
	_video_rows.add_child(_vsync_toggle)
	_add_ui_sounds(_vsync_toggle)

	if DisplaySettings.is_window_locked():
		var note := Label.new()
		note.text = tr("Window options only apply outside the editor's Game tab")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(280, 0)
		note.modulate = Color(1.0, 0.8, 0.4)
		_video_rows.add_child(note)

	_pixel_perfect_toggle = CheckButton.new()
	_pixel_perfect_toggle.text = tr("Pixel perfect scaling")
	_pixel_perfect_toggle.tooltip_text = tr("Integer scaling only: sharper pixels, may add black borders")
	_pixel_perfect_toggle.toggled.connect(DisplaySettings.set_pixel_perfect)
	_video_rows.add_child(_pixel_perfect_toggle)
	_add_ui_sounds(_pixel_perfect_toggle)

	_sync_display_controls()


func _labeled_row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = tr(label_text)
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _sync_display_controls() -> void:
	_mode_option.select(int(DisplaySettings.get_mode()))
	_vsync_toggle.set_pressed_no_signal(DisplaySettings.is_vsync_enabled())
	_pixel_perfect_toggle.set_pressed_no_signal(DisplaySettings.is_pixel_perfect())


func _on_mode_selected(index: int) -> void:
	DisplaySettings.set_mode(index as DisplaySettings.WindowMode)


func _sync_crt_controls() -> void:
	_crt_toggle.set_pressed_no_signal(CrtFilter.is_enabled())
	_crt_slider.set_value_no_signal(CrtFilter.get_intensity())
	_crt_slider.editable = CrtFilter.is_enabled()
	_crt_value_label.text = "%d%%" % roundi(CrtFilter.get_intensity() * 100.0)


func _on_crt_toggled(enabled: bool) -> void:
	CrtFilter.set_enabled(enabled)
	_crt_slider.editable = enabled


func _on_crt_intensity_changed(value: float) -> void:
	CrtFilter.set_intensity(value)
	_crt_value_label.text = "%d%%" % roundi(value * 100.0)


func _on_ambience_toggled(enabled: bool) -> void:
	AmbienceSettings.set_enabled(enabled)
	print("[UI] - Atmosphere effects: %s" % str(enabled))


func _on_slider_changed(value: float, bus: StringName) -> void:
	AudioManager.set_bus_volume(bus, value)
	_update_label(bus, value)


func _on_sfx_drag_ended(_changed: bool) -> void:
	EventBus.play_sfx_requested.emit("ui_click")


func _update_label(bus: StringName, value: float) -> void:
	(_value_labels[bus] as Label).text = "%d%%" % roundi(value * 100.0)


func _add_ui_sounds(button: BaseButton) -> void:
	button.mouse_entered.connect(EventBus.play_sfx_requested.emit.bind("ui_hover"))
	button.pressed.connect(EventBus.play_sfx_requested.emit.bind("ui_click"))
