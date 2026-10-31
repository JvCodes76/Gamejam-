class_name Bullet
extends Hitbox

@export var speed: float = 300.0
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT

var _spent: bool = false
var _age: float = 0.0


func _ready() -> void:
	super()
	hit_landed.connect(_consume)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		_consume()
		return
	global_position += direction * speed * delta


## Define a direção do projétil e gira o sprite.
func setup(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	rotation = direction.angle()


## Evita dano duplo no mesmo frame depois que a bala já acertou algo.
func _on_area_entered(area: Area2D) -> void:
	if _spent:
		return
	super(area)


## Destrói a bala ao atingir uma parede.
func _on_body_entered(_body: Node2D) -> void:
	_consume()


## Marca a bala como gasta e a remove uma única vez.
func _consume() -> void:
	if _spent:
		return
	_spent = true
	queue_free()
