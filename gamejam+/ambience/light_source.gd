class_name LightSource
extends Node2D
## Point light read by NightLighting: there are no Light2D nodes, the whole screen is lit in one shader pass.
## The node position is the center of the pool of light on the ground; an optional additive halo glows at the
## light itself (lantern, carved face, flame), above the night layer.

## Lights inside the tree; NightLighting picks the ones on screen every frame.
static var registry: Array[LightSource] = []

## Above the night layer (NightLighting.Z_LAYER) and below the projectiles
const HALO_Z_INDEX: int = 9
const GLOW_Z_INDEX: int = 6
# Halo rings (pixel art, no smooth gradient): x = outer edge as a fraction of the radius, y = alpha
const HALO_RINGS: Array[Vector2] = [Vector2(0.3, 1.0), Vector2(0.55, 0.55), Vector2(0.78, 0.28), Vector2(1.0, 0.1)]
const GLOW_TEXTURE_SIZE: int = 64
# Same vertical squash as the night shader (lights are ellipses on the ground)
const GROUND_SQUASH: float = 1.3

static var _halo_textures: Dictionary = {}
static var _glow_texture: ImageTexture = null
static var _additive: CanvasItemMaterial = null

@export var light_color: Color = Color(1.0, 0.8, 0.45)
## Reach of the light on the ground (px)
@export var radius: float = 80.0
@export var energy: float = 0.7
## Flicker strength (0 = steady, 0.2 = candle)
@export_range(0.0, 1.0) var flicker: float = 0.0
@export var flicker_speed: float = 4.0
## Halo radius in px (0 = no halo)
@export var halo_radius: int = 0
@export var halo_energy: float = 0.4
## Halo position relative to this node
@export var halo_offset: Vector2 = Vector2.ZERO
## Additive glow over the whole pool of light (0 = none): the lit area gets brighter than the art, so it reads
## as light and not only as "less darkness"
@export_range(0.0, 1.0) var glow: float = 0.0

## Optional color source, called on every sample (e.g. the potion color of the cauldron).
var color_provider: Callable = Callable()

var _phase: float = 0.0
var _halo: Sprite2D = null
var _glow: Sprite2D = null


## Creates a light from a preset dictionary. Keys: color, radius, energy, flicker, speed, offset (light center
## relative to the owner), halo (radius px), halo_energy, halo_at (halo position relative to the owner), glow.
static func from_preset(preset: Dictionary, energy_scale: float = 1.0) -> LightSource:
	var light: LightSource = LightSource.new()
	light.light_color = preset.get("color", Color.WHITE)
	light.radius = float(preset.get("radius", 80.0))
	light.energy = float(preset.get("energy", 0.7)) * energy_scale
	light.flicker = float(preset.get("flicker", 0.0))
	light.flicker_speed = float(preset.get("speed", 4.0))
	light.position = preset.get("offset", Vector2.ZERO)
	light.halo_radius = int(preset.get("halo", 0))
	light.halo_energy = float(preset.get("halo_energy", 0.4))
	light.halo_offset = (preset.get("halo_at", light.position) as Vector2) - light.position
	light.glow = float(preset.get("glow", 0.0))
	return light


func _enter_tree() -> void:
	registry.append(self)


func _exit_tree() -> void:
	registry.erase(self)


func _ready() -> void:
	_phase = randf() * TAU
	if glow > 0.0:
		_build_glow()
	if halo_radius > 0:
		_build_halo()
	sample(0.0)


## Energy at "time" (real s) with the flicker applied; also updates the halo and glow brightness.
func sample(time: float) -> float:
	var strength: float = 1.0
	if flicker > 0.0:
		var t: float = time * flicker_speed + _phase
		strength += flicker * (0.5 * sin(t) + 0.3 * sin(t * 2.37 + 1.3) + 0.2 * sin(t * 5.13 + 2.1))
	if _halo != null or _glow != null:
		var color: Color = current_color()
		if _halo != null:
			_halo.self_modulate = Color(color.r, color.g, color.b, halo_energy * strength)
		if _glow != null:
			_glow.self_modulate = Color(color.r, color.g, color.b, glow * strength)
	return energy * strength


## Current light color (the provider's, if any).
func current_color() -> Color:
	if color_provider.is_valid():
		return color_provider.call() as Color
	return light_color


# Additive sprite with stepped rings, shared texture per radius
func _build_halo() -> void:
	_halo = Sprite2D.new()
	_halo.texture = _halo_texture(halo_radius)
	_halo.material = _additive_material()
	_halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_halo.z_as_relative = false
	_halo.z_index = HALO_Z_INDEX
	_halo.position = halo_offset
	add_child(_halo)


# Soft additive ellipse the size of the pool of light (same falloff as the night shader), in world px
func _build_glow() -> void:
	_glow = Sprite2D.new()
	_glow.texture = _glow_texture_shared()
	_glow.material = _additive_material()
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_glow.z_as_relative = false
	_glow.z_index = GLOW_Z_INDEX
	var world_scale: Vector2 = get_global_transform().get_scale()
	var size: float = radius * 2.0 / float(GLOW_TEXTURE_SIZE)
	_glow.scale = Vector2(size, size / GROUND_SQUASH) / world_scale
	add_child(_glow)


static func _additive_material() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive


static func _glow_texture_shared() -> ImageTexture:
	if _glow_texture != null:
		return _glow_texture
	var size: int = GLOW_TEXTURE_SIZE
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half: float = size * 0.5
	for y: int in size:
		for x: int in size:
			var d: float = (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(Vector2(half, half)) / half
			var falloff: float = maxf(1.0 - d * d, 0.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, falloff * falloff))
	_glow_texture = ImageTexture.create_from_image(image)
	return _glow_texture


static func _halo_texture(halo: int) -> ImageTexture:
	if _halo_textures.has(halo):
		return _halo_textures[halo]
	var size: int = halo * 2
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(halo, halo)
	for y: int in size:
		for x: int in size:
			var d: float = (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(center) / float(halo)
			for ring: Vector2 in HALO_RINGS:
				if d <= ring.x:
					image.set_pixel(x, y, Color(1.0, 1.0, 1.0, ring.y))
					break
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_halo_textures[halo] = texture
	return texture
