class_name WaveManager
extends Node
## Monster Survivors waves: each wave spawns a quota of enemies (plus elites as the game gets harder) and ends when
## everything is dead. A boss wave comes every "boss_every" waves; there is a rest every "rest_every" waves and before
## every boss, and the next wave only starts when the player presses the HUD button.

const SWARM: Array[Dictionary] = [
	{"scene": preload("res://enemies/skull.tscn"), "from_wave": 1},
	{"scene": preload("res://enemies/bat.tscn"), "from_wave": 3},
	{"scene": preload("res://enemies/fire_skull.tscn"), "from_wave": 6},
	{"scene": preload("res://enemies/mushroom.tscn"), "from_wave": 10},
]
const ELITES: Array[PackedScene] = [
	preload("res://enemies/fire_skull_elite.tscn"),
	preload("res://enemies/ghost_elite.tscn"),
	preload("res://enemies/mushroom_elite.tscn"),
]
const BOSS: PackedScene = preload("res://enemies/boss_fallen_angel.tscn")

enum Phase { BREAK, REST, WAVE }

@export_group("Timing")
## Wait (s) before the first wave
@export var first_wave_delay: float = 3.0
## Rest after every "rest_every" waves and before a boss: no timer, the player starts the next wave with a button
@export var rest_every: int = 3
## Short pause (s) between waves with no rest, so the "WAVE N" announcement can be read
@export var wave_gap: float = 1.5
## A boss comes every N waves
@export var boss_every: int = 15

@export_group("Enemies")
## Quota of enemies of a wave: base + per wave (capped); a boss wave brings half
@export var base_quota: int = 6
@export var quota_per_wave: int = 2
@export var quota_cap: int = 70
## Enemies alive at the same time: base + per wave (capped)
@export var base_alive: int = 10
@export var alive_per_wave: int = 2
@export var alive_cap: int = 45
## Interval (s) between spawns: starts at the first value and shrinks per wave down to the minimum
@export var spawn_interval_start: float = 0.9
@export var spawn_interval_min: float = 0.3
@export var spawn_interval_step: float = 0.03
## Health, contact damage and speed growth per wave (0.07 = +7%)
@export var health_growth: float = 0.07
@export var damage_growth: float = 0.04
@export var speed_growth: float = 0.01
@export var speed_cap: float = 1.5

@export_group("Elites")
## First wave with elites; one more elite every "elite_step" waves
@export var elite_first_wave: int = 3
@export var elite_step: int = 4
@export var elite_cap: int = 6
## Time (s) between the elites of the same wave
@export var elite_interval: float = 4.0
@export var elite_health_multiplier: float = 6.0
@export var elite_scale: float = 1.5
@export var elite_tint: Color = Color(0.6, 0.7, 1.0)

@export_group("Boss")
@export var boss_health_multiplier: float = 80.0
## Extra boss health per boss already defeated (0.5 = +50%)
@export var boss_health_growth: float = 0.5
@export var boss_points: int = 500
## XP granted when the boss dies
@export var boss_xp: int = 30

@export_group("Spawn")
@export var spawn_radius: float = 260.0
@export var spawn_bounds: Rect2 = Rect2(-620.0, -312.0, 1240.0, 652.0)
@export var spawn_attempts: int = 8
@export var min_spawn_distance: float = 140.0

## Node that receives the enemies (set by the level before entering the tree)
var level: Node2D = null
var wave: int = 0

var _phase: Phase = Phase.BREAK
var _break_left: float = 0.0
var _quota_left: int = 0
var _elites_left: int = 0
var _boss_pending: bool = false
var _alive: int = 0
var _spawn_timer: float = 0.0
var _elite_timer: float = 0.0


func _ready() -> void:
	if level == null:
		level = get_parent() as Node2D
	EventBus.next_wave_requested.connect(_on_next_wave_requested)
	_begin_break(first_wave_delay)


func _process(delta: float) -> void:
	match _phase:
		Phase.BREAK:
			_tick_break(delta)
		Phase.WAVE:
			_tick_wave(delta)
		# Phase.REST: waits for the player (next_wave_requested)


