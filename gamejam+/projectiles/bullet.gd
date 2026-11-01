class_name Bullet
extends Hitbox

const BULLET_SCENE_PATH: String = "res://projectiles/bullet.tscn"
# Fire visual (Dragon's Blood): procedural glow texture, cached so the many flames share it
const FLAME_TEXTURE_SIZE: int = 32
const FLAME_SPRITE_SCALE: float = 0.55
const FLAME_PARTICLE_COUNT: int = 12
const FLAME_PARTICLE_LIFETIME: float = 0.3
## Flask spin while flying (rad/s)
const FLASK_SPIN_SPEED: float = 14.0
# Colliders a wall ray may skip before giving up (obstacles the caller is not interested in)
const WALL_RAY_RETRIES: int = 4
# After this age (s), spawn walls the bullet never touched stop being special (it left without overlapping them)
const SPAWN_WALL_SETTLE_TIME: float = 0.05

@export var speed: float = 300.0
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT
var modifiers: ProjectileModifiers = null
var shooter_health: HealthComponent = null
# Remaining bounces: after a hit (with no pierce left) the bullet jumps to another enemy; walls always destroy it
var bounce_count: int = 0
# Child bullet of Weird Eye Drops: does not split again, no crit or lifesteal
var split_child: bool = false
# Fraction of the bullet's damage (children use SPLIT_DAMAGE_FRACTION)
var damage_factor: float = 1.0

var _spent: bool = false
var _age: float = 0.0
var _pierce_left: int = 0
# Homing steering level (0 = off) and AOE aura (radius px, 0 = off) with its tick timer
var _homing: float = 0.0
var _aoe_radius: float = 0.0
var _aoe_left: float = 0.0
var _hit_hurtboxes: Array[Hurtbox] = []
# Hurtboxes the child bullet ignores (already hit by the parent)
var _ignored: Array[Hurtbox] = []
# Holy bullet (Light synergy), bullet color and distances since the last trail (mud and cloud)
var _holy: bool = false
var _tint: Color = Color.WHITE
var _mud_distance: float = 0.0
var _cloud_distance: float = 0.0
# Walls (obstacles, see wall_owner) the shooter's body was already overlapping when firing: while the bullet overlaps
# them they are judged at ground level (its ground track against their footprint) instead of by its image.
# See ignore_walls_at_spawn.
var _spawn_walls: Array[Object] = []
var _spawn_walls_touched: Array[Object] = []
# Ground point at the last spawn wall check (starts at the shooter's feet)
var _ground_prev: Vector2 = Vector2.ZERO
# Trail (Line2D in global coordinates) with the bullet's latest points
var _trail: Line2D
var _spin_speed: float = FLASK_SPIN_SPEED

# True for the Gun's real bullets (drawn as a bullet instead of a potion flask)
var _is_real_bullet: bool = false

static var _bullet_texture: ImageTexture = null
static var _flame_texture: GradientTexture2D = null
static var _flame_material: CanvasItemMaterial = null


func _ready() -> void:
	super()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_trail()
	# Spawns bigger and shrinks to the normal scale
	var sprite: Sprite2D = $Sprite2D as Sprite2D
	var target_scale: Vector2 = sprite.scale
	sprite.scale = target_scale * FeelConstants.BULLET_SPAWN_SCALE
	create_tween().tween_property(sprite, "scale", target_scale, FeelConstants.BULLET_SPAWN_TIME)


## Short trail in the bullet's color, with alpha falling off toward the tail.
func _build_trail() -> void:
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.width = FeelConstants.BULLET_TRAIL_WIDTH * (0.7 if split_child else 1.0)
	_trail.z_index = -1
	_trail.z_as_relative = true
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(_tint, 0.0))
	gradient.set_color(1, Color(_tint, 0.7))
	_trail.gradient = gradient
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = curve
	add_child(_trail)


