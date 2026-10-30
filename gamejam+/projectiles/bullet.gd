class_name Bullet
extends Hitbox

@export var speed: float = 300.0
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	super()
	hit_landed.connect(queue_free)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


## Define a direção do projétil e gira o sprite.
func setup(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	rotation = direction.angle()


## Destrói a bala ao atingir uma parede.
func _on_body_entered(_body: Node2D) -> void:
	queue_free()
