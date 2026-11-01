class_name Boss
extends EnemyBase
## Boss that adapts to potions: on crossing each health threshold (75%, 50%, 25%) it closes its wings and becomes immune
## to the items of the potion that dealt the last hit (immunities accumulate). The effects of those items stop
## working against it: hits go through ProjectileModifiers.for_target(), which asks for adapt_modifiers().
## Each damage taken has a small chance of dropping an item.
## Besides chasing, it alternates two attacks aimed at the player: an explosion around itself (wings close while a
## red circle fills up on the ground) and a laser (the eye charges, an aiming line locks and a beam sweeps).

enum AnimState { IDLE, CLOSING, HOLD, OPENING, ATTACK }
enum Attack { NONE, EXPLOSION, LASER_CHARGE, LASER_FIRE, RECOVER }

# Point (px from the feet) where the laser leaves the eye and where the player's body is aimed at
const EYE_OFFSET: Vector2 = Vector2(0.0, -62.0)
const TARGET_BODY_OFFSET: Vector2 = Vector2(0.0, -25.0)
# Contact damage of the scene; loop scaling multiplies the hitbox damage, and the attacks follow it
const BASE_CONTACT_DAMAGE: float = 15.0
# Death cinematic: angle (degrees) of each white rectangle and the pause (s) before each one / after the last
const DEATH_RECT_ANGLES: Array[float] = [-25.0, 40.0]
const DEATH_RECT_INTERVAL: float = 1.0

## Name shown on the health bar
@export var display_name: String = "Fallen Angel"
## Fractions of max health that trigger the adaptation (in descending order)
@export var adapt_thresholds: Array[float] = [0.75, 0.5, 0.25]
## Chance (0-1) of dropping an item on each damage taken
@export_range(0.0, 1.0) var drop_chance_per_damage: float = 0.01

@export_group("Animation")
@export var idle_texture: Texture2D
@export var idle_frames: int = 8
@export var idle_fps: float = 8.0
## Wings-closing sheet (played backwards to open)
@export var wings_texture: Texture2D
@export var wings_frames: int = 4
@export var wings_fps: float = 10.0
## Time (s) with the wings closed during adaptation
@export var adapt_hold_time: float = 0.9
## Flash color when adapting
@export var adapt_flash_color: Color = Color(0.75, 0.4, 1.0)

@export_group("Attacks")
## Delay (s) before the first attack after spawning
@export var first_attack_delay: float = 2.5
## Time (s) between the end of an attack and the next one
@export var attack_cooldown: float = 3.0
## When the player is closer than this (px), the explosion is also an option
@export var explosion_trigger_range: float = 130.0
## Chance (0-1) of choosing the explosion when the player is in range (otherwise the laser)
@export_range(0.0, 1.0) var explosion_chance: float = 0.6
## Time (s) of the explosion telegraph (wings closing and circle filling)
@export var explosion_windup: float = 1.1
@export var explosion_radius: float = 120.0
@export var explosion_damage: int = 30
## Time (s) with the wings open again before the boss moves
@export var recover_time: float = 0.5
@export var explosion_color: Color = Color(1.0, 0.3, 0.25)
## Laser sheet (the eye charges and the halo turns red)
@export var laser_texture: Texture2D
@export var laser_frames: int = 6
## Time (s) of the laser charge
@export var laser_charge_time: float = 1.3
## Fraction of the charge during which the aim still follows the player (then it locks)
@export_range(0.0, 1.0) var laser_track_fraction: float = 0.65
## Maximum turn speed (degrees/s) of the aim while tracking
@export var laser_track_speed_degrees: float = 150.0
@export var laser_fire_time: float = 0.8
## Angle (degrees) the beam sweeps while firing, in a random direction
@export var laser_sweep_degrees: float = 45.0
@export var laser_length: float = 520.0
@export var laser_width: float = 14.0
@export var laser_damage: int = 20
## Interval (s) between hits on the player while inside the beam
@export var laser_tick: float = 0.2

