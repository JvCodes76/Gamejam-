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
const WORLD_LAYER_BIT: int = 1

# region: recorte no atlas (px). origin: ponto da regiao que fica na origem do no (padrao: base-centro).
# rects: colisoes na regiao (px), so na base. z: z_index (folhas ficam abaixo de tudo).
const DEFS: Dictionary = {
	Kind.GRAVE_CROSS: {"region": Rect2(98, 193, 29, 31), "rects": [Rect2(7, 20, 15, 9)]},
	Kind.GRAVE_ROUND: {"region": Rect2(130, 196, 29, 28), "rects": [Rect2(5, 18, 19, 8)]},
	Kind.GRAVE_BROKEN: {"region": Rect2(162, 197, 29, 27), "rects": [Rect2(5, 17, 19, 8)]},
	Kind.DIRT_MOUND: {"region": Rect2(194, 192, 29, 31), "rects": []},
	Kind.CANDLES: {"region": Rect2(233, 204, 16, 16), "rects": []},
	Kind.PUMPKIN_PLAIN: {"region": Rect2(258, 199, 27, 24), "rects": []},
	Kind.PUMPKIN_SMILE: {"region": Rect2(229, 231, 24, 20), "rects": []},
	Kind.PUMPKIN_GRIN: {"region": Rect2(258, 231, 27, 22), "rects": []},
	Kind.LAMP_POST: {"region": Rect2(298, 203, 13, 48), "rects": [Rect2(3, 42, 7, 5)]},
	Kind.HOLLOW_TREE_A: {"region": Rect2(96, 299, 32, 53), "rects": [Rect2(7, 42, 18, 10)]},
	Kind.HOLLOW_TREE_B: {"region": Rect2(128, 299, 32, 53), "rects": [Rect2(7, 42, 18, 10)]},
	Kind.BUSH_A: {"region": Rect2(160, 288, 32, 31), "rects": []},
	Kind.BUSH_B: {"region": Rect2(162, 321, 29, 28), "rects": []},
	Kind.LEAVES_A: {"region": Rect2(197, 297, 23, 17), "rects": [], "z": -5},
	Kind.LEAVES_B: {"region": Rect2(194, 326, 25, 21), "rects": [], "z": -5},
	Kind.BENCH: {"region": Rect2(226, 272, 28, 12), "rects": [Rect2(1, 3, 26, 8)]},
	Kind.LOG_LANTERN: {"region": Rect2(258, 263, 28, 21), "rects": [Rect2(1, 10, 26, 10)]},
	# Arco: so os pilares sao solidos (vao livre); com portao, o portao tambem bloqueia
	Kind.ARCH_OPEN: {"region": Rect2(96, 224, 64, 64), "rects": [Rect2(1, 44, 12, 19), Rect2(51, 44, 12, 19)]},
	Kind.ARCH_GATE: {"region": Rect2(160, 224, 64, 66), "rects": [Rect2(1, 44, 12, 19), Rect2(51, 44, 12, 19), Rect2(13, 52, 38, 11)]},
	# Cercado octogonal em 3 pecas; ordenacao por y na parede de tras (top) e na base (frentes).
	# O vao de 32 px na frente e a entrada do cemiterio.
	Kind.FENCE_TOP: {"region": Rect2(0, 160, 96, 112), "origin": Vector2(48, 32), "rects": [Rect2(10, 18, 76, 14), Rect2(1, 32, 7, 80), Rect2(88, 32, 7, 80)]},
	Kind.FENCE_BOTTOM_LEFT: {"region": Rect2(0, 272, 32, 48), "rects": [Rect2(1, 0, 7, 28), Rect2(0, 28, 32, 18)]},
	Kind.FENCE_BOTTOM_RIGHT: {"region": Rect2(64, 272, 32, 48), "rects": [Rect2(24, 0, 7, 28), Rect2(0, 28, 32, 18)]},
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

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _body: StaticBody2D = $Body


func _ready() -> void:
	_build()


## Retorna a definicao (regiao, colisoes) de um tipo de prop.
static func get_def(prop_kind: Kind) -> Dictionary:
	return DEFS[prop_kind]


## Retorna o retangulo do sprite em coordenadas locais (relativo a origem do no).
static func local_rect(prop_kind: Kind) -> Rect2:
	var def: Dictionary = DEFS[prop_kind]
	var region: Rect2 = def["region"]
	var origin: Vector2 = def.get("origin", Vector2(region.size.x / 2.0, region.size.y))
	return Rect2(-origin, region.size)


## Aplica regiao do atlas, offset e colisao do tipo atual.
func _build() -> void:
	if not is_node_ready():
		return
	var def: Dictionary = DEFS[kind]
	var region: Rect2 = def["region"]
	var origin: Vector2 = def.get("origin", Vector2(region.size.x / 2.0, region.size.y))
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = TILESET_TEXTURE
	atlas.region = region
	_sprite.texture = atlas
	_sprite.centered = false
	_sprite.offset = -origin
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = def.get("z", 0)
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.free()
	if not solid:
		return
	for rect: Rect2 in def["rects"]:
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = rect.size
		var collider: CollisionShape2D = CollisionShape2D.new()
		collider.shape = shape
		collider.position = rect.position + rect.size / 2.0 - origin
		_body.add_child(collider)
