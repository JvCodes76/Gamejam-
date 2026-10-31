class_name SynergyDirector
extends Node
## Sinergias de aspecto que reagem ao mundo (marcação, raiva, cura de raízes, mortes, negação de dano).
## Vive como filho do Player; recebe o estado da poção ativa via configure().

var _player: Node2D = null
var _health: HealthComponent = null
var _mods: ProjectileModifiers = null
var _state: SynergyState = SynergyState.new()
var _mark_timer: float = 0.0
var _marked: Array[EnemyBase] = []
var _heal_carry: float = 0.0
var _rage_kills: int = 0
var _last_summary: String = ""
var _flash_tween: Tween = null


## Liga o diretor ao jogador e aos sinais globais.
func setup(player: Node2D, health: HealthComponent) -> void:
	_player = player
	_health = health
	_health.damage_negated.connect(_on_damage_negated)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.charmed_enemy_died.connect(_on_charmed_enemy_died)
	EventBus.enemy_dot_ticked.connect(_on_enemy_dot_ticked)
	EventBus.room_changed.connect(_on_room_changed)
	EventBus.floor_changed.connect(_on_floor_changed)


## Recebe os modificadores da poção ativa (e suas sinergias) e aplica o que depende do estado.
func configure(mods: ProjectileModifiers, aspect_counts: Dictionary) -> void:
	_mods = mods
	_state = mods.synergy
	StatusEffects.stun_damage_bonus = _state.stun_damage_bonus
	if _health != null:
		_health.negate_chance = _state.negate_chance
	mods.rage_multiplier = 1.0 + rage_bonus()
	if _state.mark_count == 0:
		_clear_marks()
	var summary: String = SynergyResolver.summary(aspect_counts, _state.specials)
	if summary != _last_summary:
		_last_summary = summary
		print("[Synergy] - %s" % (summary + " ativos" if summary != "" else "nenhuma ativa"))


func _process(delta: float) -> void:
	if _state.mark_count <= 0:
		return
	_mark_timer += delta
	if _mark_timer >= SynergyConstants.ANIMAL_REEVALUATE:
		_mark_timer = 0.0
		reevaluate_marks()


## Bônus de dano atual da raiva (0.05 = +5%); 0 se a sinergia Evil não está ativa.
func rage_bonus() -> float:
	return _rage_kills * SynergyConstants.EVIL_RAGE_PER_KILL if _state.rage_enabled else 0.0


## Número de mortes acumuladas pela raiva.
func rage_kills() -> int:
	return _rage_kills


## Marca os N inimigos de maior vida máxima (N = tier de Animal) e desmarca os que saíram do topo.
func reevaluate_marks() -> void:
	var candidates: Array[EnemyBase] = []
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy != null and enemy.is_alive():
			candidates.append(enemy)
	candidates.sort_custom(_stronger_first)
	var chosen: Array[EnemyBase] = []
	for i: int in mini(_state.mark_count, candidates.size()):
		chosen.append(candidates[i])
	for old: EnemyBase in _marked:
		if is_instance_valid(old) and not old in chosen:
			old.get_status().clear(StatusEffects.MARKED)
	_marked = chosen
	for enemy: EnemyBase in chosen:
		var status: StatusEffects = enemy.get_status()
		if not status.has(StatusEffects.MARKED):
			print("[Synergy] - inimigo mais forte marcado (vida %d)" % enemy.get_health().max_health)
		status.apply(StatusEffects.MARKED, SynergyConstants.ANIMAL_MARK_DURATION)
		if _state.marked_weaken > 0.0:
			status.apply(StatusEffects.WEAKENED, SynergyConstants.ANIMAL_MARK_DURATION, _state.marked_weaken)


## Sorteia a morte instantânea por tick de veneno (tier 12); false para inimigos não básicos.
func roll_poison_instakill(is_basic: bool) -> bool:
	return is_basic and _state.poison_instakill_chance > 0.0 and randf() < _state.poison_instakill_chance


func _stronger_first(a: EnemyBase, b: EnemyBase) -> bool:
	var ha: int = a.get_health().max_health
	var hb: int = b.get_health().max_health
	if ha != hb:
		return ha > hb
	return a.get_instance_id() < b.get_instance_id()


func _clear_marks() -> void:
	for old: EnemyBase in _marked:
		if is_instance_valid(old):
			old.get_status().clear(StatusEffects.MARKED)
	_marked.clear()


