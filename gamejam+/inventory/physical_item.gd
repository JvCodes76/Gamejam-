class_name PhysicalItem
extends RigidBody2D

signal hovered(item: PhysicalItem)
signal unhovered(item: PhysicalItem)
signal grabbed(item: PhysicalItem)
signal released(item: PhysicalItem)

@export var follow_strength: float = 20.0
@export var max_grab_speed: float = 900.0
@export var rest_linear_damp: float = 8.0
@export var rest_angular_damp: float = 8.0
@export var rotate_step_degrees: float = 45.0
@export var polygon_epsilon: float = 1.0

# Item atualmente segurado (apenas um por vez)
static var current_grabbed: PhysicalItem = null

var item_data: ItemData
var item_scale: float = 1.0

var is_hovered: bool = false
var is_grabbed: bool = false
var is_scaling: bool = false # true durante o tween (eventos de zona são ruído)

var _sprite: Sprite2D
var _base_polygons: Array[PackedVector2Array] = []
var _colliders: Array[CollisionPolygon2D] = []
var _scale_tween: Tween
var _pending_rotation: float = 0.0
var _has_pending_rotation: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	collision_layer = 1
	collision_mask = 1
	gravity_scale = 0.0
	lock_rotation = false
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = rest_linear_damp
	angular_damp = rest_angular_damp

# Configura sprite e colliders a partir do ItemData
func setup(data: ItemData, new_scale: float = 1.0) -> void:
	item_data = data
	item_scale = new_scale
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
	_sprite.texture = data.icon
	_base_polygons = ColliderBuilder.build_polygons(data.icon, 1.0, polygon_epsilon)
	_rebuild_colliders(new_scale)
	print("[Inventory] - Item '%s' criado (escala %.2f, %d polígonos)" % [data.id, new_scale, _base_polygons.size()])

# Reconstrói escala do sprite e colliders, com animação opcional
func apply_item_scale(new_scale: float, tween_time: float = 0.15) -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	if tween_time <= 0.0 or not is_inside_tree():
		_rebuild_colliders(new_scale)
		return
	is_scaling = true
	_scale_tween = create_tween()
	_scale_tween.tween_method(_rebuild_colliders, item_scale, new_scale, tween_time)
	_scale_tween.tween_callback(_end_scaling)
	print("[Inventory] - Escala %.2f -> %.2f" % [item_scale, new_scale])

# Libera a flag um frame de física depois, absorvendo eventos espúrios
func _end_scaling() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	is_scaling = false

# Aplica a escala ao sprite e recria um CollisionPolygon2D por polígono
func _rebuild_colliders(new_scale: float) -> void:
	item_scale = new_scale
	if _sprite:
		_sprite.scale = Vector2.ONE * new_scale
	for c: CollisionPolygon2D in _colliders:
		c.queue_free()
	_colliders.clear()
	for poly: PackedVector2Array in _base_polygons:
		var scaled := PackedVector2Array()
		for p: Vector2 in poly:
			scaled.append(p * new_scale)
		var col := CollisionPolygon2D.new()
		col.polygon = scaled
		add_child(col)
		_colliders.append(col)

# Testa se um ponto global está dentro de algum polígono do item
func contains_point(global_point: Vector2) -> bool:
	var local: Vector2 = to_local(global_point)
	for poly: PackedVector2Array in _base_polygons:
		var scaled := PackedVector2Array()
		for p: Vector2 in poly:
			scaled.append(p * item_scale)
		if Geometry2D.is_point_in_polygon(local, scaled):
			return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and is_hovered and current_grabbed == null:
				_grab()
			elif not mb.pressed and is_grabbed:
				_release()
		elif is_grabbed and mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_rotate_by(deg_to_rad(rotate_step_degrees))
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_rotate_by(-deg_to_rad(rotate_step_degrees))

func _physics_process(_delta: float) -> void:
	_update_hover()
	if is_grabbed:
		var to_mouse: Vector2 = get_global_mouse_position() - global_position
		linear_velocity = (to_mouse * follow_strength).limit_length(max_grab_speed)
		angular_velocity = 0.0

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _has_pending_rotation:
		state.transform = Transform2D(_pending_rotation, state.transform.origin)
		_has_pending_rotation = false
	if is_grabbed:
		state.angular_velocity = 0.0

# Atualiza estado de hover (apenas se ninguém está segurando outro item)
func _update_hover() -> void:
	var over: bool = false
	if current_grabbed == null or current_grabbed == self:
		over = contains_point(get_global_mouse_position())
	if over and not is_hovered:
		is_hovered = true
		hovered.emit(self)
	elif not over and is_hovered:
		is_hovered = false
		unhovered.emit(self)

func _grab() -> void:
	is_grabbed = true
	current_grabbed = self
	linear_damp = 0.0
	angular_damp = 0.0
	grabbed.emit(self)
	print("[Inventory] - Item '%s' segurado" % item_data.id)

func _release() -> void:
	is_grabbed = false
	if current_grabbed == self:
		current_grabbed = null
	linear_damp = rest_linear_damp
	angular_damp = rest_angular_damp
	released.emit(self)
	print("[Inventory] - Item '%s' solto" % item_data.id)

func _rotate_by(angle: float) -> void:
	_pending_rotation = rotation + angle
	_has_pending_rotation = true

func _exit_tree() -> void:
	if current_grabbed == self:
		current_grabbed = null