func _update_trail() -> void:
	_trail.add_point(global_position)
	while _trail.get_point_count() > FeelConstants.BULLET_TRAIL_POINTS:
		_trail.remove_point(0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		_impact(_roll_impact_damage())
		return
	if _homing > 0.0:
		_steer_toward_enemy(delta)
	global_position += direction * speed * delta
	if not _spawn_walls.is_empty() and _check_spawn_walls():
		return
	($Sprite2D as Sprite2D).rotation += _spin_speed * delta
	_update_trail()
	if _aoe_radius > 0.0:
		_aoe_left -= delta
		if _aoe_left <= 0.0:
			_aoe_left += CombatConstants.AOE_TICK
			_aoe_tick()
	if modifiers != null:
		if modifiers.synergy.mud_enabled:
			_drop_mud(speed * delta)
		if modifiers.synergy.cloud_enabled:
			_drop_cloud(speed * delta)


## Sets the projectile direction and rotates the sprite.
func setup(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	rotation = direction.angle()


## The shooter fired with its body already inside the collision of "walls" (obstacles from wall_owner): standing
## against a wall to the north or behind a tree, the shot is in front of or behind them, not inside. While the bullet
## overlaps them it only dies if its ground track, starting at "ground_from" (a ground point under the shooter, clear of
## every wall), crosses their footprint: shooting away from or along the wall works, shooting into it still hits it.
## Call before add_child.
func ignore_walls_at_spawn(walls: Array[Object], ground_from: Vector2) -> void:
	_spawn_walls = walls.duplicate()
	_ground_prev = ground_from


## Obstacle a collider belongs to: the Prop for its footprint and its projectile volume, the collider itself otherwise
## (room walls, whose single rectangle is both).
static func wall_owner(collider: Object) -> Object:
	var node: Node = collider as Node
	if node != null and node.get_parent() is Prop:
		return node.get_parent()
	return collider


## First hit of a ray on "mask" whose obstacle (wall_owner) passes "accept"; hits on other obstacles are skipped.
static func cast_wall_ray(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2, mask: int, accept: Callable) -> Dictionary:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, mask)
	var skipped: Array[RID] = []
	for i: int in WALL_RAY_RETRIES:
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or accept.call(wall_owner(hit["collider"])):
			return hit
		skipped.append(hit["rid"])
		query.exclude = skipped
	return {}


# Spawn walls at ground level: the ground track since the last frame against their footprints. True if one was hit
# (the bullet is destroyed there).
func _check_spawn_walls() -> bool:
	if _age >= SPAWN_WALL_SETTLE_TIME:
		for i: int in range(_spawn_walls.size() - 1, -1, -1):
			if not _spawn_walls_touched.has(_spawn_walls[i]):
				_spawn_walls.remove_at(i)
	var ground: Vector2 = _ground_point()
	var hit: Dictionary = cast_wall_ray(get_world_2d().direct_space_state, _ground_prev, ground, PhysicsLayers.MOVE_MASK,
		func(obstacle: Object) -> bool: return _spawn_walls.has(obstacle))
	_ground_prev = ground
	if hit.is_empty():
		return false
	global_position = Vector2(hit["position"]) - Vector2(0.0, CombatConstants.BODY_HEIGHT)
	_wall_feedback(global_position)
	_impact(_roll_impact_damage())
	return true


## Applies the potion modifiers: color, range, pierce, bounce, damage, lifesteal and DoTs.
func apply_modifiers(mods: ProjectileModifiers, shooter: HealthComponent = null) -> void:
	modifiers = mods
	shooter_health = shooter
	lifetime *= mods.range_multiplier
	_pierce_left = mods.pierce_count
	bounce_count = mods.bounce_count
	_homing = mods.homing_level
	_aoe_radius = CombatConstants.AOE_RADIUS_PER_POINT * mods.aoe_level
	set_tint(mods.color)
	_holy = mods.roll_holy()
	if _holy:
		set_tint(SynergyConstants.LIGHT_HOLY_COLOR)
		($Sprite2D as Sprite2D).scale *= 1.4
		print("[Synergy] - holy bullet fired")
	if _aoe_radius > 0.0:
		queue_redraw()


func _draw() -> void:
	if _aoe_radius > 0.0:
		draw_circle(Vector2.ZERO, _aoe_radius, Color(_tint, 0.16))
		draw_arc(Vector2.ZERO, _aoe_radius, 0.0, TAU, 32, Color(_tint, 0.45), 1.0)


## Gun: draws a brass bullet instead of the potion flask (the potion color stays on the trail and impact).
func setup_real_bullet() -> void:
	_is_real_bullet = true
	_spin_speed = 0.0
	var sprite: Sprite2D = $Sprite2D as Sprite2D
	sprite.texture = _get_bullet_texture()
	sprite.scale = Vector2.ONE * 1.2
	sprite.rotation = 0.0
	($Sprite2D/Liquid as Sprite2D).visible = false


# Small pixel-art bullet pointing right (10x5): dark base, brass casing and copper tip
static func _get_bullet_texture() -> ImageTexture:
	if _bullet_texture != null:
		return _bullet_texture
	var image: Image = Image.create_empty(10, 5, false, Image.FORMAT_RGBA8)
	var base: Color = Color(0.55, 0.4, 0.12)
	var brass: Color = Color(0.9, 0.7, 0.22)
	var shine: Color = Color(1.0, 0.9, 0.5)
	var copper: Color = Color(0.8, 0.45, 0.2)
	for x: int in 10:
		var half: int = 2
		if x == 8:
			half = 1
		elif x == 9:
			half = 0
		for y: int in range(2 - half, 3 + half):
			var color: Color = base if x < 2 else (brass if x < 6 else copper)
			if y == 1 and x >= 2 and x < 8:
				color = shine
			image.set_pixel(x, y, color)
	_bullet_texture = ImageTexture.create_from_image(image)
	return _bullet_texture


## Flame of the Dragon's Blood fire breath: short-lived, pierces everything, a fraction of the damage per flame.
func setup_flame(new_direction: Vector2) -> void:
	speed = CombatConstants.FLAME_SPEED
	lifetime = CombatConstants.FLAME_LIFETIME * modifiers.range_multiplier
	damage_factor = 1.0 / CombatConstants.FLAME_RATE_DIVISOR
	_pierce_left = CombatConstants.FLAME_PIERCE
	bounce_count = 0
	_holy = false
	set_tint(CombatConstants.FLAME_COLOR)
	_apply_flame_visual()
	setup(new_direction)


## Replaces the placeholder icon with a glowing fire ball (additive) that flickers and sheds embers.
func _apply_flame_visual() -> void:
	var sprite: Sprite2D = $Sprite2D as Sprite2D
	sprite.texture = _get_flame_texture()
	sprite.material = _get_flame_material()
	# The colors are already in the texture; the tint would darken it
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE * FLAME_SPRITE_SCALE * randf_range(0.85, 1.2)
	sprite.rotation = randf() * TAU
	_spin_speed = 0.0
	($Sprite2D/Liquid as Sprite2D).visible = false
	add_child(_build_flame_particles())


# Radial gradient: white-yellow core, orange body and red fading edge
static func _get_flame_texture() -> GradientTexture2D:
	if _flame_texture != null:
		return _flame_texture
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.95, 0.6, 1.0),
		Color(1.0, 0.55, 0.1, 0.9),
		Color(0.85, 0.15, 0.02, 0.45),
		Color(0.5, 0.0, 0.0, 0.0),
	])
	_flame_texture = GradientTexture2D.new()
	_flame_texture.gradient = gradient
	_flame_texture.fill = GradientTexture2D.FILL_RADIAL
	_flame_texture.fill_from = Vector2(0.5, 0.5)
	_flame_texture.fill_to = Vector2(1.0, 0.5)
	_flame_texture.width = FLAME_TEXTURE_SIZE
	_flame_texture.height = FLAME_TEXTURE_SIZE
	return _flame_texture


