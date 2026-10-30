class_name Player
extends CharacterBody2D

const BULLET_SCENE: PackedScene = preload("res://projectiles/bullet.tscn")

@export var move_speed: float = 110.0
@export var acceleration: float = 900.0
@export var friction: float = 1200.0
@export var fire_rate_seconds: float = 0.18
@export var aim_deadzone: float = 0.3

var _fire_timer: float = 0.0
var _aim_direction: Vector2 = Vector2.RIGHT

@onready var _pivot: Node2D = $Pivot
@onready var _muzzle: Marker2D = $Pivot/Muzzle
@onready var _health: HealthComponent = $HealthComponent


func _ready() -> void:
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)
	EventBus.player_health_changed.emit(_health.current_health, _health.max_health)
	print("[Player] - pronto")


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_update_aim()
	_fire_timer -= delta
	if Input.is_action_pressed("shoot") and _fire_timer <= 0.0:
		_shoot()


## Move o jogador em 8 direções com aceleração e atrito.
func _handle_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()


## Atualiza a direção de mira (analógico ou mouse) e gira o Pivot.
func _update_aim() -> void:
	var stick: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > aim_deadzone:
		_aim_direction = stick.normalized()
	else:
		var to_mouse: Vector2 = get_global_mouse_position() - global_position
		if to_mouse.length() > 1.0:
			_aim_direction = to_mouse.normalized()
	_pivot.rotation = _aim_direction.angle()


## Dispara uma bala na direção da mira.
func _shoot() -> void:
	_fire_timer = fire_rate_seconds
	var bullet: Bullet = BULLET_SCENE.instantiate() as Bullet
	bullet.global_position = _muzzle.global_position
	bullet.setup(_aim_direction)
	get_tree().current_scene.add_child(bullet)
	EventBus.play_sfx_requested.emit("shoot")


## Repassa a mudança de vida ao EventBus.
func _on_health_changed(current: int, max_value: int) -> void:
	EventBus.player_health_changed.emit(current, max_value)


## Trata a morte do jogador.
func _on_died() -> void:
	print("[Player] - morreu")
	EventBus.player_died.emit()
	queue_free()
