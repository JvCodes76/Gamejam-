extends Node
## Journal / compendium progress: items collected, elemental synergies and special synergies brewed.
## Starts empty and persists between runs in user://compendium.cfg.

const SAVE_PATH: String = "user://compendium.cfg"
const ITEMS_DIR: String = "res://items/data/"
const SECTION: String = "compendium"

# Every item of the game: id -> ItemData
var _registry: Dictionary = {}
# Discovered entries, in discovery order
var _items: Array[StringName] = []
# Elemental synergies as "aspect:tier" (tier 1-4 = 3/6/9/12 aspects)
var _elemental: Array[String] = []
var _specials: Array[StringName] = []

## True while there are discoveries the player has not seen yet (not persisted; drives the "new" dot)
var has_unseen: bool = false


func _ready() -> void:
	_load_registry()
	_load_progress()
	EventBus.item_collected.connect(_on_item_collected)
	print("[Compendium] - %d items, %d elemental, %d special synergies discovered" % [_items.size(), _elemental.size(), _specials.size()])


## Items already collected, in discovery order.
func discovered_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for id: StringName in _items:
		out.append(_registry[id])
	return out


## Discovered elemental synergies as {"aspect": Aspect, "tier": 1-4}, in discovery order.
func discovered_elemental() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: String in _elemental:
		var parts: PackedStringArray = key.split(":")
		out.append({"aspect": int(parts[0]), "tier": int(parts[1])})
	return out


## Discovered special recipes (SpecialSynergies.RECIPES entries), in discovery order.
func discovered_specials() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in _specials:
		for recipe: Dictionary in SpecialSynergies.RECIPES:
			if recipe["id"] == id:
				out.append(recipe)
	return out


## ItemData for an id (null if unknown).
func get_item(id: StringName) -> ItemData:
	return _registry.get(id)


## Collected items that have the aspect, in discovery order.
func discovered_items_with_aspect(aspect: int) -> Array[ItemData]:
	var out: Array[ItemData] = []
	for item: ItemData in discovered_items():
		if item.aspects.has(aspect):
			out.append(item)
	return out


## Records the synergies of a freshly brewed potion.
func register_brew(potion: PotionData) -> void:
	if potion == null:
		return
	var changed: bool = false
	for item: ItemData in potion.items:
		changed = _add_item(item.id) or changed
	for aspect: int in ItemEnums.Aspect.values():
		var tier: int = SynergyResolver.tier_of(int(potion.aspect_counts.get(aspect, 0)))
		for t: int in range(1, tier + 1):
			# Tiers with no effect (empty text) are not synergies
			if SynergyResolver.tier_text(aspect, t) == "":
				continue
			var key: String = "%d:%d" % [aspect, t]
			if not _elemental.has(key):
				_elemental.append(key)
				changed = true
	for id: StringName in potion.special_synergies:
		if not _specials.has(id):
			_specials.append(id)
			changed = true
	if changed:
		_save_and_notify()


func _on_item_collected(item_id: StringName, _position: Vector2) -> void:
	if _add_item(item_id):
		_save_and_notify()


func _add_item(id: StringName) -> bool:
	if not _registry.has(id) or _items.has(id):
		return false
	_items.append(id)
	return true


func _save_and_notify() -> void:
	has_unseen = true
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION, "items", _items)
	config.set_value(SECTION, "elemental", _elemental)
	config.set_value(SECTION, "specials", _specials)
	var err: Error = config.save(SAVE_PATH)
	if err != OK:
		push_warning("[Compendium] - could not save progress (error %d)" % err)
	EventBus.compendium_updated.emit()


func _load_progress() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for id: Variant in config.get_value(SECTION, "items", []):
		if _registry.has(StringName(id)) and not _items.has(StringName(id)):
			_items.append(StringName(id))
	for key: Variant in config.get_value(SECTION, "elemental", []):
		if String(key).split(":").size() == 2 and not _elemental.has(String(key)):
			_elemental.append(String(key))
	for id: Variant in config.get_value(SECTION, "specials", []):
		if not _specials.has(StringName(id)):
			_specials.append(StringName(id))


func _load_registry() -> void:
	var dir: DirAccess = DirAccess.open(ITEMS_DIR)
	if dir == null:
		return
	for file: String in dir.get_files():
		# On export, files may have a .remap suffix
		var clean: String = file.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var item: ItemData = load(ITEMS_DIR + clean) as ItemData
		if item != null and item.id != &"":
			_registry[item.id] = item
