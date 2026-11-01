class_name Skull
extends EnemyBase
## Skull: enemy that chases the player, faster and more fragile than the base enemy.
## The sheet has 16 frames of 32x32 that loop (hframes on the Sprite2D).

@export var anim_fps: float = 10.0

var _anim_time: float = 0.0


func _process(delta: float) -> void:
	var sprite: Sprite2D = get_sprite()
	_anim_time += delta
	sprite.frame = int(_anim_time * anim_fps) % sprite.hframes
