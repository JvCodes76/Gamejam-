extends Node2D
## Monster Survivors: graveyard arena with waves of enemies (see WaveManager). Every enemy drops a red XP orb;
## each level shrinks the items (more room in the bag and cauldron), adds damage and health
## and improves the item drops. Enemy difficulty comes from the waves, not from the level.
## The arena is closed by the graveyard fence (built at runtime by DungeonBuilder, like the dungeon rooms).

const XP_ORB_SCENE: GDScript = preload("res://survivors/xp_orb.gd")
# Night atmosphere (lights, fog, particles, shadows), behind the "Atmosphere effects" setting
const AMBIENCE_SCENE: PackedScene = preload("res://ambience/ambience_layer.tscn")
# Arches standing up to this distance (px) from the top/bottom fence line become gates of the fence
const ARCH_SNAP_DISTANCE: float = 48.0
# Intro shown at the start of every run (one freezing popup per paragraph, same popup as the tutorial)
const INTRO_MESSAGES: Array[String] = [
	"Welcome to the bonus mode! Here, waves of enemies will come to try to hurt you, so be careful!",
	"Don’t worry though, I’ve given you a few bonuses, such as base lifesteal, extra enemy drops, and every enemy drops xp, granting you levels to increase your bag capacity!",
	"Every three waves, you’ll get time to relax, enjoy the music, and, you know, actually use the ingredients you got to make new potions.",
	"Beware, though! With every fifteenth wave comes a nefarious boss to end your run!\n\nGood luck!",
]
# Seconds before the intro (lets the scene fade-in finish)
const INTRO_DELAY: float = 0.6

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
## Arena floor (world px) closed by the fence. Aligned to the cells of the Ground layer, which sits 8 px lower.
@export var arena_rect: Rect2 = Rect2(-640.0, -344.0, 1280.0, 704.0)

var level: int = 1
var xp: int = 0

@onready var _player: Node2D = $Player
@onready var _cauldron: Cauldron = $Cauldron
@onready var _ground: TileMapLayer = $Ground
@onready var _props: Node2D = $Props


func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.xp_collected.connect(_on_xp_collected)
	_build_fence()
	var waves: WaveManager = WaveManager.new()
	waves.name = "WaveManager"
	waves.level = self
	add_child(waves)
	add_child(AMBIENCE_SCENE.instantiate())
	# Deferred so the HUD (which comes later in the tree) is already connected
	_emit_xp.call_deferred()
	_show_intro()
	print("[Survivors] - mode started")


# The popup pauses the tree, so the first wave's countdown only starts after the intro is closed
func _show_intro() -> void:
	var popup: TutorialPopup = TutorialPopup.new()
	popup.name = "IntroPopup"
	add_child(popup)
	await get_tree().create_timer(INTRO_DELAY, true, false, true).timeout
	for message: String in INTRO_MESSAGES:
		popup.show_message(tr(message))


# Resets the loot bonus so it does not leak into the normal game
func _exit_tree() -> void:
	LootManager.progress_bonus = 0


# Fence and walls around the arena; the arches on the top/bottom edges snap to the fence line and open a gap in it
func _build_fence() -> void:
	var walls: Node2D = Node2D.new()
	walls.name = "Walls"
	add_child(walls)
	var top_base: float = arena_rect.position.y + DungeonBuilder.TOP_WALL_INSET
	var bottom_base: float = arena_rect.end.y + DungeonBuilder.FENCE_BOTTOM_DROP
	var top_gaps: Array[Vector2] = []
	var bottom_gaps: Array[Vector2] = []
	for child: Node in _props.get_children():
		var arch: Prop = child as Prop
		if arch == null or arch.kind not in [Prop.Kind.ARCH_OPEN, Prop.Kind.ARCH_GATE]:
			continue
		var half: float = (Prop.DEFS[arch.kind]["region"] as Rect2).size.x / 2.0
		var gap: Vector2 = Vector2(arch.position.x - half, arch.position.x + half)
		if absf(arch.position.y - top_base) <= ARCH_SNAP_DISTANCE:
			arch.position.y = top_base
			top_gaps.append(gap)
		elif absf(arch.position.y - bottom_base) <= ARCH_SNAP_DISTANCE:
			arch.position.y = bottom_base
			bottom_gaps.append(gap)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	DungeonBuilder.new().build_enclosure(_ground, walls, _props, arena_rect, top_gaps, bottom_gaps, rng)


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
