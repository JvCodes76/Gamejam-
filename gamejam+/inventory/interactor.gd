class_name Interactor
extends Area2D

@export var interact_radius: float = 28.0

var _target: GroundItem = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = interact_radius
	shape.shape = circle
	add_child(shape)


func _physics_process(_delta: float) -> void:
	var best: GroundItem = null
	var best_dist: float = interact_radius
	for node: Node in get_tree().get_nodes_in_group("ground_item"):
		var item_node: GroundItem = node as GroundItem
		if item_node == null or item_node.is_queued_for_deletion():
			continue
		var dist: float = global_position.distance_to(item_node.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = item_node
	if best == _target:
		return
	if is_instance_valid(_target):
		_target.set_highlighted(false)
	_target = best
	if _target != null:
		_target.set_highlighted(true)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if get_tree().paused or ItemManager.inventory_open or not is_instance_valid(_target):
		return
	var entry: Dictionary = _target.entry
	var item: ItemData = entry["item"]
	_target = null
	if ItemManager.try_auto_store(item):
		ItemManager.take_from_ground(entry)
		EventBus.item_picked_up.emit(item.id)
	else:
		ItemManager.take_from_ground(entry)
		ItemManager.pending_items.append(item)
		EventBus.inventory_open_requested.emit()
