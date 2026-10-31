## Gerador one-off do TileSet do Halloween Tileset.
## Uso: godot --headless --script res://tools/generate_tileset.gd
extends SceneTree

const TEXTURE_PATH: String = "res://assets/tilesets/halloween/halloween_tileset.png"
const OUTPUT_PATH: String = "res://assets/tilesets/halloween/halloween_tileset.tres"
const TILE: int = 16
const WORLD_LAYER_BIT: int = 1

# Origem (em celulas) de cada bloco 32x32 de borda da mancha laranja, por posicao na grade 3x3.
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
# [bit, lado A, lado B, diagonal]
const CORNERS: Array = [
	[TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, Vector2i(-1, 0), Vector2i(0, 1), Vector2i(-1, 1)],
	[TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)],
	[TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, Vector2i(1, 0), Vector2i(0, -1), Vector2i(1, -1)],
]

# Colisoes (em px dentro da celula 16x16): [coluna_ini, coluna_fim, linha_ini, linha_fim, Rect2]
const SOLID_CELLS: Array = [
	[1, 4, 11, 11, Rect2(0, 4, 16, 12)], # muro de tras
	[0, 0, 12, 16, Rect2(2, 0, 6, 16)], # mourao esquerdo
	[5, 5, 12, 16, Rect2(10, 0, 6, 16)], # mourao direito
	[1, 5, 19, 19, Rect2(0, 3, 16, 12)], # muro da frente
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
	print("[Level] - TileSet salvo (%d tiles, erro=%d): %s" % [count, err, OUTPUT_PATH])
	quit()


# Retorna true se a celula tem algum pixel nao transparente.
func _cell_has_pixels(image: Image, cell: Vector2i) -> bool:
	for y: int in TILE:
		for x: int in TILE:
			if image.get_pixel(cell.x * TILE + x, cell.y * TILE + y).a > 0.0:
				return true
	return false


# Conta pixels diferentes da cor base dentro da celula (a cor base e o pixel [0,0] da celula de referencia).
func _detail_pixels(image: Image, cell: Vector2i, base: Color) -> int:
	var count: int = 0
	for y: int in TILE:
		for x: int in TILE:
			var c: Color = image.get_pixel(cell.x * TILE + x, cell.y * TILE + y)
			if c.a > 0.0 and not c.is_equal_approx(base):
				count += 1
	return count


# Variacoes de chao azul recebem probabilidade proporcional a "limpeza" da celula.
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


# Chao laranja (6x4 celulas + mancha decorativa) como terreno "Orange Grass" com todos os bits.
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


# Pecas de borda da mancha: bits "laranja" so nos vizinhos internos de um remendo 6x6 (3x3 blocos).
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


# Retorna true se a celula do remendo 6x6 esta dentro da mancha.
func _inside_patch(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < 6 and cell.y >= 0 and cell.y < 6


# Poligonos de colisao (layer world) nas celulas de muro/mourao do cercado.
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
