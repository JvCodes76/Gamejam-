## One-off generator of the static scenery of main_level (Ground + Props).
## Usage: godot --headless --script res://tools/generate_level_tiles.gd
## Recreates the "Ground" and "Props" nodes (and removes the old "Floor") in levels/main_level.tscn.
extends SceneTree

const LEVEL_PATH: String = "res://levels/main_level.tscn"
const TILESET_PATH: String = "res://assets/tilesets/halloween/halloween_tileset.tres"
const TEXTURE_PATH: String = "res://assets/tilesets/halloween/halloween_tileset.png"
const PROP_SCENE: PackedScene = preload("res://levels/props/prop.tscn")
const DEBUG_COMMENT: String = "; [DEBUG] Teste: todos os itens espalhados no chao e raio maior\n"

const TILE: int = 16
# Cells: x from -40 to 39; y from -23 to 21 with the layer shifted by +8 px (arena -640..640 x -360..360).
const CELL_MIN: Vector2i = Vector2i(-40, -23)
const CELL_MAX: Vector2i = Vector2i(39, 21)
const LAYER_OFFSET: Vector2 = Vector2(0, 8)

const CENTER_CLEAR_RADIUS: float = 150.0
const CAULDRON_POS: Vector2 = Vector2(120, -60)
const CAULDRON_CLEAR_RADIUS: float = 72.0
const ARENA: Rect2 = Rect2(-640, -372, 1280, 732)
# Top wall of the arena (center; 32 px tall): the inner face sits at y=-322, so the player's feet stop
# in time for the head (47 px above) not to leave the ground (which ends at y=-360).
const TOP_WALL_Y: float = -338.0
# Cauldron origin at the feet: the drawing (center at (120,-60)) rises 13 px relative to the origin
const CAULDRON_FEET_POS: Vector2 = Vector2(120, -47)

# 2x2 orange floor blocks (origin in cells) and weight.
const ORANGE_BLOCKS: Array = [
	[Vector2i(0, 0), 4], [Vector2i(0, 2), 3], [Vector2i(2, 0), 1], [Vector2i(2, 2), 1],
	[Vector2i(4, 0), 1], [Vector2i(4, 2), 1], [Vector2i(16, 0), 1],
]
# Orange patch edges by position in the 3x3 block grid (see tools/generate_tileset.gd).
const PATCH_PIECES: Dictionary = {
	Vector2i(0, 0): Vector2i(14, 8), Vector2i(1, 0): Vector2i(12, 8), Vector2i(2, 0): Vector2i(10, 8),
	Vector2i(0, 1): Vector2i(16, 2), Vector2i(2, 1): Vector2i(8, 2),
	Vector2i(0, 2): Vector2i(14, 0), Vector2i(1, 2): Vector2i(12, 0), Vector2i(2, 2): Vector2i(10, 0),
}
# Rectangles (atlas cells) the blue floor cells come from.
const BLUE_SOURCE_RECTS: Array = [
	Rect2i(6, 2, 2, 2), Rect2i(2, 4, 3, 1), Rect2i(6, 7, 2, 1), Rect2i(10, 2, 6, 2),
]
# Blue decals: [atlas origin, size in cells, count, minimum radius to the center]
const DECALS: Array = [
	[Vector2i(6, 0), Vector2i(2, 2), 7, 160.0],
	[Vector2i(8, 0), Vector2i(2, 2), 7, 160.0],
	[Vector2i(2, 5), Vector2i(2, 1), 9, 130.0],
	[Vector2i(10, 2), Vector2i(6, 6), 3, 260.0],
	[Vector2i(16, 4), Vector2i(4, 4), 4, 200.0],
]
# Orange grass patches (world px: x, y, width, height), aligned to 32 px blocks.
const PATCHES: Array = [
	Rect2(-620, -330, 160, 96), Rect2(300, -260, 128, 128), Rect2(-250, 130, 128, 96),
	Rect2(200, 140, 160, 96), Rect2(-570, 150, 128, 128), Rect2(440, 150, 128, 96),
	Rect2(-100, 250, 96, 64), Rect2(150, -330, 96, 64), Rect2(-460, -120, 96, 64),
]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _image: Image
var _ground: TileMapLayer
var _occupied: Dictionary = {}
var _plain_blue: Array[Vector2i] = []
var _light_blue: Array[Vector2i] = []
var _props_root: Node2D
var _placed: Array[Dictionary] = []  # {kind, pos, rect}
var _path_rects: Array[Rect2] = []
var _keep_out: Array[Rect2] = []
var _prop_count: int = 0


