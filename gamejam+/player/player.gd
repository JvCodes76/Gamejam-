class_name Player
extends CharacterBody2D

const BULLET_SCENE: PackedScene = preload("res://projectiles/bullet.tscn")

@export var move_speed: float = 110.0
@export var acceleration: float = 900.0
@export var friction: float = 1200.0
@export var fire_rate_seconds: float = 0.45
@export var aim_deadzone: float = 0.3
@export var gamepad_crosshair_distance: float = 60.0
@export var walk_frame_time: float = 0.18
@export var cape_frame_time: float = 0.12
# Pixels the head rises in the "walking" frames
@export var head_bob: float = 1.0
## Invincibility after taking damage (s)
@export var invulnerability_time: float = 0.8
@export var knockback_impulse: float = FeelConstants.PLAYER_KNOCKBACK_IMPULSE

# Monster Survivors: damage multiplier from the level (1.0 = level 1)
var _level_damage_multiplier: float = 1.0
var _fire_timer: float = 0.0
# Gun (real bullets): rounds left and remaining reload time (> 0 = reloading)
var _ammo: int = CombatConstants.MAGAZINE_SIZE
var _reload_left: float = 0.0
# Brimstone (laser): charge time held, active beam and Dragon's Blood shot counter (sfx/camera only every few flames)
var _laser_charge: float = 0.0
var _laser: LaserBeam = null
# True from the moment the beam is released until it finishes (the charge no longer advances)
var _laser_firing: bool = false
var _flame_shots: int = 0
var _ammo_indicator: AmmoIndicator = null
# Distance (px) the bullet is kept away from a wall when spawned against it
const BULLET_WALL_PULLBACK: float = 2.0

var _aim_direction: Vector2 = Vector2.RIGHT
var _use_gamepad: bool = false
var _mods: ProjectileModifiers = ProjectileModifiers.new()
var _director: SynergyDirector = null
var _walk_timer: float = 0.0
var _walk_frame: int = 0
var _cape_timer: float = 0.0
var _cape_frame: int = 0
var _head_base_y: float = 0.0
# Position in the rainbow color cycle (RAINBOWS!!! recipe)
var _rainbow_index: int = 0
# Game feel: sprite recoil on shots, knockback, i-frame blinking and death
var _recoil_offset: Vector2 = Vector2.ZERO
var _cape_base_position: Vector2 = Vector2.ZERO
var _knockback: Vector2 = Vector2.ZERO
var _blink_time: float = 0.0
var _dead: bool = false
var _flash_materials: Array[ShaderMaterial] = []
var _flash_tween: Tween

# Two sheets with 4 directions x 2 frames each:
# cardinal (the Sprite2D texture): down, right, left, up — pairs [idle, walking]
# diagonal: down-right, down-left, up-right, up-left — pairs [walking, idle]
const DIAGONAL_SHEET: Texture2D = preload("res://assets/sprites/player/Player_WalkDiagonal-Sheet.png")
# The 8 aim directions in angle order (0 = right, clockwise because +y points down);
# the odd ones are the diagonals
enum Facing { RIGHT, DOWN_RIGHT, DOWN, DOWN_LEFT, LEFT, UP_LEFT, UP, UP_RIGHT }
# Facing -> (idle frame, walking frame) in the sheet of that direction
const FACING_FRAMES: Array[Vector2i] = [
	Vector2i(2, 3), # RIGHT
	Vector2i(1, 0), # DOWN_RIGHT
	Vector2i(0, 1), # DOWN
	Vector2i(3, 2), # DOWN_LEFT
	Vector2i(4, 5), # LEFT
	Vector2i(7, 6), # UP_LEFT
	Vector2i(6, 7), # UP
	Vector2i(5, 4), # UP_RIGHT
]
var _cardinal_sheet: Texture2D

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _cape: Sprite2D = $Cape
@onready var _body_center: Marker2D = $BodyCenter
@onready var _pivot: Node2D = $Pivot
@onready var _muzzle: Marker2D = $Pivot/Muzzle
@onready var _feet_collider: CollisionShape2D = $CollisionShape2D
@onready var _health: HealthComponent = $HealthComponent
@onready var _crosshair: Crosshair = $Crosshair
@onready var _camera: GameCamera = $Camera2D
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _muzzle_flash: MuzzleFlash = $Pivot/Muzzle/MuzzleFlash


## Body center in the world. The node origin is at the feet (y-sort and collision);
## the aim, the muzzle and the "body" synergies originate here.
var aim_origin: Vector2:
	get:
		return _body_center.global_position


