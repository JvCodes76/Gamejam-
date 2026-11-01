class_name BossAttackFx
extends Node2D
## Visuals of the boss attacks, drawn by code as a child of the boss (local coordinates):
## the ground circle that fills up before the explosion and the aiming line / beam of the laser.

const TELEGRAPH_COLOR: Color = Color(1.0, 0.2, 0.25)
const BEAM_COLOR: Color = Color(1.0, 0.25, 0.3)
const BEAM_CORE_COLOR: Color = Color(1.0, 0.92, 0.9)

enum Mode { NONE, CIRCLE, AIM, BEAM }

var _mode: Mode = Mode.NONE
var _radius: float = 0.0
var _progress: float = 0.0
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _width: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	z_index = CombatConstants.Z_IMPACT
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_time += delta
	if _mode != Mode.NONE:
		queue_redraw()


## Ground circle centered on the boss; "progress" (0 to 1) is how much of it is filled.
func show_circle(radius: float, progress: float) -> void:
	_mode = Mode.CIRCLE
	_radius = radius
	_progress = progress
	queue_redraw()


## Thin aiming line; "progress" (0 to 1) makes it brighter and thicker as the shot gets closer.
func show_aim(from: Vector2, to: Vector2, progress: float) -> void:
	_mode = Mode.AIM
	_from = from
	_to = to
	_progress = progress
	queue_redraw()


## Laser beam from "from" to "to" with the given width (px); "progress" (0 to 1) is how far the shot has gone.
func show_beam(from: Vector2, to: Vector2, width: float, progress: float) -> void:
	_mode = Mode.BEAM
	_from = from
	_to = to
	_width = width
	_progress = progress
	queue_redraw()


## Hides everything.
func clear() -> void:
	_mode = Mode.NONE
	queue_redraw()


func _draw() -> void:
	match _mode:
		Mode.CIRCLE:
			_draw_circle_telegraph()
		Mode.AIM:
			_draw_aim()
		Mode.BEAM:
			_draw_beam()


# Ground circle: faint full area, filled part growing with the progress and a solid outline
func _draw_circle_telegraph() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 24.0 * (0.4 + _progress))
	draw_circle(Vector2.ZERO, _radius, Color(TELEGRAPH_COLOR, 0.10 + 0.08 * pulse))
	draw_circle(Vector2.ZERO, _radius * _progress, Color(TELEGRAPH_COLOR, 0.28))
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 64, Color(TELEGRAPH_COLOR, 0.8), 2.0)


func _draw_aim() -> void:
	var blink: float = 0.6 + 0.4 * sin(_time * 30.0 * _progress)
	var alpha: float = lerpf(0.25, 0.9, _progress) * blink
	draw_line(_from, _to, Color(TELEGRAPH_COLOR, alpha), lerpf(1.0, 3.0, _progress))


func _draw_beam() -> void:
	var fade: float = clampf((1.0 - _progress) / 0.2, 0.0, 1.0)
	var flicker: float = 1.0 + 0.12 * sin(_time * 60.0)
	var width: float = _width * flicker * lerpf(0.4, 1.0, fade)
	draw_line(_from, _to, Color(BEAM_COLOR, 0.35 * fade), width * 1.6)
	draw_line(_from, _to, Color(BEAM_COLOR, 0.85 * fade), width)
	draw_line(_from, _to, Color(BEAM_CORE_COLOR, fade), width * 0.4)
	draw_circle(_from, width * 0.8, Color(BEAM_CORE_COLOR, 0.8 * fade))
