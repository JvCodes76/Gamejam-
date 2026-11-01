class_name TutorialDirector
extends Node
## Tutorial script: shows the (freezing) popups and drops the tutorial items, driven by the rooms' events.
## Rooms (see DungeonGenerator.generate_tutorial): spawn -> combat -> cauldron -> fight -> teleporter.

const ITEM_PATHS: Array[String] = [
	"res://items/data/carrot.tres",
	"res://items/data/mushroom.tres",
]
const ITEM_OFFSET: float = 28.0

const MSG_MOVE_SHOOT: String = "Move with W A S D (or the arrow keys).\nAim with the mouse and hold LEFT CLICK to shoot.\n\nDefeat the enemies to open the doors!"
const MSG_PICK_UP: String = "Two items dropped!\nStand next to an item and press E to pick it up."
const MSG_INVENTORY: String = "You can open your inventory at any time.\nPress TAB or I to open and close it."
const MSG_CAULDRON: String = "This is the cauldron.\nStand next to it and press E to interact."
const MSG_BREW: String = "Brewing: DRAG items with the mouse into the cauldron (grab and drop).\nWheel rotates an item.\nHold ENTER to brew, F to bottle the potion.\nTAB or ESC closes."

var popup: TutorialPopup

var _level: DungeonLevel
var _brew_taught: bool = false


func setup(level: DungeonLevel) -> void:
	_level = level
	popup = TutorialPopup.new()
	popup.name = "TutorialPopup"
	add_child(popup)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.cauldron_open_requested.connect(_on_cauldron_open_requested)


## The player entered a tutorial room.
func on_room_entered(room: RoomData) -> void:
	match room.tutorial_step:
		RoomData.TutorialStep.COMBAT:
			popup.show_message(MSG_MOVE_SHOOT)
		RoomData.TutorialStep.CAULDRON:
			popup.show_message(MSG_CAULDRON)


## The enemies of a tutorial room were all defeated.
func on_room_cleared(room: RoomData) -> void:
	if room.tutorial_step != RoomData.TutorialStep.COMBAT:
		return
	for i: int in ITEM_PATHS.size():
		var item: ItemData = load(ITEM_PATHS[i]) as ItemData
		if item == null:
			push_error("[Tutorial] - item not found: %s" % ITEM_PATHS[i])
			continue
		var side: float = float(i) - (ITEM_PATHS.size() - 1) * 0.5
		ItemManager.drop_to_ground(item, room.center() + Vector2(side * 2.0 * ITEM_OFFSET, 0.0))
	print("[Tutorial] - items dropped")
	popup.show_message(MSG_PICK_UP)


# First item picked up: the inventory unlocks and the player is told about it.
func _on_item_picked_up(_item_id: StringName) -> void:
	if not ItemManager.inventory_locked:
		return
	ItemManager.inventory_locked = false
	print("[Tutorial] - inventory unlocked")
	popup.show_message(MSG_INVENTORY)


func _on_cauldron_open_requested(_cauldron: Node) -> void:
	if _brew_taught:
		return
	_brew_taught = true
	popup.show_message(MSG_BREW)