func _ready() -> void:
	_head_base_y = _sprite.position.y
	_cardinal_sheet = _sprite.texture
	_cape_base_position = _cape.position
	_hurtbox.invulnerability_time = invulnerability_time
	for sprite: Sprite2D in [_sprite, _cape]:
		var mat: ShaderMaterial = HitFeedback.make_flash_material(FeelConstants.FLASH_HURT_COLOR)
		sprite.material = mat
		_flash_materials.append(mat)
	_health.health_changed.connect(_on_health_changed)
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_ammo_indicator = AmmoIndicator.new()
	_ammo_indicator.position = Vector2(0.0, -48.0)
	add_child(_ammo_indicator)
	_director = SynergyDirector.new()
	_director.name = "SynergyDirector"
	add_child(_director)
	_director.setup(self, _health)
	# Deferred so the HUD (which comes later in the tree) is already connected
	EventBus.player_health_changed.emit.call_deferred(_health.current_health, _health.max_health)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.potion_selected.connect(_on_potion_selected)
	EventBus.player_leveled_up.connect(_on_leveled_up)
	EventBus.potion_slots_changed.connect(_recalculate_modifiers)
	EventBus.active_effects_changed.connect(_recalculate_modifiers)
	_recalculate_modifiers()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	print("[Player] - ready")


## Restores the system cursor when leaving the scene.
func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Goes back to aiming with the mouse when it moves.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_use_gamepad = false


## Switches the active potion with the mouse scroll.
func _unhandled_input(event: InputEvent) -> void:
	if _dead or ItemManager.inventory_open:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_R:
		_start_reload()
		return
	if not event is InputEventMouseButton:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if not mouse.pressed:
		return
	if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
		ItemManager.cycle_potion(1)
	elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		ItemManager.cycle_potion(-1)


func _physics_process(delta: float) -> void:
	_update_aim()
	_handle_movement(delta)
	_update_sprite(delta)
	_update_blink(delta)
	_fire_timer -= delta
	_update_reload(delta)
	var wants_fire: bool = Input.is_action_pressed("shoot") and not ItemManager.inventory_open
	if _mods.laser:
		_update_laser(delta, wants_fire)
	elif wants_fire and _fire_timer <= 0.0 and _reload_left <= 0.0:
		_shoot()


## Moves the player in 8 directions with acceleration and friction.
func _handle_movement(delta: float) -> void:
	# Brewing at the cauldron: the player stands still
	if ItemManager.cauldron_open:
		velocity = Vector2.ZERO
		_knockback = Vector2.ZERO
		return
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	if _knockback == Vector2.ZERO:
		move_and_slide()
		return
	# Knockback is added only in this step; the walking speed stays the same
	var walk_velocity: Vector2 = velocity
	velocity += _knockback
	move_and_slide()
	velocity = walk_velocity
	_knockback = _knockback.move_toward(Vector2.ZERO, FeelConstants.KNOCKBACK_FRICTION * delta)


## Updates the aim (analog stick or mouse), rotates the Pivot and positions the crosshair.
func _update_aim() -> void:
	# With the inventory open the aim is frozen and the crosshair disappears
	if ItemManager.inventory_open:
		_crosshair.visible = false
		return
	_crosshair.visible = not get_tree().paused
	var stick: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > aim_deadzone:
		_use_gamepad = true
		_aim_direction = stick.normalized()
		_crosshair.global_position = aim_origin + _aim_direction * gamepad_crosshair_distance
	elif not _use_gamepad:
		var mouse_pos: Vector2 = get_global_mouse_position()
		var to_mouse: Vector2 = mouse_pos - aim_origin
		if to_mouse.length() > 1.0:
			_aim_direction = to_mouse.normalized()
		_crosshair.global_position = mouse_pos
	else:
		_crosshair.global_position = aim_origin + _aim_direction * gamepad_crosshair_distance
	_pivot.rotation = _aim_direction.angle()
	_camera.look_target = _crosshair.global_position


