class_name DungeonLevel
extends Node2D
## A graveyard (dungeon floor): generates the room graph, builds the continuous map and runs the rooms.
## The current graveyard comes from GameManager.cemetery_index; the last one ends in the boss room.

# Margin between the room edge and the area that counts as "inside" (the player's feet must enter)
const ROOM_TRIGGER_INSET: float = 40.0
# [DEBUG] Distance (px) from the player to the boss door, on the outside, in the debug shortcut
const DEBUG_BOSS_DOOR_DISTANCE: float = 48.0
# Boss arena cauldron: distance (px) from the left wall and from the far wall
const BOSS_CAULDRON_MARGIN: Vector2 = Vector2(96.0, 96.0)

@export_group("Graveyards")
## Number of rooms in each graveyard (the array size is the number of graveyards)
@export var rooms_per_cemetery: Array[int] = [6, 7, 8, 9, 10]
## Fixed seed for debugging (0 = random every run)
@export var fixed_seed: int = 0

@export_group("Mapa")
## Grid cell in tiles (largest room + corridor fit in it)
@export var cell_pitch_tiles: Vector2i = Vector2i(54, 38)
## Width of the corridor and doors: 4 tiles = 64 px, the width of the tileset arch
@export var corridor_width_tiles: int = 4
## Multiplier for the amount of decorative props
@export var prop_density: float = 1.0
## Width (in tiles) of the woods with grass, trees and bushes around the fences
@export var exterior_margin_tiles: int = 12
## Multiplier for the amount of woods props (0 = no props)
@export var exterior_density: float = 1.0
## Pumpkins inside the rooms may become mimics (chance per pumpkin, at least min_mimics per graveyard)
@export var pumpkin_mimic_scene: PackedScene = preload("res://enemies/pumpkin_mimic.tscn")
@export_range(0.0, 1.0) var pumpkin_mimic_chance: float = 0.10
@export var min_pumpkin_mimics: int = 1
@export var void_color: Color = Color.BLACK

@export_group("Salas extras")
## Roll weights for rooms besides spawn/cauldron/item/exit
@export var elite_room_weight: float = 1.0
@export var horde_room_weight: float = 1.0
@export var empty_room_weight: float = 0.0

@export_group("Inimigos")
@export var swarm_scenes: Array[PackedScene] = []
## Elites rolled in elite and cauldron rooms (empty = uses elite_scene)
@export var elite_scenes: Array[PackedScene] = []
## Generic elite (enlarged and tinted placeholder; also the boss placeholder)
@export var elite_scene: PackedScene
@export var cauldron_scene: PackedScene
@export var cauldron_swarm_count: int = 8
@export var elite_room_count: int = 3
@export var horde_enemy_count: int = 18
@export var horde_time_limit: float = 30.0
@export var elite_health_multiplier: float = 6.0
@export var elite_scale: float = 1.5
@export var elite_tint: Color = Color(0.6, 0.7, 1.0)
@export var spawn_attempts: int = 12
@export var min_spawn_distance: float = 140.0

@export_group("Boss")
## Boss scene (empty = placeholder: uses the enlarged and tinted elite_scene)
@export var boss_scene: PackedScene
@export var boss_health_multiplier: float = 100.0
@export var boss_scale: float = 2.6
@export var boss_tint: Color = Color(1.0, 0.45, 0.45)
@export var boss_move_speed_multiplier: float = 0.8
@export var boss_points: int = 500

@export_group("Modo infinito")
## Extra enemy health per completed loop (0.6 = +60% per lap)
@export var loop_health_scaling: float = 0.6
## Extra contact damage per loop (rounded; 0.5 = +1 every 2 loops with base damage 1)
@export var loop_damage_scaling: float = 0.5
## Extra speed per loop, capped by loop_max_speed_multiplier
@export var loop_speed_scaling: float = 0.08
@export var loop_max_speed_multiplier: float = 1.6
## Extra enemy count per loop in swarm/horde/elite rooms
@export var loop_count_scaling: float = 0.25
## Extra points per enemy per loop
@export var loop_points_scaling: float = 0.5

@export_group("Exit")
@export var portal_radius: float = 20.0

@export_group("Debug")
# [DEBUG] Paints each room with the color of its type (only for discussing the layout)
@export var debug_room_colors: bool = false
# [DEBUG] Starts directly in the last graveyard, at the boss room door (debug builds only)
@export var debug_start_at_boss: bool = false
# [DEBUG] Key that skips to the boss fight during a run, together with Shift (debug builds only).
# Do not use F9/F10: with the game embedded in the editor, Godot uses those keys to suspend/advance the project.
@export var debug_boss_key: Key = KEY_B

var enemy_root: Node2D
var rooms: Array[RoomData] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _encounters: Array[RoomEncounter] = []
var _player: Node2D
var _current_room: int = -1
var _portal_position: Vector2 = Vector2.INF
var _leaving: bool = false
var _previous_clear_color: Color


