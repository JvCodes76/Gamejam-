class_name RoomEncounter
extends Node
## Behavior of a room when the player first enters:
## cauldron (swarm + 1 elite, locks), elite (3 random elites, locks), horde (timer, locks) and boss (locks; placeholder).
## In infinite mode enemies gain health, damage, speed and count every loop (see DungeonLevel).

enum Kind { SWARM, ELITE, BOSS }

# Tutorial enemies: basic skulls and a ghost elite
const TUTORIAL_SKULL: PackedScene = preload("res://enemies/skull.tscn")
const TUTORIAL_ELITE: PackedScene = preload("res://enemies/ghost_elite.tscn")
const TUTORIAL_COMBAT_SKULLS: int = 3
const TUTORIAL_FIGHT_SKULLS: int = 2

var room: RoomData

var _level: DungeonLevel
var _alive: int = 0
var _started: bool = false
var _timer_left: float = 0.0
var _timer_active: bool = false
# Time (ms) of the last spawn shake: a batch of spawns shakes the screen only once
var _last_spawn_shake: int = -100000


func setup(new_room: RoomData, level: DungeonLevel) -> void:
	room = new_room
	_level = level
	set_process(false)


## Called once, when the player enters the room.
func on_player_entered() -> void:
	if _started:
		return
	_started = true
	room.visited = true
	print("[Dungeon] - room %s entered" % RoomData.Type.keys()[room.type])
	if room.tutorial_step != RoomData.TutorialStep.NONE:
		_enter_tutorial()
		return
	match room.type:
		RoomData.Type.CAULDRON:
			_lock()
			_spawn_swarm(_level.loop_count(_level.cauldron_swarm_count))
			_spawn_elites(1)
		RoomData.Type.ELITE:
			_lock()
			_spawn_elites(_level.loop_count(_level.elite_room_count))
		RoomData.Type.HORDE:
			_lock()
			_spawn_swarm(_level.loop_count(_level.horde_enemy_count))
			_timer_left = _level.horde_time_limit
			_timer_active = true
			set_process(true)
		RoomData.Type.BOSS:
			_lock()
			_spawn_boss()
		_:
			room.cleared = true


# Tutorial rooms: fixed enemies (no mimics, no random elites) and the director's popups.
func _enter_tutorial() -> void:
	match room.tutorial_step:
		RoomData.TutorialStep.COMBAT:
			_lock()
			for i: int in TUTORIAL_COMBAT_SKULLS:
				_spawn(TUTORIAL_SKULL, Kind.SWARM)
		RoomData.TutorialStep.FIGHT:
			_lock()
			_spawn(TUTORIAL_ELITE, Kind.ELITE)
			for i: int in TUTORIAL_FIGHT_SKULLS:
				_spawn(TUTORIAL_SKULL, Kind.SWARM)
		_:
			room.cleared = true
	if _level.tutorial != null:
		_level.tutorial.on_room_entered(room)


func _process(delta: float) -> void:
	if not _timer_active:
		return
	_timer_left -= delta
	EventBus.horde_timer_changed.emit(maxf(_timer_left, 0.0))
	if _timer_left <= 0.0:
		_timer_active = false
		set_process(false)
		print("[Dungeon] - horde: time ran out, doors stay closed until the room is cleared")
		EventBus.horde_timer_changed.emit(-1.0)


# Creates "count" weak enemies at free points in the room.
func _spawn_swarm(count: int) -> void:
	for i: int in count:
		_spawn(_level.swarm_scenes.pick_random(), Kind.SWARM)


# Creates "count" elites rolled from elite_scenes (without its own elites, uses the elite_scene placeholder).
func _spawn_elites(count: int) -> void:
	for i: int in count:
		var scene: PackedScene = _level.elite_scenes.pick_random() if not _level.elite_scenes.is_empty() else _level.elite_scene
		_spawn(scene, Kind.ELITE)


# Creates the boss at the center of the room (without boss_scene, uses a much larger, reddish elite_scene as a placeholder).
func _spawn_boss() -> void:
	var scene: PackedScene = _level.boss_scene if _level.boss_scene != null else _level.elite_scene
	_spawn(scene, Kind.BOSS, room.center())


# Marks the spot on the ground and only creates the enemy when the warning ends (the enemy already counts as alive).
func _spawn(scene: PackedScene, kind: Kind, point: Vector2 = Vector2.INF) -> void:
	if scene == null:
		return
	var marker: SpawnMarker = SpawnMarker.new()
	marker.duration = FeelConstants.SPAWN_WARNING_TIME + randf_range(0.0, 0.2)
	marker.finished.connect(_spawn_now.bind(scene, kind))
	_level.add_child(marker)
	marker.global_position = point if point != Vector2.INF else _random_point()
	_alive += 1


