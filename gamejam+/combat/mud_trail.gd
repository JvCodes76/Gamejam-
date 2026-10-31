class_name MudTrail
extends Area2D
## Poça de lama temporária (sinergia Earth): reduz a velocidade e, com tier 6, causa dano a quem está dentro.

var radius: float = SynergyConstants.EARTH_TRAIL_RADIUS
var lifetime: float = SynergyConstants.EARTH_TRAIL_LIFETIME
# Redução de velocidade (0.4 = -40%)
var slow_fraction: float = SynergyConstants.EARTH_MUD_SLOW
# Dano por segundo (0 = sem dano)
var dps: float = 0.0

var _age: float = 0.0
var _refresh_left: float = 0.0


## Cria uma poça na cena (adição deferida, segura dentro de callbacks de física).
static func spawn(scene: Node, pos: Vector2, new_radius: float, new_lifetime: float, new_slow: float, new_dps: float) -> MudTrail:
	var mud: MudTrail = (load("res://combat/mud_trail.tscn") as PackedScene).instantiate() as MudTrail
	mud.global_position = pos
	mud.radius = new_radius
	mud.lifetime = new_lifetime
	mud.slow_fraction = new_slow
	mud.dps = new_dps
	scene.add_child.call_deferred(mud)
	return mud


func _ready() -> void:
	z_index = -1
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	($CollisionShape2D as CollisionShape2D).shape = shape
	_refresh_left = randf() * SynergyConstants.EARTH_MUD_REFRESH


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, SynergyConstants.EARTH_MUD_COLOR)
	draw_circle(Vector2.ZERO, radius * 0.6, Color(SynergyConstants.EARTH_MUD_COLOR, SynergyConstants.EARTH_MUD_COLOR.a * 0.6))


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if lifetime - _age < 0.5:
		modulate.a = (lifetime - _age) / 0.5
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left += SynergyConstants.EARTH_MUD_REFRESH
		_affect_overlapping()


## Renova slow (e dano) em quem está dentro; o DoT usa a fonte "mud", então poças sobrepostas não empilham dano.
func _affect_overlapping() -> void:
	var span: float = SynergyConstants.EARTH_MUD_REFRESH * 2.5
	for area: Area2D in get_overlapping_areas():
		var hurtbox: Hurtbox = area as Hurtbox
		if hurtbox == null:
			continue
		hurtbox.apply_status(StatusEffects.SLOW, span, StatusEffects.slow_power(slow_fraction))
		if dps > 0.0:
			hurtbox.apply_dot(dps, span, &"mud", SynergyConstants.EARTH_MUD_TICK)