## Ticks de DoT: raízes curam o player (tier 12) e veneno pode matar básicos na hora (tier 12).
func _on_enemy_dot_ticked(enemy: Node, source: StringName, amount: int) -> void:
	if source == &"roots" and _state.root_heal_fraction > 0.0 and amount > 0 and _health != null:
		_heal_carry += amount * _state.root_heal_fraction
		var heal: int = int(_heal_carry)
		if heal > 0:
			_heal_carry -= heal
			_health.heal(heal)
			print("[Synergy] - raízes curaram %d" % heal)
	elif source == &"poison" and _state.poison_instakill_chance > 0.0:
		var target: EnemyBase = enemy as EnemyBase
		if target != null and target.is_alive() and roll_poison_instakill(target.is_basic):
			target.slay_if_basic()
			print("[Synergy] - veneno matou um inimigo básico")


## Mortes: explosão dos marcados (Animal 12), poça de lama (Earth 12) e reavaliação da marca.
func _on_enemy_died(pos: Vector2, was_marked: bool, _is_basic: bool) -> void:
	if _mods == null:
		return
	var scene: Node = get_tree().current_scene
	if _state.marked_explode and was_marked:
		var dmg: int = _mods.roll_explosion_damage(CombatConstants.WEAPON_BASE_DAMAGE, SynergyConstants.ANIMAL_EXPLOSION_FRACTION)
		ImpactEffect.spawn_blast(scene, pos, _mods.explosion_radius(SynergyConstants.ANIMAL_EXPLOSION_RADIUS), dmg, SynergyConstants.ANIMAL_EXPLOSION_COLOR)
		print("[Synergy] - inimigo marcado explodiu (dano %d)" % dmg)
	if _state.mud_death_pool:
		MudTrail.spawn(scene, pos, SynergyConstants.EARTH_DEATH_POOL_RADIUS, SynergyConstants.EARTH_DEATH_POOL_LIFETIME, _state.mud_slow, _mods.mud_dps(CombatConstants.WEAPON_BASE_DAMAGE))
		print("[Synergy] - poça de lama na morte")
	if was_marked and _state.butcher_orb_chance > 0.0 and randf() < _state.butcher_orb_chance:
		HealOrb.spawn(scene, pos)
		print("[Synergy] - Unethical Butcher: orbe de cura dropada")
	if _state.mark_count > 0:
		reevaluate_marks()


## Press F to pay respects: o inimigo enfeitiçado que morreu vira um fantasma pelo tempo restante do charm.
func _on_charmed_enemy_died(enemy: Node2D, time_left: float) -> void:
	if not _state.ghosts_enabled or time_left < SynergyConstants.GHOST_MIN_TIME or not is_instance_valid(enemy):
		return
	Ghost.spawn(get_tree().current_scene, enemy, time_left)


## Cada morte acumula raiva (Evil).
func _on_enemy_killed(_points: int) -> void:
	if not _state.rage_enabled:
		return
	_rage_kills += 1
	_apply_rage()


## Zera a raiva a cada sala, exceto com Evil tier 6 (zera por andar).
func _on_room_changed(_index: int) -> void:
	if not _state.rage_resets_per_floor:
		_reset_rage()


## Zera a raiva a cada andar.
func _on_floor_changed(_level: int) -> void:
	_reset_rage()


func _reset_rage() -> void:
	if _rage_kills == 0:
		return
	_rage_kills = 0
	_apply_rage()


func _apply_rage() -> void:
	var bonus: float = rage_bonus()
	if _mods != null:
		_mods.rage_multiplier = 1.0 + bonus
	print("[Synergy] - raiva +%.1f%%" % (bonus * 100.0))
	EventBus.rage_changed.emit(bonus)


## Dano negado (Darkness): flash escuro no player e, no tier 6, explosão sombria nos inimigos.
func _on_damage_negated(amount: int) -> void:
	print("[Synergy] - dano negado (%d)" % amount)
	if _player != null:
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		_player.modulate = SynergyConstants.DARKNESS_FLASH_COLOR
		_flash_tween = _player.create_tween()
		_flash_tween.tween_property(_player, "modulate", Color.WHITE, SynergyConstants.DARKNESS_FLASH_TIME)
	if _state.negate_blast and _mods != null and _player != null:
		var dmg: int = _mods.roll_explosion_damage(CombatConstants.WEAPON_BASE_DAMAGE, SynergyConstants.DARKNESS_BLAST_FRACTION)
		ImpactEffect.spawn_blast(get_tree().current_scene, _player.global_position, _mods.explosion_radius(SynergyConstants.DARKNESS_BLAST_RADIUS), dmg, SynergyConstants.DARKNESS_COLOR, 24)
		print("[Synergy] - explosão sombria (dano %d)" % dmg)
