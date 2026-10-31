class_name PickupFx
extends Node2D
## Item "sugado" até o player numa curva, depois um pop com partículas na cor do item e o nome flutuando.

const TRAVEL_TIME: float = 0.28

var _sprite: Sprite2D
var _target: Node2D
var _start: Vector2
var _control: Vector2
var _color: Color = Color.WHITE
var _item_name: String = ""


## Cria o efeito a partir do ícone do item do chão, voando até "target" (o player).
static func spawn(scene: Node, from: Vector2, texture: Texture2D, sprite_scale: Vector2, target: Node2D, color: Color, item_name: String) -> PickupFx:
	var fx: PickupFx = PickupFx.new()
	fx.name = "PickupFx"
	fx.z_index = CombatConstants.Z_IMPACT
	fx._target = target
	fx._start = from
	fx._color = color
	fx._item_name = item_name
	fx._sprite = Sprite2D.new()
	fx._sprite.texture = texture
	fx._sprite.scale = sprite_scale
	fx._sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.add_child(fx._sprite)
	fx.global_position = from
	scene.add_child(fx)
	return fx


func _ready() -> void:
	# Ponto de controle acima do caminho: o item sobe antes de cair no player
	_control = _start + Vector2(randf_range(-12.0, 12.0), -28.0)
	var tween: Tween = create_tween()
	tween.tween_method(_travel, 0.0, 1.0, TRAVEL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_pop)


func _target_point() -> Vector2:
	if is_instance_valid(_target):
		var player: Player = _target as Player
		return player.aim_origin if player != null else _target.global_position
	return _start


func _travel(t: float) -> void:
	var end: Vector2 = _target_point()
	global_position = _start.lerp(_control, t).lerp(_control.lerp(end, t), t)
	_sprite.scale = _sprite.scale.lerp(_sprite.scale * 0.6, t * 0.2)


func _pop() -> void:
	ImpactEffect.spawn_burst(self, Vector2.ZERO, 10.0, _color, 10, 0.4, 1.0, 1.0)
	if _item_name != "":
		FloatingText.spawn(get_parent(), global_position + Vector2(0.0, -14.0), _item_name, _color.lightened(0.4), 8, 1.0, 25.0)
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "scale", _sprite.scale * 1.8, 0.1)
	tween.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.1)
	tween.tween_interval(0.4)
	tween.tween_callback(queue_free)
