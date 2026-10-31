class_name RoomEncounter
extends Node
## Comportamento de uma sala quando o player entra pela primeira vez:
## caldeirão (enxame + 1 elite), elite (3 elites, tranca), horda (timer, tranca) e boss (placeholder).

var room: RoomData

var _level: DungeonLevel
var _alive: int = 0
var _started: bool = false
var _timer_left: float = 0.0
var _timer_active: bool = false


func setup(new_room: RoomData, level: DungeonLevel) -> void:
	room = new_room
	_level = level
	set_process(false)


## Chamado uma vez, quando o player entra na sala.
func on_player_entered() -> void:
	if _started:
		return
	_started = true
	room.visited = true
	print("[Dungeon] - sala %s entrada" % RoomData.Type.keys()[room.type])
	match room.type:
		RoomData.Type.CAULDRON:
			_spawn_swarm(_level.cauldron_swarm_count)
			_spawn_elites(1)
		RoomData.Type.ELITE:
			_lock()
			_spawn_elites(_level.elite_room_count)
		RoomData.Type.HORDE:
			_lock()
			_spawn_swarm(_level.horde_enemy_count)
			_timer_left = _level.horde_time_limit
			_timer_active = true
			set_process(true)
		RoomData.Type.BOSS:
			print("[Dungeon] - sala do boss: arena e boss ainda não implementados")
		_:
			room.cleared = true


func _process(delta: float) -> void:
	if not _timer_active:
		return
	_timer_left -= delta
	EventBus.horde_timer_changed.emit(maxf(_timer_left, 0.0))
	if _timer_left <= 0.0:
		_timer_active = false
		set_process(false)
		print("[Dungeon] - horda: tempo esgotado, portas abertas")
		EventBus.horde_timer_changed.emit(-1.0)
		_unlock()


# Cria "count" inimigos fracos em pontos livres da sala.
func _spawn_swarm(count: int) -> void:
	for i: int in count:
		_spawn(_level.swarm_scenes.pick_random(), false)


# Cria "count" elites (placeholder: inimigo base com mais vida, maior e azulado).
func _spawn_elites(count: int) -> void:
	for i: int in count:
		_spawn(_level.elite_scene, true)


func _spawn(scene: PackedScene, is_elite: bool) -> void:
	if scene == null:
		return
	var enemy: EnemyBase = scene.instantiate() as EnemyBase
	var sprite: Sprite2D = enemy.get_node("Sprite2D") as Sprite2D
	if is_elite:
		var health: HealthComponent = enemy.get_node("HealthComponent") as HealthComponent
		health.max_health = roundi(health.max_health * _level.elite_health_multiplier)
		sprite.scale *= _level.elite_scale
		sprite.modulate = _level.elite_tint
		enemy.is_basic = false
		enemy.add_to_group("elite")
	_level.enemy_root.add_child(enemy)
	enemy.global_position = _random_point()
	enemy.tree_exited.connect(_on_enemy_gone)
	_alive += 1


# Ponto livre aleatório dentro da sala, longe do player.
func _random_point() -> Vector2:
	var area: Rect2 = room.rect.grow(-48.0)
	area.position.y += 40.0
	area.size.y -= 40.0
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var point: Vector2 = area.get_center()
	for attempt: int in _level.spawn_attempts:
		point = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		var far_enough: bool = player == null or point.distance_to(player.global_position) >= _level.min_spawn_distance
		if far_enough and SpawnCheck.is_free(_level, point, 12.0):
			return point
	return point


func _on_enemy_gone() -> void:
	# Ignora a limpeza da árvore (troca de cemitério ou saída ao menu)
	if not is_inside_tree():
		return
	_alive -= 1
	if _alive > 0 or room.cleared:
		return
	room.cleared = true
	print("[Dungeon] - sala %s limpa" % RoomData.Type.keys()[room.type])
	if _timer_active:
		_timer_active = false
		set_process(false)
		EventBus.horde_timer_changed.emit(-1.0)
	_unlock()


func _lock() -> void:
	room.set_doors_closed.call_deferred(true)


func _unlock() -> void:
	room.set_doors_closed.call_deferred(false)
