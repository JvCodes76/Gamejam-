class_name FloatingText
extends Label
## Short text in the world that rises and fades (item name, the mimic's "!"). For damage numbers use DamageNumbers (pool).

var _velocity: Vector2 = Vector2.ZERO
var _lifetime: float = 0.8
var _age: float = 0.0


## Creates the text centered at "world_position" (deferred add).
static func spawn(parent: Node, world_position: Vector2, text_value: String, color: Color, font_size: int = 8, lifetime: float = 0.8, rise_speed: float = 30.0) -> FloatingText:
	var label: FloatingText = FloatingText.new()
	label.text = text_value
	label._lifetime = lifetime
	label._velocity = Vector2(0.0, -rise_speed)
	label.z_index = CombatConstants.Z_ARC + 2
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.size = label.get_minimum_size()
	label.pivot_offset = label.size * 0.5
	label.position = world_position - label.size * 0.5
	label.scale = Vector2.ONE * 1.5
	parent.add_child.call_deferred(label)
	return label


func _ready() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_age += delta
	position += _velocity * delta
	_velocity *= 0.92
	var fade_start: float = _lifetime * 0.6
	if _age > fade_start:
		modulate.a = clampf(1.0 - (_age - fade_start) / (_lifetime - fade_start), 0.0, 1.0)
	if _age >= _lifetime:
		queue_free()