func _initialize() -> void:
	_rng.seed = 20251031
	_image = Image.load_from_file(ProjectSettings.globalize_path(TEXTURE_PATH))
	var packed: PackedScene = load(LEVEL_PATH)
	var root: Node2D = packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node2D
	for old_name: String in ["Floor", "Ground", "Props"]:
		var old: Node = root.get_node_or_null(old_name)
		if old != null:
			root.remove_child(old)
			old.free()
	root.y_sort_enabled = true

	_build_ground(root)
	_build_props(root)
	_apply_scene_rules(root)

	var out: PackedScene = PackedScene.new()
	var pack_err: Error = out.pack(root)
	var save_err: Error = ResourceSaver.save(out, LEVEL_PATH)
	print("[Level] - scene saved (pack=%d, save=%d, props=%d)" % [pack_err, save_err, _prop_count])
	_restore_debug_comment()
	root.free()
	quit()


# Level layer/sorting rules: y-sorted enemy spawner, top wall, cauldron with origin at the feet.
func _apply_scene_rules(root: Node2D) -> void:
	var spawner: Node2D = root.get_node("EnemySpawner") as Node2D
	spawner.y_sort_enabled = true
	(root.get_node("Walls/Top") as Node2D).position.y = TOP_WALL_Y
	(root.get_node("Cauldron") as Node2D).position = CAULDRON_FEET_POS
	var items: Node2D = root.get_node("GroundItemSpawner") as Node2D
	items.y_sort_enabled = false
	print("[Level] - layer rules applied (EnemySpawner y-sort, top wall, cauldron)")


# Creates the "Ground" TileMapLayer with a blue base, orange patches, decals and a stone path.
func _build_ground(root: Node2D) -> void:
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.tile_set = load(TILESET_PATH)
	_ground.z_index = -10
	_ground.position = LAYER_OFFSET
	_ground.collision_enabled = false
	root.add_child(_ground)
	root.move_child(_ground, 0)
	_ground.owner = root

	_collect_blue_cells()
	for cy: int in range(CELL_MIN.y, CELL_MAX.y + 1):
		for cx: int in range(CELL_MIN.x, CELL_MAX.x + 1):
			_ground.set_cell(Vector2i(cx, cy), 0, _pick_blue())

	_build_paths()
	for rect: Rect2 in PATCHES:
		_place_patch(rect)
	_scatter_decals()
	print("[Level] - ground: %d cells" % _ground.get_used_cells().size())


# Lists clean blue cells (no detail) and nearly clean ones from the atlas.
func _collect_blue_cells() -> void:
	var base: Color = _image.get_pixel(6 * TILE, 2 * TILE)
	for rect: Rect2i in BLUE_SOURCE_RECTS:
		for cy: int in range(rect.position.y, rect.end.y):
			for cx: int in range(rect.position.x, rect.end.x):
				var detail: int = _detail_pixels(Vector2i(cx, cy), base)
				if detail == 0:
					_plain_blue.append(Vector2i(cx, cy))
				elif detail <= 6:
					_light_blue.append(Vector2i(cx, cy))
	print("[Level] - clean blue: %d, light blue: %d" % [_plain_blue.size(), _light_blue.size()])


# Counts pixels that differ from the base color in the atlas cell.
func _detail_pixels(cell: Vector2i, base: Color) -> int:
	var count: int = 0
	for y: int in TILE:
		for x: int in TILE:
			var c: Color = _image.get_pixel(cell.x * TILE + x, cell.y * TILE + y)
			if not c.is_equal_approx(base):
				count += 1
	return count


# Picks a blue floor cell (88% clean, 12% with slight detail).
func _pick_blue() -> Vector2i:
	if not _light_blue.is_empty() and _rng.randf() < 0.12:
		return _light_blue[_rng.randi() % _light_blue.size()]
	return _plain_blue[_rng.randi() % _plain_blue.size()]


# Converts a world position (px) to a Ground layer cell.
func _world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori((pos.y - LAYER_OFFSET.y) / TILE))


