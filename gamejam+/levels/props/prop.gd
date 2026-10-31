@tool
class_name Prop
extends Node2D
## Objeto de cenario do Halloween Tileset: sprite recortado do atlas e colisao so na base.
## A origem do no fica na base do objeto (ou no "origin" da regiao), para o y-sort funcionar.

enum Kind {
	GRAVE_CROSS,
	GRAVE_ROUND,
	GRAVE_BROKEN,
	DIRT_MOUND,
	CANDLES,
	PUMPKIN_PLAIN,
	PUMPKIN_SMILE,
	PUMPKIN_GRIN,
	LAMP_POST,
	HOLLOW_TREE_A,
	HOLLOW_TREE_B,
	BUSH_A,
	BUSH_B,
	LEAVES_A,
	LEAVES_B,
	BENCH,
	LOG_LANTERN,
	ARCH_OPEN,
	ARCH_GATE,
	FENCE_TOP,
	FENCE_BOTTOM_LEFT,
	FENCE_BOTTOM_RIGHT,
}

const TILESET_TEXTURE: Texture2D = preload("res://assets/tilesets/halloween/halloween_tileset.png")

# region: recorte no atlas (px). origin: ponto da regiao que fica na origem do no (padrao: base-centro = pes).
# rects: pegada (footprint) na base, em px da regiao; cada item e um Rect2 ou um poligono convexo (Array de Vector2).
# tall: obstaculo ALTO (arvore, poste, arco, muro/cerca): bloqueia movimento (layer world) e projeteis (volume na layer
#   bullet_blocker, a pegada esticada para cima em "vol" px, ja que o tiro sai da altura do corpo do player).
#   Sem "tall" e com rects: obstaculo BAIXO (lapide, banco, arbusto, tronco): so bloqueia movimento (layer low_obstacle).
# z: z_index (folhas ficam abaixo de tudo).
const TREE_FOOT: Array = [Vector2(9, 43), Vector2(23, 43), Vector2(24, 45), Vector2(24, 50), Vector2(22, 52), Vector2(10, 52), Vector2(8, 50), Vector2(8, 45)]
const DEFS: Dictionary = {
	Kind.GRAVE_CROSS: {"region": Rect2(98, 193, 29, 31), "rects": [Rect2(7, 20, 15, 9)]},
	Kind.GRAVE_ROUND: {"region": Rect2(130, 196, 29, 28), "rects": [Rect2(5, 18, 19, 8)]},
	Kind.GRAVE_BROKEN: {"region": Rect2(162, 197, 29, 27), "rects": [Rect2(5, 17, 19, 8)]},
	Kind.DIRT_MOUND: {"region": Rect2(194, 192, 29, 31), "rects": []},
	Kind.CANDLES: {"region": Rect2(233, 204, 16, 16), "rects": []},
	Kind.PUMPKIN_PLAIN: {"region": Rect2(258, 199, 27, 24), "rects": [Rect2(4, 15, 19, 8)]},
	Kind.PUMPKIN_SMILE: {"region": Rect2(229, 231, 24, 20), "rects": [Rect2(3, 11, 18, 8)]},
	Kind.PUMPKIN_GRIN: {"region": Rect2(258, 231, 27, 22), "rects": [Rect2(4, 13, 19, 8)]},
	Kind.LAMP_POST: {"region": Rect2(298, 203, 13, 48), "rects": [Rect2(3, 42, 7, 5)], "tall": true, "vol": 40},
	Kind.HOLLOW_TREE_A: {"region": Rect2(96, 299, 32, 53), "rects": [TREE_FOOT], "tall": true, "vol": 36},
	Kind.HOLLOW_TREE_B: {"region": Rect2(128, 299, 32, 53), "rects": [TREE_FOOT], "tall": true, "vol": 36},
	Kind.BUSH_A: {"region": Rect2(160, 288, 32, 31), "rects": [Rect2(6, 19, 20, 10)]},
	Kind.BUSH_B: {"region": Rect2(162, 321, 29, 28), "rects": [Rect2(7, 17, 15, 9)]},
	Kind.LEAVES_A: {"region": Rect2(197, 297, 23, 17), "rects": [], "z": -5},
	Kind.LEAVES_B: {"region": Rect2(194, 326, 25, 21), "rects": [], "z": -5},
	Kind.BENCH: {"region": Rect2(226, 272, 28, 12), "rects": [Rect2(1, 3, 26, 8)]},
	Kind.LOG_LANTERN: {"region": Rect2(258, 263, 28, 21), "rects": [Rect2(1, 10, 26, 10)]},
	# Arco: so os pilares sao solidos (vao livre); com portao, o portao tambem bloqueia
	Kind.ARCH_OPEN: {"region": Rect2(96, 224, 64, 64), "rects": [Rect2(1, 44, 12, 19), Rect2(51, 44, 12, 19)], "tall": true, "vol": 28},
	Kind.ARCH_GATE: {"region": Rect2(160, 224, 64, 66), "origin": Vector2(32, 64), "rects": [Rect2(1, 44, 12, 19), Rect2(51, 44, 12, 19), Rect2(13, 52, 38, 11)], "tall": true, "vol": 28},
	# Cercado octogonal em 3 pecas; ordenacao por y na parede de tras (top) e na base (frentes).
	# O vao de 32 px na frente e a entrada do cemiterio. As paredes diagonais (asas) sao paralelogramos.
	Kind.FENCE_TOP: {"region": Rect2(0, 160, 96, 112), "origin": Vector2(48, 32), "tall": true, "vol": 24, "rects": [
		Rect2(32, 18.5, 32, 13),
		[Vector2(6, 29), Vector2(32, 18.5), Vector2(32, 31.5), Vector2(6, 41.5)],
		[Vector2(90, 29), Vector2(64, 18.5), Vector2(64, 31.5), Vector2(90, 41.5)],
		Rect2(1, 32, 7, 80), Rect2(88, 32, 7, 80)]},
	Kind.FENCE_BOTTOM_LEFT: {"region": Rect2(0, 272, 32, 48), "tall": true, "vol": 24, "rects": [
		Rect2(1, 0, 7, 28),
		[Vector2(3, 25), Vector2(32, 38), Vector2(32, 47.5), Vector2(3, 34)]]},
	Kind.FENCE_BOTTOM_RIGHT: {"region": Rect2(64, 272, 32, 48), "tall": true, "vol": 24, "rects": [
		Rect2(24, 0, 7, 28),
		[Vector2(29, 25), Vector2(0, 38), Vector2(0, 47.5), Vector2(29, 34)]]},
}

