class_name Interactor
extends Area2D

@export var interact_radius: float = 28.0

var _target: Node2D = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = interact_radius
	shape.shape = circle
	add_child(shape)


func _physics_process(_delta: float) -> void:
	var best: Node2D = null
	var best_dist: float = interact_radius
	for node: Node in get_tree().get_nodes_in_group("ground_item"):
		var item_node: GroundItem = node as GroundItem
		if item_node == null or item_node.is_queued_for_deletion():
			continue
		var dist: float = global_position.distance_to(item_node.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = item_node
	for node: Node in get_tree().get_nodes_in_group("cauldron"):
		var cauldron: Cauldron = node as Cauldron
		if cauldron == null or cauldron.is_queued_for_deletion():
			continue
		var dist: float = global_position.distance_to(cauldron.global_position) - cauldron.interact_reach
		if dist <= best_dist:
			best_dist = dist
			best = cauldron
	if best == _target:
		return
	_set_highlight(_target, false)
	_target = best
	_set_highlight(_target, true)


# Turns the target highlight on or off (ground item or cauldron)
func _set_highlight(node: Node2D, value: bool) -> void:
	if is_instance_valid(node) and node.has_method("set_highlighted"):
		node.call("set_highlighted", value)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if get_tree().paused or ItemManager.inventory_open or not is_instance_valid(_target):
		return
	if _target is Cauldron:
		EventBus.cauldron_open_requested.emit(_target)
		return
	var ground: GroundItem = _target as GroundItem
	if ground == null:
		return
	var entry: Dictionary = ground.entry
	var item: ItemData = entry["item"]
	_target = null
	var from: Vector2 = ground.global_position
	EventBus.play_sfx_requested.emit("pickup")
	EventBus.item_collected.emit(item.id, from)
	if ItemManager.try_auto_store(item):
		var icon: Sprite2D = ground.get_node("Sprite2D") as Sprite2D
		PickupFx.spawn(get_tree().current_scene, icon.global_position, item.icon, icon.scale, get_parent() as Node2D, item.color, item.display_name)
		ItemManager.take_from_ground(entry)
		EventBus.item_picked_up.emit(item.id)
	else:
		ItemManager.take_from_ground(entry)
		ItemManager.pending_items.append(item)
		EventBus.inventory_open_requested.emit()
