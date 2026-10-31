class_name SynergyState
extends RefCounted
## Efeitos de sinergia resolvidos para a poção ativa (preenchido por SynergyResolver).

# Aspect -> tier (0 a 4)
var tiers: Dictionary = {}

# PLANT
var root_chance: float = 0.0
var root_duration: float = 0.0
var root_dot_fraction: float = 0.0
var root_heal_fraction: float = 0.0

# POISON
var poison_slow: float = 0.0
var poison_dps_bonus: float = 0.0
var poison_weaken: float = 0.0
var poison_instakill_chance: float = 0.0

# EARTH
var mud_enabled: bool = false
var mud_slow: float = 0.0
var mud_dps_fraction: float = 0.0
var mud_death_pool: bool = false

# ROCK
var stun_chance: float = 0.0
var stun_extra: float = 0.0
var stun_max: float = 0.0

# ANIMAL
var mark_count: int = 0
var marked_weaken: float = 0.0
var marked_explode: bool = false

# DARKNESS
var negate_chance: float = 0.0
var negate_blast: bool = false

# LIGHT
var holy_chance: float = 0.0
var holy_instakill_chance: float = 0.0

# MAGIC
var arc_enabled: bool = false
var arc_bounce: bool = false

# EVIL
var rage_enabled: bool = false
var rage_resets_per_floor: bool = false

# --- Sinergias especiais (receitas) ---
# Ids das receitas ativas
var specials: Array[StringName] = []
# Salad!: bônus somado à chance de lifesteal
var lifesteal_chance_bonus: float = 0.0
# EVIL Salad!!: bônus somado à chance de veneno
var poison_chance_bonus: float = 0.0
# Spice bag: rastro de nuvem e sua lentidão
var cloud_enabled: bool = false
var cloud_slow: float = 0.0
# Unethical Butcher: chance de orbe de cura ao morrer marcado
var butcher_orb_chance: float = 0.0
# Crunchy!: bônus de dano recebido por atordoados
var stun_damage_bonus: float = 0.0
# Press F: fantasmas de enfeitiçados mortos
var ghosts_enabled: bool = false
# RAINBOWS!!!: bônus de charm, ricochetes e ciclo de cores
var charm_chance_bonus: float = 0.0
var bounce_count: int = 0
var rainbow_colors: bool = false
# Do NOT make this tea.: chance e fração de vida máxima perdida
var tea_chance: float = 0.0
var tea_health_fraction: float = 0.0
# Weird Eye Drops.: a bala se divide ao acertar
var split_on_hit: bool = false
# Magical Potentializer: multiplicadores de raio e dano das explosões
var explosion_radius_mult: float = 1.0
var explosion_damage_mult: float = 1.0


## Tier (0 a 4) de um aspecto.
func tier(aspect: ItemEnums.Aspect) -> int:
	return int(tiers.get(aspect, 0))


## Retorna true se a receita especial está ativa.
func has_special(id: StringName) -> bool:
	return specials.has(id)


## Retorna true se alguma sinergia (de aspecto ou especial) está ativa.
func any_active() -> bool:
	if not specials.is_empty():
		return true
	for a: int in tiers:
		if int(tiers[a]) > 0:
			return true
	return false
