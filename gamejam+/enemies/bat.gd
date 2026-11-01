class_name Bat
extends EnemyBase
## Bat: flies fast and is fragile. Passes over low obstacles (only collides with the tall world).
## The idle sheet has 8 frames of 32x32 (hframes on the Sprite2D).

@export var anim_fps: float = 12.0

var _anim_time: float = 0.0


func _process(delta: float) -> void:
	var sprite: Sprite2D = get_sprite()
	_anim_time += delta
	sprite.frame = int(_anim_time * anim_fps) % sprite.hframes
