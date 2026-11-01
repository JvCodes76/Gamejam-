class_name GroundFog
extends Node2D
## Low fog drifting over the floor (shader in world coordinates over a square that follows the camera).
## Drawn just above the floor and the shadows: props, items and actors stand inside it. Created by the AmbienceLayer.
## It skips the pixels still showing the level background (the default clear color), so the void outside the map stays clean.

const SHADER: Shader = preload("res://assets/shaders/ground_fog.gdshader")
## Above the floor, fallen leaves, shadows (DropShadow.Z_LAYER) and dirt mounds (same z, see top_level), below the
## ground items (CombatConstants.Z_GROUND_ITEM)
const Z_LAYER: int = -4

var _material: ShaderMaterial
var _cover: float = 0.0
# Clear color last sent to the shader (alpha 0 = not sent yet)
var _void_color: Color = Color(0, 0, 0, 0)


func _init() -> void:
	name = "GroundFog"
	# Out of the level's y-sort: drawn after everything else on its z_index (the dirt mounds share it), instead of
	# covering only the mounds that happen to sort before the AmbienceLayer
	top_level = true
	z_as_relative = false
	z_index = Z_LAYER
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material


## Fog look: color, maximum opacity, patch size (noise scale) and drift (px/s).
func configure(color: Color, density: float, noise_scale: float, wind: Vector2) -> void:
	_material.set_shader_parameter(&"fog_color", color)
	_material.set_shader_parameter(&"density", density)
	_material.set_shader_parameter(&"noise_scale", noise_scale)
	_material.set_shader_parameter(&"wind", wind)


## Follows the camera ("cover" = half side of the drawn square).
func update_view(center: Vector2, cover: float) -> void:
	global_position = center
	# The level may change the background after the fog is built (the dungeon sets its void color)
	var clear: Color = RenderingServer.get_default_clear_color()
	if clear != _void_color:
		_void_color = clear
		_material.set_shader_parameter(&"void_color", clear)
	if not is_equal_approx(cover, _cover):
		_cover = cover
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-_cover, -_cover, _cover * 2.0, _cover * 2.0), Color.WHITE)
