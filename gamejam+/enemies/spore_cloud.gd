class_name SporeCloud
extends Node2D
## Lingering spore cloud released by the mushroom elite: hurts whoever stays inside every "tick" seconds
## (the player, or the enemies when the mushroom was charmed) and fades away at the end.

# Fade in/out time (s)
const FADE_TIME: float = 0.4
const PUFF_COUNT: int = 7

var radius: float = 80.0
var lifetime: float = 2.5
var tick: float = 0.5
var damage: int = 15
var color: Color = Color(0.55, 0.85, 0.25)
var hits_enemies: bool = false
# Who released it (never hurt by its own cloud)
var source: Node = null

var _age: float = 0.0
var _tick_left: float = 0.0
# Puffs (offset angle, distance, radius, spin speed) that give a smoke look
var _puffs: Array[Vector4] = []


## Creates a cloud in the scene (deferred add, safe inside physics callbacks).
static func spawn(scene: Node, pos: Vector2, new_radius: float, new_lifetime: float, new_tick: float, new_damage: int, new_color: Color, new_hits_enemies: bool, new_source: Node) -> SporeCloud:
	var cloud: SporeCloud = SporeCloud.new()
	cloud.position = pos
	cloud.radius = new_radius
	cloud.lifetime = new_lifetime
	cloud.tick = new_tick
	cloud.damage = new_damage
	cloud.color = new_color
	cloud.hits_enemies = new_hits_enemies
	cloud.source = new_source
	scene.add_child.call_deferred(cloud)
	return cloud


func _ready() -> void:
	z_index = CombatConstants.Z_CLOUD
	# First hit only after a short delay: the player sees the cloud before it hurts
	_tick_left = minf(tick, 0.2)
	for i: int in PUFF_COUNT:
		_puffs.append(Vector4(randf() * TAU, radius * randf_range(0.2, 0.7), radius * randf_range(0.3, 0.5), randf_range(-0.8, 0.8)))


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	modulate.a = clampf(minf(_age, lifetime - _age) / FADE_TIME, 0.0, 1.0)
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left += tick
		_hurt_inside()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(color, 0.18))
	for puff: Vector4 in _puffs:
		var angle: float = puff.x + puff.w * _age
		draw_circle(Vector2.from_angle(angle) * puff.y, puff.z, Color(color, 0.22))


# Hurts every target whose feet are inside the cloud
func _hurt_inside() -> void:
	if hits_enemies:
		for node: Node in get_tree().get_nodes_in_group("enemy"):
			var enemy: EnemyBase = node as EnemyBase
			if enemy != null and enemy != source and enemy.is_alive() and _is_inside(enemy):
				enemy.get_hurtbox().receive_hit(damage, global_position.direction_to(enemy.global_position))
		return
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not _is_inside(player):
		return
	var hurtbox: Hurtbox = player.get_node_or_null("Hurtbox") as Hurtbox
	if hurtbox != null:
		hurtbox.receive_hit(damage, global_position.direction_to(player.global_position))


func _is_inside(target: Node2D) -> bool:
	return target.global_position.distance_to(global_position) <= radius
