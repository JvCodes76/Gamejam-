class_name ItemEffect
extends Resource

# Tipos de efeito aplicáveis aos projéteis
enum EffectType { FIRE_DAMAGE, POISON_DAMAGE, LIFESTEAL, RANGE, DAMAGE, FIRE_RATE }

@export var effect_type: EffectType = EffectType.FIRE_DAMAGE
# Bônus aditivo: as magnitudes de todos os efeitos do mesmo tipo são somadas
@export var magnitude: float = 1.0
