extends Node2D
## Monster Survivors: graveyard arena with waves of enemies (see WaveManager). Every enemy drops a red XP orb;
## each level shrinks the items (more room in the bag and cauldron), adds damage and health
## and improves the item drops. Enemy difficulty comes from the waves, not from the level.

const XP_ORB_SCENE: GDScript = preload("res://survivors/xp_orb.gd")

## XP needed for level 2; each following level needs "xp_growth" more
@export var base_xp_to_level: int = 5
@export var xp_growth: int = 4
## XP value of the orbs (basic enemy / elite and boss)
@export var basic_orb_xp: int = 1
@export var elite_orb_xp: int = 5
## Item shrink per level (1.08 = items 8% smaller)
@export var bag_shrink_per_level: float = 1.08
## Levels needed for each "completed graveyard" granted to the loot tables
@export var levels_per_loot_step: int = 2

var level: int = 1
var xp: int = 0

@onready var _player: Node2D = $Player
@onready var _cauldron: Cauldron = $Cauldron


func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.xp_collected.connect(_on_xp_collected)
	var waves: WaveManager = WaveManager.new()
	waves.name = "WaveManager"
	waves.level = self
	add_child(waves)
	# Deferred so the HUD (which comes later in the tree) is already connected
	_emit_xp.call_deferred()
	print("[Survivors] - mode started")


# Resets the loot bonus so it does not leak into the normal game
func _exit_tree() -> void:
	LootManager.progress_bonus = 0


## XP needed to leave the given level.
func xp_needed(for_level: int) -> int:
	return base_xp_to_level + xp_growth * (for_level - 1)


# Every enemy leaves a red orb where it died
func _on_enemy_died(position: Vector2, _was_marked: bool, is_basic: bool) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	var orb: Node2D = Node2D.new()
	orb.set_script(XP_ORB_SCENE)
	orb.set("value", basic_orb_xp if is_basic else elite_orb_xp)
	orb.position = position
	add_child.call_deferred(orb)


func _on_xp_collected(amount: int) -> void:
	xp += amount
	var leveled: bool = false
	while xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
		leveled = true
		_apply_level_up()
	_emit_xp()
	if leveled:
		_announce_level_up()


# Shrinks the items (bag, cauldron and future ones), improves the loot and raises the difficulty
func _apply_level_up() -> void:
	var ratio: float = ItemManager.optimize_bag(bag_shrink_per_level)
	if _cauldron != null:
		for entry: Dictionary in _cauldron.state.entries:
			entry["scale"] = float(entry["scale"]) * ratio
	LootManager.progress_bonus = floori(float(level - 1) / float(levels_per_loot_step))
	EventBus.player_leveled_up.emit(level)
	print("[Survivors] - level %d" % level)


func _announce_level_up() -> void:
	EventBus.play_sfx_requested.emit("ui_click")
	FloatingText.spawn(self, _player.global_position + Vector2(0.0, -46.0), tr("Magic bag space optimized!"), Color(1.0, 0.85, 0.4), 10, 1.8, 18.0)


func _emit_xp() -> void:
	EventBus.xp_changed.emit(level, xp, xp_needed(level))
