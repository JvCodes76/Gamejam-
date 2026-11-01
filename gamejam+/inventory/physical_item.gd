class_name PhysicalItem
extends RigidBody2D

signal hovered(item: PhysicalItem)
signal unhovered(item: PhysicalItem)
signal grabbed(item: PhysicalItem)
signal released(item: PhysicalItem)

@export var follow_strength: float = 60.0
@export var max_grab_speed: float = 450.0
@export var rest_linear_damp: float = 0.4
@export var rest_angular_damp: float = 2.0
@export var gravity_scale_resting: float = 1.0
@export var rest_friction: float = 0.8
@export var rest_bounce: float = 0.1
@export var rotate_step_degrees: float = 45.0
@export var polygon_epsilon: float = 1.0
## Smallest scale an item can have (a zero scale makes the transform non-invertible)
const MIN_ITEM_SCALE: float = 0.05

# Item currently held (only one at a time)
static var current_grabbed: PhysicalItem = null

var item_data: ItemData
var item_scale: float = 3.0

var is_hovered: bool = false
var is_grabbed: bool = false
var is_scaling: bool = false # true during the tween (zone events are noise)

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
	gravity_scale = gravity_scale_resting
	can_sleep = true
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var mat := PhysicsMaterial.new()
	mat.friction = rest_friction
	mat.bounce = rest_bounce
	physics_material_override = mat
	lock_rotation = false
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = rest_linear_damp
	angular_damp = rest_angular_damp

# Configures the sprite and colliders from the ItemData
func setup(data: ItemData, new_scale: float = 3.0) -> void:
	item_data = data
	item_scale = new_scale
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
	_sprite.texture = data.icon
	_base_polygons = ColliderBuilder.build_polygons(data.icon, 1.0, polygon_epsilon)
	_rebuild_colliders(new_scale)
	print("[Inventory] - Item '%s' created (scale %.2f, %d polygons)" % [data.id, new_scale, _base_polygons.size()])

# Rebuilds the sprite and collider scale, with optional animation
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
	print("[Inventory] - Scale %.2f -> %.2f" % [item_scale, new_scale])

# Releases the flag one physics frame later, absorbing spurious events
func _end_scaling() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	is_scaling = false

# Applies the scale to the sprite and recreates a CollisionPolygon2D per polygon
func _rebuild_colliders(new_scale: float) -> void:
	# Invalid scales (zero, negative, NaN) would break hover tests and the physics
	if not is_finite(new_scale) or new_scale < MIN_ITEM_SCALE:
		push_warning("[Inventory] - invalid item scale %s, using %.2f" % [str(new_scale), MIN_ITEM_SCALE])
		new_scale = MIN_ITEM_SCALE
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

# Tests whether a global point is inside any of the item's polygons
func contains_point(global_point: Vector2) -> bool:
	# Degenerate transform (scale 0 or NaN position): cannot be inverted, nothing is "inside"
	var xform: Transform2D = global_transform
	if not xform.origin.is_finite() or is_zero_approx(xform.determinant()):
		return false
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
	# A body with a NaN/infinite position poisons the physics (normalize and transform warnings): reports it and recovers
	if not global_position.is_finite() or not linear_velocity.is_finite():
		push_error("[Inventory] - item '%s' had an invalid position/velocity (scale %s); resetting it" % [item_data.id if item_data != null else "?", str(item_scale)])
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		var parent_node: Node2D = get_parent() as Node2D
		global_position = parent_node.global_position if parent_node != null else Vector2.ZERO
		return
	_update_hover()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _has_pending_rotation:
		state.transform = Transform2D(_pending_rotation, state.transform.origin)
		_has_pending_rotation = false
	if is_grabbed:
		state.angular_velocity = 0.0
		# Reaches the mouse in a single step (no lag), limited by max_grab_speed
		var to_mouse: Vector2 = _clamped_mouse() - state.transform.origin
		var wanted: Vector2 = to_mouse * minf(follow_strength, 1.0 / state.step)
		wanted = wanted.limit_length(max_grab_speed)
		# Does not continuously push against static walls (avoids jitter): only slides
		for i: int in state.get_contact_count():
			if state.get_contact_collider_object(i) is StaticBody2D:
				var n: Vector2 = state.get_contact_local_normal(i)
				var into: float = wanted.dot(n)
				if into < 0.0:
					wanted -= n * into
		state.linear_velocity = wanted

# Mouse position clamped to the viewport rectangle (the item is never pulled outside)
func _clamped_mouse() -> Vector2:
	var rect: Rect2 = get_viewport().get_visible_rect()
	var m: Vector2 = get_global_mouse_position()
	return Vector2(clampf(m.x, rect.position.x, rect.end.x), clampf(m.y, rect.position.y, rect.end.y))

# Updates the hover state (only if nobody is holding another item)
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
	gravity_scale = 0.0
	lock_rotation = true # rotation only via the wheel during the grab (avoids contact torque)
	sleeping = false
	linear_damp = 0.0
	angular_damp = 0.0
	grabbed.emit(self)
	print("[Inventory] - Item '%s' held" % item_data.id)

func _release() -> void:
	is_grabbed = false
	if current_grabbed == self:
		current_grabbed = null
	gravity_scale = gravity_scale_resting
	lock_rotation = false
	linear_damp = rest_linear_damp
	angular_damp = rest_angular_damp
	released.emit(self)
	print("[Inventory] - Item '%s' released" % item_data.id)

func _rotate_by(angle: float) -> void:
	_pending_rotation = rotation + angle
	_has_pending_rotation = true

func _exit_tree() -> void:
	if current_grabbed == self:
		current_grabbed = null
