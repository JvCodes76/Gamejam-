class_name ProjectileModifiers
extends RefCounted
## Attack modifiers resolved from the active potion's effects.
## Balancing constants: combat/combat_constants.gd.
## Damage: Hitbox.damage remains an int; the fractional multiplier is accumulated
## in roll_damage() (instance shared among the bullets of the same shot/potion).

var color: Color = Color.WHITE
var damage_multiplier: float = 1.0
var range_multiplier: float = 1.0
var fire_rate_multiplier: float = 1.0
var luck: float = 0.0
var lifesteal_level: float = 0.0
var crit_damage_level: float = 0.0
var charm_level: float = 0.0
var poison_level: float = 0.0
## Pierce: base 1 = the bullet hits 1 enemy and stops; pierce_count = EXTRA enemies pierced.
var pierce_count: int = 0
var has_poison_ingredient: bool = false
var fire_dps: float = 0.0
var fire_duration: float = CombatConstants.FIRE_DURATION
## Homing level (0 = off), AOE aura level, explosive on/off, Deathcap's poison cloud level.
var homing_level: float = 0.0
var aoe_level: float = 0.0
var explosive: bool = false
var poison_cloud_level: float = 0.0
## Enemies the bounce can jump to after a hit (effect BOUNCE + RAINBOWS!!!).
var bounce_count: int = 0
## Children spawned when the shot splits on a hit (effect SPLIT; Weird Eye Drops guarantees at least 2).
var split_count: int = 0
## Weapon replacements (priority: fire breath > real bullets > laser).
var laser: bool = false
var fire_breath: bool = false
var real_bullets: bool = false
## Aspect synergy effects resolved for this potion (SynergyResolver).
var synergy: SynergyState = SynergyState.new()
## Rage damage multiplier (Evil synergy); maintained by the SynergyDirector.
var rage_multiplier: float = 1.0
## Items of the potion that generated these modifiers (the Boss adapts to them).
var source_items: Array[ItemData] = []

var _damage_carry: float = 0.0
var _heal_carry: float = 0.0
var _secondary_carry: float = 0.0


## Resolves the fields from EffectType -> float, Aspect -> int and special recipe ids.
static func from_totals(totals: Dictionary, aspects: Dictionary = {}, specials: Array[StringName] = []) -> ProjectileModifiers:
	var m: ProjectileModifiers = ProjectileModifiers.new()
	m.damage_multiplier = 1.0 + _total(totals, ItemEffect.EffectType.DAMAGE) * CombatConstants.DAMAGE_PER_POINT
	m.fire_breath = _total(totals, ItemEffect.EffectType.FIRE_BREATH) > 0.0
	m.real_bullets = not m.fire_breath and _total(totals, ItemEffect.EffectType.REAL_BULLETS) > 0.0
	m.laser = not m.fire_breath and not m.real_bullets and _total(totals, ItemEffect.EffectType.LASER) > 0.0
	if _total(totals, ItemEffect.EffectType.FIRE_BREATH) > 0.0:
		m.damage_multiplier *= CombatConstants.FIRE_BREATH_DAMAGE_MULT
	if _total(totals, ItemEffect.EffectType.REAL_BULLETS) > 0.0:
		m.damage_multiplier *= CombatConstants.REAL_BULLETS_DAMAGE_MULT
	m.range_multiplier = 1.0 + _total(totals, ItemEffect.EffectType.RANGE) * CombatConstants.RANGE_PER_POINT
	m.fire_rate_multiplier = 1.0 + _total(totals, ItemEffect.EffectType.FIRE_RATE) * CombatConstants.FIRE_RATE_PER_POINT
	m.luck = _total(totals, ItemEffect.EffectType.LUCK)
	m.lifesteal_level = _total(totals, ItemEffect.EffectType.LIFESTEAL)
	if GameManager.survivors_mode:
		m.lifesteal_level += CombatConstants.SURVIVORS_BASE_LIFESTEAL
	m.crit_damage_level = _total(totals, ItemEffect.EffectType.CRIT_DAMAGE)
	m.charm_level = _total(totals, ItemEffect.EffectType.CHARM_CHANCE)
	m.poison_level = _total(totals, ItemEffect.EffectType.POISON_DAMAGE)
	m.pierce_count = int(_total(totals, ItemEffect.EffectType.PIERCE))
	m.synergy = SynergyResolver.resolve(aspects, specials)
	m.has_poison_ingredient = int(aspects.get(ItemEnums.Aspect.POISON, 0)) >= 1
	m.fire_dps = _total(totals, ItemEffect.EffectType.FIRE_DAMAGE) * CombatConstants.FIRE_DPS_PER_POINT
	m.homing_level = _total(totals, ItemEffect.EffectType.HOMING)
	m.aoe_level = _total(totals, ItemEffect.EffectType.AOE)
	m.explosive = _total(totals, ItemEffect.EffectType.EXPLOSIVE) > 0.0
	m.poison_cloud_level = _total(totals, ItemEffect.EffectType.POISON_CLOUD)
	m.bounce_count = int(_total(totals, ItemEffect.EffectType.BOUNCE)) + m.synergy.bounce_count
	m.split_count = int(_total(totals, ItemEffect.EffectType.SPLIT))
	if m.synergy.split_on_hit:
		m.split_count = maxi(m.split_count, 2)
	return m


