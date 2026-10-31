class_name PotionSlot
extends Control
## Slot de poção: líquido colorido (máscara do interior) atrás do sprite do frasco.

const FLASK: Texture2D = preload("res://assets/sprites/ui/Flask.png")
const LIQUID_MASK: Texture2D = preload("res://assets/sprites/ui/potion_flask_liquid_mask.png")
## Linhas do topo do frasco (gargalo e rolha) que ficam sem líquido
const LIQUID_TOP_SKIP: int = 7

@export var label_text: String = "1"
@export var pixel_scale: int = 2
@export var active_scale: float = 1.2
@export var empty_alpha: float = 0.35
@export var active_border_color: Color = Color(1.0, 1.0, 0.8, 1.0)

var liquid_color: Color = Color.WHITE
var filled: bool = false
var active: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = FLASK.get_size() * pixel_scale
	custom_minimum_size = size
	pivot_offset = size * 0.5


## Atualiza o estado visual do frasco.
func set_state(new_filled: bool, new_color: Color, new_active: bool) -> void:
	filled = new_filled
	liquid_color = new_color
	active = new_active
	scale = Vector2.ONE * (active_scale if active else 1.0)
	queue_redraw()


## Desenha borda de destaque, líquido, frasco por cima e rótulo.
func _draw() -> void:
	var s: float = float(pixel_scale)
	if active:
		draw_rect(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), active_border_color, false, 1.0)
	if filled:
		var skip: float = float(LIQUID_TOP_SKIP)
		var src: Rect2 = Rect2(0, skip, LIQUID_MASK.get_width(), LIQUID_MASK.get_height() - skip)
		draw_texture_rect_region(LIQUID_MASK, Rect2(Vector2(0, skip * s), src.size * s), src, liquid_color)
	draw_texture_rect(FLASK, Rect2(Vector2.ZERO, size), false, Color.WHITE if filled else Color(1, 1, 1, empty_alpha))
	draw_string(ThemeDB.fallback_font, Vector2(0, size.y + 10), label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, Color(1, 1, 1, 0.9 if active else 0.5))