# Items the boss is immune to: id -> ItemData (equal ids = same item)
var _immune: Dictionary = {}
# Items of the potion from the last direct or splash hit
var _last_hit_items: Array[ItemData] = []
# Next adapt_thresholds threshold not yet crossed
var _next_threshold: int = 0
# Modifiers filtered per potion: original instance id -> ProjectileModifiers (cleared on every adaptation)
var _filtered_cache: Dictionary = {}
var _anim_state: AnimState = AnimState.IDLE
var _anim_time: float = 0.0
var _attack: Attack = Attack.NONE
var _attack_time: float = 0.0
var _attack_cooldown_left: float = 0.0
var _aim_angle: float = 0.0
var _sweep_sign: float = 1.0
var _laser_tick_left: float = 0.0
var _recover_wings: bool = false
var _fx: BossAttackFx = null


func _ready() -> void:
	super()
	_set_sheet(idle_texture, idle_frames)
	_health.health_changed.connect(_on_health_changed)
	_health.damaged.connect(_on_damaged)
	_attack_cooldown_left = first_attack_delay
	_fx = BossAttackFx.new()
	_fx.name = "AttackFx"
	add_child(_fx)
	EventBus.boss_spawned.emit(self)
	print("[Boss] - %s spawned (%d health)" % [display_name, _health.max_health])


func _process(delta: float) -> void:
	_tick_animation(delta)


func _physics_process(delta: float) -> void:
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	if _attack != Attack.NONE:
		_tick_attack(delta)
	elif _anim_state == AnimState.IDLE and _attack_cooldown_left <= 0.0 and _status.can_act() and not _status.has(StatusEffects.CHARMED):
		_start_next_attack()
	super._physics_process(delta)


## Stationary while adapting (wings closed).
func _chase_velocity(target: Node2D) -> Vector2:
	if _anim_state != AnimState.IDLE:
		return Vector2.ZERO
	return super(target)


## Records the hit's potion and returns the modifiers without the items the boss is immune to.
func adapt_modifiers(mods: ProjectileModifiers) -> ProjectileModifiers:
	_last_hit_items = mods.source_items
	if not _has_immune_item(mods.source_items):
		return mods
	var key: int = mods.get_instance_id()
	var filtered: ProjectileModifiers = _filtered_cache.get(key) as ProjectileModifiers
	if filtered == null:
		filtered = mods.without_items(_immune)
		_filtered_cache[key] = filtered
	# Rage (Evil synergy) changes during the fight and comes from the player, not the items
	filtered.rage_multiplier = mods.rage_multiplier
	return filtered


## Items the boss is immune to, in the order it adapted.
func immune_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	for item: ItemData in _immune.values():
		items.append(item)
	return items


func _has_immune_item(items: Array[ItemData]) -> bool:
	if _immune.is_empty():
		return false
	for item: ItemData in items:
		if _immune.has(item.id):
			return true
	return false


# Crosses the health thresholds; a hit that crosses several adapts only once.
func _on_health_changed(current: int, max_value: int) -> void:
	if _health.is_dead():
		return
	var crossed: bool = false
	while _next_threshold < adapt_thresholds.size() and current <= max_value * adapt_thresholds[_next_threshold]:
		_next_threshold += 1
		crossed = true
	if crossed:
		_adapt()


# Becomes immune to the items of the last potion that hit it and announces the adaptation.
func _adapt() -> void:
	var new_items: Array[ItemData] = []
	for item: ItemData in _last_hit_items:
		if item != null and not _immune.has(item.id):
			_immune[item.id] = item
			new_items.append(item)
	if new_items.is_empty():
		print("[Boss] - threshold crossed, but the last potion brought no new items to adapt to")
		return
	_filtered_cache.clear()
	var names: PackedStringArray = []
	for item: ItemData in new_items:
		names.append(String(item.id))
	print("[Boss] - adapted: immune to %s" % ", ".join(names))
	_play_adapt_feedback()
	EventBus.boss_adapted.emit(new_items, immune_items())


