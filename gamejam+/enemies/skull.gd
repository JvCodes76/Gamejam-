class_name Skull
extends EnemyBase
## Skull: enemy that chases the player, faster and more fragile than the base enemy.
## The sheet has 16 frames of 32x32 (hframes on the Sprite2D), in blocks of 4 per facing:
## 0-3 front, 4-7 facing right, 8-11 facing left, 12-15 back.

## Sheet frames in spin order: front -> right -> back -> left, so the turn never skips a side.
## Shared by every skull sheet (Skull, FireSkull, FireSkullElite).
const SPIN_FRAMES: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 12, 13, 14, 15, 8, 9, 10, 11]

@export var anim_fps: float = 10.0

var _anim_time: float = 0.0


func _process(delta: float) -> void:
	var sprite: Sprite2D = get_sprite()
	_anim_time += delta
	sprite.frame = SPIN_FRAMES[int(_anim_time * anim_fps) % SPIN_FRAMES.size()]