# Marks occupied cells (with margin) so decals do not overlap.
func _claim(origin: Vector2i, size: Vector2i, margin: int = 0) -> void:
	for y: int in range(origin.y - margin, origin.y + size.y + margin):
		for x: int in range(origin.x - margin, origin.x + size.x + margin):
			_occupied[Vector2i(x, y)] = true


# Copies a block from the atlas to the layer (size in cells).
func _stamp(atlas_origin: Vector2i, size: Vector2i, cell_origin: Vector2i) -> void:
	for j: int in size.y:
		for i: int in size.x:
			_ground.set_cell(cell_origin + Vector2i(i, j), 0, atlas_origin + Vector2i(i, j))


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


# Builds a rectangular orange patch of 32x32 blocks with the artist's edges.
func _place_patch(world_rect: Rect2) -> void:
	var block0: Vector2i = Vector2i(roundi(world_rect.position.x / 32.0), roundi((world_rect.position.y - LAYER_OFFSET.y) / 32.0))
	var size: Vector2i = Vector2i(roundi(world_rect.size.x / 32.0), roundi(world_rect.size.y / 32.0))
	for j: int in size.y:
		for i: int in size.x:
			var gx: int = 0 if i == 0 else (2 if i == size.x - 1 else 1)
			var gy: int = 0 if j == 0 else (2 if j == size.y - 1 else 1)
			var atlas: Vector2i = _pick_orange_block() if (gx == 1 and gy == 1) else (PATCH_PIECES[Vector2i(gx, gy)] as Vector2i)
			_stamp(atlas, Vector2i(2, 2), (block0 + Vector2i(i, j)) * 2)
	_claim(block0 * 2, size * 2, 1)
	_keep_out.append(Rect2(world_rect.position, world_rect.size))
	print("[Level] - orange patch %s (%dx%d blocks)" % [world_rect.position, size.x, size.y])


# Scatters dark decals/cracks on the free blue floor.
func _scatter_decals() -> void:
	for decal: Array in DECALS:
		var atlas: Vector2i = decal[0]
		var size: Vector2i = decal[1]
		var wanted: int = decal[2]
		var min_radius: float = decal[3]
		var placed: int = 0
		var tries: int = 0
		while placed < wanted and tries < 300:
			tries += 1
			var cell: Vector2i = Vector2i(_rng.randi_range(CELL_MIN.x, CELL_MAX.x - size.x), _rng.randi_range(CELL_MIN.y, CELL_MAX.y - size.y))
			var center: Vector2 = (Vector2(cell) + Vector2(size) / 2.0) * TILE + LAYER_OFFSET
			if center.length() < min_radius or not _cells_free(cell, size):
				continue
			_stamp(atlas, size, cell)
			_claim(cell, size, 1)
			placed += 1
		print("[Level] - decal %s: %d/%d" % [atlas, placed, wanted])


# Returns true if all cells in the area are free.
func _cells_free(origin: Vector2i, size: Vector2i) -> bool:
	for y: int in size.y:
		for x: int in size.x:
			if _occupied.has(origin + Vector2i(x, y)):
				return false
	return true


# Stone path: center block (6,4) side by side, with end caps (1x2 / 2x1 cells).
func _build_paths() -> void:
	# East-west: from the base of the enclosure to the north exit detour (x=496)
	_path_h(-20, 32, -1, false, true)
	# North exit: to the open arch (the arch opens to the south, so the path arrives from below it)
	_path_v(30, -19, -1, true, false)
	# South: from the spawn to the closed gate
	_path_v(-1, 1, 21, false, false)
	# North, to the enclosure gate (x=-304)
	_path_v(-20, -5, -1, true, false)
	# Detour to the cauldron
	_path_v(6, -5, -1, true, false)


# Horizontal strip 2 cells tall from cx0 to cx1 (exclusive).
func _path_h(cx0: int, cx1: int, cy: int, cap_start: bool, cap_end: bool) -> void:
	for cx: int in range(cx0, cx1, 2):
		_stamp(Vector2i(6, 4), Vector2i(2, 2), Vector2i(cx, cy))
	if cap_start:
		_stamp(Vector2i(5, 4), Vector2i(1, 2), Vector2i(cx0 - 1, cy))
	if cap_end:
		_stamp(Vector2i(8, 4), Vector2i(1, 2), Vector2i(cx1, cy))
	_claim(Vector2i(cx0 - 1, cy), Vector2i(cx1 - cx0 + 2, 2), 1)
	_path_rects.append(Rect2(Vector2(cx0, cy) * TILE + LAYER_OFFSET, Vector2(cx1 - cx0, 2) * TILE))


