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


## Tier (0 a 4) de um aspecto.
func tier(aspect: ItemEnums.Aspect) -> int:
	return int(tiers.get(aspect, 0))


## Retorna true se alguma sinergia está ativa.
func any_active() -> bool:
	for a: int in tiers:
		if int(tiers[a]) > 0:
			return true
	return false
