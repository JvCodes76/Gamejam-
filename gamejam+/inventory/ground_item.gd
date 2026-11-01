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


## Stores the entry (same reference as the ItemManager) and shows the icon with its outline.
func setup(new_entry: Dictionary) -> void:
	entry = new_entry
	position = new_entry["position"]
	var item: ItemData = new_entry["item"]
	_sprite.texture = item.icon
	if item.icon != null:
		var size: Vector2 = item.icon.get_size()
		_sprite.scale = Vector2.ONE * minf(1.0, 16.0 / maxf(size.x, size.y))
		_build_outline(item)
	_start_glow()


# Pulsing glow: the icon gets lighter and returns (Phase 2 may swap it for a glow shader)
func _start_glow() -> void:
	var glow: Tween = create_tween().set_loops()
	glow.tween_property(_sprite, "self_modulate", Color(1.45, 1.45, 1.45, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
	glow.tween_property(_sprite, "self_modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)


## Shows or hides the outline in the rarity color (item within the player's reach).
func set_highlighted(value: bool) -> void:
	for line: Line2D in _outlines:
		line.visible = value


# Creates a Line2D per sprite polygon, child of the Sprite2D (follows scale and bobbing).
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