## Picks the sprite direction (8 directions) from the aim and alternates the 2 frames while walking.
func _update_sprite(delta: float) -> void:
	var facing: Facing = _facing_from(_aim_direction)
	if velocity.length() > 5.0:
		_walk_timer += delta
		if _walk_timer >= walk_frame_time:
			_walk_timer = 0.0
			_walk_frame = 1 - _walk_frame
	else:
		_walk_timer = 0.0
		_walk_frame = 0
	_update_cape(delta, velocity.length() > 5.0)
	_recoil_offset = _recoil_offset.move_toward(Vector2.ZERO, FeelConstants.SPRITE_RECOIL / FeelConstants.SPRITE_RECOIL_TIME * delta)
	_sprite.position = Vector2(_recoil_offset.x, _head_base_y - (head_bob if _walk_frame == 1 else 0.0) + _recoil_offset.y)
	_cape.position = _cape_base_position + _recoil_offset
	_sprite.texture = DIAGONAL_SHEET if facing % 2 == 1 else _cardinal_sheet
	var frames: Vector2i = FACING_FRAMES[facing]
	_sprite.frame = frames.y if _walk_frame == 1 else frames.x


## Animates the cape: idle on frame 0, cycles the 4 frames while walking.
func _update_cape(delta: float, walking: bool) -> void:
	if walking:
		_cape_timer += delta
		if _cape_timer >= cape_frame_time:
			_cape_timer = 0.0
			_cape_frame = (_cape_frame + 1) % _cape.hframes
	else:
		_cape_timer = 0.0
		_cape_frame = 0
	_cape.frame = _cape_frame


## Converts the aim direction into one of the 8 directions (45° sectors centered on each one).
func _facing_from(direction: Vector2) -> Facing:
	return wrapi(roundi(direction.angle() / (PI / 4.0)), 0, 8) as Facing


## Direction of the shot: from the muzzle to the mouse (or the stick's aim).
func _shot_direction() -> Vector2:
	if not _use_gamepad:
		var to_mouse: Vector2 = get_global_mouse_position() - _muzzle.global_position
		if to_mouse.length() > 1.0:
			return to_mouse.normalized()
	return _aim_direction


## Places the bullet at the muzzle. The shot leaves at body height (CombatConstants.BODY_HEIGHT above the feet), so
## standing against a wall to the north (or behind a tree) the body is already inside that wall's collision: those
## walls are handed to the bullet to be judged at ground level (Bullet.ignore_walls_at_spawn); before, the shot died on
## leaving whatever the aim. Any other wall between the body and the muzzle (shooting point-blank at a wall) pulls the
## bullet back to its surface, so it does not spawn inside the wall or on the other side of it.
func _place_bullet(bullet: Bullet) -> void:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var from: Vector2 = _pivot.global_position
	var to: Vector2 = _muzzle.global_position
	# Walls the bullet would already touch if it left from the body itself
	var overlap: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	overlap.shape = (bullet.get_node(^"CollisionShape2D") as CollisionShape2D).shape
	overlap.transform = Transform2D(0.0, from)
	overlap.collision_mask = PhysicsLayers.PROJECTILE_WALL_MASK
	var inside: Array[Object] = []
	for contact: Dictionary in space.intersect_shape(overlap, 8):
		var obstacle: Object = Bullet.wall_owner(contact["collider"])
		if not inside.has(obstacle):
			inside.append(obstacle)
	var hit: Dictionary = Bullet.cast_wall_ray(space, from, to, PhysicsLayers.PROJECTILE_WALL_MASK,
		func(obstacle: Object) -> bool: return not inside.has(obstacle))
	bullet.global_position = to
	if not hit.is_empty():
		bullet.global_position = Vector2(hit["position"]) + (from - to).normalized() * BULLET_WALL_PULLBACK
	if not inside.is_empty():
		# Ground track starts at the center of the feet collider: always at least its radius away from any wall (the feet
		# themselves rest exactly on the edge of what they touch, and a ray grazing that edge counts as a hit)
		bullet.ignore_walls_at_spawn(inside, _feet_collider.global_position)


