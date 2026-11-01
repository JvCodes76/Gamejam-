extends CanvasLayer
## Monster Survivors HUD: XP bar across the top of the screen, level number, current wave,
## "next wave" button during the rests (red before a boss) and wave announcements.

const BAR_HEIGHT: float = 5.0
const BAR_BACK: Color = Color(0.1, 0.0, 0.02, 0.85)
const BAR_FILL: Color = Color(0.9, 0.1, 0.15)
const BOSS_BUTTON_COLOR: Color = Color(1.0, 0.35, 0.35)

var _back: ColorRect
var _fill: ColorRect
var _label: Label
var _wave_label: Label
var _next_button: Button
var _next_tween: Tween
var _announce_label: Label
var _announce_tween: Tween
var _tween: Tween
var _ratio: float = 0.0


func _ready() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.resized.connect(_apply_ratio)
	add_child(root)
	_back = ColorRect.new()
	_back.color = BAR_BACK
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_back.offset_bottom = BAR_HEIGHT
	root.add_child(_back)
	_fill = ColorRect.new()
	_fill.color = BAR_FILL
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.size = Vector2(0.0, BAR_HEIGHT)
	_back.add_child(_fill)
	_label = Label.new()
	_label.text = "LV 1"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style(_label, 12, Color(1.0, 0.8, 0.8))
	_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.offset_top = BAR_HEIGHT + 1.0
	_label.offset_right = -8.0
	root.add_child(_label)
	_wave_label = _centered_label(root, BAR_HEIGHT + 1.0, 12, Color(1.0, 0.9, 0.6))
	_wave_label.text = "WAVE 1"
	_next_button = _build_next_button(root, BAR_HEIGHT + 20.0)
	_announce_label = _centered_label(root, 90.0, 28, Color(1.0, 0.9, 0.6))
	_announce_label.modulate.a = 0.0
	EventBus.xp_changed.connect(_on_xp_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_rest_changed.connect(_on_wave_rest_changed)


# Label with outline, centered horizontally at the given height
func _centered_label(parent: Control, top: float, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	_style(label, font_size, color)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_top = top
	parent.add_child(label)
	return label


# Button that starts the next wave during the rests (hidden otherwise). No focus, so Space/Enter never press it by accident.
func _build_next_button(parent: Control, top: float) -> Button:
	var button: Button = Button.new()
	button.text = tr("Next wave")
	button.visible = false
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 14)
	button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	button.offset_top = top
	button.mouse_entered.connect(EventBus.play_sfx_requested.emit.bind("ui_hover"))
	button.pressed.connect(_on_next_wave_pressed)
	# Pivot in the center so the pop does not drift (the size is only known after the layout)
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	parent.add_child(button)
	return button


func _style(label: Label, font_size: int, color: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)


# Shows the wave number and announces it (boss waves in red)
func _on_wave_started(wave: int, is_boss: bool) -> void:
	_wave_label.text = tr("WAVE %d") % wave
	_announce_label.text = tr("BOSS WAVE %d") % wave if is_boss else tr("WAVE %d") % wave
	_announce_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3) if is_boss else Color(1.0, 0.9, 0.6))
	_announce_label.pivot_offset = _announce_label.size * 0.5
	_announce_label.scale = Vector2.ONE * 1.5
	_announce_label.modulate.a = 1.0
	if _announce_tween != null:
		_announce_tween.kill()
	_announce_tween = create_tween()
	_announce_tween.tween_property(_announce_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_announce_tween.tween_interval(1.2)
	_announce_tween.tween_property(_announce_label, "modulate:a", 0.0, 0.5)


# Rest started/ended: shows the button with a pop (in red when a boss comes next), or hides it
func _on_wave_rest_changed(resting: bool, boss_next: bool) -> void:
	if _next_tween != null:
		_next_tween.kill()
	_next_button.visible = resting
	_next_button.disabled = not resting
	if not resting:
		return
	_next_button.text = tr("Face the boss") if boss_next else tr("Next wave")
	for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		if boss_next:
			_next_button.add_theme_color_override(color_name, BOSS_BUTTON_COLOR)
		else:
			_next_button.remove_theme_color_override(color_name)
	_next_button.scale = Vector2.ONE * 1.4
	_next_tween = create_tween()
	_next_tween.tween_property(_next_button, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_next_wave_pressed() -> void:
	_next_button.disabled = true
	EventBus.play_sfx_requested.emit("ui_click")
	EventBus.next_wave_requested.emit()


func _on_xp_changed(level: int, xp: int, xp_needed: int) -> void:
	var previous: String = _label.text
	_label.text = "LV %d" % level
	var target: float = float(xp) / float(maxi(xp_needed, 1))
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	# On level up the bar fills up, empties and then shows the leftover XP
	if target < _ratio:
		_tween.tween_method(_set_ratio, _ratio, 1.0, 0.12)
		_tween.tween_callback(_set_ratio.bind(0.0))
	_tween.tween_method(_set_ratio, 0.0 if target < _ratio else _ratio, target, 0.2)
	if previous != _label.text:
		_label.pivot_offset = _label.size * 0.5
		_label.scale = Vector2.ONE * 1.6
		create_tween().tween_property(_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_ratio(value: float) -> void:
	_ratio = value
	_apply_ratio()


func _apply_ratio() -> void:
	if _fill != null and _back != null:
		_fill.size = Vector2(_back.size.x * _ratio, BAR_HEIGHT)
