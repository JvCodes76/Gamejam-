class_name MushroomElite
extends EnemyBase
## Cogumelo venenoso (elite): anda devagar e, quando o alvo chega perto, para, infla o chapéu e solta uma nuvem de esporos
## que fere tudo no raio. Folhas de 32x32: idle com 4 quadros e ataque com 6 (o último é o estouro).

const SPORE_COLOR: Color = Color(0.55, 0.85, 0.25)

@export var idle_texture: Texture2D
@export var attack_texture: Texture2D
@export var idle_fps: float = 6.0
## Distância do alvo (px) que dispara o ataque
@export var trigger_radius: float = 70.0
## Raio da nuvem de esporos (px)
@export var spore_radius: float = 80.0
@export var spore_damage: int = 2
## Duração da animação de ataque até o estouro (s)
@export var attack_time: float = 0.7
@export var attack_cooldown: float = 2.0

var _anim_time: float = 0.0
var _attacking: bool = false
var _attack_elapsed: float = 0.0
var _cooldown_left: float = 0.0


func _ready() -> void:
	super._ready()
	_cooldown_left = attack_cooldown * 0.5
	_set_sheet(idle_texture, 4)


func _process(delta: float) -> void:
	if _attacking:
		return
	_anim_time += delta
	_sprite.frame = int(_anim_time * idle_fps) % _sprite.hframes


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _attacking:
		_tick_attack(delta)
	elif _cooldown_left <= 0.0 and _status.can_act():
		var target: Node2D = _find_target()
		if target != null and global_position.distance_to(target.global_position) <= trigger_radius:
			_start_attack()
	super._physics_process(delta)


func _chase_velocity(target: Node2D) -> Vector2:
	if _attacking:
		return Vector2.ZERO
	return super._chase_velocity(target)


func _start_attack() -> void:
	_attacking = true
	_attack_elapsed = 0.0
	_set_sheet(attack_texture, 6)
	EventBus.play_sfx_requested.emit("mushroom_charge")


# Avança a animação de ataque; atordoado cancela sem soltar os esporos
func _tick_attack(delta: float) -> void:
	if not _status.can_act():
		_end_attack()
		return
	_attack_elapsed += delta
	var last: int = _sprite.hframes - 1
	_sprite.frame = mini(int(_attack_elapsed / attack_time * last), last)
	if _attack_elapsed >= attack_time:
		_release_spores()
		_end_attack()


func _end_attack() -> void:
	_attacking = false
	_cooldown_left = attack_cooldown
	_set_sheet(idle_texture, 4)


# Fere o player (ou os inimigos, se enfeitiçado) dentro do raio
func _release_spores() -> void:
	var center: Vector2 = global_position + Vector2(0.0, -12.0)
	var scene: Node = get_tree().current_scene
	if scene != null:
		var fx: ImpactEffect = ImpactEffect.spawn_burst(scene, center, spore_radius, SPORE_COLOR, 18, 0.6, 2.0, 0.8)
		fx.global_position = center
	var amount: int = maxi(1, roundi(spore_damage * _status.damage_dealt_multiplier()))
	if _status.has(StatusEffects.CHARMED):
		for node: Node in get_tree().get_nodes_in_group("enemy"):
			var other: EnemyBase = node as EnemyBase
			if other != null and other != self and other.is_alive() and other.global_position.distance_to(center) <= spore_radius:
				other.get_hurtbox().receive_hit(amount, center.direction_to(other.global_position))
	else:
		var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.global_position.distance_to(center) <= spore_radius:
			var hurtbox: Hurtbox = player.get_node_or_null("Hurtbox") as Hurtbox
			if hurtbox != null:
				hurtbox.receive_hit(amount, center.direction_to(player.global_position))
	EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_SPAWN)
	EventBus.play_sfx_requested.emit("mushroom_spores")


func _set_sheet(texture: Texture2D, frames: int) -> void:
	if texture == null:
		return
	_sprite.texture = texture
	_sprite.hframes = frames
	_sprite.frame = 0
