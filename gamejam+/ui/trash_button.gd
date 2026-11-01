class_name TrashButton
extends Control
## Clickable trash can (bucket with lid) drawn by code.

signal pressed

@export var hint_text: String = "Discard potion"
@export var body_color: Color = Color(0.55, 0.58, 0.65)
@export var hover_color: Color = Color(1.0, 0.45, 0.4)

var _hover: bool = false


func _ready() -> void:
	size = Vector2(20, 24)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	visibility_changed.connect(func() -> void: _hover = false)


func _set_hover(value: bool) -> void:
	_hover = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


## Draws lid, handle, bucket and stripes; hint on hover.
func _draw() -> void:
	var c: Color = hover_color if _hover else body_color
	draw_rect(Rect2(8, 0, 4, 2), c)
	draw_rect(Rect2(1, 2, 18, 3), c)
	draw_colored_polygon(PackedVector2Array([Vector2(3, 6), Vector2(17, 6), Vector2(15, 24), Vector2(5, 24)]), c.darkened(0.25))
	for x: float in [7.0, 10.0, 13.0]:
		draw_line(Vector2(x, 9), Vector2(x - (x - 10.0) * 0.1, 21), c.lightened(0.3), 1.0)
	if _hover:
		draw_string(ThemeDB.fallback_font, Vector2(-30, -4), hint_text, HORIZONTAL_ALIGNMENT_CENTER, 80, 8, Color(1, 1, 1))
