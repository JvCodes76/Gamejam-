extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 1.5
@export var max_enemies: int = 12
@export var spawn_radius: float = 260.0

var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = spawn_interval
	_timer.autostart = true
	_timer.timeout.connect(_spawn_enemy)
	add_child(_timer)


# Cria um inimigo num ponto aleatorio ao redor do jogador.
func _spawn_enemy() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if enemy_scene == null or player == null:
		return
	if get_tree().get_nodes_in_group("enemy").size() >= max_enemies:
		return
	var enemy := enemy_scene.instantiate() as Node2D
	add_child(enemy)
	enemy.global_position = player.global_position + Vector2.from_angle(randf() * TAU) * spawn_radius
	print("[Enemy] - spawn em %s" % enemy.global_position)
