extends CharacterBody2D

@export var move_speed: float = 45.0
@export var points: int = 10
@export var contact_cooldown: float = 0.6

@onready var _health: HealthComponent = $HealthComponent
@onready var _hitbox: Hitbox = $Hitbox


func _ready() -> void:
	add_to_group("enemy")
	_health.died.connect(_on_died)
	_hitbox.hit_landed.connect(_on_hit_landed)


# Persegue o jogador; fica parado se nao houver.
func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		velocity = Vector2.ZERO
	else:
		velocity = global_position.direction_to(player.global_position) * move_speed
	move_and_slide()


# Inicia o cooldown do dano de contato.
func _on_hit_landed() -> void:
	_hitbox.set_deferred("monitoring", false)
	await get_tree().create_timer(contact_cooldown).timeout
	if not is_instance_valid(_hitbox):
		return
	_hitbox.set_deferred("monitoring", true)
	# Quem já está encostado não gera novo area_entered; verifica a sobreposição manualmente
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(_hitbox):
		return
	for area: Area2D in _hitbox.get_overlapping_areas():
		_hitbox.apply_hit(area)
		break


# Concede pontos e remove o inimigo.
func _on_died() -> void:
	print("[Enemy] - morreu (+%d pontos)" % points)
	EventBus.enemy_killed.emit(points)
	queue_free()
