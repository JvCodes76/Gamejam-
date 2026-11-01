extends Node2D

@export var enemy_scene: PackedScene
# Extra variants rolled along with enemy_scene (e.g. Skull)
@export var extra_enemy_scenes: Array[PackedScene] = []
@export var spawn_interval: float = 1.5
@export var max_enemies: int = 12
@export var spawn_radius: float = 260.0
# Playable area; spawns are limited to it so they do not appear inside walls
# (the top stops at y=-312: the arena's top wall is at y=-322, so the player's head does not leave the ground)
@export var spawn_bounds: Rect2 = Rect2(-620.0, -312.0, 1240.0, 652.0)

const SPAWN_ATTEMPTS: int = 8

var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = spawn_interval
	_timer.autostart = true
	_timer.timeout.connect(_spawn_enemy)
	add_child(_timer)


# Creates an enemy at a random free point around the player.
func _spawn_enemy() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if enemy_scene == null or player == null:
		return
	if get_tree().get_nodes_in_group("enemy").size() >= max_enemies:
		return
	var pos: Vector2 = Vector2.ZERO
	var found: bool = false
	for attempt: int in SPAWN_ATTEMPTS:
		var candidate: Vector2 = player.global_position + Vector2.from_angle(randf() * TAU) * spawn_radius
		candidate = candidate.clamp(spawn_bounds.position, spawn_bounds.end)
		if SpawnCheck.is_free(self, candidate):
			pos = candidate
			found = true
			break
	if not found:
		print("[Enemy] - no free spawn point (%d attempts)" % SPAWN_ATTEMPTS)
		return
	var pool: Array[PackedScene] = [enemy_scene]
	pool.append_array(extra_enemy_scenes)
	var enemy := pool.pick_random().instantiate() as Node2D
	add_child(enemy)
	enemy.global_position = pos
	print("[Enemy] - spawn at %s" % enemy.global_position)
