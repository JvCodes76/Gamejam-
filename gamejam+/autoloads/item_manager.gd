extends Node

const SYNERGIES_DIR: String = "res://items/synergies/"
const ASPECT_BONUSES_DIR: String = "res://items/aspect_bonuses/"

# Owned items (only potions count for effects)
var owned_items: Array[ItemData] = []
var synergies: Array[ItemSynergy] = []
var aspect_bonuses: Array[AspectBonus] = []

# Items in the bag: {"item", "position", "rotation", "scale"}
var bag_entries: Array[Dictionary] = []
# Items on the ground: {"item": ItemData, "position": world Vector2}
var ground_entries: Array[Dictionary] = []
var starting_items_seeded: bool = false
# Items waiting on the inventory screen's floor (bag full)
var pending_items: Array[ItemData] = []
# Tutorial: the inventory cannot be opened by the player until the first item is picked up
var inventory_locked: bool = false
# True while the inventory screen is open
var inventory_open: bool = false
# True while the cauldron (brewing) screen is open: the player stands still
var cauldron_open: bool = false
# True while the journal (compendium) is open
var journal_open: bool = false
var shrink_upgrade_active: bool = false
var shrink_scale: float = 0.6
# Base scale of the sprites on the inventory screen (16 px -> 96 px)
var base_item_scale: float = 6.0
# Current floor (1 = first); each floor shrinks items by 1/FLOOR_SHRINK_FACTOR
var floor_level: int = 1
# Monster Survivors: extra item shrink from leveling up (1.0 = none, lower = smaller items)
var bag_optimization: float = 1.0
const MIN_BAG_OPTIMIZATION: float = 0.3
const FLOOR_SHRINK_FACTOR: float = 1.25
# Potion slots (2) and the active index
var potion_slots: Array[PotionData] = [null, null]
var active_potion_index: int = 0


func _ready() -> void:
	synergies.assign(_load_resources(SYNERGIES_DIR))
	aspect_bonuses.assign(_load_resources(ASPECT_BONUSES_DIR))
	print("[Items] - %d synergies, %d aspect bonuses loaded" % [synergies.size(), aspect_bonuses.size()])


# Adds an item to the inventory
func add_item(item: ItemData) -> void:
	if item == null or not item.is_valid():
		return
	if _contains(owned_items, item):
		return
	owned_items.append(item)
	print("[Items] - Item owned: %s" % item.id)


# Counts aspects of a list of items
func count_aspects(items: Array[ItemData]) -> Dictionary:
	var counts: Dictionary = {}
	for item: ItemData in items:
		for a: ItemEnums.Aspect in item.aspects:
			counts[a] = int(counts.get(a, 0)) + 1
	return counts


# Item effects + satisfied synergies + reached aspect bonuses
func compute_effect_totals(items: Array[ItemData]) -> Dictionary:
	var effects: Array[ItemEffect] = []
	for item: ItemData in items:
		effects.append_array(item.effects)
	for synergy: ItemSynergy in synergies:
		if _is_synergy_active(synergy, items):
			effects.append_array(synergy.bonus_effects)
	var counts: Dictionary = count_aspects(items)
	for bonus: AspectBonus in aspect_bonuses:
		if int(counts.get(bonus.aspect, 0)) >= bonus.required_count:
			effects.append_array(bonus.bonus_effects)
	var totals: Dictionary = {}
	for effect: ItemEffect in effects:
		totals[effect.effect_type] = float(totals.get(effect.effect_type, 0.0)) + effect.magnitude
	return totals


# Active potion (null if the slot is empty)
func get_active_potion() -> PotionData:
	return potion_slots[active_potion_index]


func set_potion_slot(index: int, potion: PotionData) -> void:
	if index < 0 or index >= potion_slots.size():
		return
	potion_slots[index] = potion
	print("[Items] - Potion slot %d updated" % index)
	EventBus.potion_slots_changed.emit()
	if index == active_potion_index:
		EventBus.active_effects_changed.emit()


# Stores in the first free slot; if full, replaces the active one. Returns the index used
func store_potion(potion: PotionData) -> int:
	var index: int = active_potion_index
	for i: int in potion_slots.size():
		if potion_slots[i] == null:
			index = i
			break
	set_potion_slot(index, potion)
	return index


