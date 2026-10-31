class_name CloudTrail
extends Area2D
## Nuvem temporária (receita Spice bag): reduz levemente a velocidade de quem está dentro; empilha com a lama.

var radius: float = SynergyConstants.CLOUD_TRAIL_RADIUS
var lifetime: float = SynergyConstants.CLOUD_TRAIL_LIFETIME
# Redução de velocidade (0.15 = -15%)
var slow_fraction: float = SynergyConstants.CLOUD_SLOW

var _age: float = 0.0
var _refresh_left: float = 0.0
# Pequenos "puffs" (posição, raio) que dão aspecto de fumaça
var _puffs: Array[Vector3] = []


## Cria uma nuvem na cena (adição deferida, segura dentro de callbacks de física).
static func spawn(scene: Node, pos: Vector2, new_radius: float, new_lifetime: float, new_slow: float) -> CloudTrail:
	var cloud: CloudTrail = (load("res://combat/cloud_trail.tscn") as PackedScene).instantiate() as CloudTrail
	cloud.global_position = pos
	cloud.radius = new_radius
	cloud.lifetime = new_lifetime
	cloud.slow_fraction = new_slow
	scene.add_child.call_deferred(cloud)
	return cloud


func _ready() -> void:
	z_index = CombatConstants.Z_CLOUD
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	($CollisionShape2D as CollisionShape2D).shape = shape
	_refresh_left = randf() * SynergyConstants.CLOUD_REFRESH
	for i: int in 4:
		var offset: Vector2 = Vector2.from_angle(randf() * TAU) * radius * randf_range(0.1, 0.55)
		_puffs.append(Vector3(offset.x, offset.y, radius * randf_range(0.45, 0.75)))


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(SynergyConstants.CLOUD_COLOR, SynergyConstants.CLOUD_COLOR.a * 0.6))
	for puff: Vector3 in _puffs:
		draw_circle(Vector2(puff.x, puff.y), puff.z, SynergyConstants.CLOUD_COLOR)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	position.y -= 4.0 * delta
	modulate.a = clampf((lifetime - _age) / 0.6, 0.0, 1.0)
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left += SynergyConstants.CLOUD_REFRESH
		_affect_overlapping()


## Renova a lentidão (fonte "cloud") em quem está dentro.
func _affect_overlapping() -> void:
	var span: float = SynergyConstants.CLOUD_REFRESH * 2.5
	for area: Area2D in get_overlapping_areas():
		var hurtbox: Hurtbox = area as Hurtbox
		if hurtbox != null:
			hurtbox.apply_slow(&"cloud", span, slow_fraction)
