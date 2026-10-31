class_name Cauldron
extends Node2D
## Caldeirão no mundo (um por andar): guarda o estado e mostra o destaque de interação.

@export var outline_color: Color = Color(1.0, 0.85, 0.35)
@export var outline_width: float = 1.5
@export var body_color: Color = Color(0.16, 0.16, 0.2)
@export var rim_color: Color = Color(0.32, 0.32, 0.38)
# Distância extra de alcance do interator (o caldeirão é maior que um item)
@export var interact_reach: float = 14.0

# A origem do nó é o chão (pés): y-sort pela base; o desenho sobe FEET_OFFSET px
const FEET_OFFSET: float = 13.0
# Pegada de movimento (elipse na base): obstáculo baixo, o player e os inimigos esbarram, mas os tiros passam
const FOOTPRINT_RADIUS: Vector2 = Vector2(13.0, 5.0)

var state: CauldronState = CauldronState.new()

var _outline: Line2D
var _visual: Node2D


func _ready() -> void:
	add_to_group("cauldron")
	_build_visual()
	_build_footprint()
	print("[Cauldron] - Caldeirão pronto em %s" % str(global_position))


## Mostra ou esconde o contorno (player ao alcance).
func set_highlighted(value: bool) -> void:
	if _outline != null:
		_outline.visible = value


# Desenha o pote placeholder (corpo, borda e contorno)
func _build_visual() -> void:
	_visual = Node2D.new()
	_visual.position = Vector2(0.0, -FEET_OFFSET)
	add_child(_visual)
	var body_points: PackedVector2Array = PackedVector2Array()
	for i: int in 24:
		var a: float = TAU * float(i) / 24.0
		body_points.append(Vector2(cos(a) * 14.0, sin(a) * 11.0 + 2.0))
	var body := Polygon2D.new()
	body.polygon = body_points
	body.color = body_color
	_visual.add_child(body)
	var rim_points: PackedVector2Array = PackedVector2Array()
	for i: int in 24:
		var a: float = TAU * float(i) / 24.0
		rim_points.append(Vector2(cos(a) * 11.0, sin(a) * 4.0 - 7.0))
	var rim := Polygon2D.new()
	rim.polygon = rim_points
	rim.color = rim_color
	_visual.add_child(rim)
	_outline = Line2D.new()
	_outline.points = body_points
	_outline.closed = true
	_outline.width = outline_width
	_outline.default_color = outline_color
	_outline.joint_mode = Line2D.LINE_JOINT_ROUND
	_outline.visible = false
	_visual.add_child(_outline)


# Cria o corpo estático (layer low_obstacle) com a pegada elíptica na base
func _build_footprint() -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 16:
		var a: float = TAU * float(i) / 16.0
		points.append(Vector2(cos(a) * FOOTPRINT_RADIUS.x, sin(a) * FOOTPRINT_RADIUS.y - FOOTPRINT_RADIUS.y))
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	shape.points = points
	var collider: CollisionShape2D = CollisionShape2D.new()
	collider.shape = shape
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = PhysicsLayers.LOW_OBSTACLE
	body.collision_mask = 0
	body.add_child(collider)
	add_child(body)
