class_name DungeonBuilder
extends RefCounted
## Builds the continuous map of a graveyard: varied floor (TileMapLayer), fence walls with doors
## (arches) only on the top/bottom walls, straight and U-shaped corridors, props inside and the woods around (exterior).
## Outside the woods the void stays black.

const TILE: int = 16
const TILESET_PATH: String = "res://assets/tilesets/halloween/halloween_tileset.tres"
const TEXTURE_PATH: String = "res://assets/tilesets/halloween/halloween_tileset.png"
const PROP_SCENE: PackedScene = preload("res://levels/props/prop.tscn")

# --- Floor (atlas cells) ---
# Rectangles the blue floor cells come from (same as the tile generator)
const BLUE_SOURCE_RECTS: Array[Rect2i] = [Rect2i(6, 2, 2, 2), Rect2i(2, 4, 3, 1), Rect2i(6, 7, 2, 1), Rect2i(10, 2, 6, 2)]
const LIGHT_DETAIL_MAX_PIXELS: int = 6
const LIGHT_BLUE_CHANCE: float = 0.12
# Plain orange floor cells (used in the exterior)
const ORANGE_PLAIN_CELLS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, 3), Vector2i(1, 3)]
# 2x2 orange floor blocks (atlas origin) and weight, for the middle of the patches
const ORANGE_BLOCKS: Array = [
	[Vector2i(0, 0), 4], [Vector2i(0, 2), 3], [Vector2i(2, 0), 1], [Vector2i(2, 2), 1],
	[Vector2i(4, 0), 1], [Vector2i(4, 2), 1], [Vector2i(16, 0), 1],
]
# Orange patch edges by position in the 3x3 block grid (see tools/generate_tileset.gd)
const PATCH_PIECES: Dictionary = {
	Vector2i(0, 0): Vector2i(14, 8), Vector2i(1, 0): Vector2i(12, 8), Vector2i(2, 0): Vector2i(10, 8),
	Vector2i(0, 1): Vector2i(16, 2), Vector2i(2, 1): Vector2i(8, 2),
	Vector2i(0, 2): Vector2i(14, 0), Vector2i(1, 2): Vector2i(12, 0), Vector2i(2, 2): Vector2i(10, 0),
}
# Blue decals: [atlas origin, size in cells]
const DECALS_SMALL: Array = [[Vector2i(6, 0), Vector2i(2, 2)], [Vector2i(8, 0), Vector2i(2, 2)], [Vector2i(2, 5), Vector2i(2, 1)]]
const DECALS_BIG: Array = [[Vector2i(10, 2), Vector2i(6, 6)], [Vector2i(16, 4), Vector2i(4, 4)]]
# Stone path: center block and end caps (2x1)
const PATH_BLOCK: Vector2i = Vector2i(6, 4)
const PATH_CAP_TOP: Vector2i = Vector2i(6, 3)
const PATH_CAP_BOTTOM: Vector2i = Vector2i(6, 6)

# Floor variety per room (square tiles of area per attempt)
const PATCH_TILES_PER_TRY: float = 260.0
const PATCH_MAX_TRIES: int = 3
const DECAL_TILES_PER_TRY: float = 140.0
const BIG_DECAL_MIN_AREA: float = 760.0

# --- Walls ---
# Wall thickness (outside the floor) and how far the top wall extends inward (one cell: this
# strip of floor turns into grass, since it sits behind the fence)
const WALL_THICKNESS: float = 16.0
const TOP_WALL_INSET: float = 16.0

# Fence pieces of the tileset (px in the atlas). The straight ones (bars + stone base) and the side ones repeat every 32 px.
# The origin of each piece is at the base, so the y-sort orders by the ground.
const FENCE_H_TOP: Rect2 = Rect2(32, 162, 32, 30)
const FENCE_H_BOTTOM: Rect2 = Rect2(32, 290, 32, 30)
const FENCE_V_LEFT: Rect2 = Rect2(1, 224, 7, 32)
const FENCE_V_RIGHT: Rect2 = Rect2(89, 224, 7, 32)
const FENCE_STEP: float = 32.0
# Corners: atlas region and its point (px of the region) that fits the end of the straight fence
const CORNER_TL: Rect2 = Rect2(0, 162, 32, 43)
const CORNER_TL_JOIN: Vector2 = Vector2(32, 30)
const CORNER_TR: Rect2 = Rect2(64, 162, 32, 43)
const CORNER_TR_JOIN: Vector2 = Vector2(0, 30)
const CORNER_BL: Rect2 = Rect2(0, 272, 32, 48)
const CORNER_BL_JOIN: Vector2 = Vector2(32, 48)
const CORNER_BR: Rect2 = Rect2(64, 272, 32, 48)
const CORNER_BR_JOIN: Vector2 = Vector2(0, 48)
# The top corner goes 13 px below the base of the straight fence; the bottom one goes 48 px above it
const CORNER_TOP_DROP: float = 13.0
const CORNER_BOTTOM_RISE: float = 48.0
# Width (in px) the corner occupies inside the room, measured from the left / right edge
const CORNER_LEFT_REACH: float = 24.0
const CORNER_RIGHT_REACH: float = 25.0
# The base of the bottom fence sits at the floor edge: the stone face (13 px) takes up the end of the floor,
# and the bottom wall collision starts at its top
const FENCE_BOTTOM_DROP: float = 0.0
const BOTTOM_WALL_INSET: float = 13.0
# Strip (width, height in px) of blue floor that covers the grass just above the tip of the diagonal of the bottom corners
const CORNER_GAP_STRIP: Vector2 = Vector2(8, 4)

# U-shaped corridor (side-by-side rooms): the horizontal strip sits this many px below the center of the rooms
const U_BAND_DEPTH: float = 224.0
# Minimum clearance between the bottom wall of the tallest room (e.g. boss) and the top of the U strip
const U_BAND_MIN_DROP: float = 64.0