func _play_adapt_feedback() -> void:
	_cancel_attack()
	_anim_state = AnimState.CLOSING
	_anim_time = 0.0
	_set_sheet(wings_texture, wings_frames)
	var feedback: HitFeedback = get_node_or_null("HitFeedback") as HitFeedback
	if feedback != null:
		feedback.flash(adapt_flash_color, 0.4)
	EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_ELITE_DEATH)
	EventBus.play_sfx_requested.emit("room_lock")


# 1% (default) chance of dropping an item on each damage taken.
func _on_damaged(_amount: int) -> void:
	if randf() < drop_chance_per_damage:
		print("[Boss] - damage dropped an item")
		EventBus.item_drop_requested.emit(LootManager.Source.BOSS_HIT, global_position)


# Idle in a loop; adaptation: closes the wings, holds and opens again.
func _tick_animation(delta: float) -> void:
	_anim_time += delta
	match _anim_state:
		AnimState.IDLE:
			_sprite.frame = int(_anim_time * idle_fps) % maxi(idle_frames, 1)
		AnimState.CLOSING:
			var frame: int = int(_anim_time * wings_fps)
			if frame >= wings_frames:
				_anim_state = AnimState.HOLD
				_anim_time = 0.0
				frame = wings_frames - 1
			_sprite.frame = frame
		AnimState.HOLD:
			if _anim_time >= adapt_hold_time:
				_anim_state = AnimState.OPENING
				_anim_time = 0.0
		AnimState.ATTACK:
			pass
		AnimState.OPENING:
			var frame: int = wings_frames - 1 - int(_anim_time * wings_fps)
			if frame < 0:
				_anim_state = AnimState.IDLE
				_anim_time = 0.0
				_set_sheet(idle_texture, idle_frames)
			else:
				_sprite.frame = frame


# --- Attacks ---

# Explosion when the player is close (sometimes), otherwise the laser
func _start_next_attack() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var close: bool = global_position.distance_to(player.global_position) <= explosion_trigger_range
	if close and randf() < explosion_chance:
		_start_explosion()
	else:
		_start_laser(player)


func _start_explosion() -> void:
	_attack = Attack.EXPLOSION
	_attack_time = 0.0
	_anim_state = AnimState.ATTACK
	_set_sheet(wings_texture, wings_frames)
	_fx.show_circle(explosion_radius, 0.0)
	EventBus.play_sfx_requested.emit("room_lock")
	print("[Boss] - explosion attack")


func _start_laser(player: Node2D) -> void:
	_attack = Attack.LASER_CHARGE
	_attack_time = 0.0
	_anim_state = AnimState.ATTACK
	_set_sheet(laser_texture, laser_frames)
	_aim_angle = (player.global_position + TARGET_BODY_OFFSET - _eye_position()).angle()
	_sweep_sign = -1.0 if randf() < 0.5 else 1.0
	EventBus.play_sfx_requested.emit("room_lock")
	print("[Boss] - laser attack")


func _tick_attack(delta: float) -> void:
	if not _status.can_act():
		_cancel_attack()
		return
	_attack_time += delta
	match _attack:
		Attack.EXPLOSION:
			_tick_explosion()
		Attack.LASER_CHARGE:
			_tick_laser_charge(delta)
		Attack.LASER_FIRE:
			_tick_laser_fire(delta)
		Attack.RECOVER:
			_tick_recover()


func _tick_explosion() -> void:
	var progress: float = clampf(_attack_time / explosion_windup, 0.0, 1.0)
	_sprite.frame = mini(int(progress * wings_frames), wings_frames - 1)
	_fx.show_circle(explosion_radius, progress)
	if progress >= 1.0:
		_explode()
		_start_recover(true)


