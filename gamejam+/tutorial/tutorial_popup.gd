class_name TutorialPopup
extends CanvasLayer
## Tutorial messages. Every popup freezes the game and dims the screen; it only closes with an input
## after MIN_READ_TIME seconds on screen. Messages are shown one at a time, in order.

const FADE_TIME: float = 0.3
const PANEL_WIDTH: float = 360.0
const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.65)
# Seconds (real time) the popup stays up before an input can close it
const MIN_READ_TIME: float = 3.0
const HINT_WAIT: String = "..."
const HINT_READY: String = "[ Press any key or click to continue ]"

var _queue: Array[String] = []
var _showing: bool = false
var _closing: bool = false
var _shown_at_msec: int = 0
var _dim: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _label: Label
var _hint: Label
var _tween: Tween


func _ready() -> void:
	# Above the inventory screen (layer 50) and always processing (the freeze pauses the tree)
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.color = DIM_COLOR
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.modulate.a = 0.0
	add_child(_dim)
	# The container centers the panel by itself, whatever size the wrapped text ends up with
	_center = CenterContainer.new()
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_label = Label.new()
	_label.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.modulate = Color(1.0, 1.0, 1.0, 0.65)
	box.add_child(_label)
	box.add_child(_hint)
	_panel.add_child(box)
	_center.add_child(_panel)
	_panel.visible = false
	set_process(false)


## Queues a message; it freezes the game when it is its turn.
func show_message(text: String) -> void:
	_queue.append(text)
	if not _showing:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	_closing = false
	_label.text = _queue.pop_front()
	_hint.text = HINT_WAIT
	_panel.visible = true
	# Waits a frame so the text is laid out (and a menu opened by the same event gets to open first)
	await get_tree().process_frame
	get_tree().paused = true
	_shown_at_msec = Time.get_ticks_msec()
	set_process(true)
	_fade(1.0)


func _process(_delta: float) -> void:
	if _can_close():
		_hint.text = HINT_READY


func _can_close() -> bool:
	return _showing and not _closing and float(Time.get_ticks_msec() - _shown_at_msec) / 1000.0 >= MIN_READ_TIME


func _input(event: InputEvent) -> void:
	if not _showing:
		return
	# Frozen: swallows every press so nothing reaches the game (not even the pause menu)
	var key: InputEventKey = event as InputEventKey
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	var pressed: bool = (key != null and key.pressed and not key.echo) or (mouse != null and mouse.pressed)
	if pressed or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
	if pressed and _can_close():
		_close()


func _close() -> void:
	_closing = true
	set_process(false)
	get_tree().paused = false
	_fade(0.0)
	await _tween.finished
	_panel.visible = false
	_next()


func _fade(target: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", target, FADE_TIME)
	_tween.tween_property(_panel, "modulate:a", target, FADE_TIME)