## Resolves the modifiers directly from a list of items (same calculation as PotionData).
static func from_items(items: Array[ItemData]) -> ProjectileModifiers:
	var m: ProjectileModifiers = from_totals(ItemManager.compute_effect_totals(items), ItemManager.count_aspects(items), SpecialSynergies.find_ids(items))
	m.source_items = items.duplicate()
	return m


## Copy of these modifiers without the items of blocked ids (id -> anything); keeps color and rage.
func without_items(blocked_ids: Dictionary) -> ProjectileModifiers:
	var kept: Array[ItemData] = []
	for item: ItemData in source_items:
		if not blocked_ids.has(item.id):
			kept.append(item)
	var m: ProjectileModifiers = from_items(kept)
	m.color = color
	m.rage_multiplier = rage_multiplier
	return m


## Modifiers that apply against the target: the Boss removes the items it is immune to (and records the hit's potion).
func for_target(target: Hurtbox) -> ProjectileModifiers:
	var boss: Boss = target.get_parent() as Boss if target != null else null
	return boss.adapt_modifiers(self) if boss != null else self


## Integer damage (minimum 1) with accumulation of the fractional part; extra = additional multiplier (holy bullet).
func roll_damage(base: int, extra: float = 1.0) -> int:
	_damage_carry += base * damage_multiplier * rage_multiplier * extra
	var amount: int = maxi(int(_damage_carry), 1)
	_damage_carry = maxf(_damage_carry - amount, 0.0)
	return amount


## Weapon damage as a float (base * damage * rage), used by explosions, DoTs and synergy bolts.
func weapon_damage(base: int) -> float:
	return base * damage_multiplier * rage_multiplier


## Integer damage (min. 1, no critical) of secondary effects: fraction of the weapon damage with accumulation.
func roll_secondary_damage(base: int, fraction: float = 1.0) -> int:
	_secondary_carry += weapon_damage(base) * fraction
	var amount: int = maxi(int(_secondary_carry), 1)
	_secondary_carry = maxf(_secondary_carry - amount, 0.0)
	return amount


## Mud DPS (fraction of the weapon damage per second; 0 before Earth tier 6).
func mud_dps(base: int) -> float:
	return weapon_damage(base) * synergy.mud_dps_fraction


## Rolls whether the shot is holy (Light synergy).
func roll_holy() -> bool:
	return synergy.holy_chance > 0.0 and randf() < synergy.holy_chance


## Rolls the instant kill of a holy bullet; kills only basic enemies. Returns true if it killed.
func try_holy_slay(target: Hurtbox) -> bool:
	if synergy.holy_instakill_chance <= 0.0 or randf() >= synergy.holy_instakill_chance:
		return false
	var enemy: EnemyBase = target.get_parent() as EnemyBase
	if enemy == null:
		return false
	var pos: Vector2 = enemy.global_position + CombatConstants.ENEMY_BODY_OFFSET
	if not enemy.slay_if_basic():
		return false
	print("[Synergy] - light burst killed a basic enemy")
	ImpactEffect.spawn_blast(target.get_tree().current_scene, pos, explosion_radius(SynergyConstants.LIGHT_BURST_RADIUS), 0, SynergyConstants.LIGHT_HOLY_COLOR, 24)
	return true


## Critical chance per hit.
func crit_chance() -> float:
	return clampf(CombatConstants.CRIT_BASE_CHANCE + CombatConstants.CRIT_CHANCE_PER_LUCK * luck, 0.0, 1.0)


## Critical damage multiplier.
func crit_multiplier() -> float:
	return CombatConstants.CRIT_BASE_MULTIPLIER + CombatConstants.CRIT_MULT_PER_POINT * crit_damage_level


## Rolls the critical of a hit.
func roll_crit() -> bool:
	return randf() < crit_chance()


## Lifesteal chance per hit (logarithmic in lifesteal and luck) plus the Salad! bonus, which applies without lifesteal.
func lifesteal_chance() -> float:
	var chance: float = synergy.lifesteal_chance_bonus
	if lifesteal_level > 0.0:
		chance += CombatConstants.LIFESTEAL_CHANCE_SCALE * log(1.0 + lifesteal_level) * (1.0 + log(1.0 + maxf(luck, 0.0)))
	return clampf(chance, 0.0, 1.0)


## Radius of a synergy explosion after the Magical Potentializer.
func explosion_radius(radius: float) -> float:
	return radius * synergy.explosion_radius_mult


## Integer damage (min. 1) of a synergy explosion: fraction of the weapon damage with the Potentializer bonus.
func roll_explosion_damage(base: int, fraction: float = 1.0) -> int:
	return roll_secondary_damage(base, fraction * synergy.explosion_damage_mult)


