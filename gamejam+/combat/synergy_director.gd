class_name SynergyDirector
extends Node
## Aspect synergies that react to the world (marking, rage, root healing, kills, damage negation).
## Lives as a child of the Player; receives the active potion's state via configure().

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


## Connects the director to the player and the global signals.
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


## Receives the active potion's modifiers (and its synergies) and applies what depends on the state.
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
		print("[Synergy] - %s" % (summary + "  active" if summary != "" else "none active"))


func _process(delta: float) -> void:
	if _state.mark_count <= 0:
		return
	_mark_timer += delta
	if _mark_timer >= SynergyConstants.ANIMAL_REEVALUATE:
		_mark_timer = 0.0
		reevaluate_marks()


## Current rage damage bonus (0.05 = +5%); 0 if the Evil synergy is not active.
func rage_bonus() -> float:
	return _rage_kills * SynergyConstants.EVIL_RAGE_PER_KILL if _state.rage_enabled else 0.0


## Number of kills accumulated by the rage.
func rage_kills() -> int:
	return _rage_kills


## Marks the N enemies with the highest max health (N = Animal tier) and unmarks the ones that left the top.
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
			print("[Synergy] - strongest enemy marked (health %d)" % enemy.get_health().max_health)
		status.apply(StatusEffects.MARKED, SynergyConstants.ANIMAL_MARK_DURATION)
		if _state.marked_weaken > 0.0:
			status.apply(StatusEffects.WEAKENED, SynergyConstants.ANIMAL_MARK_DURATION, _state.marked_weaken)


## Rolls the instant kill per poison tick (tier 12); false for non-basic enemies.
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


## DoT ticks: roots heal the player (tier 12) and poison can instantly kill basic enemies (tier 12).
func _on_enemy_dot_ticked(enemy: Node, source: StringName, amount: int) -> void:
	if source == &"roots" and _state.root_heal_fraction > 0.0 and amount > 0 and _health != null:
		_heal_carry += amount * _state.root_heal_fraction
		var heal: int = int(_heal_carry)
		if heal > 0:
			_heal_carry -= heal
			_health.heal(heal)
			print("[Synergy] - roots healed %d" % heal)
	elif source == &"poison" and _state.poison_instakill_chance > 0.0:
		var target: EnemyBase = enemy as EnemyBase
		if target != null and target.is_alive() and roll_poison_instakill(target.is_basic):
			target.slay_if_basic()
			print("[Synergy] - poison killed a basic enemy")


## Kills: explosion of marked enemies (Animal 12), mud puddle (Earth 12) and mark re-evaluation.
func _on_enemy_died(pos: Vector2, was_marked: bool, _is_basic: bool) -> void:
	if _mods == null:
		return
	var scene: Node = get_tree().current_scene
	if _state.marked_explode and was_marked:
		var dmg: int = _mods.roll_explosion_damage(CombatConstants.WEAPON_BASE_DAMAGE, SynergyConstants.ANIMAL_EXPLOSION_FRACTION)
		ImpactEffect.spawn_blast(scene, pos + CombatConstants.ENEMY_BODY_OFFSET, _mods.explosion_radius(SynergyConstants.ANIMAL_EXPLOSION_RADIUS), dmg, SynergyConstants.ANIMAL_EXPLOSION_COLOR)
		print("[Synergy] - marked enemy exploded (damage %d)" % dmg)
	if _state.mud_death_pool:
		MudTrail.spawn(scene, pos, SynergyConstants.EARTH_DEATH_POOL_RADIUS, SynergyConstants.EARTH_DEATH_POOL_LIFETIME, _state.mud_slow, _mods.mud_dps(CombatConstants.WEAPON_BASE_DAMAGE))
		print("[Synergy] - mud puddle on death")
	if was_marked and _state.butcher_orb_chance > 0.0 and randf() < _state.butcher_orb_chance:
		HealOrb.spawn(scene, pos)
		print("[Synergy] - Unethical Butcher: healing orb dropped")
	if _state.mark_count > 0:
		reevaluate_marks()


## Press F to pay respects: the charmed enemy that died becomes a ghost for the remaining charm time.
func _on_charmed_enemy_died(enemy: Node2D, time_left: float) -> void:
	if not _state.ghosts_enabled or time_left < SynergyConstants.GHOST_MIN_TIME or not is_instance_valid(enemy):
		return
	Ghost.spawn(get_tree().current_scene, enemy, time_left)


## Each kill accumulates rage (Evil).
func _on_enemy_killed(_points: int) -> void:
	if not _state.rage_enabled:
		return
	_rage_kills += 1
	_apply_rage()


## Resets the rage every room, except with Evil tier 6 (resets per floor).
func _on_room_changed(_index: int) -> void:
	if not _state.rage_resets_per_floor:
		_reset_rage()


## Resets the rage every floor.
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
	print("[Synergy] - rage +%.1f%%" % (bonus * 100.0))
	EventBus.rage_changed.emit(bonus)


## Damage negated (Darkness): dark flash on the player and, at tier 6, a dark explosion on enemies.
func _on_damage_negated(amount: int) -> void:
	print("[Synergy] - damage negated (%d)" % amount)
	if _player != null:
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		_player.modulate = SynergyConstants.DARKNESS_FLASH_COLOR
		_flash_tween = _player.create_tween()
		_flash_tween.tween_property(_player, "modulate", Color.WHITE, SynergyConstants.DARKNESS_FLASH_TIME)
	if _state.negate_blast and _mods != null and _player != null:
		var dmg: int = _mods.roll_explosion_damage(CombatConstants.WEAPON_BASE_DAMAGE, SynergyConstants.DARKNESS_BLAST_FRACTION)
		ImpactEffect.spawn_blast(get_tree().current_scene, _body_position(), _mods.explosion_radius(SynergyConstants.DARKNESS_BLAST_RADIUS), dmg, SynergyConstants.DARKNESS_COLOR, 24)
		print("[Synergy] - dark explosion (damage %d)" % dmg)


## Center of the player's body (the node origin is at the feet); "body" explosions originate here.
func _body_position() -> Vector2:
	var player: Player = _player as Player
	return player.aim_origin if player != null else _player.global_position
