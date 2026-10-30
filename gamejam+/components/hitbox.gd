class_name Hitbox
extends Area2D

signal hit_landed()

@export var damage: int = 1


func _ready() -> void:
	area_entered.connect(_on_area_entered)


# Aplica dano se a area atingida for uma Hurtbox.
func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		(area as Hurtbox).receive_hit(damage)
		hit_landed.emit()
