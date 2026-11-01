shader_type canvas_item;
// Full-screen CRT filter: barrel curvature, scanlines, RGB mask, chromatic aberration and vignette.
// Everything scales with "intensity" (0 = untouched image, 1 = full effect).

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float scanline_count = 360.0; // matches the 640x360 base viewport

vec2 curve(vec2 uv, float amount) {
	uv = uv * 2.0 - 1.0;
	vec2 offset = abs(uv.yx) / vec2(6.0, 4.0);
	uv = uv + uv * offset * offset * amount;
	return uv * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = curve(SCREEN_UV, intensity);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// Chromatic aberration (red/blue split growing towards the edges)
		vec2 dir = (uv - 0.5) * 0.004 * intensity;
		vec3 col;
		col.r = texture(screen_texture, uv + dir).r;
		col.g = texture(screen_texture, uv).g;
		col.b = texture(screen_texture, uv - dir).b;

		// Scanlines
		float scan = 0.5 + 0.5 * sin(uv.y * scanline_count * 3.14159265 * 2.0);
		col *= mix(1.0, 0.65 + 0.35 * scan, intensity);

		// Aperture grille (vertical RGB stripes in screen pixels)
		float stripe = mod(FRAGCOORD.x, 3.0);
		vec3 mask = vec3(stripe < 1.0 ? 1.0 : 0.8, (stripe >= 1.0 && stripe < 2.0) ? 1.0 : 0.8, stripe >= 2.0 ? 1.0 : 0.8);
		col *= mix(vec3(1.0), mask, 0.6 * intensity);

		// Vignette
		vec2 v = uv * (1.0 - uv.yx);
		float vig = pow(clamp(v.x * v.y * 15.0, 0.0, 1.0), 0.25);
		col *= mix(1.0, vig, intensity);

		// Compensate for the darkening
		col *= 1.0 + 0.25 * intensity;
		COLOR = vec4(col, 1.0);
	}
}
