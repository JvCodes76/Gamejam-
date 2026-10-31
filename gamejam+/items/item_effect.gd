class_name ItemEffect
extends Resource

# Tipos de efeito aplicáveis aos projéteis
# Convenção de magnitude: "+" = 1.0, "++" = 2.0, "+++" = 3.0
# FIRE_BREATH substitui as balas por sopro de fogo; REAL_BULLETS por balas reais (com recarga)
enum EffectType { FIRE_DAMAGE, POISON_DAMAGE, LIFESTEAL, RANGE, DAMAGE, FIRE_RATE, LUCK, PIERCE, CHARM_CHANCE, HOMING, AOE, CRIT_DAMAGE, LASER, EXPLOSIVE, FIRE_BREATH, REAL_BULLETS }

@export var effect_type: EffectType = EffectType.FIRE_DAMAGE
# Bônus aditivo: as magnitudes de todos os efeitos do mesmo tipo são somadas
@export var magnitude: float = 1.0