## Fires a bullet in the aim direction (a flame with Dragon's Blood, a real bullet with the Gun).
func _shoot() -> void:
	var shot_dir: Vector2 = _shot_direction()
	var bullet: Bullet = BULLET_SCENE.instantiate() as Bullet
	_place_bullet(bullet)
	bullet.damage = CombatConstants.WEAPON_BASE_DAMAGE
	bullet.setup(shot_dir)
	bullet.apply_modifiers(_mods, _health)
	var loud: bool = true
	if _mods.fire_breath:
		_fire_timer = fire_rate_seconds / _mods.fire_rate_multiplier / CombatConstants.FLAME_RATE_DIVISOR
		bullet.setup_flame(shot_dir.rotated(deg_to_rad(randf_range(-CombatConstants.FLAME_SPREAD_DEG, CombatConstants.FLAME_SPREAD_DEG))))
		_flame_shots += 1
		loud = _flame_shots % 3 == 1
	else:
		_fire_timer = fire_rate_seconds / _mods.fire_rate_multiplier
		if _mods.real_bullets:
			bullet.speed *= CombatConstants.REAL_BULLET_SPEED_MULT
			bullet.setup_real_bullet()
		if _mods.synergy.rainbow_colors:
			if not bullet.is_holy():
				bullet.set_tint(SynergyConstants.RAINBOW_COLORS[_rainbow_index % SynergyConstants.RAINBOW_COLORS.size()])
			_rainbow_index += 1
	get_tree().current_scene.add_child(bullet)
	_muzzle_flash.flash(bullet.get_tint())
	_recoil_offset = -shot_dir * FeelConstants.SPRITE_RECOIL * (1.0 if loud else 0.4)
	if loud:
		_camera.kick(shot_dir)
		EventBus.play_sfx_requested.emit("shoot")
	if _mods.real_bullets:
		_ammo -= 1
		if _ammo <= 0:
			_start_reload()
		else:
			_refresh_ammo_indicator()


## Gun: starts the reload (also with R); ignored without a magazine, with a full one or already reloading.
func _start_reload() -> void:
	if not _mods.real_bullets or _reload_left > 0.0 or _ammo >= CombatConstants.MAGAZINE_SIZE:
		return
	_reload_left = CombatConstants.RELOAD_TIME
	print("[Combat] - reloading")
	_refresh_ammo_indicator()


func _update_reload(delta: float) -> void:
	if _reload_left <= 0.0:
		return
	_reload_left -= delta
	if _reload_left <= 0.0:
		_reload_left = 0.0
		_ammo = CombatConstants.MAGAZINE_SIZE
		print("[Combat] - reloaded")
	_refresh_ammo_indicator()


func _refresh_ammo_indicator() -> void:
	if _ammo_indicator == null:
		return
	if not _mods.real_bullets:
		_ammo_indicator.show_state(0, 0, -1.0, _mods.color)
		return
	var ratio: float = 1.0 - _reload_left / CombatConstants.RELOAD_TIME if _reload_left > 0.0 else -1.0
	_ammo_indicator.show_state(_ammo, CombatConstants.MAGAZINE_SIZE, ratio, _mods.color)


## Brimstone: holding the button charges the laser; once charged the beam fires, then the cooldown starts.
func _update_laser(delta: float, wants_fire: bool) -> void:
	if _laser_firing:
		return
	if not wants_fire or _fire_timer > 0.0:
		_cancel_laser()
		return
	if _laser == null or not is_instance_valid(_laser):
		_laser = LaserBeam.new()
		_laser.setup(_mods, CombatConstants.WEAPON_BASE_DAMAGE, _health)
		_muzzle.add_child(_laser)
	_laser_charge += delta * _mods.fire_rate_multiplier
	_laser.set_charge(_laser_charge / CombatConstants.LASER_CHARGE_TIME)
	if _laser_charge >= CombatConstants.LASER_CHARGE_TIME:
		_laser_firing = true
		_laser.finished.connect(_on_laser_finished)
		_laser.fire()
		_muzzle_flash.flash(_mods.color)
		_recoil_offset = -_shot_direction() * FeelConstants.SPRITE_RECOIL


func _on_laser_finished() -> void:
	_laser_firing = false
	_laser = null
	_laser_charge = 0.0
	_fire_timer = fire_rate_seconds / _mods.fire_rate_multiplier


## Drops the charge (button released, potion swapped, death).
func _cancel_laser() -> void:
	_laser_firing = false
	_laser_charge = 0.0
	if _laser != null and is_instance_valid(_laser):
		_laser.queue_free()
	_laser = null


## Recomputes the modifiers from the active potion and tints the crosshair.
func _recalculate_modifiers() -> void:
	var potion: PotionData = ItemManager.get_active_potion()
	var specials: Array[StringName] = potion.special_synergies if potion != null else ([] as Array[StringName])
	_mods = ProjectileModifiers.from_totals(ItemManager.get_active_effect_totals(), potion.aspect_counts if potion != null else {}, specials)
	if potion != null:
		_mods.color = potion.color
		_mods.source_items = potion.items
	_mods.damage_multiplier *= _level_damage_multiplier
	_cancel_laser()
	_ammo = CombatConstants.MAGAZINE_SIZE
	_reload_left = 0.0
	_refresh_ammo_indicator()
	_director.configure(_mods, potion.aspect_counts if potion != null else {})
	_crosshair.color = Color(_mods.color, 0.9)
	_crosshair.queue_redraw()
	_crosshair.pulse()
	print("[Potion] - modifiers: damage x%.2f, range x%.2f, fire rate x%.2f" % [_mods.damage_multiplier, _mods.range_multiplier, _mods.fire_rate_multiplier])


