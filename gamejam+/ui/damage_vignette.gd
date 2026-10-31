class_name DamageVignette
extends ColorRect
## Vinheta vermelha na tela: acende ao levar dano e cai em 0,3 s; fica mais forte com vida baixa e pulsa com 1 de vida.

const SHADER_CODE: String = """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.8, 0.0, 0.05, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	float d = distance(UV, vec2(0.5)) * 1.41421;
	float v = smoothstep(0.45, 1.0, d);
	COLOR = vec4(tint.rgb, v * intensity);
}
"""

var _hit: float = 0.0
var _base: float = 0.0
var _pulse: bool = false
var _time: float = 0.0
var _material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader: Shader = Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material
	color = Color.WHITE
	EventBus.player_hurt.connect(_on_player_hurt)
	EventBus.player_health_changed.connect(_on_player_health_changed)
	_apply()


func _process(delta: float) -> void:
	_time += delta
	_hit = maxf(_hit - delta / 0.3, 0.0)
	_apply()


func _apply() -> void:
	var base: float = _base
	if _pulse:
		base += 0.2 * absf(sin(_time * 3.5))
	var value: float = clampf(maxf(_hit, base), 0.0, 1.0)
	_material.set_shader_parameter("intensity", value)
	visible = value > 0.001


func _on_player_hurt(_position: Vector2) -> void:
	_hit = 1.0


func _on_player_health_changed(current: int, max_value: int) -> void:
	_pulse = current == 1
	if current <= 0:
		_base = 0.6
	elif current == 1:
		_base = 0.35
	elif float(current) / float(maxi(max_value, 1)) <= 0.4:
		_base = 0.15
	else:
		_base = 0.0
