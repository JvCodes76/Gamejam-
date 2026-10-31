class_name MuzzleFlash
extends Node2D
## Clarão do cano desenhado por _draw() (círculo + estrela de 4 pontas) por poucos quadros.
## Fase 2: troca para um sprite branco animado, tingido com a mesma cor.

var color: Color = Color.WHITE
var _frames_left: int = 0


func _ready() -> void:
	z_index = CombatConstants.Z_BULLET + 1
	visible = false


## Mostra o clarão na cor da poção por MUZZLE_FLASH_FRAMES quadros.
func flash(new_color: Color) -> void:
	color = new_color
	_frames_left = FeelConstants.MUZZLE_FLASH_FRAMES
	visible = true
	rotation = randf() * 0.4 - 0.2
	queue_redraw()


func _process(_delta: float) -> void:
	if _frames_left <= 0:
		return
	_frames_left -= 1
	if _frames_left <= 0:
		visible = false


func _draw() -> void:
	var core: Color = color.lightened(0.6)
	draw_circle(Vector2(2.0, 0.0), 3.5, Color(color, 0.8))
	draw_circle(Vector2(2.0, 0.0), 2.0, core)
	var star: PackedVector2Array = PackedVector2Array([
		Vector2(9.0, 0.0), Vector2(3.0, 1.0), Vector2(2.0, 5.0), Vector2(1.0, 1.0),
		Vector2(-3.0, 0.0), Vector2(1.0, -1.0), Vector2(2.0, -5.0), Vector2(3.0, -1.0)])
	draw_colored_polygon(star, Color(core, 0.9))
