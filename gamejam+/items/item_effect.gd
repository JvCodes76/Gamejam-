class_name ItemEffect
extends Resource

# Tipos de efeito aplicáveis aos projéteis
enum EffectType { FIRE_DAMAGE, POISON_DAMAGE, LIFESTEAL, RANGE, DAMAGE, FIRE_RATE }

@export var effect_type: EffectType = EffectType.FIRE_DAMAGE
# 1.0 = base; 2.0 = dobro
@export var magnitude: float = 1.0