# --- Props inside the graveyard ---
const PROP_WEIGHTS: Dictionary = {
	Prop.Kind.GRAVE_CROSS: 4.0, Prop.Kind.GRAVE_ROUND: 4.0, Prop.Kind.GRAVE_BROKEN: 3.0, Prop.Kind.DIRT_MOUND: 2.0,
	Prop.Kind.CANDLES: 2.0, Prop.Kind.PUMPKIN_PLAIN: 5.0, Prop.Kind.PUMPKIN_SMILE: 4.0, Prop.Kind.PUMPKIN_GRIN: 4.0,
	Prop.Kind.BUSH_A: 2.0, Prop.Kind.BUSH_B: 2.0, Prop.Kind.LEAVES_A: 2.0, Prop.Kind.LEAVES_B: 2.0,
	Prop.Kind.HOLLOW_TREE_A: 1.0, Prop.Kind.HOLLOW_TREE_B: 1.0, Prop.Kind.LAMP_POST: 1.0, Prop.Kind.BENCH: 1.0,
}
# One prop every N tiles of room area
const TILES_PER_PROP: float = 28.0
const PROP_EDGE_MARGIN: float = 20.0
const PROP_TOP_MARGIN: float = 64.0
const PROP_CENTER_CLEAR: float = 72.0
const PROP_ATTEMPTS: int = 6

# --- Exterior (woods around the fences) ---
const EXTERIOR_WEIGHTS: Dictionary = {
	Prop.Kind.HOLLOW_TREE_A: 6.0, Prop.Kind.HOLLOW_TREE_B: 6.0, Prop.Kind.BUSH_A: 3.0, Prop.Kind.BUSH_B: 3.0,
	Prop.Kind.LEAVES_A: 2.0, Prop.Kind.LEAVES_B: 2.0, Prop.Kind.PUMPKIN_PLAIN: 1.0, Prop.Kind.PUMPKIN_GRIN: 0.5,
	Prop.Kind.LAMP_POST: 0.5,
}
# Minimum distance (tiles) from the fences to the first exterior prop
const EXTERIOR_CLEAR_TILES: int = 3
# Step (tiles) of the exterior prop roll grid and the chance of each point becoming a prop
const EXTERIOR_STEP_TILES: int = 4
const EXTERIOR_CHANCE: float = 0.6
# Holes/notches of void in the woods narrower than 2x this (tiles) become grass
const EXTERIOR_GAP_FILL_TILES: int = 10

var corridor_width: float = 64.0

var _rng: RandomNumberGenerator
var _image: Image
var _ground: TileMapLayer
var _plain_blue: Array[Vector2i] = []
var _light_blue: Array[Vector2i] = []
# Floor cells (rooms and corridors), cells with floor decoration and exterior cells
var _floor: Dictionary = {}
var _claimed: Dictionary = {}
var _exterior: Dictionary = {}


## Builds everything inside "root" (Ground, Walls and Props nodes with y-sort).
func build(root: Node2D, rooms: Array[RoomData], corridor_width_tiles: int, density: float, exterior_margin_tiles: int, exterior_density: float, rng: RandomNumberGenerator) -> void:
	_rng = rng
	corridor_width = float(corridor_width_tiles * TILE)
	_image = (load(TEXTURE_PATH) as Texture2D).get_image()
	_collect_blue_cells()

	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.tile_set = load(TILESET_PATH)
	_ground.z_index = -10
	_ground.collision_enabled = false
	root.add_child(_ground)

	var walls: Node2D = Node2D.new()
	walls.name = "Walls"
	root.add_child(walls)

	var props: Node2D = Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	root.add_child(props)

	# Corridors: once per pair of rooms
	var corridors: Array[Rect2] = []
	var straight: Array[Rect2] = []
	for index: int in rooms.size():
		for door: RoomData.Door in rooms[index].doors:
			if index < door.neighbor:
				var other: RoomData = rooms[door.neighbor]
				var pieces: Array[Rect2] = _corridor_rects(rooms[index], other, door, other.door_to(index))
				corridors.append_array(pieces)
				if pieces.size() == 1:
					straight.append(pieces[0])
	for room: RoomData in rooms:
		_mark_floor(room.rect)
	for rect: Rect2 in corridors:
		_mark_floor(rect)

	_paint_exterior(rooms, corridors, exterior_margin_tiles)
	for room: RoomData in rooms:
		_fill(room.rect)
	for rect: Rect2 in corridors:
		_fill(rect)

	for room: RoomData in rooms:
		_paint_behind_top_fence(room)
	for room: RoomData in rooms:
		_build_room_walls(walls, room)
		_build_corner_walls(walls, room)
		_build_room_fences(props, room)
	_build_corridor_edges(walls, props, rooms, corridors)
	for rect: Rect2 in straight:
		_path_v(roundi(rect.get_center().x / TILE) - 1, roundi(rect.position.y / TILE), roundi(rect.end.y / TILE), false, false)
	for room: RoomData in rooms:
		_decorate_floor(room)
		_scatter_props(props, room, density)
	var interior_props: int = props.get_child_count()
	_scatter_exterior(props, rooms, corridors, exterior_density)
	print("[Dungeon] - map built: %d rooms, %d nodes inside, %d in the woods" % [rooms.size(), interior_props, props.get_child_count() - interior_props])


# --- Corridors ---

