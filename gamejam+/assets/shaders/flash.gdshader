shader_type canvas_item;
// Flash de dano: mistura a cor do sprite até "flash_color" (0 = normal, 1 = cor sólida). Um shader para todos os sprites.

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	base.rgb = mix(base.rgb, flash_color.rgb, flash);
	COLOR = base;
}
