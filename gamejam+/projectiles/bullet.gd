class_name Bullet
extends Hitbox

@export var speed: float = 300.0
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT
var modifiers: ProjectileModifiers = null
var shooter_health: HealthComponent = null

var _spent: bool = false
var _age: float = 0.0
var _pierce_left: int = 0
var _hit_hurtboxes: Array[Hurtbox] = []
# Bala santa (sinergia Light) e distância desde a última poça de lama (sinergia Earth)
var _holy: bool = false
var _mud_distance: float = 0.0


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
	if modifiers != null and modifiers.synergy.mud_enabled:
		_drop_mud(speed * delta)


## Define a direção do projétil e gira o sprite.
func setup(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	rotation = direction.angle()


## Aplica os modificadores da poção: cor, alcance, pierce, dano, lifesteal e DoTs.
func apply_modifiers(mods: ProjectileModifiers, shooter: HealthComponent = null) -> void:
	modifiers = mods
	shooter_health = shooter
	lifetime *= mods.range_multiplier
	_pierce_left = mods.pierce_count
	($Sprite2D as Sprite2D).modulate = mods.color
	_holy = mods.roll_holy()
	if _holy:
		($Sprite2D as Sprite2D).modulate = SynergyConstants.LIGHT_HOLY_COLOR
		($Sprite2D as Sprite2D).scale *= 1.4
		print("[Synergy] - bala santa disparada")


## Deixa uma poça de lama a cada EARTH_TRAIL_SPACING px percorridos.
func _drop_mud(step: float) -> void:
	_mud_distance += step
	if _mud_distance < SynergyConstants.EARTH_TRAIL_SPACING:
		return
	_mud_distance -= SynergyConstants.EARTH_TRAIL_SPACING
	MudTrail.spawn(get_tree().current_scene, global_position, SynergyConstants.EARTH_TRAIL_RADIUS, SynergyConstants.EARTH_TRAIL_LIFETIME, modifiers.synergy.mud_slow, modifiers.mud_dps(damage))


## Aplica dano (com crit por hit), efeitos de status e lifesteal; consome a bala se não restar pierce.
func apply_hit(area: Area2D) -> void:
	if not area is Hurtbox:
		return
	var hurtbox: Hurtbox = area as Hurtbox
	var dealt: int = damage
	if modifiers != null:
		dealt = modifiers.roll_damage(damage, 1.0 + SynergyConstants.LIGHT_HOLY_BONUS if _holy else 1.0)
		if modifiers.roll_crit():
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
	if _pierce_left > 0:
		_pierce_left -= 1
	else:
		_impact(dealt)


## Evita dano duplo no mesmo frame depois que a bala já acertou algo.
func _on_area_entered(area: Area2D) -> void:
	if _spent:
		return
	super(area)


## Destrói a bala ao atingir uma parede (inimigos são tratados pela Hurtbox, para o pierce funcionar).
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		return
	var dealt: int = damage
	if modifiers != null:
		dealt = modifiers.roll_damage(damage)
	_impact(dealt)


## Destrói a bala por contato e cria o efeito de impacto (uma única vez).
func _impact(dealt: int) -> void:
	if _spent:
		return
	_spent = true
	var color: Color = Color.WHITE
	if modifiers != null:
		color = modifiers.color
	ImpactEffect.spawn(get_tree().current_scene, global_position, dealt, color, modifiers, damage, _hit_hurtboxes)
	queue_free()