# Floor rectangles of the corridor between two rooms: straight (top/bottom neighbors) or U-shaped (side by side,
# through the bottom of both).
func _corridor_rects(room: RoomData, other: RoomData, door: RoomData.Door, other_door: RoomData.Door) -> Array[Rect2]:
	var half: float = corridor_width / 2.0
	var x_a: float = room.center().x + door.offset
	var x_b: float = other.center().x + other_door.offset
	var pieces: Array[Rect2] = []
	if door.side == Vector2i.DOWN and other_door.side == Vector2i.UP:
		pieces.append(Rect2(x_a - half, room.rect.end.y, corridor_width, other.rect.position.y - room.rect.end.y))
	elif door.side == Vector2i.UP and other_door.side == Vector2i.DOWN:
		pieces.append(Rect2(x_a - half, other.rect.end.y, corridor_width, room.rect.position.y - other.rect.end.y))
	else:
		# Tall rooms (boss) would touch the strip: it moves down until it has the minimum clearance
		var lowest_wall: float = maxf(room.rect.end.y, other.rect.end.y)
		var band_y: float = maxf(room.center().y + U_BAND_DEPTH, lowest_wall + U_BAND_MIN_DROP + half)
		pieces.append(Rect2(x_a - half, room.rect.end.y, corridor_width, band_y + half - room.rect.end.y))
		pieces.append(Rect2(x_b - half, other.rect.end.y, corridor_width, band_y + half - other.rect.end.y))
		pieces.append(Rect2(minf(x_a, x_b) - half, band_y - half, absf(x_b - x_a) + corridor_width, corridor_width))
	return pieces


# Walls and fences along the corridor edges (by cells): the stretches inside the rooms' wall zone
# are handled by the room walls.
func _build_corridor_edges(walls: Node2D, props: Node2D, rooms: Array[RoomData], corridors: Array[Rect2]) -> void:
	var cells: Dictionary = {}
	var zone_cells: Dictionary = {}
	for rect: Rect2 in corridors:
		for cell: Vector2i in _cells_of(rect):
			var center: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
			var in_zone: bool = false
			for room: RoomData in rooms:
				if room.rect.grow(WALL_THICKNESS).has_point(center):
					in_zone = true
					break
			if in_zone:
				zone_cells[cell] = true
			else:
				cells[cell] = true
	var north: Dictionary = {}
	var south: Dictionary = {}
	var west: Dictionary = {}
	var east: Dictionary = {}
	# Outside the rooms' wall zone: all 4 edges. Inside it (door gap): only the sides,
	# so the corridor fence reaches the arch pillars.
	for cell: Vector2i in cells.keys():
		if not _floor.has(cell + Vector2i.UP):
			_append_edge(north, cell.y, cell.x)
		if not _floor.has(cell + Vector2i.DOWN):
			_append_edge(south, cell.y, cell.x)
	for cell: Vector2i in cells.keys() + zone_cells.keys():
		if not _floor.has(cell + Vector2i.LEFT):
			_append_edge(west, cell.x, cell.y)
		if not _floor.has(cell + Vector2i.RIGHT):
			_append_edge(east, cell.x, cell.y)
	for run: Vector3i in _runs(north):
		var x0: float = float(run.y * TILE)
		var x1: float = float((run.z + 1) * TILE)
		var line_y: float = float(run.x * TILE)
		for x: int in range(run.y, run.z + 1):
			_set_grass(Vector2i(x, run.x))
		_add_wall(walls, Rect2(x0, line_y - WALL_THICKNESS, x1 - x0, WALL_THICKNESS + TOP_WALL_INSET))
		_add_fence_h(props, x0, x1, line_y + TOP_WALL_INSET, FENCE_H_TOP)
	for run: Vector3i in _runs(south):
		var x0: float = float(run.y * TILE)
		var x1: float = float((run.z + 1) * TILE)
		var line_y: float = float((run.x + 1) * TILE)
		var base_y: float = line_y + FENCE_BOTTOM_DROP
		# Convex tips (no floor beside): the diagonal corner takes over the corner
		var left_corner: bool = not _floor.has(Vector2i(run.y - 1, run.x))
		var right_corner: bool = not _floor.has(Vector2i(run.z + 1, run.x))
		if left_corner:
			x0 += CORNER_LEFT_REACH
			_add_fence_sprite(props, CORNER_BL, CORNER_BL_JOIN, Vector2(x0, base_y))
			_set_grass(Vector2i(run.y, run.x))
			_set_grass(Vector2i(run.y + 1, run.x))
			_cover_corner_gap(props, x0, float(run.y * TILE) + TILE * 2.0, line_y)
		if right_corner:
			x1 -= CORNER_RIGHT_REACH
			_add_fence_sprite(props, CORNER_BR, CORNER_BR_JOIN, Vector2(x1, base_y))
			_set_grass(Vector2i(run.z, run.x))
			_set_grass(Vector2i(run.z - 1, run.x))
			_cover_corner_gap(props, x1, float((run.z + 1) * TILE) - TILE * 2.0, line_y)
		_add_wall(walls, Rect2(x0, line_y - BOTTOM_WALL_INSET, x1 - x0, WALL_THICKNESS + BOTTOM_WALL_INSET))
		_add_fence_h(props, x0, x1, base_y, FENCE_H_BOTTOM)
	for run: Vector3i in _runs(west):
		var y0: float = float(run.y * TILE)
		var y1: float = float((run.z + 1) * TILE)
		var line_x: float = float(run.x * TILE)
		var corner_bottom: bool = not _floor.has(Vector2i(run.x, run.z + 1))
		if corner_bottom:
			y1 -= CORNER_BOTTOM_RISE
			var corner_top: float = y1
			_add_wall(walls, Rect2(line_x - WALL_THICKNESS, corner_top, CORNER_LEFT_REACH + WALL_THICKNESS, CORNER_BOTTOM_RISE + WALL_THICKNESS))
		_add_wall(walls, Rect2(line_x - WALL_THICKNESS, y0, WALL_THICKNESS, y1 - y0))
		_add_fence_v(props, y0, y1, line_x - FENCE_V_LEFT.size.x / 2.0, FENCE_V_LEFT)
	for run: Vector3i in _runs(east):
		var y0: float = float(run.y * TILE)
		var y1: float = float((run.z + 1) * TILE)
		var line_x: float = float((run.x + 1) * TILE)
		var corner_bottom: bool = not _floor.has(Vector2i(run.x, run.z + 1))
		if corner_bottom:
			y1 -= CORNER_BOTTOM_RISE
			_add_wall(walls, Rect2(line_x - CORNER_RIGHT_REACH, y1, CORNER_RIGHT_REACH + WALL_THICKNESS, CORNER_BOTTOM_RISE + WALL_THICKNESS))
		_add_wall(walls, Rect2(line_x, y0, WALL_THICKNESS, y1 - y0))
		_add_fence_v(props, y0, y1, line_x + FENCE_V_RIGHT.size.x / 2.0, FENCE_V_RIGHT)


