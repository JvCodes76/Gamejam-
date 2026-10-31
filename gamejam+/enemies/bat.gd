class_name Bat
extends EnemyBase
## Morcego: voa rápido e é frágil. Passa por cima dos obstáculos baixos (só colide com o mundo alto).
## A folha idle tem 8 quadros de 32x32 (hframes na Sprite2D).

@export var anim_fps: float = 12.0

var _anim_time: float = 0.0


func _process(delta: float) -> void:
	var sprite: Sprite2D = get_sprite()
	_anim_time += delta
	sprite.frame = int(_anim_time * anim_fps) % sprite.hframes
