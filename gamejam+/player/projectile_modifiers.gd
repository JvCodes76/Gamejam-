class_name ProjectileModifiers
extends RefCounted
## Modificadores de ataque resolvidos a partir dos efeitos da poção ativa.
## Dano: Hitbox.damage continua int; o multiplicador fracionário é acumulado
## em roll_damage() (instância compartilhada entre as balas do mesmo disparo/poção).

const DAMAGE_PER_POINT: float = 0.25
const RANGE_PER_POINT: float = 0.25
const FIRE_RATE_PER_POINT: float = 0.25
const LIFESTEAL_PER_POINT: float = 0.1
const POISON_DPS_PER_POINT: float = 1.0
const POISON_DURATION: float = 3.0
const FIRE_DPS_PER_POINT: float = 1.5
const FIRE_DURATION: float = 2.0
const UNIMPLEMENTED_TYPES: Array[ItemEffect.EffectType] = [
	ItemEffect.EffectType.LUCK, ItemEffect.EffectType.CHARM_CHANCE, ItemEffect.EffectType.HOMING,
	ItemEffect.EffectType.AOE, ItemEffect.EffectType.CRIT_DAMAGE, ItemEffect.EffectType.LASER,
	ItemEffect.EffectType.EXPLOSIVE, ItemEffect.EffectType.FIRE_BREATH, ItemEffect.EffectType.REAL_BULLETS,
]

var color: Color = Color.WHITE
var damage_multiplier: float = 1.0
var range_multiplier: float = 1.0
var fire_rate_multiplier: float = 1.0
var lifesteal_fraction: float = 0.0
var pierce_count: int = 0
var poison_dps: float = 0.0
var poison_duration: float = POISON_DURATION
var fire_dps: float = 0.0
var fire_duration: float = FIRE_DURATION
var unimplemented: Dictionary = {}

var _damage_carry: float = 0.0
var _heal_carry: float = 0.0


## Resolve os campos a partir de um Dictionary EffectType -> float.
static func from_totals(totals: Dictionary) -> ProjectileModifiers:
	var m: ProjectileModifiers = ProjectileModifiers.new()
	m.damage_multiplier = 1.0 + _total(totals, ItemEffect.EffectType.DAMAGE) * DAMAGE_PER_POINT
	m.range_multiplier = 1.0 + _total(totals, ItemEffect.EffectType.RANGE) * RANGE_PER_POINT
	m.fire_rate_multiplier = 1.0 + _total(totals, ItemEffect.EffectType.FIRE_RATE) * FIRE_RATE_PER_POINT
	m.lifesteal_fraction = _total(totals, ItemEffect.EffectType.LIFESTEAL) * LIFESTEAL_PER_POINT
	m.pierce_count = int(_total(totals, ItemEffect.EffectType.PIERCE))
	m.poison_dps = _total(totals, ItemEffect.EffectType.POISON_DAMAGE) * POISON_DPS_PER_POINT
	m.fire_dps = _total(totals, ItemEffect.EffectType.FIRE_DAMAGE) * FIRE_DPS_PER_POINT
	for t: ItemEffect.EffectType in UNIMPLEMENTED_TYPES:
		if _total(totals, t) != 0.0:
			m.unimplemented[t] = _total(totals, t)
	return m


## Dano inteiro (mínimo 1) com acúmulo da parte fracionária.
func roll_damage(base: int) -> int:
	_damage_carry += base * damage_multiplier
	var amount: int = maxi(int(_damage_carry), 1)
	_damage_carry = maxf(_damage_carry - amount, 0.0)
	return amount


## Cura inteira gerada por um dano causado (acumula frações).
func roll_heal(damage_dealt: int) -> int:
	_heal_carry += damage_dealt * lifesteal_fraction
	var amount: int = int(_heal_carry)
	_heal_carry -= amount
	return amount


## Imprime uma vez os efeitos guardados mas ainda não implementados.
func print_unimplemented() -> void:
	for t: ItemEffect.EffectType in unimplemented:
		print("[Potion] - efeito %s ainda não implementado" % ItemEffect.EffectType.keys()[t])


static func _total(totals: Dictionary, type: ItemEffect.EffectType) -> float:
	return float(totals.get(type, 0.0))
