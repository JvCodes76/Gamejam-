class_name EnemyBase
extends CharacterBody2D

const PLAYER_MASK: int = 2
const ENEMY_MASK: int = 4

@export var move_speed: float = 45.0
@export var points: int = 10
@export var contact_cooldown: float = 0.6
# Inimigo básico (sujeito a mortes instantâneas das sinergias)
@export var is_basic: bool = true
## Fração do knockback ignorada (0 = recebe tudo, 1 = imóvel). Elites e boss resistem mais.
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0
## Tempo após o spawn sem causar dano de contato (s)
@export var spawn_grace: float = FeelConstants.SPAWN_GRACE
## Elite com arte própria: a sala não amplia nem tinge o sprite (só aplica vida e resistência de elite)
@export var has_elite_art: bool = false

@onready var _health: HealthComponent = $HealthComponent
@onready var _hitbox: Hitbox = $Hitbox
@onready var _status: StatusEffects = $StatusEffects
@onready var _sprite: Sprite2D = $Sprite2D

var _base_modulate: Color = Color.WHITE
# Cooldown do dano de contato e verificação de sobreposição por contagem de quadros (sem await no inimigo)
var _contact_cooldown_left: float = 0.0
var _recheck_frames: int = 0
# Velocidade externa (knockback), somada à perseguição e reduzida por atrito
var _knockback: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("enemy")
	_base_modulate = _sprite.modulate
	_health.died.connect(_on_died)
	_hitbox.hit_landed.connect(_on_hit_landed)
	_hitbox.hurtbox_hit.connect(_on_hurtbox_hit)
	_status.changed.connect(_on_status_changed)
	_health.dot_damaged.connect(_on_dot_damaged)
	# Carência do spawn: reaproveita o cooldown de contato (a hitbox volta sozinha e reverifica a sobreposição)
	if spawn_grace > 0.0:
		_hitbox.set_deferred("monitoring", false)
		_contact_cooldown_left = spawn_grace


# Persegue o jogador (ou o inimigo mais próximo se enfeitiçado); respeita roots, slow e stun.
func _physics_process(delta: float) -> void:
	_hitbox.damage_scale = _status.damage_dealt_multiplier()
	_tick_contact(delta)
	var target: Node2D = _find_target()
	if target == null or not _status.can_move():
		velocity = Vector2.ZERO
	else:
		velocity = _chase_velocity(target) * _status.speed_multiplier()
	velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, FeelConstants.KNOCKBACK_FRICTION * delta)
	move_and_slide()


## Velocidade desejada em direção ao alvo (antes de lentidão e knockback); subclasses mudam o jeito de andar.
func _chase_velocity(target: Node2D) -> Vector2:
	return global_position.direction_to(target.global_position) * move_speed


## Empurrão externo (golpe): reduzido pela resistência, decai por atrito em _physics_process.
func apply_knockback(impulse: Vector2) -> void:
	_knockback += impulse * (1.0 - knockback_resistance)


## Animação de surgimento: o sprite cresce de 0 até a escala base.
func play_spawn_pop() -> void:
	var feedback: HitFeedback = get_node_or_null("HitFeedback") as HitFeedback
	var target_scale: Vector2 = feedback.base_scale() if feedback != null else _sprite.scale
	_sprite.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "scale", target_scale, FeelConstants.SPAWN_POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Alvo atual: jogador, ou o inimigo não enfeitiçado mais próximo quando enfeitiçado.
func _find_target() -> Node2D:
	if _status.has(StatusEffects.CHARMED):
		return nearest_enemy(self, true)
	return get_tree().get_first_node_in_group("player") as Node2D


# Inimigo vivo mais próximo de "from"; opcionalmente ignora marcados e enfeitiçados.
static func nearest_enemy(from: EnemyBase, only_unmarked_uncharmed: bool) -> EnemyBase:
	var best: EnemyBase = null
	var best_dist: float = INF
	for node: Node in from.get_tree().get_nodes_in_group("enemy"):
		var other: EnemyBase = node as EnemyBase
		if other == null or other == from or other.is_queued_for_deletion() or other._health.is_dead():
			continue
		if only_unmarked_uncharmed and other._status.has(StatusEffects.CHARMED):
			continue
		if not only_unmarked_uncharmed and other._status.has(StatusEffects.MARKED):
			continue
		var dist: float = from.global_position.distance_squared_to(other.global_position)
		if dist < best_dist:
			best_dist = dist
			best = other
	return best


