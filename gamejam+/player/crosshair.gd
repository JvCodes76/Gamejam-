class_name Crosshair
extends Node2D

@export var radius: float = 4.0
@export var cross_size: float = 8.0
@export var line_width: float = 1.0
@export var color: Color = Color(1.0, 1.0, 1.0, 0.9)


func _ready() -> void:
	top_level = true
	z_index = 100


## Desenha um círculo com cruz centrado na posição.
func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 16, color, line_width)
	draw_line(Vector2(-cross_size, 0.0), Vector2(-radius, 0.0), color, line_width)
	draw_line(Vector2(radius, 0.0), Vector2(cross_size, 0.0), color, line_width)
	draw_line(Vector2(0.0, -cross_size), Vector2(0.0, -radius), color, line_width)
	draw_line(Vector2(0.0, radius), Vector2(0.0, cross_size), color, line_width)
