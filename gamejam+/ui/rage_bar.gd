class_name RageBar
extends Control
## Rage bar (Evil synergy): fills according to the bonus and pulses stronger and faster the higher the rage.

@export var bar_size: Vector2 = Vector2(60.0, 4.0)
@export var low_color: Color = Color(1.0, 0.55, 0.1)
@export var high_color: Color = Color(1.0, 0.1, 0.1)
## Bonus that leaves the bar almost full (rage has no cap; the bar saturates)
@export var reference_bonus: float = 0.25

var bonus: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = bar_size
	size = bar_size


func set_bonus(value: float) -> void:
	bonus = value
	queue_redraw()


func _fill() -> float:
	return 1.0 - exp(-bonus / maxf(reference_bonus, 0.001) * 2.5)


func _process(delta: float) -> void:
	if bonus <= 0.0:
		return
	_time += delta * (2.0 + _fill() * 8.0)
	queue_redraw()


func _draw() -> void:
	var fill: float = _fill()
	draw_rect(Rect2(Vector2(-1, -1), bar_size + Vector2(2, 2)), Color(0, 0, 0, 0.8))
	var color: Color = low_color.lerp(high_color, fill)
	color = color.lightened(0.35 * fill * absf(sin(_time)))
	draw_rect(Rect2(Vector2.ZERO, Vector2(bar_size.x * fill, bar_size.y)), color)
