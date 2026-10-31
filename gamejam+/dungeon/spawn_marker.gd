class_name SpawnMarker
extends Node2D
## Aviso de spawn no chão: círculo e cruz pulsando por "duration" segundos; depois emite "finished" e some.
## Fase 2: vira uma runa/cova animada (sprite).

signal finished(point: Vector2)

const COLOR: Color = Color(0.85, 0.2, 0.25)
const RADIUS: float = 9.0

var duration: float = FeelConstants.SPAWN_WARNING_TIME
var _age: float = 0.0


func _ready() -> void:
	z_index = CombatConstants.Z_MUD


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= duration:
		finished.emit(global_position)
		queue_free()


func _draw() -> void:
	var t: float = clampf(_age / duration, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 22.0)
	var color: Color = Color(COLOR, 0.35 + 0.45 * pulse)
	var r: float = RADIUS * (0.6 + 0.4 * t)
	# Elipse achatada (perspectiva do chão)
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 17:
		var a: float = TAU * float(i) / 16.0
		points.append(Vector2(cos(a) * r, sin(a) * r * 0.5))
	draw_polyline(points, color, 1.0)
	var c: float = r * 0.6
	draw_line(Vector2(-c, -c * 0.5), Vector2(c, c * 0.5), color, 1.0)
	draw_line(Vector2(-c, c * 0.5), Vector2(c, -c * 0.5), color, 1.0)
