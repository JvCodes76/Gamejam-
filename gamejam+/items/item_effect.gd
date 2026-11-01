class_name ItemEffect
extends Resource

# Effect types applicable to projectiles
# Magnitude convention: "+" = 1.0, "++" = 2.0, "+++" = 3.0
# FIRE_BREATH replaces bullets with a fire breath; REAL_BULLETS with real bullets (with reload)
enum EffectType { FIRE_DAMAGE, POISON_DAMAGE, LIFESTEAL, RANGE, DAMAGE, FIRE_RATE, LUCK, PIERCE, CHARM_CHANCE, HOMING, AOE, CRIT_DAMAGE, LASER, EXPLOSIVE, FIRE_BREATH, REAL_BULLETS }

@export var effect_type: EffectType = EffectType.FIRE_DAMAGE
# Additive bonus: the magnitudes of all effects of the same type are added
@export var magnitude: float = 1.0
