class_name Bullet
extends Hitbox

const BULLET_SCENE_PATH: String = "res://projectiles/bullet.tscn"

@export var speed: float = 300.0
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT
var modifiers: ProjectileModifiers = null
var shooter_health: HealthComponent = null
# Ricochetes restantes nas paredes (0 = a parede destrói a bala); inimigos nunca causam ricochete
var bounce_count: int = 0
# Bala filha da Weird Eye Drops: não se divide de novo, não dá crit nem lifesteal
var split_child: bool = false
# Fração do dano da bala (filhas usam SPLIT_DAMAGE_FRACTION)
var damage_factor: float = 1.0

var _spent: bool = false
var _age: float = 0.0
var _pierce_left: int = 0
var _hit_hurtboxes: Array[Hurtbox] = []
# Hurtboxes que a bala filha ignora (já atingidas pela mãe)
var _ignored: Array[Hurtbox] = []
# Bala santa (sinergia Light), cor da bala e distâncias desde o último rastro (lama e nuvem)
var _holy: bool = false
var _tint: Color = Color.WHITE
var _mud_distance: float = 0.0
var _cloud_distance: float = 0.0


func _ready() -> void:
	super()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		_spent = true
		queue_free()
		return
	global_position += direction * speed * delta
	if modifiers != null:
		if modifiers.synergy.mud_enabled:
			_drop_mud(speed * delta)
		if modifiers.synergy.cloud_enabled:
			_drop_cloud(speed * delta)


