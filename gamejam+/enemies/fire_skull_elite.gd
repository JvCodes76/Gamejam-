class_name FireSkullElite
extends EnemyBase
## Blue fire skull (elite): chases the player and, from time to time, stops, flashes and charges in a straight line.
## The sheet has 16 frames of 32x32 (hframes on the Sprite2D), played in Skull.SPIN_FRAMES order.

enum State { CHASE, WINDUP, DASH }

@export var anim_fps: float = 12.0
## Interval between charges (s), rolled between x and y
@export var dash_interval: Vector2 = Vector2(2.2, 3.4)
## Time standing still warning before the charge (s)
@export var windup_time: float = 0.5
@export var dash_speed: float = 320.0
@export var dash_time: float = 0.35
@export var windup_color: Color = Color(0.5, 0.8, 1.0)

var _anim_time: float = 0.0
var _state: State = State.CHASE
var _state_left: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	_state_left = randf_range(dash_interval.x, dash_interval.y)


func _process(delta: float) -> void:
	var speed_up: float = 2.0 if _state == State.DASH else 1.0
	_anim_time += delta * speed_up
	_sprite.frame = Skull.SPIN_FRAMES[int(_anim_time * anim_fps) % Skull.SPIN_FRAMES.size()]


func _physics_process(delta: float) -> void:
	# Stunned or rooted: cancels the charge and goes back to chasing
	if not _status.can_move() and _state != State.CHASE:
		_enter_chase()
	if _status.can_act():
		_state_left -= delta
		if _state_left <= 0.0:
			_advance_state()
	super._physics_process(delta)


func _chase_velocity(target: Node2D) -> Vector2:
	match _state:
		State.WINDUP:
			return Vector2.ZERO
		State.DASH:
			return _dash_direction * dash_speed
	return super._chase_velocity(target)


# Chases -> warns -> charges -> chases
func _advance_state() -> void:
	match _state:
		State.CHASE:
			var target: Node2D = _find_target()
			if target == null:
				_state_left = dash_interval.x
				return
			_state = State.WINDUP
			_state_left = windup_time
			_play_windup_feedback()
		State.WINDUP:
			var target: Node2D = _find_target()
			_dash_direction = global_position.direction_to(target.global_position) if target != null else Vector2.ZERO
			_state = State.DASH
			_state_left = dash_time
			EventBus.play_sfx_requested.emit("elite_dash")
		State.DASH:
			_enter_chase()


func _enter_chase() -> void:
	_state = State.CHASE
	_state_left = randf_range(dash_interval.x, dash_interval.y)


# Flashes blue and shakes before charging
func _play_windup_feedback() -> void:
	var feedback: HitFeedback = get_node_or_null("HitFeedback") as HitFeedback
	if feedback != null:
		feedback.flash(windup_color, windup_time)
	var base_x: float = _sprite.position.x
	var tween: Tween = create_tween()
	for i: int in 4:
		tween.tween_property(_sprite, "position:x", base_x + (2.0 if i % 2 == 0 else -2.0), windup_time / 8.0)
		tween.tween_property(_sprite, "position:x", base_x, windup_time / 8.0)
