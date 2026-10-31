class_name Ghost
extends Area2D
## Fantasma (receita Press F to pay respects): ex-inimigo enfeitiçado que persegue e fere outros inimigos até o charm acabar.
## Imune a dano (não está em nenhuma camada de física) e não fere o player (máscara só dos inimigos).
## A origem fica nos pés (y-sort, z 0); um CharacterBody2D filho ("Mover") o faz esbarrar nos obstáculos altos e baixos.

const BODY_OFFSET_Y: float = -16.0

var duration: float = 1.0
var texture: Texture2D = null
var sprite_scale: Vector2 = Vector2.ONE
var sprite_hframes: int = 1
var sprite_frame: int = 0
var damage: int = SynergyConstants.GHOST_DAMAGE

var _age: float = 0.0
var _hit_left: float = 0.0
var _sprite: Sprite2D = null
var _mover: CharacterBody2D = null


## Cria um fantasma com a aparência do inimigo morto (adição deferida, segura dentro de callbacks de física).
static func spawn(scene: Node, source: Node2D, time_left: float) -> Ghost:
	var ghost: Ghost = (load("res://enemies/ghost.tscn") as PackedScene).instantiate() as Ghost
	ghost.global_position = source.global_position
	ghost.duration = time_left
	var enemy: EnemyBase = source as EnemyBase
	if enemy != null:
		ghost.texture = enemy.get_sprite().texture
		ghost.sprite_scale = enemy.get_sprite().scale
		ghost.sprite_hframes = enemy.get_sprite().hframes
		ghost.sprite_frame = enemy.get_sprite().frame
	scene.add_child.call_deferred(ghost)
	return ghost


func _ready() -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = SynergyConstants.GHOST_RADIUS
	($CollisionShape2D as CollisionShape2D).shape = shape
	_sprite = $Sprite2D as Sprite2D
	_mover = $Mover as CharacterBody2D
	_sprite.texture = texture
	_sprite.hframes = sprite_hframes
	_sprite.frame = sprite_frame
	_sprite.scale = sprite_scale
	_sprite.modulate = SynergyConstants.GHOST_COLOR
	print("[Synergy] - fantasma surgiu (%.2f s)" % duration)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	var fade_left: float = duration - _age
	_sprite.modulate.a = SynergyConstants.GHOST_COLOR.a * clampf(fade_left / SynergyConstants.GHOST_FADE_TIME, 0.0, 1.0)
	_sprite.position.y = BODY_OFFSET_Y + sin(_age * 5.0) * 1.5
	var target: EnemyBase = _nearest_enemy()
	if target != null:
		_move_toward(target.global_position)
	_hit_left -= delta
	if _hit_left <= 0.0:
		_strike()


## Avança em direção ao alvo, deslizando nos obstáculos (o Mover colide; a posição do fantasma segue o Mover).
func _move_toward(target_position: Vector2) -> void:
	_mover.position = Vector2.ZERO
	_mover.velocity = global_position.direction_to(target_position) * SynergyConstants.GHOST_SPEED
	_mover.move_and_slide()
	global_position = _mover.global_position
	_mover.position = Vector2.ZERO


## Fere os inimigos encostados (um golpe por intervalo) e reinicia o cooldown se acertou.
func _strike() -> void:
	var hit_any: bool = false
	for area: Area2D in get_overlapping_areas():
		var hurtbox: Hurtbox = area as Hurtbox
		if hurtbox != null:
			hurtbox.receive_hit(damage)
			hit_any = true
	if hit_any:
		_hit_left = SynergyConstants.GHOST_HIT_COOLDOWN
		print("[Synergy] - fantasma atacou")


## Inimigo vivo mais próximo (preferindo os que não estão enfeitiçados).
func _nearest_enemy() -> EnemyBase:
	var best: EnemyBase = null
	var best_score: float = INF
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy == null or not enemy.is_alive():
			continue
		var score: float = global_position.distance_squared_to(enemy.global_position)
		if enemy.get_status().has(StatusEffects.CHARMED):
			score += 1.0e6
		if score < best_score:
			best_score = score
			best = enemy
	return best
