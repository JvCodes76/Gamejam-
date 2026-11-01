## One-off generator of the Halloween Tileset's TileSet.
## Usage: godot --headless --script res://tools/generate_tileset.gd
extends SceneTree

const TEXTURE_PATH: String = "res://assets/tilesets/halloween/halloween_tileset.png"
const OUTPUT_PATH: String = "res://assets/tilesets/halloween/halloween_tileset.tres"
const TILE: int = 16
const WORLD_LAYER_BIT: int = 1

# Origin (in cells) of each 32x32 border block of the orange patch, by position in the 3x3 grid.
const PATCH_PIECES: Dictionary = {
	Vector2i(0, 0): Vector2i(14, 8), # TL
	Vector2i(1, 0): Vector2i(12, 8), # T
	Vector2i(2, 0): Vector2i(10, 8), # TR
	Vector2i(0, 1): Vector2i(16, 2), # L
	Vector2i(2, 1): Vector2i(8, 2), # R
	Vector2i(0, 2): Vector2i(14, 0), # BL
	Vector2i(1, 2): Vector2i(12, 0), # B
	Vector2i(2, 2): Vector2i(10, 0), # BR
}

const NEIGHBORS: Array = [
	[TileSet.CELL_NEIGHBOR_RIGHT_SIDE, Vector2i(1, 0)],
	[TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, Vector2i(0, 1)],
	[TileSet.CELL_NEIGHBOR_LEFT_SIDE, Vector2i(-1, 0)],
	[TileSet.CELL_NEIGHBOR_TOP_SIDE, Vector2i(0, -1)],
]
# [bit, side A, side B, diagonal]
const CORNERS: Array = [
	[TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, Vector2i(-1, 0), Vector2i(0, 1), Vector2i(-1, 1)],
	[TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)],
	[TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, Vector2i(1, 0), Vector2i(0, -1), Vector2i(1, -1)],
]

# Collisions (in px within the 16x16 cell): [start_column, end_column, start_row, end_row, Rect2]
const SOLID_CELLS: Array = [
	[1, 4, 11, 11, Rect2(0, 4, 16, 12)], # back wall
	[0, 0, 12, 16, Rect2(2, 0, 6, 16)], # left gatepost
	[5, 5, 12, 16, Rect2(10, 0, 6, 16)], # right gatepost
	[1, 5, 19, 19, Rect2(0, 3, 16, 12)], # front wall
]


func _init() -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(TEXTURE_PATH))
	var texture: Texture2D = load(TEXTURE_PATH)
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, WORLD_LAYER_BIT)
	tile_set.set_physics_layer_collision_mask(0, 0)
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 0, "Orange Grass")
	tile_set.set_terrain_color(0, 0, Color(0.78, 0.42, 0.4))

	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	tile_set.add_source(source, 0)

	var count: int = 0
	var cols: int = image.get_width() / TILE
	var rows: int = image.get_height() / TILE
	for row: int in rows:
		for col: int in cols:
			if _cell_has_pixels(image, Vector2i(col, row)):
				source.create_tile(Vector2i(col, row))
				count += 1

	_setup_blue_probabilities(source, image)
	_setup_orange_terrain(source, image)
	_setup_patch_terrain(source)
	_setup_collisions(source)

	var err: Error = ResourceSaver.save(tile_set, OUTPUT_PATH)
	print("[Level] - TileSet saved (%d tiles, error=%d): %s" % [count, err, OUTPUT_PATH])
	quit()


# Returns true if the cell has any non-transparent pixel.
func _cell_has_pixels(image: Image, cell: Vector2i) -> bool:
	for y: int in TILE:
		for x: int in TILE:
			if image.get_pixel(cell.x * TILE + x, cell.y * TILE + y).a > 0.0:
				return true
	return false