# Toggles the active slot between 0 and 1 (non-zero direction)
func cycle_potion(direction: int) -> void:
	if direction == 0:
		return
	active_potion_index = posmod(active_potion_index + direction, potion_slots.size())
	print("[Items] - Active potion: %d" % active_potion_index)
	EventBus.potion_selected.emit(active_potion_index)
	EventBus.active_effects_changed.emit()


# Effects of the active potion (empty if null)
func get_active_effect_totals() -> Dictionary:
	var potion: PotionData = get_active_potion()
	return potion.effect_totals if potion != null else {}


# Clears the state for a new run
func reset() -> void:
	owned_items.clear()
	bag_entries.clear()
	ground_entries.clear()
	pending_items.clear()
	starting_items_seeded = false
	inventory_locked = false
	cauldron_open = false
	shrink_upgrade_active = false
	floor_level = 1
	bag_optimization = 1.0
	potion_slots = [null, null]
	active_potion_index = 0
	EventBus.potion_slots_changed.emit()
	EventBus.active_effects_changed.emit()


# Scale per floor: each floor shrinks items by 1/FLOOR_SHRINK_FACTOR
func floor_scale() -> float:
	return pow(1.0 / FLOOR_SHRINK_FACTOR, floor_level - 1) * bag_optimization


# Shrinks every item (current and future ones) by 1/factor; returns the ratio actually applied (1.0 = hit the limit)
func optimize_bag(factor: float) -> float:
	var previous: float = bag_optimization
	bag_optimization = maxf(bag_optimization / factor, MIN_BAG_OPTIMIZATION)
	var ratio: float = bag_optimization / previous
	for entry: Dictionary in bag_entries:
		entry["scale"] = float(entry["scale"]) * ratio
	print("[Items] - bag optimized (scale %.3f)" % floor_scale())
	return ratio


# Advances the floor; items already in the bag shrink along with it
func advance_floor() -> void:
	floor_level += 1
	for entry: Dictionary in bag_entries:
		entry["scale"] = float(entry["scale"]) / FLOOR_SHRINK_FACTOR
	print("[Items] - Floor %d (scale %.3f)" % [floor_level, floor_scale()])
	EventBus.floor_changed.emit(floor_level)


# Current scale of an item: base * rarity * floor * (shrink if active and with_shrink)
func current_item_scale(item: ItemData = null, with_shrink: bool = true) -> float:
	var result: float = base_item_scale * floor_scale()
	if item != null:
		result *= item.rarity_scale()
	if with_shrink and shrink_upgrade_active:
		result *= shrink_scale
	return result


# Stores the item in the bag if it fits easily
func try_auto_store(item: ItemData) -> bool:
	var scale_now: float = current_item_scale(item)
	var spot: Variant = BagFit.find_free_position(item, bag_entries, scale_now)
	if spot == null:
		print("[Inventory] - No room in the bag: %s" % (item.id if item != null else &"null"))
		return false
	bag_entries.append({"item": item, "position": spot["position"], "rotation": spot["rotation"], "scale": scale_now})
	add_item(item)
	print("[Inventory] - Item stored in the bag: %s" % item.id)
	return true


# Replaces the bag layout
func save_bag_layout(entries: Array[Dictionary]) -> void:
	bag_entries = entries.duplicate()


func remove_from_bag(entry: Dictionary) -> void:
	bag_entries.erase(entry)


# Drops the item on the world ground
func drop_to_ground(item: ItemData, world_position: Vector2) -> void:
	ground_entries.append({"item": item, "position": world_position})
	EventBus.ground_items_changed.emit()


func take_from_ground(entry: Dictionary) -> void:
	ground_entries.erase(entry)
	EventBus.ground_items_changed.emit()


func _is_synergy_active(synergy: ItemSynergy, items: Array[ItemData]) -> bool:
	if synergy.required_items.is_empty():
		return false
	for req: ItemData in synergy.required_items:
		if not _contains(items, req):
			return false
	return true


# Compares by id, since the same .tres can be loaded as distinct instances
func _contains(list: Array[ItemData], item: ItemData) -> bool:
	for other: ItemData in list:
		if other == item or other.id == item.id:
			return true
	return false


func _load_resources(dir_path: String) -> Array:
	var out: Array = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	for file: String in dir.get_files():
		# On export, files may have a .remap suffix
		var clean: String = file.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			var res: Resource = load(dir_path + clean)
			if res != null:
				out.append(res)
	return out