# Vertical strip 2 cells wide from cy0 to cy1 (exclusive).
func _path_v(cx: int, cy0: int, cy1: int, cap_start: bool, cap_end: bool) -> void:
	for cy: int in range(cy0, cy1, 2):
		_stamp(Vector2i(6, 4), Vector2i(2, 2), Vector2i(cx, cy))
	if cap_start:
		_stamp(Vector2i(6, 3), Vector2i(2, 1), Vector2i(cx, cy0 - 1))
	if cap_end:
		_stamp(Vector2i(6, 6), Vector2i(2, 1), Vector2i(cx, cy1))
	_claim(Vector2i(cx - 1, cy0 - 1), Vector2i(4, cy1 - cy0 + 2), 1)
	_path_rects.append(Rect2(Vector2(cx, cy0) * TILE + LAYER_OFFSET, Vector2(2, cy1 - cy0) * TILE))


# Creates the "Props" node (y-sort) with the graveyard, posts, pumpkins, border trees and leaves.
func _build_props(root: Node2D) -> void:
	_props_root = Node2D.new()
	_props_root.name = "Props"
	_props_root.y_sort_enabled = true
	root.add_child(_props_root)
	root.move_child(_props_root, 2)
	_props_root.owner = root

	_build_enclosure(Vector2(-304, -56))
	_build_arches()
	_build_graveyards()
	_build_lamps()
	_build_edge_trees()
	_build_filler()
	_validate_props()
	print("[Level] - props: %d" % _prop_count)


# Warns if any solid prop invades the free center or the cauldron area.
func _validate_props() -> void:
	var warnings: int = 0
	for entry: Dictionary in _placed:
		var kind: Prop.Kind = entry["kind"]
		var def: Dictionary = Prop.get_def(kind)
		var region: Rect2 = def["region"]
		var origin: Vector2 = def.get("origin", Vector2(region.size.x / 2.0, region.size.y))
		for foot: Variant in def["rects"]:
			var bounds: Rect2 = _bounds_of(Prop.footprint_points(foot))
			var world: Rect2 = Rect2((entry["pos"] as Vector2) - origin + bounds.position, bounds.size)
			if _distance_to_rect(Vector2.ZERO, world) < CENTER_CLEAR_RADIUS - 10.0 or _distance_to_rect(CAULDRON_POS, world) < 40.0:
				warnings += 1
				print("[Level] - WARNING: collision of %s at %s invades the free area" % [Prop.Kind.keys()[kind], entry["pos"]])
	print("[Level] - props validation: %d warnings" % warnings)


# Rectangle that encloses a list of points.
func _bounds_of(points: PackedVector2Array) -> Rect2:
	var bounds: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		bounds = bounds.expand(point)
	return bounds


# Instantiates a prop and records the occupied rectangle.
func _place(kind: Prop.Kind, pos: Vector2) -> void:
	var prop: Prop = PROP_SCENE.instantiate() as Prop
	prop.kind = kind
	prop.position = pos
	prop.name = "%s_%d" % [(Prop.Kind.keys()[kind] as String).capitalize().replace(" ", ""), _prop_count]
	_props_root.add_child(prop)
	prop.owner = _props_root.owner
	_prop_count += 1
	var local: Rect2 = Prop.local_rect(kind)
	_placed.append({"kind": kind, "pos": pos, "rect": Rect2(pos + local.position, local.size)})


# Octagonal enclosure in 3 pieces (base_center = center of the front); the 32 px gap is the entrance.
func _build_enclosure(base_center: Vector2) -> void:
	_place(Prop.Kind.FENCE_TOP, base_center + Vector2(0, -128))
	_place(Prop.Kind.FENCE_BOTTOM_LEFT, base_center + Vector2(-32, 0))
	_place(Prop.Kind.FENCE_BOTTOM_RIGHT, base_center + Vector2(32, 0))
	_keep_out.append(Rect2(base_center + Vector2(-56, -176), Vector2(112, 190)))
	# Interior
	_place(Prop.Kind.GRAVE_CROSS, base_center + Vector2(-24, -62))
	_place(Prop.Kind.GRAVE_ROUND, base_center + Vector2(22, -62))
	_place(Prop.Kind.CANDLES, base_center + Vector2(-34, -86))
	_place(Prop.Kind.DIRT_MOUND, base_center + Vector2(26, -86))
	_place(Prop.Kind.PUMPKIN_SMILE, base_center + Vector2(0, -92))