# Blast around the boss: hurts the player if the feet are inside the circle
func _explode() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null:
		ImpactEffect.spawn_burst(scene, global_position + Vector2(0.0, -20.0), explosion_radius, explosion_color, 36, 0.7, 4.0, 1.4)
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.global_position.distance_to(global_position) <= explosion_radius:
		_hurt_player(player, _scaled(explosion_damage), global_position.direction_to(player.global_position))
	EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_ELITE_DEATH)
	EventBus.hitstop_requested.emit(FeelConstants.HITSTOP_ELITE_DEATH_MS / 1000.0)
	EventBus.play_sfx_requested.emit("elite_die")
	print("[Boss] - explosion (radius %.0f)" % explosion_radius)


# The aim follows the player with limited turn speed, then locks for the last part of the charge
func _tick_laser_charge(delta: float) -> void:
	var progress: float = clampf(_attack_time / laser_charge_time, 0.0, 1.0)
	_sprite.frame = mini(int(progress * laser_frames), laser_frames - 1)
	if progress < laser_track_fraction:
		var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			var wanted: float = (player.global_position + TARGET_BODY_OFFSET - _eye_position()).angle()
			var max_step: float = deg_to_rad(laser_track_speed_degrees) * delta
			_aim_angle += clampf(angle_difference(_aim_angle, wanted), -max_step, max_step)
	var from: Vector2 = _eye_position() - global_position
	_fx.show_aim(from, from + Vector2.from_angle(_aim_angle) * _beam_length(), progress)
	if progress >= 1.0:
		_attack = Attack.LASER_FIRE
		_attack_time = 0.0
		_laser_tick_left = 0.0
		EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_ELITE_DEATH)
		EventBus.play_sfx_requested.emit("synergy")


func _tick_laser_fire(delta: float) -> void:
	var progress: float = clampf(_attack_time / laser_fire_time, 0.0, 1.0)
	_aim_angle += deg_to_rad(laser_sweep_degrees) * _sweep_sign * delta / laser_fire_time
	var eye: Vector2 = _eye_position()
	var tip: Vector2 = eye + Vector2.from_angle(_aim_angle) * _beam_length()
	_fx.show_beam(eye - global_position, tip - global_position, laser_width, progress)
	_laser_tick_left -= delta
	if _laser_tick_left <= 0.0:
		_laser_tick_left = laser_tick
		_hurt_in_beam(eye, tip)
	EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_SPAWN)
	if progress >= 1.0:
		_start_recover(false)


# Beam length, shortened where it hits a tall wall
func _beam_length() -> float:
	var eye: Vector2 = _eye_position()
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(eye, eye + Vector2.from_angle(_aim_angle) * laser_length, PhysicsLayers.WORLD)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return laser_length
	return eye.distance_to(hit["position"] as Vector2)


# Hurts the player if the body is within half the beam width (plus a margin) of the segment
func _hurt_in_beam(eye: Vector2, tip: Vector2) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var body: Vector2 = player.global_position + TARGET_BODY_OFFSET
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(body, eye, tip)
	if body.distance_to(closest) <= laser_width * 0.5 + 8.0:
		_hurt_player(player, _scaled(laser_damage), (tip - eye).normalized())
		print("[Boss] - laser hit the player")


func _hurt_player(player: Node2D, amount: int, direction: Vector2) -> void:
	var hurtbox: Hurtbox = player.get_node_or_null("Hurtbox") as Hurtbox
	if hurtbox != null:
		hurtbox.receive_hit(amount, direction)


# Brief pause after the attack: the wings open again (explosion) or the halo goes back to normal (laser)
func _start_recover(wings: bool) -> void:
	_attack = Attack.RECOVER
	_attack_time = 0.0
	_recover_wings = wings
	_fx.clear()


func _tick_recover() -> void:
	if _recover_wings:
		var frame: int = wings_frames - 1 - int(_attack_time / recover_time * wings_frames)
		_sprite.frame = maxi(frame, 0)
	else:
		_sprite.frame = 0
	if _attack_time >= recover_time:
		_end_attack()


