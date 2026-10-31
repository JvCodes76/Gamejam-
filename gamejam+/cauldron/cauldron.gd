class_name Cauldron
extends Node2D
## Caldeirão no mundo (um por andar): guarda o estado e mostra o destaque de interação.

@export var outline_color: Color = Color(1.0, 0.85, 0.35)
@export var outline_width: float = 1.5
@export var body_color: Color = Color(0.16, 0.16, 0.2)
@export var rim_color: Color = Color(0.32, 0.32, 0.38)
# Distância extra de alcance do interator (o caldeirão é maior que um item)
@export var interact_reach: float = 14.0
# Cor das bolhas sem poção pronta
@export var idle_bubble_color: Color = Color(0.45, 0.85, 0.35)

# A origem do nó é o chão (pés): y-sort pela base; o desenho sobe FEET_OFFSET px
const FEET_OFFSET: float = 13.0
# Pegada de movimento (elipse na base): obstáculo baixo, o player e os inimigos esbarram, mas os tiros passam
const FOOTPRINT_RADIUS: Vector2 = Vector2(13.0, 5.0)

var state: CauldronState = CauldronState.new()

var _outline: Line2D
var _visual: Node2D
var _bubbles: CPUParticles2D
var _steam: CPUParticles2D
var _bubble_color: Color = Color.TRANSPARENT


func _ready() -> void:
	add_to_group("cauldron")
	_build_visual()
	_build_footprint()
	_build_particles()
	EventBus.potion_brewed.connect(_on_potion_brewed)
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


func _process(_delta: float) -> void:
	var color: Color = state.potion.color if state.potion != null else idle_bubble_color
	if color != _bubble_color:
		_set_bubble_color(color)


# Bolhas na boca do caldeirão (cor da mistura) e vapor subindo (Fase 2: sprites de bolha/vapor)
func _build_particles() -> void:
	var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var texture: ImageTexture = ImageTexture.create_from_image(img)
	_bubbles = CPUParticles2D.new()
	_bubbles.texture = texture
	_bubbles.position = Vector2(0.0, -7.0)
	_bubbles.amount = 6
	_bubbles.lifetime = 0.7
	_bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_bubbles.emission_rect_extents = Vector2(8.0, 1.5)
	_bubbles.direction = Vector2.UP
	_bubbles.spread = 15.0
	_bubbles.initial_velocity_min = 4.0
	_bubbles.initial_velocity_max = 10.0
	_bubbles.gravity = Vector2.ZERO
	_bubbles.scale_amount_min = 0.5
	_bubbles.scale_amount_max = 1.5
	_visual.add_child(_bubbles)
	_steam = CPUParticles2D.new()
	_steam.texture = texture
	_steam.position = Vector2(0.0, -9.0)
	_steam.amount = 5
	_steam.lifetime = 1.6
	_steam.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_steam.emission_rect_extents = Vector2(6.0, 1.0)
	_steam.direction = Vector2.UP
	_steam.spread = 20.0
	_steam.initial_velocity_min = 6.0
	_steam.initial_velocity_max = 12.0
	_steam.gravity = Vector2(4.0, -2.0)
	_steam.scale_amount_min = 1.5
	_steam.scale_amount_max = 3.0
	var steam_fade: Gradient = Gradient.new()
	steam_fade.set_color(0, Color(0.85, 0.85, 0.9, 0.35))
	steam_fade.set_color(1, Color(0.85, 0.85, 0.9, 0.0))
	_steam.color_ramp = steam_fade
	_visual.add_child(_steam)
	_set_bubble_color(idle_bubble_color)


func _set_bubble_color(color: Color) -> void:
	_bubble_color = color
	var fade: Gradient = Gradient.new()
	fade.set_color(0, color.lightened(0.3))
	fade.set_color(1, Color(color, 0.0))
	_bubbles.color_ramp = fade


# Poção pronta neste caldeirão: "puff" de partículas, flash e tremida leve
func _on_potion_brewed(color: Color, at: Vector2) -> void:
	if at.distance_to(global_position) > 4.0:
		return
	_set_bubble_color(color)
	ImpactEffect.spawn_burst(_visual, Vector2(0.0, -8.0), 22.0, color, 24, 0.7, 2.0, 1.4)
	_visual.modulate = Color(2.5, 2.5, 2.5)
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "modulate", Color.WHITE, 0.3)
	EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_BREW)
	EventBus.play_sfx_requested.emit("brew")
	print("[Cauldron] - poção pronta (puff)")


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
