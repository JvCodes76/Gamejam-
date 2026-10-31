class_name Bag
extends Node2D

signal item_entered_bag(item: PhysicalItem)
signal item_left_bag(item: PhysicalItem)

@export var item_scene: PackedScene
@export var shrink_tween_time: float = 0.15
@export var bag_fill_color: Color = Color(0.35, 0.22, 0.12, 0.6)
@export var bag_line_color: Color = Color(0.6, 0.4, 0.2)

var mouth_zone: Area2D
var inside_zone: Area2D
var walls: StaticBody2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_visual()
	_build_walls()
	_build_zones()

# Desenha a bolsa (preenchimento + contorno)
func _build_visual() -> void:
	var fill := Polygon2D.new()
	fill.polygon = BagLayout.INTERIOR
	fill.color = bag_fill_color
	fill.z_index = -1
	add_child(fill)
	var line := Line2D.new()
	line.points = BagLayout.INTERIOR
	line.closed = true
	line.width = 2.0
	line.default_color = bag_line_color
	add_child(line)

# Constrói paredes ao redor do INTERIOR, sem parede na boca
func _build_walls() -> void:
	walls = StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 1
	add_child(walls)
	var pts: PackedVector2Array = BagLayout.INTERIOR
	var t: float = BagLayout.WALL_THICKNESS
	for i: int in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		if BagLayout.MOUTH_RECT.grow(1.0).has_point((a + b) * 0.5):
			continue
		var dir: Vector2 = (b - a).normalized()
		var n: Vector2 = Vector2(-dir.y, dir.x)
		if Geometry2D.is_point_in_polygon((a + b) * 0.5 + n * 0.5, pts):
			n = -n
		var col := CollisionPolygon2D.new()
		col.polygon = PackedVector2Array([a, b, b + n * t, a + n * t])
		walls.add_child(col)

# Cria MouthZone e InsideZone
func _build_zones() -> void:
	mouth_zone = Area2D.new()
	mouth_zone.name = "MouthZone"
	mouth_zone.collision_layer = 0
	mouth_zone.collision_mask = 1
	var rs := RectangleShape2D.new()
	rs.size = BagLayout.MOUTH_RECT.size
	var rc := CollisionShape2D.new()
	rc.shape = rs
	rc.position = BagLayout.MOUTH_RECT.get_center()
	mouth_zone.add_child(rc)
	add_child(mouth_zone)
	mouth_zone.body_entered.connect(_on_mouth_entered)
	mouth_zone.body_exited.connect(_on_mouth_exited)

	inside_zone = Area2D.new()
	inside_zone.name = "InsideZone"
	inside_zone.collision_layer = 0
	inside_zone.collision_mask = 1
	var cp := CollisionPolygon2D.new()
	cp.polygon = BagLayout.INTERIOR
	inside_zone.add_child(cp)
	add_child(inside_zone)
	inside_zone.body_entered.connect(_on_inside_entered)
	inside_zone.body_exited.connect(_on_inside_exited)

# Centro do item dentro do INTERIOR
func is_inside(item: PhysicalItem) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(item.global_position), BagLayout.INTERIOR)

func _on_mouth_entered(body: Node2D) -> void:
	if not body is PhysicalItem or not ItemManager.shrink_upgrade_active:
		return
	var item := body as PhysicalItem
	if item.is_scaling:
		return
	if to_local(item.global_position).y < BagLayout.MOUTH_RECT.position.y:
		item.apply_item_scale(ItemManager.current_item_scale(), shrink_tween_time)

func _on_mouth_exited(body: Node2D) -> void:
	if not body is PhysicalItem or not ItemManager.shrink_upgrade_active:
		return
	var item := body as PhysicalItem
	if item.is_scaling:
		return
	if to_local(item.global_position).y < BagLayout.MOUTH_RECT.position.y:
		item.apply_item_scale(ItemManager.base_item_scale, shrink_tween_time)

func _on_inside_entered(body: Node2D) -> void:
	if body is PhysicalItem:
		item_entered_bag.emit(body as PhysicalItem)

func _on_inside_exited(body: Node2D) -> void:
	if body is PhysicalItem:
		item_left_bag.emit(body as PhysicalItem)

# Instancia um item como filho da bolsa
func spawn_item(data: ItemData, local_position: Vector2, item_rotation: float = 0.0, item_scale: float = 3.0) -> PhysicalItem:
	var item: PhysicalItem = item_scene.instantiate() as PhysicalItem
	item.position = local_position
	item.rotation = item_rotation
	add_child(item)
	item.setup(data, item_scale)
	return item

# Lista os itens dentro da bolsa para persistência
func collect_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for child: Node in get_children():
		if child is PhysicalItem and is_inside(child as PhysicalItem):
			var it := child as PhysicalItem
			out.append({"item": it.item_data, "position": it.position, "rotation": it.rotation, "scale": it.item_scale})
	return out
