class_name CauldronVessel
extends Bag
## Recipiente físico do caldeirão: reaproveita a bolsa, com paredes grossas, líquido e tampa.

@export var size_multiplier: float = 1.0
# Sprite opcional que substitui o desenho placeholder
@export var vessel_texture: Texture2D
@export var wall_color: Color = Color(0.2, 0.2, 0.25)
@export var wall_line_color: Color = Color(0.42, 0.42, 0.5)
@export var liquid_wobble: float = 1.2
@export var liquid_wobble_speed: float = 2.5

var liquid: Polygon2D
var lid: StaticBody2D
var bubbles: CPUParticles2D

var _liquid_surface_y: float = 0.0
var _has_liquid: bool = false
var _time: float = 0.0
var _liquid_poly: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	interior = CauldronLayout.scaled_interior(size_multiplier)
	mouth_rect = CauldronLayout.scaled_mouth(size_multiplier)
	wall_thickness = CauldronLayout.WALL_THICKNESS
	super._ready()
	_build_liquid()
	_build_lid()
	_build_bubbles()


func _process(delta: float) -> void:
	if not _has_liquid:
		return
	_time += delta
	liquid.position.y = sin(_time * liquid_wobble_speed) * liquid_wobble * 0.5


# Desenha o caldeirão: paredes grossas + fundo do interior (ou sprite)
func _build_visual() -> void:
	if vessel_texture != null:
		var sprite := Sprite2D.new()
		sprite.texture = vessel_texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = -3
		add_child(sprite)
	else:
		for quad: PackedVector2Array in _wall_quads():
			var wall := Polygon2D.new()
			wall.polygon = quad
			wall.color = wall_color
			wall.z_index = -3
			add_child(wall)
	var fill := Polygon2D.new()
	fill.polygon = interior
	fill.color = bag_fill_color
	fill.z_index = -2
	add_child(fill)
	var line := Line2D.new()
	line.points = interior
	line.closed = true
	line.width = 2.0
	line.default_color = wall_line_color
	line.z_index = 1
	add_child(line)


# Caldeirão não encolhe itens na boca
func _on_mouth_entered(_body: Node2D) -> void:
	pass


func _on_mouth_exited(_body: Node2D) -> void:
	pass


# Quads das paredes (mesma geometria do colisor, sem a boca)
func _wall_quads() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for i: int in interior.size():
		var a: Vector2 = interior[i]
		var b: Vector2 = interior[(i + 1) % interior.size()]
		if mouth_rect.grow(1.0).has_point((a + b) * 0.5):
			continue
		var dir: Vector2 = (b - a).normalized()
		var n: Vector2 = Vector2(-dir.y, dir.x)
		if Geometry2D.is_point_in_polygon((a + b) * 0.5 + n * 0.5, interior):
			n = -n
		out.append(PackedVector2Array([a, b, b + n * wall_thickness, a + n * wall_thickness]))
	return out


func _build_liquid() -> void:
	liquid = Polygon2D.new()
	liquid.name = "Liquid"
	liquid.z_index = 0
	liquid.visible = false
	add_child(liquid)


# Tampa invisível: fecha a boca quando há poção pronta
func _build_lid() -> void:
	lid = StaticBody2D.new()
	lid.name = "Lid"
	lid.collision_layer = 1
	lid.collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = mouth_rect.size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = mouth_rect.get_center()
	col.disabled = true
	lid.add_child(col)
	add_child(lid)


# Bolhas subindo do líquido (ligadas só durante o preparo)
func _build_bubbles() -> void:
	bubbles = CPUParticles2D.new()
	bubbles.name = "Bubbles"
	bubbles.emitting = false
	bubbles.amount = 14
	bubbles.lifetime = 0.9
	bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bubbles.emission_rect_extents = Vector2(interior[0].abs().x * 0.9, 3.0)
	bubbles.position = Vector2(0, 20.0 * size_multiplier)
	bubbles.direction = Vector2.UP
	bubbles.spread = 15.0
	bubbles.gravity = Vector2.ZERO
	bubbles.initial_velocity_min = 25.0
	bubbles.initial_velocity_max = 45.0
	bubbles.scale_amount_min = 1.5
	bubbles.scale_amount_max = 3.0
	bubbles.color = Color(1, 1, 1, 0.55)
	bubbles.z_index = 2
	add_child(bubbles)


## Liga ou desliga as bolhas do preparo.
func set_brewing(value: bool) -> void:
	bubbles.emitting = value


## Itens com o centro dentro do interior (filhos desta e de bolsas irmãs, pois itens são arrastados entre elas).
func collect_items() -> Array[PhysicalItem]:
	var out: Array[PhysicalItem] = []
	var holders: Array[Node] = [self]
	if get_parent() != null:
		for sibling: Node in get_parent().get_children():
			if sibling is Bag and sibling != self:
				holders.append(sibling)
	for holder: Node in holders:
		for child: Node in holder.get_children():
			if child is PhysicalItem and not child.is_queued_for_deletion() and is_inside(child as PhysicalItem):
				out.append(child as PhysicalItem)
	return out


## Mostra o líquido da poção, preenchendo o interior até a altura em que a área = volume.
func show_potion(potion: PotionData) -> void:
	_liquid_poly = _liquid_polygon(potion.volume)
	_has_liquid = _liquid_poly.size() >= 3
	liquid.polygon = _liquid_poly
	liquid.color = potion.color
	liquid.visible = _has_liquid
	(lid.get_child(0) as CollisionShape2D).set_deferred("disabled", false)
	print("[Cauldron] - Líquido exibido (volume %.1f, área %.1f)" % [potion.volume, liquid_area()])


## Remove o líquido e abre a boca de novo.
func clear_potion() -> void:
	_has_liquid = false
	_liquid_poly = PackedVector2Array()
	liquid.visible = false
	liquid.position = Vector2.ZERO
	(lid.get_child(0) as CollisionShape2D).set_deferred("disabled", true)


## Área do polígono do líquido atual (0 se vazio).
func liquid_area() -> float:
	return absf(_area(_liquid_poly)) if _has_liquid else 0.0


# Corta o interior abaixo de y; bisseção da altura até a área alvo
func _liquid_polygon(volume: float) -> PackedVector2Array:
	var total: float = absf(_area(interior))
	if volume <= 0.0:
		return PackedVector2Array()
	if volume >= total:
		return interior
	var bounds: Rect2 = Rect2(interior[0], Vector2.ZERO)
	for p: Vector2 in interior:
		bounds = bounds.expand(p)
	var lo: float = bounds.position.y
	var hi: float = bounds.end.y
	for i: int in 24:
		var mid: float = (lo + hi) * 0.5
		if absf(_area(_below(mid))) > volume:
			lo = mid
		else:
			hi = mid
	_liquid_surface_y = (lo + hi) * 0.5
	return _below(_liquid_surface_y)


# Parte do interior abaixo da linha y (semiplano)
func _below(y: float) -> PackedVector2Array:
	var half := PackedVector2Array([Vector2(-1000, y), Vector2(1000, y), Vector2(1000, 1000), Vector2(-1000, 1000)])
	var parts: Array[PackedVector2Array] = Geometry2D.intersect_polygons(interior, half)
	return parts[0] if not parts.is_empty() else PackedVector2Array()


static func _area(poly: PackedVector2Array) -> float:
	var sum: float = 0.0
	for i: int in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5