# Reage a mudanças de status: stun (e dano recebido), charme (máscara e cor) e dano de marcado.
func _on_status_changed(status: StringName, active: bool) -> void:
	match status:
		StatusEffects.STUN:
			_hitbox.suppressed = active
			_health.damage_taken_multiplier = _status.damage_taken_multiplier()
			if not active:
				_recheck_contact()
		StatusEffects.CHARMED:
			_hitbox.collision_mask = ENEMY_MASK if active else PLAYER_MASK
			_sprite.modulate = _base_modulate.lerp(CombatConstants.CHARM_TINT, CombatConstants.CHARM_TINT_AMOUNT) if active else _base_modulate
			print("[Combat] - enfeitiçado: %s" % active)
			_recheck_contact()
		StatusEffects.MARKED:
			_health.damage_taken_multiplier = _status.damage_taken_multiplier()


# Inicia o cooldown do dano de contato (contado em _physics_process, sem await).
func _on_hit_landed() -> void:
	_hitbox.set_deferred("monitoring", false)
	_contact_cooldown_left = contact_cooldown


# Conta o cooldown de contato e a espera de 2 quadros antes de reverificar a sobreposição.
func _tick_contact(delta: float) -> void:
	if _contact_cooldown_left > 0.0:
		_contact_cooldown_left -= delta
		if _contact_cooldown_left <= 0.0:
			_contact_cooldown_left = 0.0
			_hitbox.monitoring = true
			_recheck_contact()
	if _recheck_frames > 0:
		_recheck_frames -= 1
		if _recheck_frames == 0:
			_check_overlap()


# Enfeitiçado: o inimigo atingido revida com o próprio dano de contato (dano simétrico).
func _on_hurtbox_hit(hurtbox: Hurtbox) -> void:
	if not _status.has(StatusEffects.CHARMED):
		return
	var other: EnemyBase = hurtbox.get_parent() as EnemyBase
	if other != null and other._status.can_act() and not other._status.has(StatusEffects.CHARMED):
		_health.take_damage(other._hitbox.damage)


# Agenda a verificação de sobreposição para daqui a 2 quadros de física.
func _recheck_contact() -> void:
	_recheck_frames = 2


# Quem já está encostado não gera novo area_entered; verifica a sobreposição manualmente.
func _check_overlap() -> void:
	if not _hitbox.monitoring:
		return
	for area: Area2D in _hitbox.get_overlapping_areas():
		if area is Hurtbox and area.get_parent() != self:
			_hitbox.apply_hit(area)
			break


# Concede pontos, passa a marca ao inimigo mais próximo e remove o inimigo.
func _on_died() -> void:
	print("[Enemy] - morreu (+%d pontos)" % points)
	if _status.has(StatusEffects.MARKED):
		var next: EnemyBase = nearest_enemy(self, false)
		if next != null:
			next._status.apply(StatusEffects.MARKED, maxf(_status.time_left(StatusEffects.MARKED), 1.0))
			print("[Combat] - marca passou para o inimigo mais próximo")
	if _status.has(StatusEffects.CHARMED):
		EventBus.charmed_enemy_died.emit(self, _status.time_left(StatusEffects.CHARMED))
	EventBus.enemy_killed.emit(points)
	EventBus.enemy_died.emit(global_position, _status.has(StatusEffects.MARKED), is_basic)
	# O boss não sorteia drop próprio: a recompensa dele é o lendário da arena
	if not is_in_group("boss"):
		var source: int = LootManager.Source.NORMAL_ENEMY if is_basic else LootManager.Source.ELITE_ENEMY
		EventBus.item_drop_requested.emit(source, global_position)
	_play_death_feedback()
	queue_free()


# Visual da morte num nó separado (o inimigo some na hora): cadáver, tremida, hitstop em elite e som
func _play_death_feedback() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null:
		EnemyDeathFx.spawn(scene, _sprite, global_position)
	if is_basic:
		EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_BASIC_DEATH)
		EventBus.play_sfx_requested.emit("enemy_die")
	else:
		EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_ELITE_DEATH)
		EventBus.hitstop_requested.emit(FeelConstants.HITSTOP_ELITE_DEATH_MS / 1000.0)
		EventBus.play_sfx_requested.emit("elite_die")


# Sprite do inimigo (usado para copiar a aparência, p.ex. fantasmas).
func get_sprite() -> Sprite2D:
	return _sprite


# Componente de status do inimigo.
func get_status() -> StatusEffects:
	return _status


# Componente de vida do inimigo.
func get_health() -> HealthComponent:
	return _health


# Hurtbox do inimigo.
func get_hurtbox() -> Hurtbox:
	return $Hurtbox as Hurtbox


# Retorna true se o inimigo está vivo e não foi marcado para remoção.
func is_alive() -> bool:
	return not is_queued_for_deletion() and not _health.is_dead()


# Mata na hora se for um inimigo básico vivo; retorna true se matou.
func slay_if_basic() -> bool:
	if not is_basic or not is_alive():
		return false
	_health.kill()
	return true


# Repassa o tick de dano ao longo do tempo ao EventBus (sinergias de raiz e veneno).
func _on_dot_damaged(source: StringName, amount: int) -> void:
	EventBus.enemy_dot_ticked.emit(self, source, amount)
