class_name Hitbox
extends Area2D

signal hit_landed()
signal hurtbox_hit(hurtbox: Hurtbox)

@export var damage: int = 15

# When true, deals no damage (e.g. owner stunned)
var suppressed: bool = false
# Owner multiplier (e.g. weakened); the fraction is accumulated
var damage_scale: float = 1.0
var _scale_carry: float = 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)


# Applies damage if the area hit is a Hurtbox.
func _on_area_entered(area: Area2D) -> void:
	apply_hit(area)


# Applies damage to an area, if it is another owner's Hurtbox.
func apply_hit(area: Area2D) -> void:
	if suppressed or not area is Hurtbox or area.get_parent() == get_parent():
		return
	var amount: int = damage
	if damage_scale != 1.0:
		_scale_carry += damage * damage_scale
		amount = int(_scale_carry)
		_scale_carry -= amount
	if amount > 0:
		(area as Hurtbox).receive_hit(amount, (area.global_position - global_position).normalized())
	hit_landed.emit()
	hurtbox_hit.emit(area as Hurtbox)
