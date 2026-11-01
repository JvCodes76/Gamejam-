class_name AmbientParticles
extends Node2D
## Fireflies (glowing, above the night layer) and falling leaves (below it, so the night shades them) around the
## camera. The particles live in world coordinates; only the emitters follow the view. Created by the AmbienceLayer.

## Fireflies glow above the night layer (NightLighting.Z_LAYER); leaves fall over the actors but below it
const Z_FIREFLIES: int = 9
const Z_LEAVES: int = 4
const FIREFLY_COLOR: Color = Color(0.85, 1.0, 0.5)
const FIREFLY_LIFETIME: float = 6.0
const LEAF_COLORS: Array[Color] = [Color(0.85, 0.42, 0.2), Color(0.72, 0.28, 0.2), Color(0.92, 0.6, 0.25), Color(0.55, 0.3, 0.25)]
const LEAF_LIFETIME: float = 8.0
# Extra area (px) around the view where particles are born
const EMISSION_MARGIN: Vector2 = Vector2(32.0, 32.0)

var _emitters: Array[CPUParticles2D] = []


func _init() -> void:
	name = "AmbientParticles"


## Creates the emitters (count 0 = none of that kind); "wind" (px/s) pushes the leaves.
func configure(firefly_count: int, leaf_count: int, wind: Vector2) -> void:
	if firefly_count > 0:
		_add_emitter(_make_fireflies(firefly_count))
	if leaf_count > 0:
		_add_emitter(_make_leaves(leaf_count, wind))


## Moves the emitters to the view center; "half_view" = half the size of the view in world px.
func update_view(center: Vector2, half_view: Vector2) -> void:
	global_position = center
	var extents: Vector2 = half_view + EMISSION_MARGIN
	for emitter: CPUParticles2D in _emitters:
		if emitter.emission_rect_extents != extents:
			emitter.emission_rect_extents = extents


func _add_emitter(emitter: CPUParticles2D) -> void:
	emitter.local_coords = false
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emitter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	emitter.z_as_relative = false
	_emitters.append(emitter)
	add_child(emitter)


# Slow drifting dots that blink (additive)
func _make_fireflies(count: int) -> CPUParticles2D:
	var emitter: CPUParticles2D = CPUParticles2D.new()
	emitter.name = "Fireflies"
	emitter.z_index = Z_FIREFLIES
	emitter.amount = count
	emitter.lifetime = FIREFLY_LIFETIME
	emitter.preprocess = FIREFLY_LIFETIME
	emitter.randomness = 1.0
	emitter.texture = _firefly_texture()
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	emitter.material = additive
	emitter.direction = Vector2.UP
	emitter.spread = 180.0
	emitter.gravity = Vector2(0.0, -1.5)
	emitter.initial_velocity_min = 2.0
	emitter.initial_velocity_max = 8.0
	var blink: Gradient = Gradient.new()
	blink.offsets = PackedFloat32Array([0.0, 0.12, 0.3, 0.42, 0.6, 0.75, 0.9, 1.0])
	var alphas: Array[float] = [0.0, 0.9, 0.2, 0.8, 0.15, 0.9, 0.35, 0.0]
	var colors: PackedColorArray = PackedColorArray()
	for alpha: float in alphas:
		colors.append(Color(FIREFLY_COLOR, alpha))
	blink.colors = colors
	emitter.color_ramp = blink
	return emitter


# Small leaves spinning down with the wind, fading in and out
func _make_leaves(count: int, wind: Vector2) -> CPUParticles2D:
	var emitter: CPUParticles2D = CPUParticles2D.new()
	emitter.name = "Leaves"
	emitter.z_index = Z_LEAVES
	emitter.amount = count
	emitter.lifetime = LEAF_LIFETIME
	emitter.preprocess = LEAF_LIFETIME
	emitter.randomness = 1.0
	emitter.texture = _leaf_texture()
	emitter.direction = (wind.normalized() + Vector2.DOWN).normalized()
	emitter.spread = 25.0
	emitter.gravity = Vector2(wind.x * 0.6, 7.0)
	emitter.initial_velocity_min = 6.0
	emitter.initial_velocity_max = 14.0
	emitter.angle_min = 0.0
	emitter.angle_max = 360.0
	emitter.angular_velocity_min = -140.0
	emitter.angular_velocity_max = 140.0
	emitter.scale_amount_min = 1.0
	emitter.scale_amount_max = 1.4
	var palette: Gradient = Gradient.new()
	palette.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets: PackedFloat32Array = PackedFloat32Array()
	for i: int in LEAF_COLORS.size():
		offsets.append(float(i) / float(LEAF_COLORS.size()))
	palette.offsets = offsets
	palette.colors = PackedColorArray(LEAF_COLORS)
	emitter.color_initial_ramp = palette
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	emitter.color_ramp = fade
	return emitter


# 5x5 dot with a soft cross-shaped glow
static func _firefly_texture() -> ImageTexture:
	var image: Image = Image.create(5, 5, false, Image.FORMAT_RGBA8)
	for y: int in 5:
		for x: int in 5:
			var d: int = absi(x - 2) + absi(y - 2)
			var alpha: float = [1.0, 0.45, 0.15][d] if d <= 2 else 0.0
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


# 3x2 leaf
static func _leaf_texture() -> ImageTexture:
	var image: Image = Image.create(3, 2, false, Image.FORMAT_RGBA8)
	for pixel: Vector2i in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		image.set_pixelv(pixel, Color.WHITE)
	return ImageTexture.create_from_image(image)
