class_name MuzzleFlash
extends Node2D
## Muzzle flash drawn by _draw() (circle + 4-point star) for a few frames.
## Phase 2: swaps to an animated white sprite, tinted with the same color.

var color: Color = Color.WHITE
var _frames_left: int = 0


func _ready() -> void:
	z_index = CombatConstants.Z_BULLET + 1
	visible = false


## Shows the flash in the potion color for MUZZLE_FLASH_FRAMES frames.
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
