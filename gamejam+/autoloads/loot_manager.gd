extends Node
## Item drop system. Every drop first rolls the rarity (weighted roll) and then
## one item among the items of that rarity only. Chances improve with every completed graveyard and,
## aggressively, with every completed set of graveyards (infinite mode loop).
## Whoever wants a drop emits EventBus.item_drop_requested(source, position); this autoload decides.

const ITEMS_DIR: String = "res://items/data/"

## Drop source (each one has its own table)
enum Source {
	ITEM_ROOM,     # item room
	HORDE_CLEAR,   # timer room cleared before time runs out
	NORMAL_ENEMY,  # regular enemy defeated
	ELITE_ENEMY,   # elite defeated
	BOSS_REWARD,   # boss arena at the end of a set of graveyards (always legendary)
	BOSS_HIT,      # damage to the boss (the per-hit chance lives in the Boss itself; here it always drops)
}

@export_group("Base tables")
## Rarity weights [Basic, Intermediate, Advanced, Legendary] for the item room and the timer room
@export var room_rarity_weights: Array[float] = [75.0, 20.0, 4.0, 1.0]
## Rarity weights for regular enemy drops
@export var normal_rarity_weights: Array[float] = [75.0, 20.0, 4.0, 1.0]
## Rarity weights for elite drops
@export var elite_rarity_weights: Array[float] = [25.0, 50.0, 20.0, 5.0]
## Rarity weights for drops from damaging the boss
@export var boss_hit_rarity_weights: Array[float] = [40.0, 40.0, 17.0, 3.0]
## Chance (0-1) of a regular enemy dropping an item
@export var normal_drop_chance: float = 0.075
## Chance (0-1) of an elite dropping an item
@export var elite_drop_chance: float = 0.25

@export_group("Improvement per graveyard")
## Weight growth per completed graveyard (0.15 = +15% of the base weight per graveyard)
@export var cemetery_rarity_growth: Array[float] = [0.0, 0.15, 0.3, 0.4]
## Drop chance added per completed graveyard
@export var normal_drop_chance_per_cemetery: float = 0.005
@export var elite_drop_chance_per_cemetery: float = 0.02

@export_group("Improvement per loop (aggressive)")
## Extra weight multiplier per completed loop (1.0 = doubles the weight each loop)
@export var loop_rarity_growth: Array[float] = [0.0, 0.5, 1.0, 1.5]
## Extra drop chance multiplier per completed loop
@export var loop_drop_chance_growth: float = 0.25
## Drop chance caps
@export var normal_drop_chance_cap: float = 0.2
@export var elite_drop_chance_cap: float = 0.6

## Extra "completed graveyards" granted by other modes (Monster Survivors: player level)
var progress_bonus: int = 0

@export_group("Bad luck protection")
## Each enemy kill without a drop adds this much to the next drop chance (0.004 = +0.4%)
@export var normal_pity_chance_step: float = 0.004
@export var elite_pity_chance_step: float = 0.06
## Consecutive kills without a drop after which the next one always drops an item
@export var normal_pity_guarantee: int = 30
@export var elite_pity_guarantee: int = 5
## Consecutive Basic enemy drops after which the next drop cannot be Basic
@export var basic_streak_limit: int = 3

## Graveyards per loop (updated by the cemetery_changed signal)
var cemeteries_per_loop: int = 5

# Enemy kills in a row without a drop, per source (Source -> int)
var _misses: Dictionary = {}
# Enemy drops in a row that were Basic
var _basic_streak: int = 0
# Items per rarity: Rarity -> Array[ItemData]
var _items_by_rarity: Dictionary = {}
# Boss legendary not yet picked up: reappears at the spawn of the next loop
var _unclaimed_boss_item: ItemData = null


func _ready() -> void:
	_load_items()
	EventBus.item_drop_requested.connect(_on_item_drop_requested)
	EventBus.cemetery_changed.connect(_on_cemetery_changed)
	EventBus.item_collected.connect(_on_item_collected)


