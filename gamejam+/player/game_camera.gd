class_name GameCamera
extends Camera2D
## Câmera do player: suavização leve, look-ahead na direção da mira, recuo no tiro e tremida do Juice.

@export var look_ahead_fraction: float = FeelConstants.CAMERA_LOOK_AHEAD
@export var look_ahead_max: float = FeelConstants.CAMERA_LOOK_AHEAD_MAX

# Ponto que a câmera "olha" (crosshair); definido pelo player a cada quadro
var look_target: Vector2 = Vector2.INF
# Câmera parada (morte do player): ignora look-ahead
var frozen: bool = false

var _look_offset: Vector2 = Vector2.ZERO
var _recoil: Vector2 = Vector2.ZERO


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = FeelConstants.CAMERA_SMOOTHING_SPEED
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	var paused: bool = get_tree().paused
	if not paused:
		var desired: Vector2 = Vector2.ZERO
		if not frozen and look_target != Vector2.INF:
			desired = ((look_target - get_parent().global_position - position) * look_ahead_fraction).limit_length(look_ahead_max)
		_look_offset = _look_offset.lerp(desired, clampf(FeelConstants.CAMERA_LOOK_AHEAD_LERP * delta, 0.0, 1.0))
		_recoil = _recoil.move_toward(Vector2.ZERO, FeelConstants.CAMERA_RECOIL_DECAY * delta)
	offset = _look_offset + _recoil + Juice.shake_offset
	rotation = Juice.shake_rotation
	ignore_rotation = is_zero_approx(Juice.shake_rotation)


## Recuo de câmera: empurra 1 a 2 px para trás da direção do tiro.
func kick(direction: Vector2, strength: float = FeelConstants.CAMERA_RECOIL) -> void:
	_recoil = -direction.normalized() * strength