static func _get_flame_material() -> CanvasItemMaterial:
	if _flame_material == null:
		_flame_material = CanvasItemMaterial.new()
		_flame_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _flame_material


# Embers that stay where they were born (global space) and rise while shrinking and turning dark red
func _build_flame_particles() -> CPUParticles2D:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.texture = _get_flame_texture()
	particles.material = _get_flame_material()
	particles.local_coords = false
	particles.amount = FLAME_PARTICLE_COUNT
	particles.lifetime = FLAME_PARTICLE_LIFETIME
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 6.0
	particles.initial_velocity_max = 22.0
	particles.gravity = Vector2(0.0, -45.0)
	particles.scale_amount_min = 0.12
	particles.scale_amount_max = 0.3
	var shrink: Curve = Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = shrink
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.85, 0.3, 1.0), Color(1.0, 0.4, 0.05, 0.8), Color(0.4, 0.05, 0.0, 0.0)])
	particles.color_ramp = ramp
	return particles


## Nearest living enemy not yet hit, within the homing range; null if none.
func _nearest_enemy(max_range: float) -> EnemyBase:
	var best: EnemyBase = null
	var best_dist: float = max_range * max_range
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy == null or not enemy.is_alive() or enemy.get_hurtbox() in _hit_hurtboxes:
			continue
		var dist: float = global_position.distance_squared_to(enemy.global_position + CombatConstants.ENEMY_BODY_OFFSET)
		if dist <= best_dist:
			best_dist = dist
			best = enemy
	return best


