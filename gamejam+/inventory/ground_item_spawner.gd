class_name GroundItemSpawner
extends Node2D

const GROUND_ITEM_SCENE: PackedScene = preload("res://inventory/ground_item.tscn")

const SPAWN_ATTEMPTS: int = 8

@export var starting_items: Array[ItemData] = []
@export var seed_on_first_load: bool = true
@export var min_radius: float = 80.0
@export var max_radius: float = 160.0

var _nodes: Dictionary = {}  # entry (Dictionary) -> GroundItem


func _ready() -> void:
	# Ground items sit above the ground and decals, but below everything that is Y-sorted
	z_index = CombatConstants.Z_GROUND_ITEM
	EventBus.ground_items_changed.connect(_sync)
	if seed_on_first_load and not ItemManager.starting_items_seeded:
		ItemManager.starting_items_seeded = true
		# Waits one frame: the props' solid bodies only enter the physics space after _ready
		await get_tree().process_frame
		_seed_starting_items()
	_sync()


## Drops the initial items scattered around the center.
func _seed_starting_items() -> void:
	var count: int = starting_items.size()
	var offset: float = randf() * TAU
	for i: int in count:
		var angle: float = offset + TAU * float(i) / float(maxi(count, 1))
		var pos: Vector2 = Vector2.from_angle(angle) * randf_range(min_radius, max_radius)
		for attempt: int in SPAWN_ATTEMPTS:
			if SpawnCheck.is_free(self, pos):
				break
			pos = Vector2.from_angle(angle + randf_range(-0.3, 0.3)) * randf_range(min_radius, max_radius)
		ItemManager.drop_to_ground(starting_items[i], pos)
	print("[Inventory] - %d initial items on the ground" % count)


## Resyncs the nodes with ItemManager.ground_entries.
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
