class_name Cauldron
extends Node2D
## Caldeirão no mundo (um por andar): guarda o estado e mostra o destaque de interação.

@export var outline_color: Color = Color(1.0, 0.85, 0.35)
@export var outline_width: float = 1.5
@export var body_color: Color = Color(0.16, 0.16, 0.2)
@export var rim_color: Color = Color(0.32, 0.32, 0.38)
# Distância extra de alcance do interator (o caldeirão é maior que um item)
@export var interact_reach: float = 14.0

var state: CauldronState = CauldronState.new()

var _outline: Line2D


func _ready() -> void:
	add_to_group("cauldron")
	_build_visual()
	print("[Cauldron] - Caldeirão pronto em %s" % str(global_position))


## Mostra ou esconde o contorno (player ao alcance).
func set_highlighted(value: bool) -> void:
	if _outline != null:
		_outline.visible = value


# Desenha o pote placeholder (corpo, borda e contorno)
func _build_visual() -> void:
	var body_points: PackedVector2Array = PackedVector2Array()
	for i: int in 24:
		var a: float = TAU * float(i) / 24.0
		body_points.append(Vector2(cos(a) * 14.0, sin(a) * 11.0 + 2.0))
	var body := Polygon2D.new()
	body.polygon = body_points
	body.color = body_color
	add_child(body)
	var rim_points: PackedVector2Array = PackedVector2Array()
	for i: int in 24:
		var a: float = TAU * float(i) / 24.0
		rim_points.append(Vector2(cos(a) * 11.0, sin(a) * 4.0 - 7.0))
	var rim := Polygon2D.new()
	rim.polygon = rim_points
	rim.color = rim_color
	add_child(rim)
	_outline = Line2D.new()
	_outline.points = body_points
	_outline.closed = true
	_outline.width = outline_width
	_outline.default_color = outline_color
	_outline.joint_mode = Line2D.LINE_JOINT_ROUND
	_outline.visible = false
	add_child(_outline)