## Homing: turns the direction toward the nearest enemy, limited by the turn rate.
func _steer_toward_enemy(delta: float) -> void:
	var target: EnemyBase = _nearest_enemy(CombatConstants.HOMING_RANGE)
	if target == null:
		return
	var wanted: Vector2 = (target.global_position + CombatConstants.ENEMY_BODY_OFFSET - global_position).normalized()
	var max_turn: float = CombatConstants.HOMING_TURN_RATE_PER_POINT * _homing * delta
	direction = direction.rotated(clampf(direction.angle_to(wanted), -max_turn, max_turn))
	rotation = direction.angle()


## AOE aura: damages every enemy inside the radius with a fraction of the weapon damage.
func _aoe_tick() -> void:
	if modifiers == null:
		return
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = _aoe_radius
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = PhysicsLayers.ENEMY
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var hurtbox: Hurtbox = hit["collider"] as Hurtbox
		if hurtbox == null or hurtbox in _ignored:
			continue
		var mods: ProjectileModifiers = modifiers.for_target(hurtbox)
		hurtbox.receive_hit(mods.roll_secondary_damage(damage, CombatConstants.AOE_TICK_FRACTION * damage_factor), (hurtbox.global_position - global_position).normalized())


## Sets the bullet color (sprite and impact particles).
func set_tint(color: Color) -> void:
	_tint = color
	# The flask stays as drawn; only the liquid takes the color
	($Sprite2D/Liquid as Sprite2D).modulate = color
	if _trail != null:
		_trail.gradient.set_color(0, Color(color, 0.0))
		_trail.gradient.set_color(1, Color(color, 0.7))
	queue_redraw()


## Current bullet color.
func get_tint() -> Color:
	return _tint


## Returns true if the bullet is holy (Light synergy).
func is_holy() -> bool:
	return _holy


## Configures this bullet as a child of Weird Eye Drops: inherits color, effects and reduced damage, without splitting again.
func setup_child(parent: Bullet, new_direction: Vector2) -> void:
	split_child = true
	if parent._is_real_bullet:
		setup_real_bullet()
	damage = parent.damage
	damage_factor = SynergyConstants.SPLIT_DAMAGE_FRACTION
	modifiers = parent.modifiers
	shooter_health = null
	lifetime = parent.lifetime * SynergyConstants.SPLIT_LIFETIME_FRACTION
	_holy = parent._holy
	_pierce_left = 0
	bounce_count = 0
	_homing = parent._homing
	_hit_hurtboxes = parent._hit_hurtboxes.duplicate()
	_ignored = parent._hit_hurtboxes.duplicate()
	set_tint(parent._tint)
	($Sprite2D as Sprite2D).scale = ($Sprite2D as Sprite2D).scale * 0.8
	setup(new_direction)
	# Leaves from where the parent is (position set before this call, still out of the tree): the walls the parent was
	# flying in front of stay judged at ground level for the child too
	ignore_walls_at_spawn(parent._spawn_walls, position + Vector2(0.0, CombatConstants.BODY_HEIGHT))


