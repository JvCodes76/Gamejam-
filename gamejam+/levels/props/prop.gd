@tool
class_name Prop
extends Node2D
## Scenery object from the Halloween Tileset: sprite cropped from the atlas and collision only at the base.
## The node origin is at the base of the object (or at the region's "origin"), so y-sort works.

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

# region: crop in the atlas (px). origin: point of the region that sits at the node origin (default: bottom-center = feet).
# rects: footprint at the base, in region px; each item is a Rect2 or a convex polygon (Array of Vector2).
# tall: TALL obstacle (tree, post, arch, wall/fence): blocks movement (world layer) and projectiles (volume on the layer
#   bullet_blocker, the footprint stretched upward by "vol" px, since the shot leaves from the height of the player's body).
#   Without "tall" and with rects: LOW obstacle (tombstone, bench, bush, log): only blocks movement (low_obstacle layer).
# shots: low obstacle that also stops projectiles (tombstones): gets the bullet_blocker volume of height "vol",
#   but stays low for movement (bats and ghosts pass over).
# z: z_index (leaves stay below everything).
const TREE_FOOT: Array = [Vector2(9, 43), Vector2(23, 43), Vector2(24, 45), Vector2(24, 50), Vector2(22, 52), Vector2(10, 52), Vector2(8, 50), Vector2(8, 45)]
const DEFS: Dictionary = {
	Kind.GRAVE_CROSS: {"region": Rect2(98, 193, 29, 31), "rects": [Rect2(7, 20, 15, 9)], "shots": true, "vol": 18},
	Kind.GRAVE_ROUND: {"region": Rect2(130, 196, 29, 28), "rects": [Rect2(5, 18, 19, 8)], "shots": true, "vol": 16},
	Kind.GRAVE_BROKEN: {"region": Rect2(162, 197, 29, 27), "rects": [Rect2(5, 17, 19, 8)], "shots": true, "vol": 14},
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
	# Arch: only the pillars are solid (free gap); with a gate, the gate also blocks
	Kind.ARCH_OPEN: {"region": Rect2(96, 224, 64, 64), "rects": [Rect2(1, 44, 12, 19), Rect2(51, 44, 12, 19)], "tall": true, "vol": 28},
	Kind.ARCH_GATE: {"region": Rect2(160, 224, 64, 66), "origin": Vector2(32, 64), "rects": [Rect2(1, 44, 12, 19), Rect2(51, 44, 12, 19), Rect2(13, 52, 38, 11)], "tall": true, "vol": 28},
	# Octagonal enclosure in 3 pieces; y-sorting on the back wall (top) and on the base (fronts).
	# The 32 px gap at the front is the graveyard entrance. The diagonal walls (wings) are parallelograms.
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
## If false, the object becomes decoration only (no collision).
@export var solid: bool = true:
	set(value):
		solid = value
		_build()

## True if the type stops projectiles (tall obstacles and tombstones).
var blocks_projectiles: bool:
	get:
		return stops_shots(kind)

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _body: StaticBody2D = $Body
@onready var _volume: StaticBody2D = $Volume


func _ready() -> void:
	_build()


## Returns the definition (region, collisions) of a prop type.
static func get_def(prop_kind: Kind) -> Dictionary:
	return DEFS[prop_kind]


## Returns true if the type is a tall obstacle (blocks movement and projectiles).
static func is_tall(prop_kind: Kind) -> bool:
	return DEFS[prop_kind].get("tall", false)


## Returns true if the type stops projectiles: a tall obstacle or a low one marked with "shots".
static func stops_shots(prop_kind: Kind) -> bool:
	return is_tall(prop_kind) or DEFS[prop_kind].get("shots", false)


## Returns the point of the region that sits at the node origin (the object's feet).
static func origin_of(prop_kind: Kind) -> Vector2:
	var def: Dictionary = DEFS[prop_kind]
	var region: Rect2 = def["region"]
	return def.get("origin", Vector2(region.size.x / 2.0, region.size.y))


## Returns the sprite rectangle in local coordinates (relative to the node origin).
static func local_rect(prop_kind: Kind) -> Rect2:
	var def: Dictionary = DEFS[prop_kind]
	var region: Rect2 = def["region"]
	return Rect2(-origin_of(prop_kind), region.size)


## Returns the points (region px) of a footprint, whether Rect2 or polygon.
static func footprint_points(entry: Variant) -> PackedVector2Array:
	if entry is Rect2:
		var rect: Rect2 = entry
		return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in entry as Array:
		points.append(point)
	return points


## Collision shape of a footprint (Rect2 becomes a rectangle; polygon becomes convex), with the points shifted by "shift".
static func make_shape(points: PackedVector2Array, shift: Vector2) -> Shape2D:
	var shifted: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		shifted.append(point + shift)
	var convex: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	convex.set_point_cloud(shifted)
	return convex


## Projectile blocking volume: the footprint stretched upward by "extend" px (convex hull).
static func volume_points(points: PackedVector2Array, extend: float) -> PackedVector2Array:
	var cloud: PackedVector2Array = PackedVector2Array(points)
	for point: Vector2 in points:
		cloud.append(point + Vector2(0.0, -extend))
	return Geometry2D.convex_hull(cloud)


## Applies the atlas region, offset and collision of the current type.
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
	var shots: bool = stops_shots(kind)
	_body.collision_layer = PhysicsLayers.WORLD if tall else PhysicsLayers.LOW_OBSTACLE
	_volume.collision_layer = PhysicsLayers.BULLET_BLOCKER
	for entry: Variant in def["rects"]:
		var points: PackedVector2Array = footprint_points(entry)
		_add_collider(_body, make_shape(points, Vector2.ZERO), -origin)
		if shots:
			var hull: PackedVector2Array = volume_points(points, float(def.get("vol", 30)))
			_add_collider(_volume, make_shape(hull, Vector2.ZERO), -origin)


## Creates a CollisionShape2D on the body, offset to the node origin.
func _add_collider(body: StaticBody2D, shape: Shape2D, offset: Vector2) -> void:
	var collider: CollisionShape2D = CollisionShape2D.new()
	collider.shape = shape
	collider.position = offset
	body.add_child(collider)