# Open arch at the north exit and arch with a closed gate at the end of the south path.
func _build_arches() -> void:
	_place(Prop.Kind.ARCH_OPEN, Vector2(496, -290))
	_place(Prop.Kind.ARCH_GATE, Vector2(0, 346))
	_place(Prop.Kind.LAMP_POST, Vector2(462, -110))
	_place(Prop.Kind.LAMP_POST, Vector2(530, -190))
	_place(Prop.Kind.PUMPKIN_GRIN, Vector2(-46, 332))
	_place(Prop.Kind.PUMPKIN_PLAIN, Vector2(52, 334))


# Rows of tombs and decoration groups.
func _build_graveyards() -> void:
	var kinds: Array = [Prop.Kind.GRAVE_CROSS, Prop.Kind.GRAVE_ROUND, Prop.Kind.GRAVE_BROKEN]
	# West graveyard: two rows
	for row: int in 2:
		for col: int in 4:
			var pos: Vector2 = Vector2(-560 + col * 52, 36 + row * 52) + Vector2(_rng.randf_range(-3, 3), 0)
			_place(kinds[(row + col) % 3], pos)
			if _rng.randf() < 0.5:
				_place(Prop.Kind.DIRT_MOUND, pos + Vector2(0, 24))
	_place(Prop.Kind.CANDLES, Vector2(-376, 52))
	_place(Prop.Kind.CANDLES, Vector2(-584, 12))
	_place(Prop.Kind.PUMPKIN_SMILE, Vector2(-380, 100))
	# Southeast graveyard
	for col: int in 3:
		_place(kinds[(col + 1) % 3], Vector2(300 + col * 56, 215))
		_place(kinds[col % 3], Vector2(320 + col * 56, 168))
	_place(Prop.Kind.CANDLES, Vector2(268, 190))
	_place(Prop.Kind.PUMPKIN_GRIN, Vector2(480, 220))
	# Northeast group
	_place(Prop.Kind.GRAVE_ROUND, Vector2(330, -190))
	_place(Prop.Kind.GRAVE_CROSS, Vector2(376, -170))
	_place(Prop.Kind.GRAVE_BROKEN, Vector2(420, -196))
	_place(Prop.Kind.CANDLES, Vector2(354, -150))
	_place(Prop.Kind.LOG_LANTERN, Vector2(232, -190))
	_place(Prop.Kind.BENCH, Vector2(470, -80))
	_place(Prop.Kind.BENCH, Vector2(-240, 70))
	_place(Prop.Kind.BENCH, Vector2(150, 110))


# Lantern posts along the paths (outside the central area).
func _build_lamps() -> void:
	for x: int in [200, 340, 540]:
		_place(Prop.Kind.LAMP_POST, Vector2(x, -14))
	for x: int in [-200, -260]:
		_place(Prop.Kind.LAMP_POST, Vector2(x, 38))
	_place(Prop.Kind.LAMP_POST, Vector2(-30, 160))
	_place(Prop.Kind.LAMP_POST, Vector2(32, 240))
	_place(Prop.Kind.LAMP_POST, Vector2(-30, 290))
	_place(Prop.Kind.LAMP_POST, Vector2(172, -126))


