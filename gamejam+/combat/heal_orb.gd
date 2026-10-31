class_name HealOrb
extends Area2D
## Orbe de cura (receita Unethical Butcher): atrai levemente o player e cura ao ser coletada; some após alguns segundos.

const ORB_HOVER: float = 8.0

var heal_amount: int = SynergyConstants.BUTCHER_ORB_HEAL
var lifetime: float = SynergyConstants.BUTCHER_ORB_LIFETIME

var _age: float = 0.0
var _collected: bool = false
var _player: Node2D = null


## Cria uma orbe na cena (adição deferida, segura dentro de callbacks de física).
static func spawn(scene: Node, pos: Vector2) -> HealOrb:
	var orb: HealOrb = (load("res://combat/heal_orb.tscn") as PackedScene).instantiate() as HealOrb
	orb.global_position = pos
	scene.add_child.call_deferred(orb)
	return orb


func _ready() -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = SynergyConstants.BUTCHER_ORB_PICKUP_RADIUS
	($CollisionShape2D as CollisionShape2D).shape = shape
	body_entered.connect(_on_body_entered)
	print("[Synergy] - orbe de cura criada em %s" % global_position)


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_age * 8.0)
	var glow: Color = SynergyConstants.BUTCHER_ORB_COLOR_A.lerp(SynergyConstants.BUTCHER_ORB_COLOR_B, pulse)
	# A origem do nó é o chão (y-sort, z 0); a orbe paira ORB_HOVER px acima, com sombra no chão
	draw_circle(Vector2.ZERO, 3.0, Color(0.0, 0.0, 0.0, 0.25))
	var center: Vector2 = Vector2(0.0, -ORB_HOVER)
	draw_circle(center, 6.0, Color(glow, 0.25))
	draw_circle(center, 4.0, Color(SynergyConstants.BUTCHER_ORB_COLOR_A, 0.9))
	draw_circle(center, 2.0, Color(SynergyConstants.BUTCHER_ORB_COLOR_B, 0.95))


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if lifetime - _age < 1.0:
		modulate.a = lifetime - _age
	queue_redraw()
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return
	var to_player: Vector2 = _player.global_position - global_position
	if to_player.length() <= SynergyConstants.BUTCHER_ORB_ATTRACT_RADIUS:
		global_position += to_player.normalized() * SynergyConstants.BUTCHER_ORB_ATTRACT_SPEED * delta
	if to_player.length() <= SynergyConstants.BUTCHER_ORB_PICKUP_RADIUS and not _collected:
		_collect(_player)


## Coleta ao tocar o corpo do player.
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_collect(body)


## Cura o player em heal_amount e some (uma única vez).
func _collect(player: Node2D) -> void:
	if _collected:
		return
	_collected = true
	var health: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		health.heal(heal_amount)
	print("[Synergy] - orbe coletada (+%d de vida)" % heal_amount)
	queue_free()
