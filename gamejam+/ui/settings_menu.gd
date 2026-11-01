extends CanvasLayer
## Settings screen: Master, Music and SFX volume sliders.
## Instantiated by the main menu and the pause menu; call open() to show it.

signal closed()

# Bus name -> label shown in the UI
const VOLUME_ROWS: Array[Dictionary] = [
	{"bus": &"Master", "label": "Master Volume"},
	{"bus": &"Music", "label": "Music Volume"},
	{"bus": &"SFX", "label": "SFX Volume"},
]

@onready var _rows: VBoxContainer = $Painel/VBox/Linhas
@onready var _botao_voltar: Button = $Painel/VBox/BotaoVoltar

var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}


func _ready() -> void:
	visible = false
	for row: Dictionary in VOLUME_ROWS:
		_build_row(row["bus"] as StringName, row["label"] as String)
	_botao_voltar.pressed.connect(close)
	_add_ui_sounds(_botao_voltar)
	print("[UI] - Settings menu ready")


func open() -> void:
	for bus: StringName in _sliders:
		var slider: HSlider = _sliders[bus]
		slider.set_value_no_signal(AudioManager.get_bus_volume(bus))
		_update_label(bus, slider.value)
	visible = true
	(_sliders[VOLUME_ROWS[0]["bus"]] as HSlider).grab_focus()
	print("[UI] - Settings opened")


func close() -> void:
	if not visible:
		return
	visible = false
	AudioManager.save_settings()
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

	_rows.add_child(row)
	_sliders[bus] = slider
	_value_labels[bus] = value_label
	slider.set_value_no_signal(AudioManager.get_bus_volume(bus))
	_update_label(bus, slider.value)


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