# Hollow trees and bushes forming the visual border of the arena.
func _build_edge_trees() -> void:
	var tree_kinds: Array = [Prop.Kind.HOLLOW_TREE_A, Prop.Kind.HOLLOW_TREE_B]
	var x: float = -600.0
	while x < 610.0:
		_try_place(tree_kinds[_rng.randi() % 2], Vector2(x + _rng.randf_range(-8, 8), -316 + _rng.randf_range(-6, 6)))
		_try_place(tree_kinds[_rng.randi() % 2], Vector2(x + _rng.randf_range(-8, 8), 352 + _rng.randf_range(-4, 0)))
		x += _rng.randf_range(62, 96)
	var y: float = -240.0
	while y < 330.0:
		_try_place(tree_kinds[_rng.randi() % 2], Vector2(-616 + _rng.randf_range(-3, 3), y))
		_try_place(tree_kinds[_rng.randi() % 2], Vector2(616 + _rng.randf_range(-3, 3), y))
		y += _rng.randf_range(70, 100)
	# Bushes next to the trees
	for i: int in 16:
		var pos: Vector2 = Vector2.ZERO
		if _rng.randf() < 0.5:
			pos = Vector2(_rng.randf_range(-600, 600), -300.0 if _rng.randf() < 0.5 else 338.0)
		else:
			pos = Vector2(-596.0 if _rng.randf() < 0.5 else 596.0, _rng.randf_range(-260, 320))
		_try_place(Prop.Kind.BUSH_A if _rng.randf() < 0.5 else Prop.Kind.BUSH_B, pos)


# Scattered decoration: pumpkins, candles, leaves, bushes and a few inner trees.
func _build_filler() -> void:
	var area: Rect2 = Rect2(-590, -290, 1180, 620)
	_scatter([Prop.Kind.PUMPKIN_PLAIN, Prop.Kind.PUMPKIN_SMILE, Prop.Kind.PUMPKIN_GRIN], 14, area)
	_scatter([Prop.Kind.CANDLES], 6, area)
	_scatter([Prop.Kind.BUSH_A, Prop.Kind.BUSH_B], 10, area)
	_scatter([Prop.Kind.HOLLOW_TREE_A, Prop.Kind.HOLLOW_TREE_B], 7, area)
	_scatter([Prop.Kind.LEAVES_A, Prop.Kind.LEAVES_B], 26, area)
	_scatter([Prop.Kind.GRAVE_CROSS, Prop.Kind.GRAVE_ROUND, Prop.Kind.GRAVE_BROKEN], 6, area)


# Tries to place "count" random props inside the area, respecting the placement rules.
func _scatter(kinds: Array, count: int, area: Rect2) -> void:
	var placed: int = 0
	var tries: int = 0
	while placed < count and tries < count * 40:
		tries += 1
		var pos: Vector2 = Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))
		if _try_place(kinds[_rng.randi() % kinds.size()], pos):
			placed += 1


# Places the prop if the position respects the free center, cauldron, paths and other props.
func _try_place(kind: Prop.Kind, pos: Vector2) -> bool:
	var local: Rect2 = Prop.local_rect(kind)
	var rect: Rect2 = Rect2(pos + local.position, local.size)
	if not ARENA.encloses(rect):
		return false
	if _distance_to_rect(Vector2.ZERO, rect) < CENTER_CLEAR_RADIUS:
		return false
	if _distance_to_rect(CAULDRON_POS, rect) < CAULDRON_CLEAR_RADIUS:
		return false
	var base_band: Rect2 = Rect2(rect.position.x, rect.end.y - 10.0, rect.size.x, 10.0)
	for path_rect: Rect2 in _path_rects:
		if path_rect.grow(6.0).intersects(base_band):
			return false
	for zone: Rect2 in _keep_out:
		if zone.intersects(rect):
			return false
	var is_floor_decor: bool = (Prop.get_def(kind).get("z", 0) as int) < 0
	for other: Dictionary in _placed:
		var other_rect: Rect2 = other["rect"]
		var other_floor: bool = (Prop.get_def(other["kind"] as Prop.Kind).get("z", 0) as int) < 0
		if is_floor_decor or other_floor:
			if is_floor_decor and other_floor and other_rect.grow(-1.0).intersects(rect):
				return false
			continue
		if other_rect.grow(-3.0).intersects(rect.grow(-3.0)):
			return false
	_place(kind, pos)
	return true


# Distance from a point to the nearest rectangle (0 if inside).
func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	var nearest: Vector2 = Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
	return point.distance_to(nearest)


# Godot discards comments when saving; re-adds the [DEBUG] comment of the GroundItemSpawner.
func _restore_debug_comment() -> void:
	var path: String = ProjectSettings.globalize_path(LEVEL_PATH)
	var text: String = FileAccess.get_file_as_string(path)
	if text.contains("[DEBUG]"):
		return
	text = text.replace("\nmax_radius = ", "\n" + DEBUG_COMMENT + "max_radius = ")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