func _spawn_now(point: Vector2, scene: PackedScene, kind: Kind) -> void:
	var enemy: EnemyBase = scene.instantiate() as EnemyBase
	var sprite: Sprite2D = enemy.get_node("Sprite2D") as Sprite2D
	var health: HealthComponent = enemy.get_node("HealthComponent") as HealthComponent
	match kind:
		Kind.ELITE:
			health.max_health = roundi(health.max_health * _level.elite_health_multiplier)
			# Elites with their own art already come in the right size and color
			if not enemy.has_elite_art:
				sprite.scale *= _level.elite_scale
				sprite.modulate = _level.elite_tint
			enemy.is_basic = false
			# Keeps a higher resistance from the scene (e.g. the static mushroom is immovable)
			enemy.knockback_resistance = maxf(enemy.knockback_resistance, FeelConstants.ELITE_KNOCKBACK_RESISTANCE)
			enemy.add_to_group("elite")
		Kind.BOSS:
			health.max_health = roundi(health.max_health * _level.boss_health_multiplier)
			enemy.move_speed *= _level.boss_move_speed_multiplier
			enemy.points = _level.boss_points
			enemy.is_basic = false
			enemy.knockback_resistance = 1.0
			enemy.add_to_group("boss")
			# Only the placeholder (without its own scene) is enlarged and tinted; the boss scene already comes in the right size
			if _level.boss_scene == null:
				sprite.scale *= _level.boss_scale
				sprite.modulate = _level.boss_tint
				for area_name: String in ["Hurtbox", "Hitbox"]:
					var area: Node2D = enemy.get_node_or_null(area_name) as Node2D
					if area != null:
						area.scale *= _level.boss_scale
	_apply_loop_scaling(enemy, health)
	_level.enemy_root.add_child(enemy)
	enemy.global_position = point
	enemy.tree_exited.connect(_on_enemy_gone)
	enemy.play_spawn_pop()
	var fx: ImpactEffect = ImpactEffect.spawn_burst(_level, point, 10.0, Color(0.85, 0.2, 0.25), 6, 0.35, 1.0, 0.7)
	fx.global_position = point
	var now: int = Time.get_ticks_msec()
	if now - _last_spawn_shake > 250:
		_last_spawn_shake = now
		EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_SPAWN)


# Infinite mode: health, contact damage, speed and points grow with every completed loop.
func _apply_loop_scaling(enemy: EnemyBase, health: HealthComponent) -> void:
	if GameManager.loop_index <= 0:
		return
	health.max_health = maxi(1, roundi(health.max_health * _level.loop_health_multiplier()))
	var hitbox: Hitbox = enemy.get_node_or_null("Hitbox") as Hitbox
	if hitbox != null:
		hitbox.damage = maxi(1, roundi(hitbox.damage * _level.loop_damage_multiplier()))
	enemy.move_speed *= _level.loop_speed_multiplier()
	enemy.points = roundi(enemy.points * _level.loop_points_multiplier())


# Random free point inside the room, away from the player.
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
	# Ignored when the tree is being cleaned up (graveyard change or exit to the menu)
	if not is_inside_tree():
		return
	_alive -= 1
	if _alive > 0 or room.cleared:
		return
	room.cleared = true
	print("[Dungeon] - room %s cleared" % RoomData.Type.keys()[room.type])
	EventBus.slowmo_requested.emit(FeelConstants.ROOM_CLEAR_SLOWMO, FeelConstants.ROOM_CLEAR_SLOWMO_TIME)
	EventBus.play_sfx_requested.emit("room_clear")
	EventBus.room_cleared.emit()
	# Timer still running = horde room cleared in time: rewards an item
	if room.type == RoomData.Type.HORDE and _timer_active:
		EventBus.item_drop_requested.emit(LootManager.Source.HORDE_CLEAR, room.center())
	if room.type == RoomData.Type.BOSS:
		# End of the set of graveyards: guaranteed legendary in the arena
		EventBus.item_drop_requested.emit(LootManager.Source.BOSS_REWARD, room.center())
		EventBus.boss_defeated.emit()
	if _timer_active:
		_timer_active = false
		set_process(false)
		EventBus.horde_timer_changed.emit(-1.0)
	if _level.tutorial != null:
		_level.tutorial.on_room_cleared(room)
	_unlock()


func _lock() -> void:
	room.set_doors_closed.call_deferred(true)
	_animate_doors(true)
	EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_ROOM_LOCK)
	EventBus.play_sfx_requested.emit("room_lock")
	EventBus.room_locked.emit()


func _unlock() -> void:
	room.set_doors_closed.call_deferred(false)
	_animate_doors(false)


# Gates drop with a bounce when locking and hop when opening (Phase 2: fence/tombstone sprite)
func _animate_doors(closing: bool) -> void:
	for door: RoomData.Door in room.doors:
		if door.arch == null:
			continue
		var arch: Prop = door.arch
		arch.scale = Vector2(1.1, 0.55) if closing else Vector2(0.9, 1.15)
		var tween: Tween = arch.create_tween()
		tween.tween_property(arch, "scale", Vector2.ONE, 0.35 if closing else 0.2).set_trans(Tween.TRANS_BOUNCE if closing else Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