# Back to idle and starts the cooldown to the next attack
func _end_attack() -> void:
	_attack = Attack.NONE
	_anim_state = AnimState.IDLE
	_anim_time = 0.0
	_attack_cooldown_left = attack_cooldown
	_fx.clear()
	_set_sheet(idle_texture, idle_frames)


# Stun or adaptation interrupts the attack (the adaptation sets its own animation state afterwards)
func _cancel_attack() -> void:
	if _attack == Attack.NONE:
		return
	_attack = Attack.NONE
	_attack_cooldown_left = attack_cooldown
	_fx.clear()
	if _anim_state == AnimState.ATTACK:
		_anim_state = AnimState.IDLE
		_anim_time = 0.0
		_set_sheet(idle_texture, idle_frames)


# Death cinematic: boss frozen on the first idle frame, white, crossed by two thin white rectangles that
# span the screen at different angles; the player is frozen meanwhile. Then the normal death runs (super).
func _on_died() -> void:
	print("[Boss] - death animation started")
	_cancel_attack()
	_fx.clear()
	set_process(false)
	set_physics_process(false)
	velocity = Vector2.ZERO
	_hitbox.set_deferred("monitoring", false)
	_hitbox.set_deferred("monitorable", false)
	$Hurtbox.set_deferred("monitorable", false)

	var feedback: Node = get_node_or_null("HitFeedback")
	if feedback != null:
		feedback.queue_free()
	_set_sheet(idle_texture, idle_frames)
	_sprite.frame = 0
	var mat: ShaderMaterial = HitFeedback.make_flash_material(Color.WHITE)
	mat.set_shader_parameter("flash", 1.0)
	_sprite.material = mat

	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var player_hurtbox: Area2D = null
	if player != null:
		player.velocity = Vector2.ZERO
		player.set_physics_process(false)
		player_hurtbox = player.get_node_or_null("Hurtbox") as Area2D
		if player_hurtbox != null:
			player_hurtbox.set_deferred("monitorable", false)

	for degrees: float in DEATH_RECT_ANGLES:
		await get_tree().create_timer(DEATH_RECT_INTERVAL).timeout
		if not is_inside_tree():
			return
		_spawn_death_rect(degrees)
	await get_tree().create_timer(DEATH_RECT_INTERVAL).timeout

	if is_instance_valid(player):
		player.set_physics_process(true)
		if player_hurtbox != null:
			player_hurtbox.set_deferred("monitorable", true)
	if not is_inside_tree():
		return
	super()


# Thin white bar centered on the sprite that pops in lengthwise (long enough to cross the whole screen)
func _spawn_death_rect(degrees: float) -> void:
	var half_length: float = 2500.0
	var half_width: float = 5.0
	var rect: Polygon2D = Polygon2D.new()
	rect.polygon = PackedVector2Array([
		Vector2(-half_width, -half_length), Vector2(half_width, -half_length),
		Vector2(half_width, half_length), Vector2(-half_width, half_length),
	])
	rect.color = Color.WHITE
	rect.position = _sprite.position
	rect.rotation_degrees = degrees
	rect.z_index = 10
	rect.scale = Vector2(1.0, 0.05)
	add_child(rect)
	var tween: Tween = create_tween()
	tween.tween_property(rect, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_ELITE_DEATH)
	EventBus.play_sfx_requested.emit("elite_die")


func _eye_position() -> Vector2:
	return global_position + EYE_OFFSET


# Damage with the status multiplier (weakened deals less) and the loop scaling of the contact damage
func _scaled(base: int) -> int:
	return maxi(1, roundi(base * _status.damage_dealt_multiplier() * float(_hitbox.damage) / BASE_CONTACT_DAMAGE))


func _set_sheet(texture: Texture2D, frames: int) -> void:
	if texture == null:
		return
	_sprite.texture = texture
	_sprite.hframes = maxi(frames, 1)
	_sprite.frame = 0
