class_name Player
extends CharacterBody2D

const BULLET_SCENE: PackedScene = preload("res://projectiles/bullet.tscn")

@export var move_speed: float = 110.0
@export var acceleration: float = 900.0
@export var friction: float = 1200.0
@export var fire_rate_seconds: float = 0.18
@export var aim_deadzone: float = 0.3
@export var gamepad_crosshair_distance: float = 60.0

var _fire_timer: float = 0.0
var _aim_direction: Vector2 = Vector2.RIGHT
var _use_gamepad: bool = false

@onready var _pivot: Node2D = $Pivot
@onready var _muzzle: Marker2D = $Pivot/Muzzle
@onready var _health: HealthComponent = $HealthComponent
@onready var _crosshair: Crosshair = $Crosshair


func _ready() -> void:
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)
	# Adiado para o HUD (que vem depois na árvore) já estar conectado
	EventBus.player_health_changed.emit.call_deferred(_health.current_health, _health.max_health)
	EventBus.game_paused.connect(_on_game_paused)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	print("[Player] - pronto")


## Restaura o cursor do sistema ao sair da cena.
func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Volta a mirar com o mouse quando ele se move.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_use_gamepad = false


func _physics_process(delta: float) -> void:
	_update_aim()
	_handle_movement(delta)
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


## Atualiza a mira (analógico ou mouse), gira o Pivot e posiciona o crosshair.
func _update_aim() -> void:
	var stick: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > aim_deadzone:
		_use_gamepad = true
		_aim_direction = stick.normalized()
		_crosshair.global_position = global_position + _aim_direction * gamepad_crosshair_distance
	elif not _use_gamepad:
		var mouse_pos: Vector2 = get_global_mouse_position()
		var to_mouse: Vector2 = mouse_pos - global_position
		if to_mouse.length() > 1.0:
			_aim_direction = to_mouse.normalized()
		_crosshair.global_position = mouse_pos
	else:
		_crosshair.global_position = global_position + _aim_direction * gamepad_crosshair_distance
	_pivot.rotation = _aim_direction.angle()


## Dispara uma bala na direção da mira.
func _shoot() -> void:
	_fire_timer = fire_rate_seconds
	var bullet: Bullet = BULLET_SCENE.instantiate() as Bullet
	bullet.global_position = _muzzle.global_position
	var shot_dir: Vector2 = _aim_direction
	if not _use_gamepad:
		var to_mouse: Vector2 = get_global_mouse_position() - _muzzle.global_position
		if to_mouse.length() > 1.0:
			shot_dir = to_mouse.normalized()
	bullet.setup(shot_dir)
	get_tree().current_scene.add_child(bullet)
	EventBus.play_sfx_requested.emit("shoot")


## Alterna cursor do sistema e crosshair conforme a pausa.
func _on_game_paused(paused: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_HIDDEN
	_crosshair.visible = not paused


## Repassa a mudança de vida ao EventBus.
func _on_health_changed(current: int, max_value: int) -> void:
	EventBus.player_health_changed.emit(current, max_value)


## Trata a morte do jogador.
func _on_died() -> void:
	print("[Player] - morreu")
	EventBus.player_died.emit()
	queue_free()