func _ready() -> void:
	print("[Dungeon] - [DEBUG] level ready (debug build: %s, start at boss: %s)" % [OS.is_debug_build(), debug_start_at_boss])
	_previous_clear_color = RenderingServer.get_default_clear_color()
	RenderingServer.set_default_clear_color(void_color)
	enemy_root = $Enemies as Node2D
	var damage_numbers: DamageNumbers = DamageNumbers.new()
	damage_numbers.name = "DamageNumbers"
	add_child(damage_numbers)
	_player = $Player as Node2D

	var total: int = rooms_per_cemetery.size()
	# [DEBUG] Boss fight shortcut: skips to the last graveyard
	var jump_to_boss: bool = OS.is_debug_build() and (debug_start_at_boss or GameManager.debug_boss_requested)
	GameManager.debug_boss_requested = false
	if jump_to_boss:
		GameManager.cemetery_index = total
	var index: int = clampi(GameManager.cemetery_index, 1, total)
	var is_final: bool = index == total
	_rng.seed = fixed_seed if fixed_seed != 0 else GameManager.run_seed + index
	var weights: Dictionary = {
		RoomData.Type.ELITE: elite_room_weight,
		RoomData.Type.HORDE: horde_room_weight,
		RoomData.Type.EMPTY: empty_room_weight,
	}
	rooms = DungeonGenerator.generate(rooms_per_cemetery[index - 1], is_final, weights, cell_pitch_tiles, DungeonBuilder.TILE, _rng)
	DungeonBuilder.new().build(self, rooms, corridor_width_tiles, prop_density, exterior_margin_tiles, exterior_density, _rng)
	_spawn_pumpkin_mimics()
	_populate_rooms()
	if jump_to_boss:
		_debug_place_at_boss()
	var minimap: Minimap = get_node_or_null("Minimap") as Minimap
	if minimap != null:
		minimap.setup(rooms, _player)
	if debug_room_colors:
		_paint_debug_colors()
	_print_layout(index, total)
	EventBus.cemetery_changed.emit(index, total)


func _exit_tree() -> void:
	RenderingServer.set_default_clear_color(_previous_clear_color)


# [DEBUG] Shortcut key: reloads the level already in the last graveyard, at the boss door.
func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() or _leaving:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or not key.shift_pressed:
		return
	if key.keycode != debug_boss_key and key.physical_keycode != debug_boss_key:
		return
	print("[Dungeon] - [DEBUG] boss shortcut pressed")
	get_viewport().set_input_as_handled()
	_leaving = true
	GameManager.debug_go_to_boss()


# [DEBUG] Puts the player in the corridor, just outside the boss room door (they walk in).
func _debug_place_at_boss() -> void:
	for room: RoomData in rooms:
		if room.type != RoomData.Type.BOSS or room.doors.is_empty():
			continue
		var door: RoomData.Door = room.doors[0]
		var edge_y: float = room.rect.end.y if door.side == Vector2i.DOWN else room.rect.position.y
		_player.global_position = Vector2(room.center().x + door.offset, edge_y + float(door.side.y) * DEBUG_BOSS_DOOR_DISTANCE)
		print("[Dungeon] - [DEBUG] player taken to the boss door")
		return
	print("[Dungeon] - [DEBUG] boss room not found")


func _physics_process(_delta: float) -> void:
	if _player == null or _leaving:
		return
	var feet: Vector2 = _player.global_position
	var found: int = -1
	for i: int in rooms.size():
		if rooms[i].rect.grow(-ROOM_TRIGGER_INSET).has_point(feet):
			found = i
			break
	if found != -1 and found != _current_room:
		_current_room = found
		GameManager.advance_room()
		_encounters[found].on_player_entered()
	if _portal_position != Vector2.INF and feet.distance_to(_portal_position) <= portal_radius:
		_leaving = true
		print("[Dungeon] - graveyard exit %d" % GameManager.cemetery_index)
		GameManager.advance_cemetery()


## Enemy health multiplier in the current infinite mode loop.
func loop_health_multiplier() -> float:
	return 1.0 + loop_health_scaling * GameManager.loop_index


## Enemy contact damage multiplier in the current loop.
func loop_damage_multiplier() -> float:
	return 1.0 + loop_damage_scaling * GameManager.loop_index


## Enemy speed multiplier in the current loop (capped).
func loop_speed_multiplier() -> float:
	return minf(1.0 + loop_speed_scaling * GameManager.loop_index, loop_max_speed_multiplier)


## Enemy count scaled by the current loop (never less than the base).
func loop_count(base: int) -> int:
	return maxi(base, roundi(base * (1.0 + loop_count_scaling * GameManager.loop_index)))


