class_name SynergyState
extends RefCounted
## Synergy effects resolved for the active potion (filled in by SynergyResolver).

# Aspect -> tier (0 to 4)
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

# --- Special synergies (recipes) ---
# Ids of the active recipes
var specials: Array[StringName] = []
# Salad!: bonus added to the lifesteal chance
var lifesteal_chance_bonus: float = 0.0
# EVIL Salad!!: bonus added to the poison chance
var poison_chance_bonus: float = 0.0
# Spice bag: cloud trail and its slow
var cloud_enabled: bool = false
var cloud_slow: float = 0.0
# Unethical Butcher: chance of a healing orb when dying marked
var butcher_orb_chance: float = 0.0
# Crunchy!: bonus damage taken by stunned enemies
var stun_damage_bonus: float = 0.0
# Press F: ghosts of dead charmed enemies
var ghosts_enabled: bool = false
# RAINBOWS!!!: charm bonus, bounces and color cycle
var charm_chance_bonus: float = 0.0
var bounce_count: int = 0
var rainbow_colors: bool = false
# Do NOT make this tea.: chance and fraction of max health lost
var tea_chance: float = 0.0
var tea_health_fraction: float = 0.0
# Weird Eye Drops.: the bullet splits on hit
var split_on_hit: bool = false
# Magical Potentializer: explosion radius and damage multipliers
var explosion_radius_mult: float = 1.0
var explosion_damage_mult: float = 1.0


## Tier (0 to 4) of an aspect.
func tier(aspect: ItemEnums.Aspect) -> int:
	return int(tiers.get(aspect, 0))


## Returns true if the special recipe is active.
func has_special(id: StringName) -> bool:
	return specials.has(id)


## Returns true if any synergy (aspect or special) is active.
func any_active() -> bool:
	if not specials.is_empty():
		return true
	for a: int in tiers:
		if int(tiers[a]) > 0:
			return true
	return false