# Counts pixels different from the base color inside the cell (the base color is the pixel [0,0] of the reference cell).
func _detail_pixels(image: Image, cell: Vector2i, base: Color) -> int:
	var count: int = 0
	for y: int in TILE:
		for x: int in TILE:
			var c: Color = image.get_pixel(cell.x * TILE + x, cell.y * TILE + y)
			if c.a > 0.0 and not c.is_equal_approx(base):
				count += 1
	return count


# Blue floor variations get a probability proportional to the cell's "cleanliness".
func _setup_blue_probabilities(source: TileSetAtlasSource, image: Image) -> void:
	var base: Color = image.get_pixel(6 * TILE, 2 * TILE)
	for row: int in range(2, 8):
		for col: int in range(2, 20):
			var cell: Vector2i = Vector2i(col, row)
			if not source.has_tile(cell):
				continue
			var data: TileData = source.get_tile_data(cell, 0)
			var detail: int = _detail_pixels(image, cell, base)
			data.probability = 4.0 if detail == 0 else (0.5 if detail <= 12 else 0.05)


# Orange floor (6x4 cells + decorative patch) as an "Orange Grass" terrain with all bits.
func _setup_orange_terrain(source: TileSetAtlasSource, image: Image) -> void:
	var base: Color = image.get_pixel(0, 0)
	var cells: Array[Vector2i] = []
	for row: int in 4:
		for col: int in 6:
			cells.append(Vector2i(col, row))
	for row: int in 2:
		for col: int in range(16, 18):
			cells.append(Vector2i(col, row))
	for cell: Vector2i in cells:
		var data: TileData = source.get_tile_data(cell, 0)
		data.terrain_set = 0
		data.terrain = 0
		for n: Array in NEIGHBORS:
			data.set_terrain_peering_bit(n[0], 0)
		for c: Array in CORNERS:
			data.set_terrain_peering_bit(c[0], 0)
		var detail: int = _detail_pixels(image, cell, base)
		data.probability = 4.0 if detail == 0 else (1.0 if detail <= 12 else 0.3)


# Patch edge pieces: "orange" bits only on the inner neighbors of a 6x6 patch (3x3 blocks).
func _setup_patch_terrain(source: TileSetAtlasSource) -> void:
	for block: Vector2i in PATCH_PIECES:
		var origin: Vector2i = PATCH_PIECES[block]
		for j: int in 2:
			for i: int in 2:
				var patch_cell: Vector2i = block * 2 + Vector2i(i, j)
				var data: TileData = source.get_tile_data(origin + Vector2i(i, j), 0)
				data.terrain_set = 0
				data.terrain = 0
				for n: Array in NEIGHBORS:
					if _inside_patch(patch_cell + n[1]):
						data.set_terrain_peering_bit(n[0], 0)
				for c: Array in CORNERS:
					if _inside_patch(patch_cell + c[1]) and _inside_patch(patch_cell + c[2]) and _inside_patch(patch_cell + c[3]):
						data.set_terrain_peering_bit(c[0], 0)
				data.probability = 1.0


# Returns true if the cell of the 6x6 patch is inside the patch.
func _inside_patch(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < 6 and cell.y >= 0 and cell.y < 6


# Collision polygons (world layer) on the wall/gatepost cells of the enclosure.
func _setup_collisions(source: TileSetAtlasSource) -> void:
	for entry: Array in SOLID_CELLS:
		for row: int in range(entry[2], entry[3] + 1):
			for col: int in range(entry[0], entry[1] + 1):
				var cell: Vector2i = Vector2i(col, row)
				if not source.has_tile(cell):
					continue
				var rect: Rect2 = entry[4]
				var half: Vector2 = Vector2(TILE, TILE) / 2.0
				var data: TileData = source.get_tile_data(cell, 0)
				data.add_collision_polygon(0)
				data.set_collision_polygon_points(0, 0, PackedVector2Array([
					rect.position - half,
					Vector2(rect.end.x, rect.position.y) - half,
					rect.end - half,
					Vector2(rect.position.x, rect.end.y) - half,
				]))
