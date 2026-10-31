class_name GroundItemSpawner
extends Node2D

const GROUND_ITEM_SCENE: PackedScene = preload("res://inventory/ground_item.tscn")

@export var starting_items: Array[ItemData] = []
@export var seed_on_first_load: bool = true
@export var min_radius: float = 80.0
@export var max_radius: float = 160.0

var _nodes: Dictionary = {}  # entry (Dictionary) -> GroundItem


func _ready() -> void:
	if seed_on_first_load and not ItemManager.starting_items_seeded:
		ItemManager.starting_items_seeded = true
		_seed_starting_items()
	EventBus.ground_items_changed.connect(_sync)
	_sync()


## Solta os itens iniciais espalhados ao redor do centro.
func _seed_starting_items() -> void:
	var count: int = starting_items.size()
	var offset: float = randf() * TAU
	for i: int in count:
		var angle: float = offset + TAU * float(i) / float(maxi(count, 1))
		var pos: Vector2 = Vector2.from_angle(angle) * randf_range(min_radius, max_radius)
		ItemManager.drop_to_ground(starting_items[i], pos)
	print("[Inventory] - %d itens iniciais no chão" % count)


## Ressincroniza os nós com ItemManager.ground_entries.
func _sync() -> void:
	for entry: Dictionary in _nodes.keys():
		if not ItemManager.ground_entries.has(entry):
			_nodes[entry].queue_free()
			_nodes.erase(entry)
	for entry: Dictionary in ItemManager.ground_entries:
		if _nodes.has(entry):
			continue
		var node: GroundItem = GROUND_ITEM_SCENE.instantiate()
		add_child(node)
		node.setup(entry)
		_nodes[entry] = node
