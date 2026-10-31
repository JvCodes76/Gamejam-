class_name GroundItem
extends Node2D

@export var bob_height: float = 2.0
@export var bob_time: float = 0.8
@export var outline_width_px: float = 2.0

var entry: Dictionary = {}

var _outlines: Array[Line2D] = []

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("ground_item")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var base_y: float = _sprite.position.y
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(_sprite, "position:y", base_y - bob_height, bob_time).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_sprite, "position:y", base_y, bob_time).set_trans(Tween.TRANS_SINE)


## Guarda a entry (mesma referência do ItemManager) e mostra o ícone com seu contorno.
func setup(new_entry: Dictionary) -> void:
	entry = new_entry
	position = new_entry["position"]
	var item: ItemData = new_entry["item"]
	_sprite.texture = item.icon
	if item.icon != null:
		var size: Vector2 = item.icon.get_size()
		_sprite.scale = Vector2.ONE * minf(1.0, 16.0 / maxf(size.x, size.y))
		_build_outline(item)


## Mostra ou esconde o contorno na cor da raridade (item ao alcance do player).
func set_highlighted(value: bool) -> void:
	for line: Line2D in _outlines:
		line.visible = value


# Cria um Line2D por polígono do sprite, filho do Sprite2D (acompanha escala e oscilação).
func _build_outline(item: ItemData) -> void:
	var color: Color = ItemEnums.RARITY_COLORS.get(item.rarity, Color.WHITE)
	for polygon: PackedVector2Array in ColliderBuilder.build_polygons(item.icon):
		var line: Line2D = Line2D.new()
		line.points = polygon
		line.closed = true
		line.default_color = color
		line.width = outline_width_px / _sprite.scale.x
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.visible = false
		_sprite.add_child(line)
		_outlines.append(line)
