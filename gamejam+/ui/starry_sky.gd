class_name StarrySky
extends Control
## Menu background: night gradient with twinkling stars drawn as points of light (additive halo + bright core)
## and the occasional shooting star.

const STAR_COUNT: int = 140
const SKY_TOP: Color = Color(0.02, 0.02, 0.09)
const SKY_BOTTOM: Color = Color(0.13, 0.06, 0.22)
const HALO_SIZE: int = 32
const SHOOTING_INTERVAL: Vector2 = Vector2(4.0, 9.0)
const SHOOTING_DURATION: float = 0.7
const BOB_AMPLITUDE: Vector2 = Vector2.ZERO  # Pixels (x sway, y bob). Zero = static sky (was Vector2(8, 12))
const BOB_SPEED: Vector2 = Vector2(0.9, 1.3)  # Radians per second
const BOB_MARGIN: float = 24.0  # Sky drawn past the edges so the bobbing never shows a gap

var _stars: Array[Dictionary] = []
var _glow: Control
var _halo: GradientTexture2D
var _dot: GradientTexture2D
var _time: float = 0.0
var _sky_offset: Vector2 = Vector2.ZERO
var _shoot_timer: float = 3.0
var _shoot_t: float = -1.0
var _shoot_from: Vector2
var _shoot_dir: Vector2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_halo = GradientTexture2D.new()
	_halo.fill = GradientTexture2D.FILL_RADIAL
	_halo.fill_from = Vector2(0.5, 0.5)
	_halo.fill_to = Vector2(1.0, 0.5)
	_halo.width = HALO_SIZE
	_halo.height = HALO_SIZE
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_halo.gradient = gradient
	# Soft dot for the star cores: filtered, so sub-pixel movement is smooth instead of jumping pixel by pixel
	_dot = GradientTexture2D.new()
	_dot.fill = GradientTexture2D.FILL_RADIAL
	_dot.fill_from = Vector2(0.5, 0.5)
	_dot.fill_to = Vector2(1.0, 0.5)
	_dot.width = 8
	_dot.height = 8
	var dot_gradient: Gradient = Gradient.new()
	dot_gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	dot_gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_dot.gradient = dot_gradient
	# Additive layer so overlapping halos add up like real lights
	_glow = Control.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = material
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	resized.connect(_generate_stars)
	_generate_stars()


func _process(delta: float) -> void:
	_time += delta
	_shoot_timer -= delta
	if _shoot_t >= 0.0:
		_shoot_t += delta / SHOOTING_DURATION
		if _shoot_t > 1.0:
			_shoot_t = -1.0
	elif _shoot_timer <= 0.0:
		_shoot_timer = randf_range(SHOOTING_INTERVAL.x, SHOOTING_INTERVAL.y)
		_shoot_t = 0.0
		_shoot_from = Vector2(randf_range(0.1, 0.9) * size.x, randf_range(0.0, 0.4) * size.y)
		_shoot_dir = Vector2(randf_range(0.6, 1.0) * (1.0 if randf() < 0.5 else -1.0), 0.5).normalized()
	var offset: Vector2 = Vector2(sin(_time * BOB_SPEED.x) * BOB_AMPLITUDE.x, sin(_time * BOB_SPEED.y) * BOB_AMPLITUDE.y)
	_sky_offset = offset
	queue_redraw()
	_glow.queue_redraw()


func _generate_stars() -> void:
	_stars.clear()
	for i: int in STAR_COUNT:
		var y_ratio: float = pow(randf(), 1.4)  # More stars near the top, fading toward the horizon
		var big: bool = randf() < 0.12
		_stars.append({
			"pos": Vector2(randf() * size.x, y_ratio * size.y),
			"radius": randf_range(5.0, 9.0) if big else randf_range(2.0, 4.5),
			"speed": randf_range(0.6, 2.2),
			"depth": randf_range(0.4, 1.0),  # Parallax: nearer (bigger) stars bob more
			"phase": randf() * TAU,
			"color": [Color(1, 1, 1), Color(0.75, 0.85, 1.0), Color(1.0, 0.92, 0.7)].pick_random(),
			"big": big,
		})


func _draw() -> void:
	# The gradient bobs together with the stars (it is oversized by BOB_MARGIN to cover the edges)
	var margin: Vector2 = Vector2.ONE * BOB_MARGIN
	var top_left: Vector2 = _sky_offset - margin
	var bottom_right: Vector2 = _sky_offset + size + margin
	var points: PackedVector2Array = PackedVector2Array([top_left, Vector2(bottom_right.x, top_left.y), bottom_right, Vector2(top_left.x, bottom_right.y)])
	var colors: PackedColorArray = PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM])
	draw_polygon(points, colors)


func _draw_glow() -> void:
	for star: Dictionary in _stars:
		var twinkle: float = 0.55 + 0.45 * sin(_time * star.speed + star.phase)
		var color: Color = star.color
		var radius: float = star.radius * (0.8 + 0.2 * twinkle)
		var pos: Vector2 = star.pos + _sky_offset * star.depth
		var halo_rect: Rect2 = Rect2(pos - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		_glow.draw_texture_rect(_halo, halo_rect, false, Color(color, 0.55 * twinkle))
		# Bright 1px core (2px on bigger stars), plus a small cross flare on those
		var core: float = 2.0 if star.big else 1.0
		var core_size: Vector2 = Vector2.ONE * core * 2.4
		_glow.draw_texture_rect(_dot, Rect2(pos + Vector2.ONE * 0.5 * core - core_size * 0.5, core_size), false, Color(color, 0.6 + 0.4 * twinkle))
		if star.big:
			var flare: float = radius * 0.9 * twinkle
			_glow.draw_line(pos + Vector2(-flare, 0.5), pos + Vector2(flare + 1, 0.5), Color(color, 0.35 * twinkle), 1.0, true)
			_glow.draw_line(pos + Vector2(0.5, -flare), pos + Vector2(0.5, flare + 1), Color(color, 0.35 * twinkle), 1.0, true)
	if _shoot_t >= 0.0:
		var head: Vector2 = _shoot_from + _shoot_dir * _shoot_t * size.x * 0.5
		var fade: float = sin(_shoot_t * PI)
		for i: int in 12:
			var segment: float = float(i) / 12.0
			var tail: Vector2 = head - _shoot_dir * segment * 40.0
			_glow.draw_circle(tail, 1.5 * (1.0 - segment) + 0.5, Color(1, 1, 1, fade * (1.0 - segment)))
		_glow.draw_texture_rect(_halo, Rect2(head - Vector2.ONE * 8.0, Vector2.ONE * 16.0), false, Color(1, 1, 1, 0.7 * fade))
