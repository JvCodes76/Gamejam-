class_name ImpactEffect
extends Node2D

@export var splash_damage_fraction: float = 0.5
@export var particle_count: int = 16
@export var particle_lifetime: float = 0.6
@export var ring_alpha: float = 0.25

const ENEMY_MASK: int = 4

var impact_damage: int = 1
var tint: Color = Color.WHITE
var modifiers: ProjectileModifiers = null
var base_damage: int = 1
var impact_radius: float = CombatConstants.IMPACT_RADIUS_BASE
var excluded: Array[Hurtbox] = []
# Quando false, só o visual (ex.: rajada de luz sem dano de área)
var splash_enabled: bool = true
# Espessura do anel (0 = disco preenchido) e multiplicador da velocidade das partículas
var ring_width: float = 0.0
var speed_scale: float = 1.0
# Tempo de expansão do anel (s)
var ring_grow_time: float = 0.15

var _ring_scale: float = 0.2


## Cria o efeito na cena atual (adicionado de forma deferida, seguro dentro de callbacks de física).
static func spawn(scene: Node, pos: Vector2, damage: int, color: Color, mods: ProjectileModifiers, new_base_damage: int, skip: Array[Hurtbox]) -> ImpactEffect:
	var fx: ImpactEffect = (load("res://projectiles/impact_effect.tscn") as PackedScene).instantiate() as ImpactEffect
	fx.global_position = pos
	fx.impact_damage = damage
	fx.tint = color
	fx.modifiers = mods
	fx.base_damage = new_base_damage
	if mods != null:
		fx.impact_radius = mods.impact_radius()
	fx.excluded = skip
	scene.add_child.call_deferred(fx)
	return fx


## Explosão parametrizada das sinergias: raio, dano exato (0 = só visual) e cor; sem crit nem efeitos de poção.
static func spawn_blast(scene: Node, pos: Vector2, radius: float, damage: int, color: Color, particles: int = 16) -> ImpactEffect:
	var fx: ImpactEffect = (load("res://projectiles/impact_effect.tscn") as PackedScene).instantiate() as ImpactEffect
	fx.global_position = pos
	fx.impact_damage = damage
	fx.splash_damage_fraction = 1.0
	fx.splash_enabled = damage > 0
	fx.impact_radius = radius
	fx.tint = color
	fx.particle_count = particles
	fx.ring_alpha = 0.4
	scene.add_child.call_deferred(fx)
	return fx


## Só visual (sem dano): burst de partículas e anel expansivo, maior que o impacto normal (ex.: anúncio no caldeirão).
static func spawn_burst(parent: Node, pos: Vector2, radius: float, color: Color, particles: int, lifetime: float, new_ring_width: float, new_speed_scale: float) -> ImpactEffect:
	var fx: ImpactEffect = (load("res://projectiles/impact_effect.tscn") as PackedScene).instantiate() as ImpactEffect
	fx.position = pos
	fx.impact_damage = 0
	fx.splash_enabled = false
	fx.impact_radius = radius
	fx.tint = color
	fx.particle_count = particles
	fx.particle_lifetime = lifetime
	fx.ring_alpha = 0.6
	fx.ring_width = new_ring_width
	fx.speed_scale = new_speed_scale
	fx.ring_grow_time = SynergyConstants.ANNOUNCE_RING_GROW_TIME
	parent.add_child(fx)
	return fx


func _ready() -> void:
	z_index = CombatConstants.Z_IMPACT
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if splash_enabled:
		_apply_splash()
	_spawn_particles()
	var tween: Tween = create_tween()
	tween.tween_property(self, "_ring_scale", 1.0, ring_grow_time)
	tween.parallel().tween_property(self, "modulate:a", 0.0, particle_lifetime)
	tween.tween_callback(queue_free)
	print("[Combat] - impacto em %s (dano de área %d)" % [global_position, _splash_damage() if splash_enabled else 0])


func _draw() -> void:
	if ring_width > 0.0:
		draw_arc(Vector2.ZERO, impact_radius * _ring_scale, 0.0, TAU, 48, Color(tint, ring_alpha), ring_width)
	else:
		draw_circle(Vector2.ZERO, impact_radius * _ring_scale, Color(tint, ring_alpha))


func _process(_delta: float) -> void:
	queue_redraw()


## Dano de área (mínimo 1), com o multiplicador de dano das explosões (Magical Potentializer).
func _splash_damage() -> int:
	var mult: float = modifiers.synergy.explosion_damage_mult if modifiers != null else 1.0
	return maxi(roundi(impact_damage * splash_damage_fraction * mult), 1)


## Aplica dano e efeitos (sem crit/lifesteal) às Hurtbox de inimigos no raio, exceto as já atingidas.
func _apply_splash() -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = impact_radius
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = ENEMY_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var seen: Array[Hurtbox] = excluded.duplicate()
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var hurtbox: Hurtbox = hit["collider"] as Hurtbox
		if hurtbox == null or hurtbox in seen:
			continue
		seen.append(hurtbox)
		hurtbox.receive_hit(_splash_damage())
		if modifiers != null:
			modifiers.apply_on_hit_effects(hurtbox, base_damage)


## Burst de partículas quadradas (pixel art) na cor da poção.
func _spawn_particles() -> void:
	var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var p: CPUParticles2D = CPUParticles2D.new()
	p.texture = ImageTexture.create_from_image(img)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.amount = particle_count
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = particle_lifetime
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 20.0 * speed_scale
	p.initial_velocity_max = 60.0 * speed_scale
	p.gravity = Vector2(0.0, -20.0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.5
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(tint, 1.0))
	fade.set_color(1, Color(tint, 0.0))
	p.color_ramp = fade
	var bright: Gradient = Gradient.new()
	bright.set_color(0, Color(0.75, 0.75, 0.75, 1.0))
	bright.set_color(1, Color(1.0, 1.0, 1.0, 1.0))
	p.color_initial_ramp = bright
	add_child(p)
	p.emitting = true