@export var kind: Kind = Kind.GRAVE_CROSS:
	set(value):
		kind = value
		_build()
## Se falso, o objeto vira apenas decoracao (sem colisao).
@export var solid: bool = true:
	set(value):
		solid = value
		_build()

## Verdadeiro se o tipo e um obstaculo alto (os projeteis tambem sao bloqueados).
var blocks_projectiles: bool:
	get:
		return is_tall(kind)

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _body: StaticBody2D = $Body
@onready var _volume: StaticBody2D = $Volume


func _ready() -> void:
	_build()


## Retorna a definicao (regiao, colisoes) de um tipo de prop.
static func get_def(prop_kind: Kind) -> Dictionary:
	return DEFS[prop_kind]


## Retorna true se o tipo e um obstaculo alto (bloqueia movimento e projeteis).
static func is_tall(prop_kind: Kind) -> bool:
	return DEFS[prop_kind].get("tall", false)


## Retorna o ponto da regiao que fica na origem do no (pes do objeto).
static func origin_of(prop_kind: Kind) -> Vector2:
	var def: Dictionary = DEFS[prop_kind]
	var region: Rect2 = def["region"]
	return def.get("origin", Vector2(region.size.x / 2.0, region.size.y))


## Retorna o retangulo do sprite em coordenadas locais (relativo a origem do no).
static func local_rect(prop_kind: Kind) -> Rect2:
	var def: Dictionary = DEFS[prop_kind]
	var region: Rect2 = def["region"]
	return Rect2(-origin_of(prop_kind), region.size)


## Retorna os pontos (px da regiao) de uma pegada, seja Rect2 ou poligono.
static func footprint_points(entry: Variant) -> PackedVector2Array:
	if entry is Rect2:
		var rect: Rect2 = entry
		return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in entry as Array:
		points.append(point)
	return points


## Forma de colisao de uma pegada (Rect2 vira retangulo; poligono vira convexo), com os pontos deslocados por "shift".
static func make_shape(points: PackedVector2Array, shift: Vector2) -> Shape2D:
	var shifted: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		shifted.append(point + shift)
	var convex: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	convex.set_point_cloud(shifted)
	return convex


## Volume de bloqueio de projeteis: a pegada esticada para cima em "extend" px (casco convexo).
static func volume_points(points: PackedVector2Array, extend: float) -> PackedVector2Array:
	var cloud: PackedVector2Array = PackedVector2Array(points)
	for point: Vector2 in points:
		cloud.append(point + Vector2(0.0, -extend))
	return Geometry2D.convex_hull(cloud)


## Aplica regiao do atlas, offset e colisao do tipo atual.
func _build() -> void:
	if not is_node_ready():
		return
	var def: Dictionary = DEFS[kind]
	var region: Rect2 = def["region"]
	var origin: Vector2 = origin_of(kind)
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = TILESET_TEXTURE
	atlas.region = region
	_sprite.texture = atlas
	_sprite.centered = false
	_sprite.offset = -origin
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = def.get("z", 0)
	for body: StaticBody2D in [_body, _volume]:
		for child: Node in body.get_children():
			body.remove_child(child)
			child.free()
	if not solid:
		return
	var tall: bool = is_tall(kind)
	_body.collision_layer = PhysicsLayers.WORLD if tall else PhysicsLayers.LOW_OBSTACLE
	_volume.collision_layer = PhysicsLayers.BULLET_BLOCKER
	for entry: Variant in def["rects"]:
		var points: PackedVector2Array = footprint_points(entry)
		_add_collider(_body, make_shape(points, Vector2.ZERO), -origin)
		if tall:
			var hull: PackedVector2Array = volume_points(points, float(def.get("vol", 30)))
			_add_collider(_volume, make_shape(hull, Vector2.ZERO), -origin)


## Cria um CollisionShape2D no corpo, deslocado para a origem do no.
func _add_collider(body: StaticBody2D, shape: Shape2D, offset: Vector2) -> void:
	var collider: CollisionShape2D = CollisionShape2D.new()
	collider.shape = shape
	collider.position = offset
	body.add_child(collider)