func _append_edge(map: Dictionary, line: int, pos: int) -> void:
	if not map.has(line):
		map[line] = []
	(map[line] as Array).append(pos)


# Joins consecutive positions of each row into runs (row, start, end), end inclusive.
func _runs(map: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for line: int in map.keys():
		var positions: Array = map[line]
		positions.sort()
		var start: int = positions[0]
		var previous: int = start
		for i: int in range(1, positions.size()):
			var pos: int = positions[i]
			if pos != previous + 1:
				out.append(Vector3i(line, start, previous))
				start = pos
			previous = pos
		out.append(Vector3i(line, start, previous))
	return out


# --- Floor ---

# Lists clean blue cells (no detail) and nearly clean ones from the atlas.
func _collect_blue_cells() -> void:
	var base: Color = _image.get_pixel(6 * TILE, 2 * TILE)
	for rect: Rect2i in BLUE_SOURCE_RECTS:
		for cy: int in range(rect.position.y, rect.end.y):
			for cx: int in range(rect.position.x, rect.end.x):
				var detail: int = _detail_pixels(Vector2i(cx, cy), base)
				if detail == 0:
					_plain_blue.append(Vector2i(cx, cy))
				elif detail <= LIGHT_DETAIL_MAX_PIXELS:
					_light_blue.append(Vector2i(cx, cy))


# Counts pixels that differ from the base color in the atlas cell.
func _detail_pixels(cell: Vector2i, base: Color) -> int:
	var count: int = 0
	for y: int in TILE:
		for x: int in TILE:
			if not _image.get_pixel(cell.x * TILE + x, cell.y * TILE + y).is_equal_approx(base):
				count += 1
	return count


# Picks a blue floor cell (mostly clean, some with slight detail).
func _pick_blue() -> Vector2i:
	if not _light_blue.is_empty() and _rng.randf() < LIGHT_BLUE_CHANCE:
		return _light_blue[_rng.randi() % _light_blue.size()]
	return _plain_blue[_rng.randi() % _plain_blue.size()]


# Cells (16 px grid) covered by a grid-aligned rectangle.
func _cells_of(rect: Rect2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var first: Vector2i = Vector2i(roundi(rect.position.x / TILE), roundi(rect.position.y / TILE))
	var last: Vector2i = Vector2i(roundi(rect.end.x / TILE), roundi(rect.end.y / TILE))
	for cy: int in range(first.y, last.y):
		for cx: int in range(first.x, last.x):
			cells.append(Vector2i(cx, cy))
	return cells


func _mark_floor(rect: Rect2) -> void:
	for cell: Vector2i in _cells_of(rect):
		_floor[cell] = true


# Fills the rectangle with blue floor.
func _fill(rect: Rect2) -> void:
	for cell: Vector2i in _cells_of(rect):
		_ground.set_cell(cell, 0, _pick_blue())


# Copies a block from the atlas to the layer (size in cells).
func _stamp(atlas_origin: Vector2i, size: Vector2i, cell_origin: Vector2i) -> void:
	for j: int in size.y:
		for i: int in size.x:
			_ground.set_cell(cell_origin + Vector2i(i, j), 0, atlas_origin + Vector2i(i, j))


# Marks occupied cells (with margin) so floor decoration does not overlap.
func _claim(origin: Vector2i, size: Vector2i, margin: int = 0) -> void:
	for y: int in range(origin.y - margin, origin.y + size.y + margin):
		for x: int in range(origin.x - margin, origin.x + size.x + margin):
			_claimed[Vector2i(x, y)] = true


func _cells_free(origin: Vector2i, size: Vector2i) -> bool:
	for y: int in size.y:
		for x: int in size.x:
			if _claimed.has(origin + Vector2i(x, y)):
				return false
	return true


# Vertical stone path 2 cells wide, from cy0 to cy1 (exclusive), with optional caps.
func _path_v(cx: int, cy0: int, cy1: int, cap_start: bool, cap_end: bool) -> void:
	for cy: int in range(cy0, cy1 - 1, 2):
		_stamp(PATH_BLOCK, Vector2i(2, 2), Vector2i(cx, cy))
	# Odd length: the last row gets the top half of the block
	if (cy1 - cy0) % 2 == 1:
		_stamp(PATH_BLOCK, Vector2i(2, 1), Vector2i(cx, cy1 - 1))
	if cap_start:
		_stamp(PATH_CAP_TOP, Vector2i(2, 1), Vector2i(cx, cy0 - 1))
	if cap_end:
		_stamp(PATH_CAP_BOTTOM, Vector2i(2, 1), Vector2i(cx, cy1))
	_claim(Vector2i(cx - 1, cy0 - 1), Vector2i(4, cy1 - cy0 + 2), 1)


# Room floor variety: stone paths to the doors, orange grass patches and decals.
func _decorate_floor(room: RoomData) -> void:
	var rect: Rect2 = room.rect
	var first: Vector2i = Vector2i(roundi(rect.position.x / TILE), roundi(rect.position.y / TILE))
	var size: Vector2i = room.size_tiles
	var center_cell: Vector2i = Vector2i(roundi(rect.get_center().x / TILE), roundi(rect.get_center().y / TILE))

	# Paths: from the door to the center (one per door). Top and bottom doors in the same column become one
	# single path, with no caps in the middle. Each entry: [start, end, start cap, end cap]
	var paths: Dictionary = {}
	for door: RoomData.Door in room.doors:
		var cx: int = roundi((rect.get_center().x + door.offset) / TILE) - 1
		var path: Array = [first.y, center_cell.y, false, true] if door.side == Vector2i.UP else [center_cell.y, first.y + size.y, true, false]
		if paths.has(cx):
			var other: Array = paths[cx]
			var top: Array = path if int(path[0]) <= int(other[0]) else other
			var bottom: Array = path if int(path[1]) >= int(other[1]) else other
			path = [top[0], bottom[1], top[2], bottom[3]]
		paths[cx] = path
	for cx: int in paths.keys():
		var path: Array = paths[cx]
		_path_v(cx, path[0], path[1], path[2], path[3])

	var area: float = float(size.x * size.y)
	for i: int in mini(int(area / PATCH_TILES_PER_TRY), PATCH_MAX_TRIES):
		var blocks: Vector2i = Vector2i(_rng.randi_range(3, 5), _rng.randi_range(2, 3))
		var origin: Vector2i = first + Vector2i(_rng.randi_range(2, size.x - blocks.x * 2 - 2), _rng.randi_range(4, size.y - blocks.y * 2 - 2))
		if _cells_free(origin, blocks * 2):
			_place_patch(origin, blocks)
	for i: int in int(area / DECAL_TILES_PER_TRY):
		_try_decal(DECALS_SMALL[_rng.randi() % DECALS_SMALL.size()], first, size)
	if area >= BIG_DECAL_MIN_AREA:
		_try_decal(DECALS_BIG[_rng.randi() % DECALS_BIG.size()], first, size)


# Rectangular orange patch of 2x2 blocks with the artist's edges (origin in cells, size in blocks).
func _place_patch(origin: Vector2i, blocks: Vector2i) -> void:
	for j: int in blocks.y:
		for i: int in blocks.x:
			var gx: int = 0 if i == 0 else (2 if i == blocks.x - 1 else 1)
			var gy: int = 0 if j == 0 else (2 if j == blocks.y - 1 else 1)
			var atlas: Vector2i = _pick_orange_block() if (gx == 1 and gy == 1) else (PATCH_PIECES[Vector2i(gx, gy)] as Vector2i)
			_stamp(atlas, Vector2i(2, 2), origin + Vector2i(i, j) * 2)
	_claim(origin, blocks * 2, 1)


# Picks an orange floor block by weight.
func _pick_orange_block() -> Vector2i:
	var total: int = 0
	for entry: Array in ORANGE_BLOCKS:
		total += entry[1] as int
	var roll: int = _rng.randi() % total
	for entry: Array in ORANGE_BLOCKS:
		roll -= entry[1] as int
		if roll < 0:
			return entry[0]
	return ORANGE_BLOCKS[0][0]


# Tries to place a decal [atlas, size] at a random free position in the room.
func _try_decal(decal: Array, first: Vector2i, size: Vector2i) -> void:
	var atlas: Vector2i = decal[0]
	var decal_size: Vector2i = decal[1]
	if size.x <= decal_size.x + 4 or size.y <= decal_size.y + 6:
		return
	for attempt: int in 8:
		var origin: Vector2i = first + Vector2i(_rng.randi_range(2, size.x - decal_size.x - 2), _rng.randi_range(4, size.y - decal_size.y - 2))
		if _cells_free(origin, decal_size):
			_stamp(atlas, decal_size, origin)
			_claim(origin, decal_size, 1)
			return


# --- Exterior ---

# The strip of floor behind the top fence and the wedges under the diagonal of the bottom corners are outside the
# graveyard: they become grass (except at the entrance of the top doors).
func _paint_behind_top_fence(room: RoomData) -> void:
	var first: Vector2i = Vector2i(roundi(room.rect.position.x / TILE), roundi(room.rect.position.y / TILE))
	var width: int = room.size_tiles.x
	var door_gaps: Array[Vector2] = _gaps(room, Vector2i.UP)
	for x: int in width:
		var center_x: float = float(first.x + x) * TILE + TILE / 2.0
		var in_gap: bool = false
		for gap: Vector2 in door_gaps:
			if center_x > gap.x and center_x < gap.y:
				in_gap = true
		if not in_gap:
			_set_grass(Vector2i(first.x + x, first.y))
	# Floor wedges under the diagonal of the bottom corners
	var last_row: int = first.y + room.size_tiles.y - 1
	for corner_x: int in [0, 1, width - 2, width - 1]:
		_set_grass(Vector2i(first.x + corner_x, last_row))


func _set_grass(cell: Vector2i) -> void:
	_ground.set_cell(cell, 0, ORANGE_PLAIN_CELLS[_rng.randi() % ORANGE_PLAIN_CELLS.size()])


# Orange floor (grass) around rooms and corridors, up to the margin.
func _paint_exterior(rooms: Array[RoomData], corridors: Array[Rect2], margin_tiles: int) -> void:
	for rect: Rect2 in _all_rects(rooms, corridors):
		for cell: Vector2i in _cells_of(rect.grow(float(margin_tiles * TILE))):
			if _floor.has(cell) or _exterior.has(cell):
				continue
			_exterior[cell] = true
			_ground.set_cell(cell, 0, ORANGE_PLAIN_CELLS[_rng.randi() % ORANGE_PLAIN_CELLS.size()])
	_fill_exterior_gaps(EXTERIOR_GAP_FILL_TILES)


# Morphological closing (dilates and erodes by "radius" cells): fills with grass the holes and the
# narrow notches of black void left between the rectangular margins of rooms and corridors.
func _fill_exterior_gaps(radius: int) -> void:
	var land: Dictionary = _floor.merged(_exterior)
	if land.is_empty():
		return
	var lo: Vector2i = land.keys()[0]
	var hi: Vector2i = lo
	for cell: Vector2i in land.keys():
		lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
		hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
	var pad: int = radius + 1
	var origin: Vector2i = lo - Vector2i(pad, pad)
	var w: int = hi.x - lo.x + 1 + pad * 2
	var h: int = hi.y - lo.y + 1 + pad * 2
	var grid: PackedByteArray = PackedByteArray()
	grid.resize(w * h)
	for cell: Vector2i in land.keys():
		grid[(cell.y - origin.y) * w + (cell.x - origin.x)] = 1
	var closed: PackedByteArray = _morph(_morph(grid, w, h, radius, true), w, h, radius, false)
	for y: int in h:
		for x: int in w:
			if closed[y * w + x] == 1 and grid[y * w + x] == 0:
				var cell: Vector2i = origin + Vector2i(x, y)
				_exterior[cell] = true
				_set_grass(cell)


# Dilation (dilate = true) or erosion with a square of side 2*radius+1, separable (rows then columns).
func _morph(grid: PackedByteArray, w: int, h: int, radius: int, dilate: bool) -> PackedByteArray:
	var rows: PackedByteArray = _morph_pass(grid, w, h, radius, dilate, true)
	return _morph_pass(rows, w, h, radius, dilate, false)


# A 1D pass with a running sum: dilates if there is any 1 in the window; erodes if the window is all 1s.
func _morph_pass(grid: PackedByteArray, w: int, h: int, radius: int, dilate: bool, horizontal: bool) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(w * h)
	var lines: int = h if horizontal else w
	var length: int = w if horizontal else h
	var prefix: PackedInt32Array = PackedInt32Array()
	prefix.resize(length + 1)
	for line: int in lines:
		for i: int in length:
			var index: int = line * w + i if horizontal else i * w + line
			prefix[i + 1] = prefix[i] + grid[index]
		for i: int in length:
			var a: int = maxi(i - radius, 0)
			var b: int = mini(i + radius + 1, length)
			var count: int = prefix[b] - prefix[a]
			# Outside the grid counts as void: erosion near the edge zeroes out
			var full: bool = count == radius * 2 + 1
			var index: int = line * w + i if horizontal else i * w + line
			out[index] = 1 if (count > 0 if dilate else full) else 0
	return out


func _all_rects(rooms: Array[RoomData], corridors: Array[Rect2]) -> Array[Rect2]:
	var rects: Array[Rect2] = corridors.duplicate()
	for room: RoomData in rooms:
		rects.append(room.rect)
	return rects


# Trees, bushes, leaves and pumpkins in the woods, away from the fences (decoration only: no collision).
func _scatter_exterior(props: Node2D, rooms: Array[RoomData], corridors: Array[Rect2], density: float) -> void:
	if density <= 0.0:
		return
	var near: Dictionary = {}
	for rect: Rect2 in _all_rects(rooms, corridors):
		for cell: Vector2i in _cells_of(rect.grow(float(EXTERIOR_CLEAR_TILES * TILE))):
			near[cell] = true
	var chance: float = clampf(EXTERIOR_CHANCE * density, 0.0, 1.0)
	for cell: Vector2i in _exterior.keys():
		if posmod(cell.x, EXTERIOR_STEP_TILES) != 0 or posmod(cell.y, EXTERIOR_STEP_TILES) != 0:
			continue
		if near.has(cell) or _rng.randf() > chance:
			continue
		var kind: Prop.Kind = _pick_kind(EXTERIOR_WEIGHTS)
		var pos: Vector2 = ((Vector2(cell) + Vector2(_rng.randf(), _rng.randf())) * TILE).snapped(Vector2.ONE)
		# The whole sprite must sit on grass (otherwise the tree canopy invades the black void)
		if not _over_exterior(Rect2(pos + Prop.local_rect(kind).position, Prop.local_rect(kind).size)):
			continue
		var prop: Prop = PROP_SCENE.instantiate() as Prop
		prop.solid = false
		prop.kind = kind
		prop.position = pos
		props.add_child(prop)


# True if all cells under the rectangle (px) are exterior grass.
func _over_exterior(rect: Rect2) -> bool:
	var first: Vector2i = Vector2i(floori(rect.position.x / TILE), floori(rect.position.y / TILE))
	var last: Vector2i = Vector2i(floori((rect.end.x - 1.0) / TILE), floori((rect.end.y - 1.0) / TILE))
	for cy: int in range(first.y, last.y + 1):
		for cx: int in range(first.x, last.x + 1):
			if not _exterior.has(Vector2i(cx, cy)):
				return false
	return true


# --- Room walls ---

# Walls on the 4 sides of the room; top and bottom have a gap per door; each gap gets a blocker (disabled).
func _build_room_walls(walls: Node2D, room: RoomData) -> void:
	var rect: Rect2 = room.rect
	var t: float = WALL_THICKNESS
	for span: Vector2 in _spans(rect.position.x - t, rect.end.x + t, _gaps(room, Vector2i.UP)):
		_add_wall(walls, Rect2(span.x, rect.position.y - t, span.y - span.x, t + TOP_WALL_INSET))
	for span: Vector2 in _spans(rect.position.x - t, rect.end.x + t, _gaps(room, Vector2i.DOWN)):
		_add_wall(walls, Rect2(span.x, rect.end.y - BOTTOM_WALL_INSET, span.y - span.x, t + BOTTOM_WALL_INSET))
	_add_wall(walls, Rect2(rect.position.x - t, rect.position.y, t, rect.size.y))
	_add_wall(walls, Rect2(rect.end.x, rect.position.y, t, rect.size.y))
	for door: RoomData.Door in room.doors:
		door.blocker = _add_door_blocker(walls, room, door)


# Gaps (start, end in x) of the doors on one side of the room, in order.
func _gaps(room: RoomData, side: Vector2i) -> Array[Vector2]:
	var gaps: Array[Vector2] = []
	for door: RoomData.Door in room.doors:
		if door.side == side:
			var x: float = room.center().x + door.offset
			gaps.append(Vector2(x - corridor_width / 2.0, x + corridor_width / 2.0))
	gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return gaps


# Splits [from, to] removing the gaps (sorted).
func _spans(from: float, to: float, gaps: Array[Vector2]) -> Array[Vector2]:
	var spans: Array[Vector2] = []
	var cursor: float = from
	for gap: Vector2 in gaps:
		if gap.x > cursor:
			spans.append(Vector2(cursor, gap.x))
		cursor = gap.y
	if to > cursor:
		spans.append(Vector2(cursor, to))
	return spans


# Corner collision (squares covering the diagonal fence).
func _build_corner_walls(walls: Node2D, room: RoomData) -> void:
	var rect: Rect2 = room.rect
	var t: float = WALL_THICKNESS
	var top: float = rect.position.y - t
	var top_height: float = TOP_WALL_INSET + CORNER_TOP_DROP + t
	var bottom: float = rect.end.y + FENCE_BOTTOM_DROP - CORNER_BOTTOM_RISE
	var bottom_height: float = rect.end.y + t - bottom
	_add_wall(walls, Rect2(rect.position.x - t, top, CORNER_LEFT_REACH + t, top_height))
	_add_wall(walls, Rect2(rect.end.x - CORNER_RIGHT_REACH, top, CORNER_RIGHT_REACH + t, top_height))
	_add_wall(walls, Rect2(rect.position.x - t, bottom, CORNER_LEFT_REACH + t, bottom_height))
	_add_wall(walls, Rect2(rect.end.x - CORNER_RIGHT_REACH, bottom, CORNER_RIGHT_REACH + t, bottom_height))


# Room fence: straight pieces with gaps at the doors, corners, sides and an arch at each door.
func _build_room_fences(props: Node2D, room: RoomData) -> void:
	var rect: Rect2 = room.rect
	var top_base: float = rect.position.y + TOP_WALL_INSET
	var bottom_base: float = rect.end.y + FENCE_BOTTOM_DROP
	var join_left: float = rect.position.x + CORNER_LEFT_REACH
	var join_right: float = rect.end.x - CORNER_RIGHT_REACH

	_add_fence_sprite(props, CORNER_TL, CORNER_TL_JOIN, Vector2(join_left, top_base))
	_add_fence_sprite(props, CORNER_TR, CORNER_TR_JOIN, Vector2(join_right, top_base))
	_add_fence_sprite(props, CORNER_BL, CORNER_BL_JOIN, Vector2(join_left, bottom_base))
	_add_fence_sprite(props, CORNER_BR, CORNER_BR_JOIN, Vector2(join_right, bottom_base))
	_cover_corner_gap(props, join_left, rect.position.x + TILE * 2.0, rect.end.y)
	_cover_corner_gap(props, join_right, rect.end.x - TILE * 2.0, rect.end.y)

	for span: Vector2 in _spans(join_left, join_right, _gaps(room, Vector2i.UP)):
		_add_fence_h(props, span.x, span.y, top_base, FENCE_H_TOP)
	for span: Vector2 in _spans(join_left, join_right, _gaps(room, Vector2i.DOWN)):
		_add_fence_h(props, span.x, span.y, bottom_base, FENCE_H_BOTTOM)
	var y_from: float = top_base + CORNER_TOP_DROP
	var y_to: float = bottom_base - CORNER_BOTTOM_RISE
	_add_fence_v(props, y_from, y_to, rect.position.x - FENCE_V_LEFT.size.x / 2.0, FENCE_V_LEFT)
	_add_fence_v(props, y_from, y_to, rect.end.x + FENCE_V_RIGHT.size.x / 2.0, FENCE_V_RIGHT)

	for door: RoomData.Door in room.doors:
		var base_y: float = top_base if door.side == Vector2i.UP else bottom_base
		var arch: Prop = PROP_SCENE.instantiate() as Prop
		arch.kind = Prop.Kind.ARCH_OPEN
		arch.position = Vector2(room.center().x + door.offset, base_y)
		props.add_child(arch)
		door.arch = arch


# Horizontal fence from x0 to x1 with the base at height "base_y" (32 px pieces; the last one is clipped).
func _add_fence_h(props: Node2D, x0: float, x1: float, base_y: float, piece: Rect2) -> void:
	var x: float = x0
	while x < x1 - 0.01:
		var width: float = minf(FENCE_STEP, x1 - x)
		var region: Rect2 = Rect2(piece.position, Vector2(width, piece.size.y))
		_add_fence_sprite(props, region, Vector2(width / 2.0, piece.size.y), Vector2(x + width / 2.0, base_y))
		x += width


# Vertical fence from y0 to y1 centered at "center_x" (32 px pieces; the last one is clipped).
func _add_fence_v(props: Node2D, y0: float, y1: float, center_x: float, piece: Rect2) -> void:
	var y: float = y0
	while y < y1 - 0.01:
		var height: float = minf(FENCE_STEP, y1 - y)
		var region: Rect2 = Rect2(piece.position, Vector2(piece.size.x, height))
		_add_fence_sprite(props, region, Vector2(piece.size.x / 2.0, height), Vector2(center_x, y + height))
		y += height


# The 2 grass cells under the bottom corner extend slightly past the diagonal and would show as an orange thread
# behind the fence: blue floor cutouts cover the excess. "join_x" is where the corner meets the straight fence,
# "cells_end_x" is the end of the 2 grass cells and "line_y" is the base of the wall.
func _cover_corner_gap(props: Node2D, join_x: float, cells_end_x: float, line_y: float) -> void:
	var dir: float = signf(cells_end_x - join_x)
	# From the junction to the end of the cells (behind the straight fence)
	_cover_blue(props, Rect2(minf(join_x, cells_end_x), line_y - TILE, absf(cells_end_x - join_x), TILE))
	# Top strip, slightly inside the corner (above the stone diagonal)
	_cover_blue(props, Rect2(join_x - CORNER_GAP_STRIP.x if dir > 0.0 else join_x, line_y - TILE, CORNER_GAP_STRIP.x, CORNER_GAP_STRIP.y))


# Plain blue floor cutout (below everything standing, above the floor).
func _cover_blue(props: Node2D, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var sprite: Sprite2D = Sprite2D.new()
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = Prop.TILESET_TEXTURE
	atlas.region = Rect2(Vector2(_plain_blue[0] * TILE), rect.size)
	sprite.texture = atlas
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = rect.position
	sprite.z_index = -9
	props.add_child(sprite)


# Fence sprite: "origin" is the point of the region (px) that sits at "base_pos" (y-sort by the feet).
func _add_fence_sprite(props: Node2D, region: Rect2, origin: Vector2, base_pos: Vector2) -> void:
	var sprite: Sprite2D = Sprite2D.new()
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = Prop.TILESET_TEXTURE
	atlas.region = region
	sprite.texture = atlas
	sprite.centered = false
	sprite.offset = -origin
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = base_pos
	props.add_child(sprite)


# Creates a rectangular StaticBody2D on the world layer (blocks movement and projectiles).
func _add_wall(parent: Node2D, rect: Rect2) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var collider: CollisionShape2D = CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	return body


# Door gap blocker (centered on the wall line); starts disabled (layer 0).
func _add_door_blocker(walls: Node2D, room: RoomData, door: RoomData.Door) -> StaticBody2D:
	var t: float = WALL_THICKNESS
	var x: float = room.center().x + door.offset
	var line_y: float = room.rect.position.y - t if door.side == Vector2i.UP else room.rect.end.y - t
	var body: StaticBody2D = _add_wall(walls, Rect2(x - corridor_width / 2.0, line_y, corridor_width, t * 2.0))
	body.collision_layer = 0
	return body


# --- Props inside the graveyard ---

# Scatters decorative props in the room, away from the doors, the center and each other.
func _scatter_props(props: Node2D, room: RoomData, density: float) -> void:
	if room.type == RoomData.Type.BOSS:
		return
	var count: int = roundi(float(room.size_tiles.x * room.size_tiles.y) / TILES_PER_PROP * density)
	var placed: Array[Rect2] = []
	var area: Rect2 = Rect2(room.rect.position + Vector2(PROP_EDGE_MARGIN, PROP_TOP_MARGIN), room.rect.size - Vector2(PROP_EDGE_MARGIN * 2.0, PROP_TOP_MARGIN + PROP_EDGE_MARGIN))
	var lanes: Array[Rect2] = _door_lanes(room)
	for i: int in count:
		var kind: Prop.Kind = _pick_kind(PROP_WEIGHTS)
		for attempt: int in PROP_ATTEMPTS:
			var pos: Vector2 = Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y)).snapped(Vector2.ONE)
			var local: Rect2 = Prop.local_rect(kind)
			var footprint: Rect2 = Rect2(pos + local.position, local.size)
			if not area.encloses(footprint) or _blocked(footprint, room.center(), placed, lanes):
				continue
			var prop: Prop = PROP_SCENE.instantiate() as Prop
			prop.kind = kind
			prop.position = pos
			props.add_child(prop)
			placed.append(footprint)
			break


# Free strips from the door to the center of the room (for the player and enemies to pass).
func _door_lanes(room: RoomData) -> Array[Rect2]:
	var lanes: Array[Rect2] = []
	var center: Vector2 = room.center()
	var width: float = corridor_width + 32.0
	for door: RoomData.Door in room.doors:
		var x: float = center.x + door.offset
		var y0: float = room.rect.position.y if door.side == Vector2i.UP else center.y
		lanes.append(Rect2(x - width / 2.0, y0, width, room.rect.size.y / 2.0))
		# Side gaps: free connection to the center
		if door.offset != 0.0:
			lanes.append(Rect2(minf(x, center.x) - width / 2.0, center.y - width / 2.0, absf(x - center.x) + width, width))
	return lanes


# True if the rectangle invades the free center, a door strip or another prop.
func _blocked(footprint: Rect2, center: Vector2, placed: Array[Rect2], lanes: Array[Rect2]) -> bool:
	if footprint.grow(8.0).has_point(center) or footprint.get_center().distance_to(center) < PROP_CENTER_CLEAR:
		return true
	for lane: Rect2 in lanes:
		if lane.intersects(footprint):
			return true
	for other: Rect2 in placed:
		if other.grow(2.0).intersects(footprint):
			return true
	return false


func _pick_kind(weights: Dictionary) -> Prop.Kind:
	var total: float = 0.0
	for weight: float in weights.values():
		total += weight
	var roll: float = _rng.randf() * total
	for kind: Prop.Kind in weights.keys():
		roll -= float(weights[kind])
		if roll <= 0.0:
			return kind
	return Prop.Kind.GRAVE_CROSS
