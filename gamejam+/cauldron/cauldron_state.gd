class_name CauldronState
extends RefCounted

# Items inside the cauldron: {"item", "position", "rotation", "scale"} (local position)
var entries: Array[Dictionary] = []
# Finished potion (null if none)
var potion: PotionData = null
# Interior space multiplier (expanded by future upgrades)
var size_multiplier: float = 1.0
# Brewing progress, 0 to 1
var brew_progress: float = 0.0