## Points-per-enemy multiplier in the current loop.
func loop_points_multiplier() -> float:
	return 1.0 + loop_points_scaling * GameManager.loop_index


# Swaps some pumpkins inside the rooms (not in the woods, where the player cannot reach) for mimics.
func _spawn_pumpkin_mimics() -> void:
	var props_root: Node2D = get_node_or_null("Props") as Node2D
	if props_root == null:
		return
	var pumpkins: Array[Prop] = []
	for child: Node in props_root.get_children():
		var prop: Prop = child as Prop
		if prop == null or prop.kind not in PumpkinMimicSpawner.PUMPKIN_KINDS:
			continue
		for room: RoomData in rooms:
			if room.rect.has_point(prop.position):
				pumpkins.append(prop)
				break
	var spawner: PumpkinMimicSpawner = PumpkinMimicSpawner.new()
	spawner.props_root = props_root
	spawner.mimic_scene = pumpkin_mimic_scene
	spawner.mimic_chance = pumpkin_mimic_chance
	spawner.min_mimics = min_pumpkin_mimics
	spawner.swap_pumpkins(pumpkins)
	spawner.free()


# Places the player, the cauldron, the item and the portal; creates each room's encounter.
func _populate_rooms() -> void:
	for room: RoomData in rooms:
		var encounter: RoomEncounter = RoomEncounter.new()
		encounter.name = "Encounter_%s" % RoomData.Type.keys()[room.type]
		encounter.setup(room, self)
		add_child(encounter)
		_encounters.append(encounter)
		match room.type:
			RoomData.Type.SPAWN:
				_player.global_position = room.center()
				_drop_boss_carryover(room)
			RoomData.Type.CAULDRON:
				var cauldron: Node2D = cauldron_scene.instantiate() as Node2D
				cauldron.position = room.center()
				add_child(cauldron)
			RoomData.Type.BOSS:
				_place_boss_cauldron(room)
			RoomData.Type.ITEM:
				_drop_room_item(room)
			RoomData.Type.EXIT:
				_build_portal(room)


# Boss arena: cauldron in a corner on the side opposite the door, so the player can brew during the fight.
func _place_boss_cauldron(room: RoomData) -> void:
	if cauldron_scene == null:
		return
	var from_door_up: bool = not room.doors.is_empty() and room.doors[0].side == Vector2i.UP
	var y: float = room.rect.end.y - BOSS_CAULDRON_MARGIN.y if from_door_up else room.rect.position.y + BOSS_CAULDRON_MARGIN.y + 32.0
	var cauldron: Node2D = cauldron_scene.instantiate() as Node2D
	cauldron.position = Vector2(room.rect.position.x + BOSS_CAULDRON_MARGIN.x, y)
	add_child(cauldron)
	print("[Dungeon] - cauldron placed in the boss arena")


# Item room: rarity roll + item from the LootManager, at the center of the room.
func _drop_room_item(room: RoomData) -> void:
	if LootManager.drop_item(LootManager.Source.ITEM_ROOM, room.center()) == null:
		print("[Dungeon] - no items for the item room")


# Boss legendary not picked up in the previous loop (the ground is cleared on the turn): reappears near the spawn.
func _drop_boss_carryover(room: RoomData) -> void:
	var item: ItemData = LootManager.take_unclaimed_boss_item()
	if item == null:
		return
	ItemManager.drop_to_ground(item, room.center() + Vector2(0.0, -48.0))
	print("[Dungeon] - boss legendary brought to the spawn: %s" % item.id)


# Purple portal at the center of the exit room (placeholder until the sprite exists).
func _build_portal(room: RoomData) -> void:
	_portal_position = room.center()
	var portal: Polygon2D = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 24:
		var a: float = TAU * float(i) / 24.0
		points.append(Vector2(cos(a) * portal_radius, sin(a) * portal_radius * 0.6))
	portal.polygon = points
	portal.color = RoomData.DEBUG_COLORS[RoomData.Type.EXIT]
	portal.position = _portal_position
	portal.z_index = -8
	add_child(portal)


# [DEBUG] Semi-transparent rectangle in the color of each room's type.
func _paint_debug_colors() -> void:
	for room: RoomData in rooms:
		var overlay: Polygon2D = Polygon2D.new()
		var r: Rect2 = room.rect
		overlay.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		overlay.color = Color(RoomData.DEBUG_COLORS[room.type], 0.28)
		overlay.z_index = -9
		add_child(overlay)


func _print_layout(index: int, total: int) -> void:
	var counts: Dictionary = {}
	for room: RoomData in rooms:
		var key: String = RoomData.Type.keys()[room.type]
		counts[key] = int(counts.get(key, 0)) + 1
	print("[Dungeon] - loop %d, graveyard %d/%d: %d rooms %s" % [GameManager.loop_index + 1, index, total, rooms.size(), counts])
