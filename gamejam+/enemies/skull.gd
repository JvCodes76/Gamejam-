class_name Skull
extends EnemyBase
## Caveira: inimigo que persegue o player, mais rápido e frágil que o inimigo base.
## A folha tem 16 quadros de 32x32 que giram em loop (hframes na Sprite2D).

@export var anim_fps: float = 10.0

var _anim_time: float = 0.0


func _process(delta: float) -> void:
	var sprite: Sprite2D = get_sprite()
	_anim_time += delta
	sprite.frame = int(_anim_time * anim_fps) % sprite.hframes
