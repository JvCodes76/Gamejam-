class_name CauldronVessel
extends Bag
## Physical cauldron vessel: reuses the bag, with thick walls, liquid and lid.

@export var size_multiplier: float = 1.0
# Optional sprite that replaces the placeholder drawing; scale and offset are for size_multiplier 1 (they grow with it)
# and make the sprite cover the whole CauldronLayout interior
@export var vessel_texture: Texture2D
@export var vessel_texture_scale: float = CauldronLayout.SPRITE_SCALE
@export var vessel_texture_offset: Vector2 = Vector2.ZERO
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


# Draws the cauldron: thick walls + interior background (or sprite)
func _build_visual() -> void:
	if vessel_texture != null:
		add_child(_make_sprite(vessel_texture, vessel_texture_scale * size_multiplier, vessel_texture_offset * size_multiplier, -3))
		var shade := Polygon2D.new()
		shade.polygon = interior
		shade.color = sprite_interior_shade
		shade.z_index = -2
		add_child(shade)
		return
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


# The cauldron does not shrink items at the mouth
func _on_mouth_entered(_body: Node2D) -> void:
	pass


func _on_mouth_exited(_body: Node2D) -> void:
	pass


# Wall quads (same geometry as the collider, without the mouth)
func _wall_quads() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for i: int in interior.size():
		var a: Vector2 = interior[i]
		var b: Vector2 = interior[(i + 1) % interior.size()]
		if mouth_rect.grow(1.0).has_point((a + b) * 0.5):
			continue
		if a.distance_squared_to(b) < 0.0001:
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


# Invisible lid: closes the mouth when a potion is ready
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


# Bubbles rising from the liquid (on only while brewing)
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


## Lowest point (local y) of the drawing: bottom of the sprite, or of the walls without one.
func visual_bottom() -> float:
	if vessel_texture != null:
		return (vessel_texture_offset.y + vessel_texture.get_height() * 0.5 * vessel_texture_scale) * size_multiplier
	return CauldronLayout.INTERIOR[9].y * size_multiplier + wall_thickness


## Turns the brewing bubbles on or off.
func set_brewing(value: bool) -> void:
	bubbles.emitting = value


## Items with their center inside the interior (children of this and of sibling bags, since items are dragged between them).
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


## Shows the potion liquid, filling the interior up to the height where area = volume.
func show_potion(potion: PotionData) -> void:
	_liquid_poly = _liquid_polygon(potion.volume)
	_has_liquid = _liquid_poly.size() >= 3
	liquid.polygon = _liquid_poly
	liquid.color = potion.color
	liquid.visible = _has_liquid
	(lid.get_child(0) as CollisionShape2D).set_deferred("disabled", false)
	print("[Cauldron] - Liquid shown (volume %.1f, area %.1f)" % [potion.volume, liquid_area()])


## Removes the liquid and opens the mouth again.
func clear_potion() -> void:
	_has_liquid = false
	_liquid_poly = PackedVector2Array()
	liquid.visible = false
	liquid.position = Vector2.ZERO
	(lid.get_child(0) as CollisionShape2D).set_deferred("disabled", true)


## Area of the current liquid polygon (0 if empty).
func liquid_area() -> float:
	return absf(_area(_liquid_poly)) if _has_liquid else 0.0


# Clips the interior below y; bisection on the height until the target area
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


# Part of the interior below the line y (half-plane)
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
