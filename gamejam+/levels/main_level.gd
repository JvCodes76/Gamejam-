extends Node2D
## Debug test level (arena with props and scattered items).

# [DEBUG] Test: items on the inventory screen 5x smaller than the game's default
const DEBUG_BASE_ITEM_SCALE: float = 1.2

var _previous_item_scale: float = 0.0


func _ready() -> void:
	_previous_item_scale = ItemManager.base_item_scale
	ItemManager.base_item_scale = DEBUG_BASE_ITEM_SCALE
	print("[Debug] - base_item_scale %.1f -> %.1f" % [_previous_item_scale, DEBUG_BASE_ITEM_SCALE])


# Restores the global value so it does not leak into the normal game
func _exit_tree() -> void:
	ItemManager.base_item_scale = _previous_item_scale
