class_name ProjectileModifiers
extends RefCounted
## Modificadores de ataque resolvidos a partir dos efeitos da poção ativa.
## Constantes de balanceamento: combat/combat_constants.gd.
## Dano: Hitbox.damage continua int; o multiplicador fracionário é acumulado
## em roll_damage() (instância compartilhada entre as balas do mesmo disparo/poção).

const UNIMPLEMENTED_TYPES: Array[ItemEffect.EffectType] = [
	ItemEffect.EffectType.HOMING, ItemEffect.EffectType.AOE, ItemEffect.EffectType.LASER,
	ItemEffect.EffectType.EXPLOSIVE, ItemEffect.EffectType.FIRE_BREATH, ItemEffect.EffectType.REAL_BULLETS,
]

var color: Color = Color.WHITE
var damage_multiplier: float = 1.0
var range_multiplier: float = 1.0
var fire_rate_multiplier: float = 1.0
var luck: float = 0.0
var lifesteal_level: float = 0.0
var crit_damage_level: float = 0.0
var charm_level: float = 0.0
var poison_level: float = 0.0
## Pierce: base 1 = a bala acerta 1 inimigo e para; pierce_count = inimigos EXTRA atravessados.
var pierce_count: int = 0
var has_poison_ingredient: bool = false
var fire_dps: float = 0.0
var fire_duration: float = CombatConstants.FIRE_DURATION
var unimplemented: Dictionary = {}
## Efeitos de sinergia de aspecto resolvidos para esta poção (SynergyResolver).
var synergy: SynergyState = SynergyState.new()
## Multiplicador de dano da raiva (sinergia Evil); mantido pelo SynergyDirector.
var rage_multiplier: float = 1.0

var _damage_carry: float = 0.0
var _heal_carry: float = 0.0
var _secondary_carry: float = 0.0


## Resolve os campos a partir de EffectType -> float e Aspect -> int.
static func from_totals(totals: Dictionary, aspects: Dictionary = {}) -> ProjectileModifiers:
	var m: ProjectileModifiers = ProjectileModifiers.new()
	m.damage_multiplier = 1.0 + _total(totals, ItemEffect.EffectType.DAMAGE) * CombatConstants.DAMAGE_PER_POINT
	m.range_multiplier = 1.0 + _total(totals, ItemEffect.EffectType.RANGE) * CombatConstants.RANGE_PER_POINT
	m.fire_rate_multiplier = 1.0 + _total(totals, ItemEffect.EffectType.FIRE_RATE) * CombatConstants.FIRE_RATE_PER_POINT
	m.luck = _total(totals, ItemEffect.EffectType.LUCK)
	m.lifesteal_level = _total(totals, ItemEffect.EffectType.LIFESTEAL)
	m.crit_damage_level = _total(totals, ItemEffect.EffectType.CRIT_DAMAGE)
	m.charm_level = _total(totals, ItemEffect.EffectType.CHARM_CHANCE)
	m.poison_level = _total(totals, ItemEffect.EffectType.POISON_DAMAGE)
	m.pierce_count = int(_total(totals, ItemEffect.EffectType.PIERCE))
	m.synergy = SynergyResolver.resolve(aspects)
	m.has_poison_ingredient = int(aspects.get(ItemEnums.Aspect.POISON, 0)) >= 1
	m.fire_dps = _total(totals, ItemEffect.EffectType.FIRE_DAMAGE) * CombatConstants.FIRE_DPS_PER_POINT
	for t: ItemEffect.EffectType in UNIMPLEMENTED_TYPES:
		if _total(totals, t) != 0.0:
			m.unimplemented[t] = _total(totals, t)
	return m


## Dano inteiro (mínimo 1) com acúmulo da parte fracionária; extra = multiplicador adicional (bala santa).
func roll_damage(base: int, extra: float = 1.0) -> int:
	_damage_carry += base * damage_multiplier * rage_multiplier * extra
	var amount: int = maxi(int(_damage_carry), 1)
	_damage_carry = maxf(_damage_carry - amount, 0.0)
	return amount


## Dano da arma como float (base * dano * raiva), usado por explosões, DoTs e raios das sinergias.
func weapon_damage(base: int) -> float:
	return base * damage_multiplier * rage_multiplier


## Dano inteiro (mín. 1, sem crítico) de efeitos secundários: fração do dano da arma com acúmulo.
func roll_secondary_damage(base: int, fraction: float = 1.0) -> int:
	_secondary_carry += weapon_damage(base) * fraction
	var amount: int = maxi(int(_secondary_carry), 1)
	_secondary_carry = maxf(_secondary_carry - amount, 0.0)
	return amount


## DPS da lama (fração do dano da arma por segundo; 0 antes do tier 6 de Earth).
func mud_dps(base: int) -> float:
	return weapon_damage(base) * synergy.mud_dps_fraction


## Sorteia se o tiro é santo (sinergia Light).
func roll_holy() -> bool:
	return synergy.holy_chance > 0.0 and randf() < synergy.holy_chance


## Sorteia a morte instantânea de uma bala santa; mata só inimigos básicos. Retorna true se matou.
func try_holy_slay(target: Hurtbox) -> bool:
	if synergy.holy_instakill_chance <= 0.0 or randf() >= synergy.holy_instakill_chance:
		return false
	var enemy: EnemyBase = target.get_parent() as EnemyBase
	if enemy == null:
		return false
	var pos: Vector2 = enemy.global_position
	if not enemy.slay_if_basic():
		return false
	print("[Synergy] - rajada de luz matou um inimigo básico")
	ImpactEffect.spawn_blast(target.get_tree().current_scene, pos, SynergyConstants.LIGHT_BURST_RADIUS, 0, SynergyConstants.LIGHT_HOLY_COLOR, 24)
	return true


