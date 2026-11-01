class_name PoisonCloud
extends Node2D
## Poison cloud (Deathcap): left where an enemy was poisoned; poisons everyone inside it for a few seconds.
## No scene: the area is checked with a physics query every POISON_CLOUD_TICK.

var radius: float = 0.0
var lifetime: float = CombatConstants.POISON_CLOUD_LIFETIME
var modifiers: ProjectileModifiers = null
var base_damage: int = 1

var _age: float = 0.0
var _tick_left: float = 0.0
var _puffs: Array[Vector3] = []


## Creates a cloud under the poisoned enemy (deferred add, safe inside physics callbacks).
## Skips the spawn if another cloud already covers that spot.
static func spawn(scene: Node, target: Hurtbox, mods: ProjectileModifiers, new_base_damage: int) -> PoisonCloud:
	var owner_node: Node2D = target.get_parent() as Node2D
	if scene == null or owner_node == null:
		return null
	var pos: Vector2 = owner_node.global_position
	var new_radius: float = CombatConstants.POISON_CLOUD_RADIUS_PER_POINT * mods.poison_cloud_level
	for node: Node in scene.get_tree().get_nodes_in_group("poison_cloud"):
		if (node as Node2D).global_position.distance_to(pos) < new_radius * 0.5:
			return null
	var cloud: PoisonCloud = PoisonCloud.new()
	cloud.global_position = pos
	cloud.radius = new_radius
	cloud.modifiers = mods
	cloud.base_damage = new_base_damage
	scene.add_child.call_deferred(cloud)
	return cloud


func _ready() -> void:
	add_to_group("poison_cloud")
	z_index = CombatConstants.Z_CLOUD
	for i: int in 5:
		var offset: Vector2 = Vector2.from_angle(randf() * TAU) * radius * randf_range(0.1, 0.55)
		_puffs.append(Vector3(offset.x, offset.y, radius * randf_range(0.4, 0.7)))


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(CombatConstants.POISON_CLOUD_COLOR, CombatConstants.POISON_CLOUD_COLOR.a * 0.6))
	for puff: Vector3 in _puffs:
		draw_circle(Vector2(puff.x, puff.y), puff.z, CombatConstants.POISON_CLOUD_COLOR)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	modulate.a = clampf((lifetime - _age) / 0.6, 0.0, 1.0)
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left += CombatConstants.POISON_CLOUD_TICK
		_poison_inside()


## Renews the poison (same source as the hit poison, does not stack) on every enemy inside the cloud.
func _poison_inside() -> void:
	if modifiers == null:
		return
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = PhysicsLayers.ENEMY
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var span: float = CombatConstants.POISON_CLOUD_TICK * 2.5
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var hurtbox: Hurtbox = hit["collider"] as Hurtbox
		if hurtbox == null:
			continue
		var mods: ProjectileModifiers = modifiers.for_target(hurtbox)
		hurtbox.apply_dot(mods.poison_dps(base_damage), span, &"poison", CombatConstants.POISON_TICK)
		if mods.synergy.poison_slow > 0.0:
			hurtbox.apply_slow(&"poison", span, mods.synergy.poison_slow)
		if mods.synergy.poison_weaken > 0.0:
			hurtbox.apply_status(StatusEffects.WEAKENED, span, mods.synergy.poison_weaken)
