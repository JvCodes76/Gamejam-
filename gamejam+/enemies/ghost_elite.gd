class_name GhostElite
extends EnemyBase
## Assombração (elite): flutua atravessando paredes e obstáculos em direção ao player.
## De tempos em tempos some (fica quase transparente e intangível: não fere nem pode ser atingida).
## A folha tem 16 quadros de 32x32: 4 olhando para a direita, 4 para baixo, 4 para cima e 4 para a esquerda.

enum Facing { RIGHT, DOWN, UP, LEFT }

const FRAMES_PER_FACING: int = 4

@export var anim_fps: float = 8.0
## Intervalo entre os sumiços (s), sorteado entre x e y
@export var fade_interval: Vector2 = Vector2(3.5, 5.0)
## Quanto tempo fica intangível (s)
@export var fade_time: float = 1.4
@export var faded_alpha: float = 0.2
@export var bob_height: float = 3.0
@export var bob_speed: float = 3.0

var _anim_time: float = 0.0
var _facing: Facing = Facing.DOWN
var _faded: bool = false
var _fade_left: float = 0.0
var _base_sprite_y: float = 0.0
var _hurtbox: Hurtbox


func _ready() -> void:
	super._ready()
	# Atravessa paredes e obstáculos baixos
	collision_mask = 0
	_hurtbox = get_hurtbox()
	_base_sprite_y = _sprite.position.y
	_fade_left = randf_range(fade_interval.x, fade_interval.y)


func _process(delta: float) -> void:
	_anim_time += delta
	_update_facing()
	var step: int = int(_anim_time * anim_fps) % FRAMES_PER_FACING
	_sprite.frame = int(_facing) * FRAMES_PER_FACING + step
	_sprite.position.y = _base_sprite_y + sin(_anim_time * bob_speed) * bob_height


func _physics_process(delta: float) -> void:
	_fade_left -= delta
	if _fade_left <= 0.0:
		if _faded:
			_set_faded(false)
		elif _status.can_act():
			_set_faded(true)
	super._physics_process(delta)


# Olha na direção em que está andando (horizontal tem prioridade quando empata)
func _update_facing() -> void:
	if velocity.length_squared() < 4.0:
		return
	if absf(velocity.x) >= absf(velocity.y):
		_facing = Facing.RIGHT if velocity.x > 0.0 else Facing.LEFT
	else:
		_facing = Facing.DOWN if velocity.y > 0.0 else Facing.UP


## Some (intangível) ou reaparece.
func _set_faded(faded: bool) -> void:
	_faded = faded
	_fade_left = fade_time if faded else randf_range(fade_interval.x, fade_interval.y)
	_hurtbox.set_deferred("monitorable", not faded)
	# Reaparecer respeita o atordoamento (que também suprime o dano de contato)
	_hitbox.suppressed = faded or _status.has(StatusEffects.STUN)
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "self_modulate:a", faded_alpha if faded else 1.0, 0.25)
	if not faded:
		_recheck_contact()
	EventBus.play_sfx_requested.emit("ghost_fade")


func _on_status_changed(status: StringName, active: bool) -> void:
	super._on_status_changed(status, active)
	# O fim do stun não pode reativar o dano enquanto ela está sumida
	if status == StatusEffects.STUN and _faded:
		_hitbox.suppressed = true