## Chance de crítico por hit.
func crit_chance() -> float:
	return clampf(CombatConstants.CRIT_BASE_CHANCE + CombatConstants.CRIT_CHANCE_PER_LUCK * luck, 0.0, 1.0)


## Multiplicador de dano do crítico.
func crit_multiplier() -> float:
	return CombatConstants.CRIT_BASE_MULTIPLIER + CombatConstants.CRIT_MULT_PER_POINT * crit_damage_level


## Sorteia o crítico de um hit.
func roll_crit() -> bool:
	return randf() < crit_chance()


## Chance de lifesteal por hit (logarítmica em lifesteal e luck; 0 sem lifesteal).
func lifesteal_chance() -> float:
	if lifesteal_level <= 0.0:
		return 0.0
	var chance: float = CombatConstants.LIFESTEAL_CHANCE_SCALE * log(1.0 + lifesteal_level) * (1.0 + log(1.0 + maxf(luck, 0.0)))
	return clampf(chance, 0.0, 1.0)


## Cura inteira de um hit direto: sorteia a chance e acumula frações (mín. 1% da vida máxima).
func roll_heal(damage_dealt: int, max_health: int) -> int:
	if randf() >= lifesteal_chance():
		return 0
	_heal_carry += maxf(damage_dealt * CombatConstants.LIFESTEAL_HEAL_FRACTION, max_health * CombatConstants.LIFESTEAL_HEAL_FRACTION)
	var amount: int = int(_heal_carry)
	_heal_carry -= amount
	return amount


## Chance de envenenar por hit (0 sem ingrediente de veneno).
func poison_chance() -> float:
	return CombatConstants.POISON_HIT_CHANCE if has_poison_ingredient else 0.0


## Dano por segundo do veneno: dano base da arma * (1 + bônus por ponto de POISON_DAMAGE).
func poison_dps(base_damage: int) -> float:
	return base_damage * (1.0 + CombatConstants.POISON_DPS_BONUS_PER_POINT * poison_level) * (1.0 + synergy.poison_dps_bonus)


## Chance de enfeitiçar por hit (0 sem CHARM_CHANCE).
func charm_chance() -> float:
	if charm_level <= 0.0:
		return 0.0
	return clampf(CombatConstants.CHARM_PER_POINT * charm_level * (1.0 + log(1.0 + maxf(luck, 0.0))), 0.0, 1.0)


## Raio da área de impacto (escala com o alcance).
func impact_radius() -> float:
	return CombatConstants.IMPACT_RADIUS_BASE * range_multiplier


## Aplica fogo (sempre) e sorteia veneno e charme num alvo; usado no hit direto e no splash.
func apply_on_hit_effects(target: Hurtbox, base_damage: int) -> void:
	if fire_dps > 0.0:
		target.apply_dot(fire_dps, fire_duration, &"fire", CombatConstants.FIRE_TICK)
	if has_poison_ingredient and randf() < poison_chance():
		target.apply_dot(poison_dps(base_damage), CombatConstants.POISON_DURATION, &"poison", CombatConstants.POISON_TICK)
		print("[Combat] - alvo envenenado (%.1f dps)" % poison_dps(base_damage))
		_apply_poison_synergy(target)
	if randf() < charm_chance():
		target.apply_status(StatusEffects.CHARMED, CombatConstants.CHARM_DURATION)
	_apply_hit_synergies(target, base_damage)


## Veneno com sinergia: lentidão (tier 3) e enfraquecimento (tier 9) enquanto envenenado.
func _apply_poison_synergy(target: Hurtbox) -> void:
	if synergy.poison_slow > 0.0:
		target.apply_status(StatusEffects.SLOW, CombatConstants.POISON_DURATION, StatusEffects.slow_power(synergy.poison_slow))
	if synergy.poison_weaken > 0.0:
		target.apply_status(StatusEffects.WEAKENED, CombatConstants.POISON_DURATION, synergy.poison_weaken)


## Sinergias por hit: raízes + DoT de raiz (Plant) e stun (Rock).
func _apply_hit_synergies(target: Hurtbox, base_damage: int) -> void:
	if synergy.root_chance > 0.0 and randf() < synergy.root_chance:
		target.apply_status(StatusEffects.ROOTS, synergy.root_duration)
		if synergy.root_dot_fraction > 0.0:
			target.apply_dot(weapon_damage(base_damage) * synergy.root_dot_fraction, synergy.root_duration, &"roots", SynergyConstants.PLANT_ROOT_DOT_TICK)
		print("[Synergy] - inimigo enraizado")
	if synergy.stun_chance > 0.0 and randf() < synergy.stun_chance:
		target.apply_status(StatusEffects.STUN, StatusEffects.stun_duration(0.0, synergy.stun_extra, synergy.stun_max))
		print("[Synergy] - inimigo atordoado")


## Imprime uma vez os efeitos guardados mas ainda não implementados.
func print_unimplemented() -> void:
	for t: ItemEffect.EffectType in unimplemented:
		print("[Potion] - efeito %s ainda não implementado" % ItemEffect.EffectType.keys()[t])


static func _total(totals: Dictionary, type: ItemEffect.EffectType) -> float:
	return float(totals.get(type, 0.0))