## Ground point under the bullet (it flies at the height of the player's body): mud and cloud stay on the ground, not in the air.
func _ground_point() -> Vector2:
	return global_position + Vector2(0.0, CombatConstants.BODY_HEIGHT)


## Leaves a mud puddle every EARTH_TRAIL_SPACING px traveled.
func _drop_mud(step: float) -> void:
	_mud_distance += step
	if _mud_distance < SynergyConstants.EARTH_TRAIL_SPACING:
		return
	_mud_distance -= SynergyConstants.EARTH_TRAIL_SPACING
	MudTrail.spawn(get_tree().current_scene, _ground_point(), SynergyConstants.EARTH_TRAIL_RADIUS, SynergyConstants.EARTH_TRAIL_LIFETIME, modifiers.synergy.mud_slow, modifiers.mud_dps(damage))


## Leaves a cloud (Spice bag) every CLOUD_TRAIL_SPACING px traveled.
func _drop_cloud(step: float) -> void:
	_cloud_distance += step
	if _cloud_distance < SynergyConstants.CLOUD_TRAIL_SPACING:
		return
	_cloud_distance -= SynergyConstants.CLOUD_TRAIL_SPACING
	CloudTrail.spawn(get_tree().current_scene, _ground_point(), SynergyConstants.CLOUD_TRAIL_RADIUS, SynergyConstants.CLOUD_TRAIL_LIFETIME, modifiers.synergy.cloud_slow)


# Easter egg: a critical with the Gun item (real bullets) plays an eagle scream, at most once per scream length
const EAGLE_SFX: String = "eagle_scream"
const EAGLE_COOLDOWN_MS: int = 1800
static var _last_eagle_ms: int = -EAGLE_COOLDOWN_MS


## Applies damage (with crit per hit), status effects and lifesteal; consumes the bullet if no pierce remains.
func apply_hit(area: Area2D) -> void:
	if not area is Hurtbox:
		return
	var hurtbox: Hurtbox = area as Hurtbox
	if hurtbox in _ignored or hurtbox in _hit_hurtboxes:
		return
	# Against the boss only the items it is not immune to apply
	var mods: ProjectileModifiers = modifiers.for_target(hurtbox) if modifiers != null else null
	var dealt: int = damage
	var crit: bool = false
	if mods != null:
		var extra: float = (1.0 + SynergyConstants.LIGHT_HOLY_BONUS if _holy else 1.0) * damage_factor
		dealt = mods.roll_damage(damage, extra)
		if not split_child and mods.roll_crit():
			dealt = maxi(roundi(dealt * mods.crit_multiplier()), 1)
			crit = true
			print("[Combat] - critical! damage %d" % dealt)
	hurtbox.receive_hit(dealt, direction, crit)
	EventBus.play_sfx_requested.emit("crit" if crit else "hit")
	if crit and mods.real_bullets:
		_play_eagle()
	if mods != null:
		mods.apply_on_hit_effects(hurtbox, damage)
		if _holy:
			mods.try_holy_slay(hurtbox)
		if mods.synergy.arc_enabled:
			MagicArc.chain_from(hurtbox, mods, damage)
		if shooter_health != null and is_instance_valid(shooter_health):
			shooter_health.heal(mods.roll_heal(dealt, shooter_health.max_health))
	hit_landed.emit()
	_hit_hurtboxes.append(hurtbox)
	_split(global_position, direction)
	if _pierce_left > 0:
		_pierce_left -= 1
		if mods != null:
			mods.try_tea(hurtbox)
	elif bounce_count > 0 and _bounce_to_next_enemy():
		return
	else:
		_impact(dealt, true)


func _play_eagle() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_eagle_ms < EAGLE_COOLDOWN_MS:
		return
	_last_eagle_ms = now
	EventBus.play_sfx_requested.emit(EAGLE_SFX)