## Define a direção do projétil e gira o sprite.
func setup(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	rotation = direction.angle()


## Aplica os modificadores da poção: cor, alcance, pierce, ricochete, dano, lifesteal e DoTs.
func apply_modifiers(mods: ProjectileModifiers, shooter: HealthComponent = null) -> void:
	modifiers = mods
	shooter_health = shooter
	lifetime *= mods.range_multiplier
	_pierce_left = mods.pierce_count
	bounce_count = mods.synergy.bounce_count
	set_tint(mods.color)
	_holy = mods.roll_holy()
	if _holy:
		set_tint(SynergyConstants.LIGHT_HOLY_COLOR)
		($Sprite2D as Sprite2D).scale *= 1.4
		print("[Synergy] - bala santa disparada")


## Define a cor da bala (sprite e partículas do impacto).
func set_tint(color: Color) -> void:
	_tint = color
	($Sprite2D as Sprite2D).modulate = color


## Retorna true se a bala é santa (sinergia Light).
func is_holy() -> bool:
	return _holy


## Configura esta bala como filha da Weird Eye Drops: herda cor, efeitos e dano reduzido, sem se dividir de novo.
func setup_child(parent: Bullet, new_direction: Vector2) -> void:
	split_child = true
	damage = parent.damage
	damage_factor = SynergyConstants.SPLIT_DAMAGE_FRACTION
	modifiers = parent.modifiers
	shooter_health = null
	lifetime = parent.lifetime * SynergyConstants.SPLIT_LIFETIME_FRACTION
	_holy = parent._holy
	_pierce_left = 0
	bounce_count = 0
	_hit_hurtboxes = parent._hit_hurtboxes.duplicate()
	_ignored = parent._hit_hurtboxes.duplicate()
	set_tint(parent._tint)
	($Sprite2D as Sprite2D).scale = ($Sprite2D as Sprite2D).scale * 0.8
	setup(new_direction)


## Ponto do chão sob a bala (ela voa na altura do corpo do player): lama e nuvem ficam no chão, não no ar.
func _ground_point() -> Vector2:
	return global_position + Vector2(0.0, CombatConstants.BODY_HEIGHT)


## Deixa uma poça de lama a cada EARTH_TRAIL_SPACING px percorridos.
func _drop_mud(step: float) -> void:
	_mud_distance += step
	if _mud_distance < SynergyConstants.EARTH_TRAIL_SPACING:
		return
	_mud_distance -= SynergyConstants.EARTH_TRAIL_SPACING
	MudTrail.spawn(get_tree().current_scene, _ground_point(), SynergyConstants.EARTH_TRAIL_RADIUS, SynergyConstants.EARTH_TRAIL_LIFETIME, modifiers.synergy.mud_slow, modifiers.mud_dps(damage))


## Deixa uma nuvem (Spice bag) a cada CLOUD_TRAIL_SPACING px percorridos.
func _drop_cloud(step: float) -> void:
	_cloud_distance += step
	if _cloud_distance < SynergyConstants.CLOUD_TRAIL_SPACING:
		return
	_cloud_distance -= SynergyConstants.CLOUD_TRAIL_SPACING
	CloudTrail.spawn(get_tree().current_scene, _ground_point(), SynergyConstants.CLOUD_TRAIL_RADIUS, SynergyConstants.CLOUD_TRAIL_LIFETIME, modifiers.synergy.cloud_slow)


## Aplica dano (com crit por hit), efeitos de status e lifesteal; consome a bala se não restar pierce.
func apply_hit(area: Area2D) -> void:
	if not area is Hurtbox:
		return
	var hurtbox: Hurtbox = area as Hurtbox
	if hurtbox in _ignored:
		return
	var dealt: int = damage
	if modifiers != null:
		var extra: float = (1.0 + SynergyConstants.LIGHT_HOLY_BONUS if _holy else 1.0) * damage_factor
		dealt = modifiers.roll_damage(damage, extra)
		if not split_child and modifiers.roll_crit():
			dealt = maxi(roundi(dealt * modifiers.crit_multiplier()), 1)
			print("[Combat] - crítico! dano %d" % dealt)
	hurtbox.receive_hit(dealt)
	if modifiers != null:
		modifiers.apply_on_hit_effects(hurtbox, damage)
		if _holy:
			modifiers.try_holy_slay(hurtbox)
		if modifiers.synergy.arc_enabled:
			MagicArc.chain_from(hurtbox, modifiers, damage)
		if shooter_health != null and is_instance_valid(shooter_health):
			shooter_health.heal(modifiers.roll_heal(dealt, shooter_health.max_health))
	hit_landed.emit()
	_hit_hurtboxes.append(hurtbox)
	_split(global_position, direction)
	if _pierce_left > 0:
		_pierce_left -= 1
		if modifiers != null:
			modifiers.try_tea(hurtbox)
	else:
		_impact(dealt)


## Weird Eye Drops: spawna 2 balas filhas a +-SPLIT_ANGLE_DEG de "dir", saindo de "origin"; filhas não se dividem.
func _split(origin: Vector2, dir: Vector2) -> void:
	if split_child or modifiers == null or not modifiers.synergy.split_on_hit:
		return
	var scene: Node = get_tree().current_scene
	for side: float in [-1.0, 1.0]:
		var child: Bullet = (load(BULLET_SCENE_PATH) as PackedScene).instantiate() as Bullet
		child.global_position = origin
		child.setup_child(self, dir.rotated(deg_to_rad(SynergyConstants.SPLIT_ANGLE_DEG) * side))
		scene.add_child.call_deferred(child)
	print("[Synergy] - projétil se dividiu em dois")


## Evita dano duplo no mesmo frame depois que a bala já acertou algo.
func _on_area_entered(area: Area2D) -> void:
	if _spent:
		return
	super(area)


## Parede alta ou volume de obstáculo alto (obstáculos baixos não colidem): ricocheteia se ainda há ricochetes, senão destrói a bala (inimigos são tratados pela Hurtbox, para o pierce funcionar).
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or _spent:
		return
	var wall: Dictionary = _probe_wall()
	var normal: Vector2 = wall["normal"]
	var out_pos: Vector2 = Vector2(wall["position"]) + normal * SynergyConstants.BOUNCE_PUSH_OUT
	var reflected: Vector2 = direction.bounce(normal).normalized()
	_split(out_pos, reflected)
	if bounce_count > 0:
		bounce_count -= 1
		direction = reflected
		rotation = direction.angle()
		global_position = out_pos
		print("[Synergy] - bala ricocheteou (restam %d)" % bounce_count)
		return
	var dealt: int = damage
	if modifiers != null:
		dealt = modifiers.roll_damage(damage, damage_factor)
	_impact(dealt)


## Ponto e normal da parede tocada: raio curto ao longo da direção; sem hit, usa a direção oposta como normal.
func _probe_wall() -> Dictionary:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position - direction * 12.0, global_position + direction * 10.0, PhysicsLayers.PROJECTILE_WALL_MASK)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"position": global_position, "normal": -direction}
	return hit


## Destrói a bala por contato e cria o efeito de impacto (uma única vez).
func _impact(dealt: int) -> void:
	if _spent:
		return
	_spent = true
	ImpactEffect.spawn(get_tree().current_scene, global_position, dealt, _tint, modifiers, damage, _hit_hurtboxes)
	queue_free()
