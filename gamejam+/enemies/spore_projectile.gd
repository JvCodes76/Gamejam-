class_name SporeProjectile
extends Area2D
## Spore shot by the mushroom elite: flies straight, hurts the first target hurtbox it touches and pops on walls
## and tombstones. Hits the player, or the enemies when the mushroom that shot it was charmed.

const RADIUS: float = 5.0
# Time (s) fading out at the end of its life
const FADE_TIME: float = 0.3

var velocity: Vector2 = Vector2.ZERO
var damage: int = 15
var lifetime: float = 2.5
var color: Color = Color(0.55, 0.85, 0.25)
# Who shot it (never hit by its own spore)
var shooter: Node = null

var _age: float = 0.0
var _popped: bool = false


## Creates a spore in the scene (deferred add, safe inside physics callbacks).
static func spawn(scene: Node, pos: Vector2, new_velocity: Vector2, new_damage: int, new_lifetime: float, new_color: Color, hits_enemies: bool, new_shooter: Node) -> SporeProjectile:
	var spore: SporeProjectile = SporeProjectile.new()
	spore.position = pos
	spore.velocity = new_velocity
	spore.damage = new_damage
	spore.lifetime = new_lifetime
	spore.color = new_color
	spore.shooter = new_shooter
	spore.collision_layer = PhysicsLayers.ENEMY_BULLET
	spore.collision_mask = PhysicsLayers.PROJECTILE_WALL_MASK | (PhysicsLayers.ENEMY if hits_enemies else PhysicsLayers.PLAYER)
	scene.add_child.call_deferred(spore)
	return spore


func _ready() -> void:
	z_index = CombatConstants.Z_BULLET
	monitorable = false
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = RADIUS
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	position += velocity * delta
	modulate.a = clampf((lifetime - _age) / FADE_TIME, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	# Pulsing spore: dark halo, body and light core
	var pulse: float = 1.0 + 0.15 * sin(_age * 18.0)
	draw_circle(Vector2.ZERO, RADIUS * 1.4 * pulse, Color(color.darkened(0.5), 0.5))
	draw_circle(Vector2.ZERO, RADIUS * pulse, color)
	draw_circle(Vector2(-1.5, -1.5), RADIUS * 0.4, color.lightened(0.5))


func _on_area_entered(area: Area2D) -> void:
	var hurtbox: Hurtbox = area as Hurtbox
	if hurtbox == null or _popped or hurtbox.get_parent() == shooter:
		return
	hurtbox.receive_hit(damage, velocity.normalized())
	_pop()


func _on_body_entered(_body: Node2D) -> void:
	_pop()


# Small spore burst and removal (only once)
func _pop() -> void:
	if _popped:
		return
	_popped = true
	var parent: Node = get_parent()
	if parent != null:
		ImpactEffect.spawn_burst(parent, position, RADIUS * 2.0, color, 6, 0.3, 1.0, 0.6)
	queue_free()