## Level up (Monster Survivors): a little more damage and a bit more health. Does not reset ammo or the laser.
func _on_leveled_up(level: int) -> void:
	var new_multiplier: float = 1.0 + CombatConstants.LEVEL_DAMAGE_BONUS * (level - 1)
	_mods.damage_multiplier *= new_multiplier / _level_damage_multiplier
	_level_damage_multiplier = new_multiplier
	_health.increase_max_health(CombatConstants.LEVEL_HEALTH_BONUS)
	print("[Player] - level %d: damage x%.2f, max health %d" % [level, _level_damage_multiplier, _health.max_health])


## Recomputes the modifiers when swapping potions.
func _on_potion_selected(_index: int) -> void:
	_recalculate_modifiers()


## Toggles the system cursor and crosshair according to the pause.
func _on_game_paused(paused: bool) -> void:
	if ItemManager.inventory_open:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_HIDDEN
	_crosshair.visible = not paused


## Forwards the health change to the EventBus.
func _on_health_changed(current: int, max_value: int) -> void:
	EventBus.player_health_changed.emit(current, max_value)


## Damage: red flash, shake, hitstop, knockback and notice on the EventBus (the i-frames live in the Hurtbox).
func _on_damaged(_amount: int) -> void:
	if _health.is_dead():
		return
	_flash(FeelConstants.FLASH_HURT_COLOR, 0.15)
	var direction: Vector2 = _hurtbox.last_hit_direction
	if direction != Vector2.ZERO:
		_knockback = direction.normalized() * knockback_impulse
	_blink_time = 0.0
	EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_PLAYER_HURT)
	EventBus.hitstop_requested.emit(FeelConstants.HITSTOP_PLAYER_HURT_MS / 1000.0)
	EventBus.player_hurt.emit(global_position)
	EventBus.play_sfx_requested.emit("player_hurt")


## Blinks by alternating transparency during the i-frames.
func _update_blink(delta: float) -> void:
	if _hurtbox.is_invulnerable():
		_blink_time += delta
		var on: bool = int(_blink_time / FeelConstants.PLAYER_BLINK_INTERVAL) % 2 == 0
		var alpha: float = 1.0 if on else 0.25
		_sprite.modulate.a = alpha
		_cape.modulate.a = alpha
	elif _sprite.modulate.a < 1.0:
		_sprite.modulate.a = 1.0
		_cape.modulate.a = 1.0


## Flashes the sprite and cape in a color (flash shader).
func _flash(color: Color, duration: float) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	for mat: ShaderMaterial in _flash_materials:
		mat.set_shader_parameter("flash_color", color)
		mat.set_shader_parameter("flash", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash, 1.0, 0.0, duration).set_delay(duration * 0.4)


func _set_flash(value: float) -> void:
	for mat: ShaderMaterial in _flash_materials:
		mat.set_shader_parameter("flash", value)


## Handles the player's death: player_died is emitted right away; the body stays as a visual "corpse" until the scene change.
func _on_died() -> void:
	print("[Player] - died")
	_dead = true
	EventBus.player_died.emit()
	remove_from_group("player")
	set_physics_process(false)
	_cancel_laser()
	set_process_unhandled_input(false)
	_hurtbox.set_deferred("monitorable", false)
	_crosshair.visible = false
	_muzzle_flash.visible = false
	_camera.frozen = true
	_sprite.modulate.a = 1.0
	_cape.modulate.a = 1.0
	_flash(Color.WHITE, 0.4)
	EventBus.slowmo_requested.emit(FeelConstants.PLAYER_DEATH_SLOWMO, FeelConstants.PLAYER_DEATH_SLOWMO_TIME)
	EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_PLAYER_DEATH)
	EventBus.play_sfx_requested.emit("player_die")
	ImpactEffect.spawn_burst(self, _body_center.position, 40.0, Color(1.0, 0.3, 0.3), 40, 0.9, 2.0, 2.0)
	var tween: Tween = create_tween()
	tween.tween_interval(FeelConstants.PLAYER_CORPSE_TIME)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
