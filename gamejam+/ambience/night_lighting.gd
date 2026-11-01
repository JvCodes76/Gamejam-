class_name NightLighting
extends Node2D
## Night layer: a square over the camera view whose shader multiplies everything below its z_index by the ambient
## color plus the LightSources on screen (one pass, no Light2D). Layers above it (projectiles, effects, damage
## numbers, crosshair) keep full brightness, so combat stays readable. Created by the AmbienceLayer.

const SHADER: Shader = preload("res://assets/shaders/night_lighting.gdshader")
## Same value as MAX_LIGHTS in the shader; with more lights on screen, the ones closest to the view center win
const MAX_LIGHTS: int = 24
## Between the actors (y-sort, z 0) and the projectiles (CombatConstants.Z_BULLET)
const Z_LAYER: int = 5

var _material: ShaderMaterial
var _data: PackedVector4Array = PackedVector4Array()
var _colors: PackedColorArray = PackedColorArray()
var _visible_lights: Array[LightSource] = []
# Half side of the drawn square (covers the view at any camera rotation)
var _cover: float = 0.0
var _view_center: Vector2 = Vector2.ZERO


func _init() -> void:
	name = "NightLighting"
	z_as_relative = false
	z_index = Z_LAYER
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material
	_data.resize(MAX_LIGHTS)
	_colors.resize(MAX_LIGHTS)


## Overall look of the night (colors and limits).
func configure(ambient: Color, min_brightness: float, vignette: float, bands: int) -> void:
	_material.set_shader_parameter(&"ambient_color", ambient)
	_material.set_shader_parameter(&"min_brightness", min_brightness)
	_material.set_shader_parameter(&"vignette_strength", vignette)
	_material.set_shader_parameter(&"light_bands", float(bands))


## Follows the camera and sends the lights inside "view" (world rect) to the shader.
func update_view(center: Vector2, cover: float, view: Rect2, time: float) -> void:
	global_position = center
	_view_center = center
	if not is_equal_approx(cover, _cover):
		_cover = cover
		queue_redraw()
	_visible_lights.clear()
	for light: LightSource in LightSource.registry:
		var r: float = light.radius
		var p: Vector2 = light.global_position
		if p.x + r < view.position.x or p.x - r > view.end.x or p.y + r < view.position.y or p.y - r > view.end.y:
			continue
		if light.is_visible_in_tree():
			_visible_lights.append(light)
	if _visible_lights.size() > MAX_LIGHTS:
		_visible_lights.sort_custom(_closer_to_center)
	var count: int = mini(_visible_lights.size(), MAX_LIGHTS)
	for i: int in count:
		var light: LightSource = _visible_lights[i]
		var p: Vector2 = light.global_position
		_data[i] = Vector4(p.x, p.y, light.radius, light.sample(time))
		_colors[i] = light.current_color()
	_material.set_shader_parameter(&"light_count", count)
	_material.set_shader_parameter(&"light_data", _data)
	_material.set_shader_parameter(&"light_colors", _colors)


func _draw() -> void:
	draw_rect(Rect2(-_cover, -_cover, _cover * 2.0, _cover * 2.0), Color.WHITE)


func _closer_to_center(a: LightSource, b: LightSource) -> bool:
	return a.global_position.distance_squared_to(_view_center) < b.global_position.distance_squared_to(_view_center)
