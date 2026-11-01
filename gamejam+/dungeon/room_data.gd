class_name RoomData
extends RefCounted
## Data of a graveyard room: type, grid position, size, world rectangle and doors.

# Types (drawing colors): SPAWN cyan, CAULDRON orange, ITEM yellow, EXIT purple, BOSS (exit of the last graveyard),
# ELITE blue, HORDE red, EMPTY white (passage with no enemies)
enum Type { SPAWN, CAULDRON, ITEM, EXIT, BOSS, ELITE, HORDE, EMPTY }

# Size of each type in tiles (even values, so room centers align on the grid)
const SIZES: Dictionary = {
	Type.SPAWN: Vector2i(24, 16),
	Type.CAULDRON: Vector2i(36, 22),
	Type.ITEM: Vector2i(24, 16),
	Type.EXIT: Vector2i(24, 16),
	Type.BOSS: Vector2i(48, 30),
	Type.ELITE: Vector2i(40, 24),
	Type.HORDE: Vector2i(44, 26),
	Type.EMPTY: Vector2i(28, 18),
}

# Debug color of each type (same palette as the level drawing)
const DEBUG_COLORS: Dictionary = {
	Type.SPAWN: Color(0.0, 1.0, 1.0),
	Type.CAULDRON: Color(1.0, 0.5, 0.0),
	Type.ITEM: Color(1.0, 1.0, 0.0),
	Type.EXIT: Color(1.0, 0.0, 1.0),
	Type.BOSS: Color(0.5, 0.0, 0.0),
	Type.ELITE: Color(0.0, 0.0, 1.0),
	Type.HORDE: Color(1.0, 0.0, 0.0),
	Type.EMPTY: Color(1.0, 1.0, 1.0),
}

## Door on a top or bottom wall. "offset" is the x relative to the room center (px):
## neighbors above/below use the center; side neighbors use a shifted gap on the bottom wall
## (the corridor leaves from below, loops around and enters through the bottom wall of the other room).
class Door extends RefCounted:
	var side: Vector2i = Vector2i.DOWN
	var offset: float = 0.0
	var neighbor: int = -1
	var blocker: StaticBody2D = null
	# Door arch (open/closed)
	var arch: Prop = null

# Distance (px) of the side gaps to the center of the bottom wall
const SIDE_DOOR_OFFSET: float = 96.0

var type: Type = Type.EMPTY
var cell: Vector2i = Vector2i.ZERO
var size_tiles: Vector2i = Vector2i.ZERO
# Room floor rectangle in world px
var rect: Rect2 = Rect2()
# Grid direction (Vector2i) -> neighbor room index
var neighbors: Dictionary = {}
# Room doors: all on the top or bottom wall
var doors: Array[Door] = []
var visited: bool = false
var cleared: bool = false


func _init(new_cell: Vector2i) -> void:
	cell = new_cell


## Sets the type and the matching size.
func set_type(new_type: Type) -> void:
	type = new_type
	size_tiles = SIZES[new_type]


## Closes or opens the room doors: collision blocker and arch gate.
func set_doors_closed(closed: bool) -> void:
	for door: Door in doors:
		if door.blocker != null:
			door.blocker.collision_layer = PhysicsLayers.WORLD if closed else 0
		if door.arch != null:
			door.arch.kind = Prop.Kind.ARCH_GATE if closed else Prop.Kind.ARCH_OPEN


## Returns true if the room has a single connection (dead end).
func is_leaf() -> bool:
	return neighbors.size() == 1


## Creates the doors from the neighbors: above/below at the center; sides shifted on the bottom wall.
func make_doors() -> void:
	doors.clear()
	for dir: Vector2i in neighbors.keys():
		var door: Door = Door.new()
		door.neighbor = neighbors[dir]
		if dir == Vector2i.UP or dir == Vector2i.DOWN:
			door.side = dir
		else:
			door.side = Vector2i.DOWN
			door.offset = SIDE_DOOR_OFFSET * float(dir.x)
		doors.append(door)


## Door leading to room "neighbor_index" (null if it does not exist).
func door_to(neighbor_index: int) -> Door:
	for door: Door in doors:
		if door.neighbor == neighbor_index:
			return door
	return null


## Computes the world rectangle: the room is centered in its grid cell.
@warning_ignore("integer_division")
func place(pitch_tiles: Vector2i, tile_px: int) -> void:
	var origin: Vector2i = cell * pitch_tiles + (pitch_tiles - size_tiles) / 2
	rect = Rect2(Vector2(origin * tile_px), Vector2(size_tiles * tile_px))


## Center of the room floor.
func center() -> Vector2:
	return rect.get_center()