## Bounce: redirects the bullet to the nearest enemy not yet hit and refunds part of its range. False if none is near.
func _bounce_to_next_enemy() -> bool:
	var target: EnemyBase = _nearest_enemy(CombatConstants.BOUNCE_RANGE)
	if target == null:
		return false
	bounce_count -= 1
	direction = (target.global_position + CombatConstants.ENEMY_BODY_OFFSET - global_position).normalized()
	rotation = direction.angle()
	_age = maxf(_age - lifetime * CombatConstants.BOUNCE_LIFETIME_REFUND, 0.0)
	print("[Combat] - bullet bounced to another enemy (%d left)" % bounce_count)
	return true


## Split (Eye of Giant Newt / Weird Eye Drops): spawns split_count child bullets fanned around "dir", leaving from "origin"; children do not split.
func _split(origin: Vector2, dir: Vector2) -> void:
	if split_child or modifiers == null or modifiers.split_count <= 0:
		return
	var scene: Node = get_tree().current_scene
	var count: int = modifiers.split_count
	var span: float = SynergyConstants.SPLIT_ANGLE_DEG
	for i: int in count:
		# One child leaves to a random side; two or more are spread evenly across +-span
		var offset: float = span * (1.0 if randf() < 0.5 else -1.0) if count == 1 else lerpf(-span, span, float(i) / float(count - 1))
		var child: Bullet = (load(BULLET_SCENE_PATH) as PackedScene).instantiate() as Bullet
		child.global_position = origin
		child.setup_child(self, dir.rotated(deg_to_rad(offset)))
		scene.add_child.call_deferred(child)
	print("[Combat] - projectile split into %d" % count)


## Avoids double damage in the same frame after the bullet has already hit something.
func _on_area_entered(area: Area2D) -> void:
	if _spent:
		return
	super(area)


## Tall wall or tall obstacle volume (low obstacles do not collide): destroys the bullet (enemies are handled by the Hurtbox, so pierce and bounce work).
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or _spent:
		return
	var obstacle: Object = wall_owner(body)
	if _spawn_walls.has(obstacle):
		# Judged at ground level while overlapping (_check_spawn_walls)
		if not _spawn_walls_touched.has(obstacle):
			_spawn_walls_touched.append(obstacle)
		return
	var wall: Dictionary = _probe_wall()
	_wall_feedback(Vector2(wall["position"]))
	_impact(_roll_impact_damage())


# Out of a spawn wall (none of its bodies overlapped any more): from now on it is a normal wall for this bullet
func _on_body_exited(body: Node2D) -> void:
	var obstacle: Object = wall_owner(body)
	if not _spawn_walls.has(obstacle):
		return
	for other: Node2D in get_overlapping_bodies():
		if other != body and wall_owner(other) == obstacle:
			return
	_spawn_walls.erase(obstacle)


## Impact damage without a direct target (wall or end of range): no crit, with the bullet's damage fraction.
func _roll_impact_damage() -> int:
	if modifiers == null:
		return damage
	return modifiers.roll_damage(damage, damage_factor)


## Bullet died on the wall: mini burst with a ring and notice on the EventBus.
func _wall_feedback(at: Vector2) -> void:
	var scene: Node = get_tree().current_scene
	if scene != null:
		var fx: ImpactEffect = ImpactEffect.spawn_burst(scene, at, 7.0, _tint, 5, 0.3, 1.0, 0.6)
		fx.global_position = at
	EventBus.bullet_hit_wall.emit(at, _tint)
	EventBus.play_sfx_requested.emit("wall_hit")


## Point and normal of the touched wall: short ray along the direction; with no hit, uses the opposite direction as the normal.
func _probe_wall() -> Dictionary:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position - direction * 12.0, global_position + direction * 10.0, PhysicsLayers.PROJECTILE_WALL_MASK)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"position": global_position, "normal": -direction}
	return hit


## Destroys the bullet on contact and creates the impact effect (only once). The explosion (Explosive) only happens on an enemy hit.
func _impact(dealt: int, hit_enemy: bool = false) -> void:
	if _spent:
		return
	_spent = true
	var explode: bool = hit_enemy and modifiers != null and modifiers.explosive
	ImpactEffect.spawn(get_tree().current_scene, global_position, dealt, _tint, modifiers, damage, _hit_hurtboxes, explode)
	queue_free()
