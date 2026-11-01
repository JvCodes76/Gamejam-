class_name PotionSlot
extends Control
## Potion slot: colored liquid (interior mask) behind the flask sprite.

const FLASK: Texture2D = preload("res://assets/sprites/ui/Flask.png")
const LIQUID_MASK: Texture2D = preload("res://assets/sprites/ui/potion_flask_liquid_mask.png")
## Rows at the top of the flask (neck and cork) that stay without liquid
const LIQUID_TOP_SKIP: int = 7

@export var label_text: String = "1"
@export var pixel_scale: int = 2
@export var active_scale: float = 1.2
@export var empty_alpha: float = 0.35
@export var active_border_color: Color = Color(1.0, 1.0, 0.8, 1.0)

var liquid_color: Color = Color.WHITE
var filled: bool = false
var active: bool = false
# Glow ring when the flask becomes active (0 = no ring, 0..1 = expansion)
var _ring_t: float = 0.0
var _scale_tween: Tween


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = FLASK.get_size() * pixel_scale
	custom_minimum_size = size
	pivot_offset = size * 0.5


## Updates the flask's visual state.
func set_state(new_filled: bool, new_color: Color, new_active: bool) -> void:
	var became_active: bool = new_active and not active
	filled = new_filled
	liquid_color = new_color
	active = new_active
	if _scale_tween != null:
		_scale_tween.kill()
	if became_active and is_inside_tree():
		# Grows beyond the active size and returns with a bounce, plus a glow ring
		scale = Vector2.ONE * (active_scale + 0.25)
		_scale_tween = create_tween().set_parallel()
		_scale_tween.tween_property(self, "scale", Vector2.ONE * active_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_scale_tween.tween_method(_set_ring, 0.001, 1.0, 0.3)
	else:
		scale = Vector2.ONE * (active_scale if active else 1.0)
	queue_redraw()


func _set_ring(value: float) -> void:
	_ring_t = value if value < 1.0 else 0.0
	queue_redraw()


## Draws highlight border, liquid, flask on top and label.
func _draw() -> void:
	var s: float = float(pixel_scale)
	if active:
		draw_rect(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), active_border_color, false, 1.0)
	if filled:
		var skip: float = float(LIQUID_TOP_SKIP)
		var src: Rect2 = Rect2(0, skip, LIQUID_MASK.get_width(), LIQUID_MASK.get_height() - skip)
		draw_texture_rect_region(LIQUID_MASK, Rect2(Vector2(0, skip * s), src.size * s), src, liquid_color)
	draw_texture_rect(FLASK, Rect2(Vector2.ZERO, size), false, Color.WHITE if filled else Color(1, 1, 1, empty_alpha))
	if _ring_t > 0.0:
		var ring_color: Color = Color(liquid_color if filled else active_border_color, 1.0 - _ring_t)
		draw_arc(size * 0.5, size.y * (0.5 + _ring_t * 0.6), 0.0, TAU, 24, ring_color, 1.5)
	draw_string(get_theme_default_font(), Vector2(0, size.y + 10), label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, Color(1, 1, 1, 0.9 if active else 0.5))