## Integer heal of a direct hit: rolls the chance and accumulates fractions (min. 1% of max health).
func roll_heal(damage_dealt: int, max_health: int) -> int:
	if randf() >= lifesteal_chance():
		return 0
	_heal_carry += maxf(damage_dealt * CombatConstants.LIFESTEAL_HEAL_FRACTION, max_health * CombatConstants.LIFESTEAL_HEAL_FRACTION)
	var amount: int = int(_heal_carry)
	_heal_carry -= amount
	return amount


## Chance to poison per hit (0 without a poison ingredient), with the EVIL Salad!! bonus.
func poison_chance() -> float:
	return clampf(CombatConstants.POISON_HIT_CHANCE + synergy.poison_chance_bonus, 0.0, 1.0) if has_poison_ingredient else 0.0


## Poison damage per second: weapon base damage * (1 + bonus per POISON_DAMAGE point).
func poison_dps(base_damage: int) -> float:
	return base_damage * (1.0 + CombatConstants.POISON_DPS_BONUS_PER_POINT * poison_level) * (1.0 + synergy.poison_dps_bonus)


## Chance to charm per hit (CHARM_CHANCE) plus the RAINBOWS!!! bonus, which applies without CHARM_CHANCE.
func charm_chance() -> float:
	var chance: float = synergy.charm_chance_bonus
	if charm_level > 0.0:
		chance += CombatConstants.CHARM_PER_POINT * charm_level * (1.0 + log(1.0 + maxf(luck, 0.0)))
	return clampf(chance, 0.0, 1.0)


## Radius of the impact area (scales with range and with the Potentializer).
func impact_radius() -> float:
	return explosion_radius(CombatConstants.IMPACT_RADIUS_BASE * range_multiplier)


## Do NOT make this tea.: when piercing a basic enemy, rolls an immediate loss of max health. Returns true if it happened.
func try_tea(target: Hurtbox) -> bool:
	if synergy.tea_chance <= 0.0 or randf() >= synergy.tea_chance:
		return false
	var enemy: EnemyBase = target.get_parent() as EnemyBase
	if enemy == null or not enemy.is_basic or not enemy.is_alive():
		return false
	var health: HealthComponent = enemy.get_health()
	var loss: int = maxi(roundi(health.max_health * synergy.tea_health_fraction), 1)
	health.take_damage(loss)
	print("[Synergy] - bad tea: basic enemy lost %d health (%d%% of max)" % [loss, roundi(synergy.tea_health_fraction * 100.0)])
	return true


## Applies fire (always) and rolls poison and charm on a target; used on the direct hit and the splash.
func apply_on_hit_effects(target: Hurtbox, base_damage: int) -> void:
	if fire_dps > 0.0:
		target.apply_dot(fire_dps, fire_duration, &"fire", CombatConstants.FIRE_TICK)
	if has_poison_ingredient and randf() < poison_chance():
		target.apply_dot(poison_dps(base_damage), CombatConstants.POISON_DURATION, &"poison", CombatConstants.POISON_TICK, CombatConstants.POISON_MAX_STACKS)
		print("[Combat] - target poisoned (%.1f dps)" % poison_dps(base_damage))
		_apply_poison_synergy(target)
		if poison_cloud_level > 0.0:
			PoisonCloud.spawn(target.get_tree().current_scene, target, self, base_damage)
	if randf() < charm_chance():
		target.apply_status(StatusEffects.CHARMED, CombatConstants.CHARM_DURATION)
	_apply_hit_synergies(target, base_damage)


## Poison with synergy: slow (tier 3) and weakening (tier 9) while poisoned.
func _apply_poison_synergy(target: Hurtbox) -> void:
	if synergy.poison_slow > 0.0:
		target.apply_slow(&"poison", CombatConstants.POISON_DURATION, synergy.poison_slow)
	if synergy.poison_weaken > 0.0:
		target.apply_status(StatusEffects.WEAKENED, CombatConstants.POISON_DURATION, synergy.poison_weaken)


## Per-hit synergies: roots + root DoT (Plant) and stun (Rock).
func _apply_hit_synergies(target: Hurtbox, base_damage: int) -> void:
	if synergy.root_chance > 0.0 and randf() < synergy.root_chance:
		target.apply_status(StatusEffects.ROOTS, synergy.root_duration)
		if synergy.root_dot_fraction > 0.0:
			target.apply_dot(weapon_damage(base_damage) * synergy.root_dot_fraction, synergy.root_duration, &"roots", SynergyConstants.PLANT_ROOT_DOT_TICK)
		print("[Synergy] - enemy rooted")
	if synergy.stun_chance > 0.0 and randf() < synergy.stun_chance:
		target.apply_status(StatusEffects.STUN, StatusEffects.stun_duration(0.0, synergy.stun_extra, synergy.stun_max))
		print("[Synergy] - enemy stunned")


static func _total(totals: Dictionary, type: ItemEffect.EffectType) -> float:
	return float(totals.get(type, 0.0))
