class_name GameCamera
extends Camera2D
## Player camera: light smoothing, look-ahead in the aim direction, recoil on shots and Juice shake.

@export var look_ahead_fraction: float = FeelConstants.CAMERA_LOOK_AHEAD
@export var look_ahead_max: float = FeelConstants.CAMERA_LOOK_AHEAD_MAX

# Point the camera "looks" at (crosshair); set by the player every frame
var look_target: Vector2 = Vector2.INF
# Camera stopped (player death): ignores look-ahead
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


## Camera recoil: pushes 1 to 2 px back from the shot direction.
func kick(direction: Vector2, strength: float = FeelConstants.CAMERA_RECOIL) -> void:
	_recoil = -direction.normalized() * strength
