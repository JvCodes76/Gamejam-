class_name GroundItem
extends Node2D

@export var bob_height: float = 2.0
@export var bob_time: float = 0.8

var entry: Dictionary = {}

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _label: Label = $PromptLabel


func _ready() -> void:
	add_to_group("ground_item")
	_label.visible = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(_sprite, "position:y", -bob_height, bob_time).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_sprite, "position:y", 0.0, bob_time).set_trans(Tween.TRANS_SINE)


## Guarda a entry (mesma referência do ItemManager) e mostra o ícone.
func setup(new_entry: Dictionary) -> void:
	entry = new_entry
	position = new_entry["position"]
	var item: ItemData = new_entry["item"]
	_sprite.texture = item.icon
	if item.icon != null:
		var size: Vector2 = item.icon.get_size()
		_sprite.scale = Vector2.ONE * minf(1.0, 16.0 / maxf(size.x, size.y))


## Mostra ou esconde o prompt "E".
func set_highlighted(value: bool) -> void:
	_label.visible = value