## Graveyards completed in the whole run (the current loop counts the ones before it).
func cemeteries_completed() -> int:
	return GameManager.loop_index * cemeteries_per_loop + maxi(GameManager.cemetery_index - 1, 0) + progress_bonus


## Rarity weights already improved by the run's progress.
func rarity_weights(source: Source) -> Array[float]:
	var base: Array[float] = _base_weights(source)
	var done: int = cemeteries_completed()
	var loops: int = GameManager.loop_index
	var out: Array[float] = []
	for i: int in base.size():
		var growth: float = 1.0 + _at(cemetery_rarity_growth, i) * done
		var loop_growth: float = 1.0 + _at(loop_rarity_growth, i) * loops
		out.append(maxf(base[i] * growth * loop_growth, 0.0))
	return out


## Chance (0-1) of an enemy dropping something; rooms always drop.
func drop_chance(source: Source) -> float:
	var done: int = cemeteries_completed()
	var loop_mult: float = 1.0 + loop_drop_chance_growth * GameManager.loop_index
	match source:
		Source.NORMAL_ENEMY:
			return minf((normal_drop_chance + normal_drop_chance_per_cemetery * done) * loop_mult * _butcher_mult(), normal_drop_chance_cap)
		Source.ELITE_ENEMY:
			return minf((elite_drop_chance + elite_drop_chance_per_cemetery * done) * loop_mult * _butcher_mult(), elite_drop_chance_cap)
	return 1.0


## Rolls an item for the source (null = no drop). Does not drop it on the ground.
func roll_item(source: Source) -> ItemData:
	var pity: bool = _is_enemy_source(source)
	if randf() >= _effective_chance(source):
		if pity:
			_misses[source] = int(_misses.get(source, 0)) + 1
			print("[Loot] - %s: %d kills without a drop" % [Source.keys()[source], _misses[source]])
		return null
	var rarity: ItemEnums.Rarity = ItemEnums.Rarity.LEGENDARY
	if source != Source.BOSS_REWARD:
		var weights: Array[float] = rarity_weights(source)
		# Too many Basic drops in a row: the next one is at least Intermediate
		if pity and _basic_streak >= basic_streak_limit and weights.size() > 1:
			weights[ItemEnums.Rarity.BASIC] = 0.0
		rarity = _roll_rarity(weights)
		if pity:
			_basic_streak = _basic_streak + 1 if rarity == ItemEnums.Rarity.BASIC else 0
	if pity:
		_misses[source] = 0
	return _roll_from_rarity(rarity)


## Forgets the bad luck counters (new run).
func reset_pity() -> void:
	_misses.clear()
	_basic_streak = 0


# Drop chance with the bad luck protection: grows with every miss and is 100% after the guarantee
func _effective_chance(source: Source) -> float:
	var chance: float = drop_chance(source)
	if not _is_enemy_source(source):
		return chance
	var misses: int = int(_misses.get(source, 0))
	var guarantee: int = normal_pity_guarantee if source == Source.NORMAL_ENEMY else elite_pity_guarantee
	if misses >= guarantee:
		return 1.0
	var step: float = normal_pity_chance_step if source == Source.NORMAL_ENEMY else elite_pity_chance_step
	return minf(chance + step * misses, 1.0)


func _is_enemy_source(source: Source) -> bool:
	return source == Source.NORMAL_ENEMY or source == Source.ELITE_ENEMY


## Rolls and drops the item on the ground. Returns the item (null = no drop).
func drop_item(source: Source, world_position: Vector2) -> ItemData:
	var item: ItemData = roll_item(source)
	if item == null:
		return null
	ItemManager.drop_to_ground(item, world_position)
	if source == Source.BOSS_REWARD:
		_unclaimed_boss_item = item
	print("[Loot] - %s dropped %s (%s)" % [Source.keys()[source], item.id, ItemEnums.Rarity.keys()[item.rarity]])
	return item


