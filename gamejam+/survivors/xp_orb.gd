class_name XpOrb
extends Node2D
## Red XP orb dropped by enemies: scatters, is pulled toward the player when close and gives XP on touch.

## XP given on pickup
var value: int = 1
## Distance (px) at which the orb starts flying to the player
var magnet_radius: float = 70.0
var pickup_radius: float = 9.0
var max_speed: float = 260.0
var acceleration: float = 520.0

var _speed: float = 0.0
var _scatter: Vector2 = Vector2.ZERO
var _player: Node2D = null


func _ready() -> void:
	z_index = CombatConstants.Z_GROUND_ITEM + 1
	_scatter = Vector2.from_angle(randf() * TAU) * randf_range(10.0, 26.0)
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", position + _scatter, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_player = get_tree().get_first_node_in_group("player") as Node2D
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var target: Vector2 = _player.global_position + Vector2(0.0, -10.0)
	var distance: float = global_position.distance_to(target)
	if distance <= pickup_radius:
		EventBus.xp_collected.emit(value)
		EventBus.play_sfx_requested.emit("ui_hover")
		queue_free()
		return
	if distance <= magnet_radius:
		_speed = minf(_speed + acceleration * delta, max_speed)
		global_position = global_position.move_toward(target, _speed * delta)


func _draw() -> void:
	var radius: float = 2.5 if value <= 1 else 4.0
	draw_circle(Vector2.ZERO, radius + 1.0, Color(0.25, 0.0, 0.03))
	draw_circle(Vector2.ZERO, radius, Color(0.9, 0.1, 0.15))
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.35, Color(1.0, 0.6, 0.6))
