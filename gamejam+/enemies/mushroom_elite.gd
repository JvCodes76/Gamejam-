class_name MushroomElite
extends EnemyBase
## Poisonous mushroom (elite): static and tanky. Keeps shooting volleys of spores toward the target and, when the
## target gets close, inflates its cap and releases a lingering cloud of spores around itself.
## 32x32 sheets: idle with 4 frames and attack with 6 (the last is the burst).

const SPORE_COLOR: Color = Color(0.55, 0.85, 0.25)
# Point (px from the feet) where the spores leave the cap and where the cloud is centered
const CAP_OFFSET: Vector2 = Vector2(0.0, -26.0)
const CLOUD_OFFSET: Vector2 = Vector2(0.0, -8.0)
# Point (px from the target's feet) the spores aim at
const TARGET_AIM_OFFSET: Vector2 = Vector2(0.0, -12.0)

@export var idle_texture: Texture2D
@export var attack_texture: Texture2D
@export var idle_fps: float = 6.0

@export_group("Spore shots")
## Interval between volleys (s)
@export var shot_interval: float = 1.6
## Spores per volley (fan aimed at the target)
@export var shot_count: int = 3
## Angle (degrees) between spores of the same volley
@export var shot_spread_degrees: float = 14.0
@export var shot_speed: float = 120.0
## Lifetime of each spore (s); range = speed * lifetime
@export var shot_lifetime: float = 2.5
@export var spore_damage: int = 15
## Maximum distance (px) to the target to shoot
@export var shot_range: float = 320.0

@export_group("Spore cloud")
## Distance (px) to the target that triggers the cloud
@export var cloud_trigger_radius: float = 90.0
@export var cloud_radius: float = 80.0
## Time the cloud stays around the mushroom (s)
@export var cloud_lifetime: float = 2.5
## Interval (s) between hits on whoever is inside the cloud
@export var cloud_tick: float = 0.5
@export var cloud_damage: int = 15
## Duration of the charge animation until the cloud comes out (s)
@export var attack_time: float = 0.7
## Time (s) between clouds, counted from the release
@export var cloud_cooldown: float = 3.5

var _anim_time: float = 0.0
var _attacking: bool = false
var _attack_elapsed: float = 0.0
var _shot_left: float = 0.0
var _cloud_left: float = 0.0


func _ready() -> void:
	super._ready()
	# Desynchronizes mushrooms spawned together
	_shot_left = shot_interval * randf_range(0.5, 1.0)
	_set_sheet(idle_texture, 4)


func _process(delta: float) -> void:
	if _attacking:
		return
	_anim_time += delta
	_sprite.frame = int(_anim_time * idle_fps) % _sprite.hframes


func _physics_process(delta: float) -> void:
	_shot_left = maxf(_shot_left - delta, 0.0)
	_cloud_left = maxf(_cloud_left - delta, 0.0)
	if _attacking:
		_tick_attack(delta)
	elif _status.can_act():
		var target: Node2D = _find_target()
		if target != null:
			var distance: float = global_position.distance_to(target.global_position)
			if distance <= cloud_trigger_radius and _cloud_left <= 0.0:
				_start_attack()
			elif distance <= shot_range and _shot_left <= 0.0:
				_shoot(target)
	super._physics_process(delta)


# Static: never walks (knockback is ignored by knockback_resistance in the scene)
func _chase_velocity(_target: Node2D) -> Vector2:
	return Vector2.ZERO


# Volley of spores in a fan aimed at the target
func _shoot(target: Node2D) -> void:
	_shot_left = shot_interval
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var origin: Vector2 = global_position + CAP_OFFSET
	var aim: Vector2 = origin.direction_to(target.global_position + TARGET_AIM_OFFSET)
	var amount: int = _scaled(spore_damage)
	var hits_enemies: bool = _status.has(StatusEffects.CHARMED)
	for i: int in shot_count:
		var angle: float = deg_to_rad(shot_spread_degrees) * (float(i) - float(shot_count - 1) * 0.5)
		SporeProjectile.spawn(scene, origin, aim.rotated(angle) * shot_speed, amount, shot_lifetime, SPORE_COLOR, hits_enemies, self)
	ImpactEffect.spawn_burst(scene, origin, 10.0, SPORE_COLOR, 8, 0.3, 1.0, 0.6)


func _start_attack() -> void:
	_attacking = true
	_attack_elapsed = 0.0
	_set_sheet(attack_texture, 6)
	EventBus.play_sfx_requested.emit("mushroom_charge")


# Advances the charge animation; stun cancels it without releasing the cloud
func _tick_attack(delta: float) -> void:
	if not _status.can_act():
		_end_attack()
		return
	_attack_elapsed += delta
	var last: int = _sprite.hframes - 1
	_sprite.frame = mini(int(_attack_elapsed / attack_time * last), last)
	if _attack_elapsed >= attack_time:
		_release_cloud()
		_end_attack()


func _end_attack() -> void:
	_attacking = false
	_set_sheet(idle_texture, 4)


# Lingering cloud around the mushroom (hurts the player, or the enemies if charmed)
func _release_cloud() -> void:
	_cloud_left = cloud_cooldown
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var center: Vector2 = global_position + CLOUD_OFFSET
	SporeCloud.spawn(scene, center, cloud_radius, cloud_lifetime, cloud_tick, _scaled(cloud_damage), SPORE_COLOR, _status.has(StatusEffects.CHARMED), self)
	ImpactEffect.spawn_burst(scene, center, cloud_radius, SPORE_COLOR, 18, 0.6, 2.0, 0.8)
	EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_SPAWN)
	EventBus.play_sfx_requested.emit("mushroom_spores")


# Damage with the status multiplier (weakened deals less)
func _scaled(base: int) -> int:
	return maxi(1, roundi(base * _status.damage_dealt_multiplier()))


func _set_sheet(texture: Texture2D, frames: int) -> void:
	if texture == null:
		return
	_sprite.texture = texture
	_sprite.hframes = frames
	_sprite.frame = 0