## Boss legendary that was left behind (infinite mode clears the ground); returned only once.
func take_unclaimed_boss_item() -> ItemData:
	# Only exists within the same run, at the start of a new loop
	if GameManager.loop_index <= 0:
		_unclaimed_boss_item = null
		return null
	var item: ItemData = _unclaimed_boss_item
	_unclaimed_boss_item = null
	return item


# Weighted rarity roll; the weight index is the value of the Rarity enum
func _roll_rarity(weights: Array[float]) -> ItemEnums.Rarity:
	var total: float = 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		return ItemEnums.Rarity.BASIC
	var pick: float = randf() * total
	for i: int in weights.size():
		pick -= weights[i]
		if pick < 0.0:
			return i as ItemEnums.Rarity
	return (weights.size() - 1) as ItemEnums.Rarity


# Item of the rarity, preferring ones the player does not have yet; with no items in it, drops down a rarity
func _roll_from_rarity(rarity: ItemEnums.Rarity) -> ItemData:
	for r: int in range(rarity, -1, -1):
		var pool: Array = _items_by_rarity.get(r, [])
		if pool.is_empty():
			continue
		if r != rarity:
			push_warning("[Loot] - no %s items, falling back to %s" % [ItemEnums.Rarity.keys()[rarity], ItemEnums.Rarity.keys()[r]])
		var fresh: Array = pool.filter(func(item: ItemData) -> bool: return not _is_owned(item))
		return (fresh if not fresh.is_empty() else pool).pick_random()
	return null


# Unethical Butcher (active potion): multiplier on the enemies' drop chance
func _butcher_mult() -> float:
	var potion: PotionData = ItemManager.get_active_potion()
	if potion != null and potion.special_synergies.has(SpecialSynergies.BUTCHER):
		return SynergyConstants.BUTCHER_DROP_CHANCE_MULT
	return 1.0


func _base_weights(source: Source) -> Array[float]:
	match source:
		Source.NORMAL_ENEMY:
			return normal_rarity_weights
		Source.ELITE_ENEMY:
			return elite_rarity_weights
		Source.BOSS_HIT:
			return boss_hit_rarity_weights
	return room_rarity_weights


func _at(values: Array[float], index: int) -> float:
	return values[index] if index < values.size() else 0.0


# Already owned, on the ground or waiting on the inventory screen
func _is_owned(item: ItemData) -> bool:
	for owned: ItemData in ItemManager.owned_items:
		if owned.id == item.id:
			return true
	for entry: Dictionary in ItemManager.ground_entries:
		if (entry["item"] as ItemData).id == item.id:
			return true
	for pending: ItemData in ItemManager.pending_items:
		if pending.id == item.id:
			return true
	return false


func _load_items() -> void:
	var dir: DirAccess = DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_warning("[Loot] - items folder not found: %s" % ITEMS_DIR)
		return
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file: String in files:
		# On export, files may have a .remap suffix
		var clean: String = file.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var item: ItemData = load(ITEMS_DIR + clean) as ItemData
		if item == null:
			continue
		if not _items_by_rarity.has(item.rarity):
			_items_by_rarity[item.rarity] = []
		_items_by_rarity[item.rarity].append(item)
	for r: int in _items_by_rarity.keys():
		print("[Loot] - %d items %s" % [_items_by_rarity[r].size(), ItemEnums.Rarity.keys()[r]])


func _on_item_drop_requested(source: int, world_position: Vector2) -> void:
	drop_item(source as Source, world_position)


func _on_cemetery_changed(_index: int, total: int) -> void:
	cemeteries_per_loop = maxi(total, 1)


func _on_item_collected(item_id: StringName, _position: Vector2) -> void:
	if _unclaimed_boss_item != null and _unclaimed_boss_item.id == item_id:
		_unclaimed_boss_item = null