## Quota of basic enemies of the wave.
func quota_for(wave_number: int) -> int:
	var quota: int = mini(base_quota + quota_per_wave * (wave_number - 1), quota_cap)
	return maxi(floori(quota / 2.0), 1) if is_boss_wave(wave_number) else quota


## Elites of the wave (none in boss waves, where the boss is the show).
func elites_for(wave_number: int) -> int:
	if wave_number < elite_first_wave or is_boss_wave(wave_number):
		return 0
	return mini(1 + floori(float(wave_number - elite_first_wave) / float(elite_step)), elite_cap)


func is_boss_wave(wave_number: int) -> bool:
	return wave_number > 0 and wave_number % boss_every == 0


# Short automatic wait before the next wave (first wave and between waves with no rest)
func _begin_break(seconds: float) -> void:
	_phase = Phase.BREAK
	_break_left = seconds


func _tick_break(delta: float) -> void:
	_break_left -= delta
	if _break_left <= 0.0:
		_start_wave()


# Rest with no timer: the next wave only comes when the player asks for it
func _begin_rest(boss_next: bool) -> void:
	_phase = Phase.REST
	print("[Wave] - rest before wave %d (boss: %s), waiting for the player" % [wave + 1, str(boss_next)])
	EventBus.wave_rest_changed.emit(true, boss_next)


func _on_next_wave_requested() -> void:
	if _phase != Phase.REST:
		return
	EventBus.wave_rest_changed.emit(false, false)
	_start_wave()


func _start_wave() -> void:
	wave += 1
	_phase = Phase.WAVE
	var boss_wave: bool = is_boss_wave(wave)
	_quota_left = quota_for(wave)
	_elites_left = elites_for(wave)
	_boss_pending = boss_wave
	_spawn_timer = 0.0
	_elite_timer = elite_interval * 0.5
	print("[Wave] - wave %d (%d enemies, %d elites, boss: %s)" % [wave, _quota_left, _elites_left, str(boss_wave)])
	EventBus.wave_started.emit(wave, boss_wave)
	if boss_wave:
		_spawn_boss()
		_boss_pending = false


func _tick_wave(delta: float) -> void:
	_spawn_timer -= delta
	if _quota_left > 0 and _spawn_timer <= 0.0 and get_tree().get_nodes_in_group("enemy").size() < _max_alive():
		_spawn_timer = maxf(spawn_interval_start - spawn_interval_step * (wave - 1), spawn_interval_min)
		_quota_left -= 1
		_spawn(_pick_swarm_scene(), false)
	_elite_timer -= delta
	if _elites_left > 0 and _elite_timer <= 0.0:
		_elite_timer = elite_interval
		_elites_left -= 1
		_spawn(ELITES.pick_random(), true)
	_check_wave_end()


func _max_alive() -> int:
	return mini(base_alive + alive_per_wave * (wave - 1), alive_cap)


# Basic enemy among the types already unlocked
func _pick_swarm_scene() -> PackedScene:
	var pool: Array[PackedScene] = []
	for entry: Dictionary in SWARM:
		if wave >= int(entry["from_wave"]):
			pool.append(entry["scene"] as PackedScene)
	return pool.pick_random()


# Wave over: everything was spawned and has died
func _check_wave_end() -> void:
	if _phase != Phase.WAVE or _quota_left > 0 or _elites_left > 0 or _boss_pending or _alive > 0:
		return
	print("[Wave] - wave %d cleared" % wave)
	EventBus.wave_cleared.emit(wave)
	EventBus.play_sfx_requested.emit("room_clear")
	var next_is_boss: bool = is_boss_wave(wave + 1)
	if next_is_boss or wave % rest_every == 0:
		_begin_rest(next_is_boss)
	else:
		_begin_break(wave_gap)


# Creates an enemy with a spawn warning; elites always get it, basic ones only when they are far from the player
func _spawn(scene: PackedScene, elite: bool) -> void:
	var point: Vector2 = _random_point(-1.0, SpawnCheck.clearance_of(scene))
	if elite:
		var marker: SpawnMarker = SpawnMarker.new()
		marker.duration = FeelConstants.SPAWN_WARNING_TIME + 0.3
		marker.finished.connect(_create_enemy.bind(scene, elite))
		level.add_child(marker)
		marker.global_position = point
		_alive += 1
	else:
		_alive += 1
		_create_enemy(point, scene, elite)


