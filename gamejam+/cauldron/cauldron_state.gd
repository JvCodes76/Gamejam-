class_name CauldronState
extends RefCounted

# Itens dentro do caldeirão: {"item", "position", "rotation", "scale"} (posição local)
var entries: Array[Dictionary] = []
# Poção pronta (null se não há)
var potion: PotionData = null
# Multiplicador do espaço interno (expandido por upgrades futuros)
var size_multiplier: float = 1.0
# Progresso do preparo, 0 a 1
var brew_progress: float = 0.0
