shader_type canvas_item;
// Ground fog (GroundFog): two layers of value noise drifting with the wind, in world coordinates and snapped to the
// pixel grid. Drawn just above the floor, so props and actors stand inside it; the night layer shades it.
// Where nothing was drawn below it (only the level background, the void outside the map) there is no fog.
render_mode unshaded;

// What is already on screen below the fog (floor, shadows)
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
// Background (clear color) of the level: pixels of this color have no ground under them
uniform vec4 void_color = vec4(0.0, 0.0, 0.0, 1.0);

uniform vec4 fog_color = vec4(0.8, 0.78, 0.95, 1.0);
// Maximum opacity of the thickest patches
uniform float density : hint_range(0.0, 1.0) = 0.2;
// World px -> noise cells (smaller = bigger patches)
uniform float noise_scale = 0.008;
// Drift (px/s)
uniform vec2 wind = vec2(7.0, 2.5);
// Noise level where the fog starts and how soft its edge is
uniform float coverage : hint_range(0.0, 1.0) = 0.42;
uniform float softness : hint_range(0.01, 1.0) = 0.35;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 3; i++) {
		sum += amplitude * value_noise(p);
		p = p * 2.07 + vec2(13.1, 7.7);
		amplitude *= 0.5;
	}
	return sum / 0.875;
}

void fragment() {
	vec2 p = floor(world_pos) * noise_scale;
	vec2 drift = wind * noise_scale * TIME;
	// Banks stretched sideways, plus a finer layer moving slower in another direction
	float n = fbm(p * vec2(1.0, 1.6) - drift) * 0.65 + fbm(p * 1.9 + drift * 0.55 + 31.7) * 0.35;
	float alpha = smoothstep(coverage, coverage + softness, n);
	vec3 below = texture(screen_texture, SCREEN_UV).rgb;
	float on_ground = smoothstep(0.015, 0.04, distance(below, void_color.rgb));
	COLOR = vec4(fog_color.rgb, alpha * density * on_ground);
}
