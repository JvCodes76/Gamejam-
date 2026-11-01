class_name Crosshair
extends Node2D

@export var radius: float = 4.0
@export var cross_size: float = 8.0
@export var line_width: float = 1.0
@export var color: Color = Color(1.0, 1.0, 1.0, 0.9)


var _pulse_tween: Tween


func _ready() -> void:
	top_level = true
	z_index = 100


## Scale pop with a brightness flash (potion swap).
func pulse() -> void:
	if not is_inside_tree():
		return
	if _pulse_tween != null:
		_pulse_tween.kill()
	scale = Vector2.ONE * 1.8
	modulate = Color(2.0, 2.0, 2.0, 1.0)
	_pulse_tween = create_tween().set_parallel()
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "modulate", Color.WHITE, 0.2)


## Draws a circle with a cross centered on the position.
func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 16, color, line_width)
	draw_line(Vector2(-cross_size, 0.0), Vector2(-radius, 0.0), color, line_width)
	draw_line(Vector2(radius, 0.0), Vector2(cross_size, 0.0), color, line_width)
	draw_line(Vector2(0.0, -cross_size), Vector2(0.0, -radius), color, line_width)
	draw_line(Vector2(0.0, radius), Vector2(0.0, cross_size), color, line_width)
