class_name TutorialDirector
extends Node
## Tutorial script: shows the (freezing) popups and drops the tutorial items, driven by the rooms' events.
## Rooms (see DungeonGenerator.generate_tutorial): spawn -> combat -> cauldron -> fight -> teleporter.

const ITEM_PATHS: Array[String] = [
	"res://items/data/carrot.tres",
	"res://items/data/mushroom.tres",
]
const ITEM_OFFSET: float = 28.0

const MSG_MOVE: String = "Hello! Welcome! You, my friend, are a witch's apprentice, and monsters are invading your forest! Use WASD to move around."
const MSG_SHOOT: String = "Shocker, but those monsters really want to hurt you! Don't worry though, you have your potions to defend yourself! Press M1 to shoot where you're looking."
const MSG_PICK_UP: String = "Wow! Two items dropped!! Go up to them and press E to pick them up! If your bag is full, you can open it at any time with TAB and every item nearby will show up there, on the ground."
const MSG_CAULDRON: String = "This is your trusty cauldron, every graveyard has one, obviously. Press E to interact with it."
const MSG_BREW: String = "This is the cauldron Screen! To make a new potion, drag the ingredients you want to use into the cauldron and hold ENTER"
const MSG_BOTTLE: String = "When the potion is done brewing, press F to bottle it up."
const MSG_EXPERIMENT: String = "You're only an apprendice, so you just know the basics of every ingredient, to find out how they synergise and interact, experiment!"
const MSG_FINISH: String = "That's the basics! Now go out there and get'em! And if you fail, remember, there's always the... next hex!!! Please laugh."

# Seconds before the first popup (lets the scene fade-in finish)
const START_DELAY: float = 0.6

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
	# First thing the player sees: starts in the spawn room, after the scene fade-in
	if room.type == RoomData.Type.SPAWN:
		await get_tree().create_timer(START_DELAY, true, false, true).timeout
		popup.show_message(MSG_MOVE)
		return
	match room.tutorial_step:
		RoomData.TutorialStep.COMBAT:
			popup.show_message(MSG_SHOOT)
		RoomData.TutorialStep.CAULDRON:
			popup.show_message(MSG_CAULDRON)
		RoomData.TutorialStep.FINISH:
			popup.show_message(MSG_FINISH)


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


func _on_cauldron_open_requested(_cauldron: Node) -> void:
	if _brew_taught:
		return
	_brew_taught = true
	popup.show_message(MSG_BREW)
	popup.show_message(MSG_BOTTLE)
	popup.show_message(MSG_EXPERIMENT)
