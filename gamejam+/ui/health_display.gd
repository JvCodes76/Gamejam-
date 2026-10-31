class_name HealthDisplay
extends Control
## Vida desenhada como blocos (Fase 2: corações/frascos em sprite). Ao perder vida o bloco estoura em partículas,
## o HUD treme e pisca; com 1 de vida o último bloco pulsa.

@export var block_size: Vector2 = Vector2(9.0, 9.0)
@export var block_gap: float = 3.0
@export var full_color: Color = Color(0.9, 0.15, 0.2)
@export var empty_color: Color = Color(0.15, 0.05, 0.08, 0.8)
@export var border_color: Color = Color(0.05, 0.0, 0.02)

var current: int = 0
var max_value: int = 0

var _base_position: Vector2
var _shake_left: float = 0.0
var _blink_left: float = 0.0
var _time: float = 0.0
var _particle_texture: ImageTexture


func _ready() -> void:
	_base_position = position
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_particle_texture = ImageTexture.create_from_image(img)


## Atualiza a vida; se diminuiu, estoura os blocos perdidos e treme.
func set_health(new_current: int, new_max: int) -> void:
	var lost_from: int = new_current
	var lost_to: int = current
	var lost: bool = new_current < current and max_value > 0
	current = new_current
	max_value = new_max
	custom_minimum_size = Vector2(new_max * (block_size.x + block_gap), block_size.y)
	size = custom_minimum_size
	if lost:
		for i: int in range(lost_from, lost_to):
			_burst(_block_rect(i).get_center())
		_shake_left = 0.3
		_blink_left = 0.4
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _shake_left > 0.0:
		_shake_left -= delta
		position = _base_position + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)) * (_shake_left / 0.3)
		if _shake_left <= 0.0:
			position = _base_position
	if _blink_left > 0.0:
		_blink_left -= delta
		modulate = Color(3.0, 3.0, 3.0) if int(_blink_left / 0.06) % 2 == 0 else Color.WHITE
		if _blink_left <= 0.0:
			modulate = Color.WHITE
	if current == 1 or _shake_left > 0.0 or _blink_left > 0.0:
		queue_redraw()


func _block_rect(index: int) -> Rect2:
	return Rect2(Vector2(index * (block_size.x + block_gap), 0.0), block_size)


func _draw() -> void:
	for i: int in max_value:
		var rect: Rect2 = _block_rect(i)
		var filled: bool = i < current
		if filled and current == 1:
			var pulse: float = 1.0 + 0.15 * absf(sin(_time * 6.0))
			rect = Rect2(rect.get_center() - rect.size * pulse * 0.5, rect.size * pulse)
		draw_rect(rect.grow(1.0), border_color)
		draw_rect(rect, full_color if filled else empty_color)
		if filled:
			draw_rect(Rect2(rect.position + Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(1.0, 0.7, 0.7))


func _burst(at: Vector2) -> void:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.texture = _particle_texture
	p.position = at
	p.amount = 10
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.45
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 70.0
	p.gravity = Vector2(0.0, 160.0)
	var fade: Gradient = Gradient.new()
	fade.set_color(0, full_color.lightened(0.3))
	fade.set_color(1, Color(full_color, 0.0))
	p.color_ramp = fade
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