func _spawn_boss() -> void:
	var marker: SpawnMarker = SpawnMarker.new()
	marker.duration = FeelConstants.SPAWN_WARNING_TIME + 1.0
	marker.finished.connect(_create_boss)
	level.add_child(marker)
	marker.global_position = _random_point(spawn_radius * 0.8)
	_alive += 1
	EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_SPAWN)


func _create_enemy(point: Vector2, scene: PackedScene, elite: bool) -> void:
	var enemy: EnemyBase = scene.instantiate() as EnemyBase
	var health: HealthComponent = enemy.get_node("HealthComponent") as HealthComponent
	var sprite: Sprite2D = enemy.get_node("Sprite2D") as Sprite2D
	var hitbox: Hitbox = enemy.get_node_or_null("Hitbox") as Hitbox
	var health_mult: float = 1.0 + health_growth * (wave - 1)
	if elite:
		health_mult *= elite_health_multiplier
		if not enemy.has_elite_art:
			sprite.scale *= elite_scale
			sprite.modulate = elite_tint
		enemy.is_basic = false
		enemy.knockback_resistance = maxf(enemy.knockback_resistance, FeelConstants.ELITE_KNOCKBACK_RESISTANCE)
		enemy.add_to_group("elite")
	health.max_health = maxi(1, roundi(health.max_health * health_mult))
	if hitbox != null:
		hitbox.damage = maxi(1, roundi(hitbox.damage * (1.0 + damage_growth * (wave - 1))))
	enemy.move_speed *= minf(1.0 + speed_growth * (wave - 1), speed_cap)
	_add_enemy(enemy, point)


func _create_boss(point: Vector2) -> void:
	var boss: EnemyBase = BOSS.instantiate() as EnemyBase
	var health: HealthComponent = boss.get_node("HealthComponent") as HealthComponent
	var boss_index: int = floori(float(wave) / float(boss_every)) - 1
	health.max_health = roundi(health.max_health * boss_health_multiplier * (1.0 + boss_health_growth * boss_index))
	boss.points = boss_points
	boss.is_basic = false
	boss.knockback_resistance = 1.0
	boss.add_to_group("boss")
	health.died.connect(_on_boss_died.bind(boss))
	_add_enemy(boss, point)


func _add_enemy(enemy: EnemyBase, point: Vector2) -> void:
	level.add_child(enemy)
	enemy.global_position = point
	enemy.tree_exited.connect(_on_enemy_gone)
	enemy.play_spawn_pop()


func _on_enemy_gone() -> void:
	# Ignored when the scene is being torn down
	if not is_inside_tree():
		return
	_alive = maxi(_alive - 1, 0)
	_check_wave_end()


# Boss reward: guaranteed legendary, XP and back to the normal music
func _on_boss_died(boss: Node2D) -> void:
	print("[Wave] - boss defeated on wave %d" % wave)
	EventBus.item_drop_requested.emit(LootManager.Source.BOSS_REWARD, boss.global_position)
	EventBus.xp_collected.emit(boss_xp)
	EventBus.boss_defeated.emit()


# Free point around the player, inside the arena and away from walls and props
# Free point around the player with "clearance" px free of collisions; falls back to the default clearance.
func _random_point(radius: float = -1.0, clearance: float = SpawnCheck.ENEMY_CLEARANCE) -> Vector2:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var origin: Vector2 = player.global_position if player != null else Vector2.ZERO
	var point: Vector2 = origin
	var fallback: Vector2 = Vector2.INF
	for attempt: int in SpawnCheck.attempts_for(spawn_attempts, clearance):
		var distance: float = radius if radius > 0.0 else spawn_radius * randf_range(0.8, 1.2)
		point = (origin + Vector2.from_angle(randf() * TAU) * distance).clamp(spawn_bounds.position, spawn_bounds.end)
		if point.distance_to(origin) < min_spawn_distance:
			continue
		if SpawnCheck.is_free(level, point, clearance):
			return point
		if fallback == Vector2.INF and SpawnCheck.is_free(level, point, SpawnCheck.ENEMY_CLEARANCE):
			fallback = point
	return fallback if fallback != Vector2.INF else point
