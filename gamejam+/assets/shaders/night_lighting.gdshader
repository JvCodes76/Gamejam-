shader_type canvas_item;
// Night lighting (NightLighting): multiplies everything drawn below this layer (ground, props, actors) by the
// ambient color plus the point lights on screen. Layers above it (projectiles, impacts, damage numbers) keep full
// brightness. Single pass, no Light2D: the cost does not grow with the number of sprites.
render_mode unshaded, blend_mul;

// Keep equal to NightLighting.MAX_LIGHTS
const int MAX_LIGHTS = 24;
// Lights become ellipses on the ground (3/4 top-down view): vertical distance counts more
const float GROUND_SQUASH = 1.3;

uniform vec4 ambient_color = vec4(0.74, 0.7, 0.88, 1.0);
// Nothing gets darker than this (per channel): keeps the game readable
uniform float min_brightness : hint_range(0.0, 1.0) = 0.42;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.22;
uniform float vignette_start = 0.42;
// Steps in the light falloff (0 = smooth; 4 to 6 gives a pixel-art look)
uniform float light_bands = 0.0;
uniform int light_count = 0;
// xy = world position, z = radius (px), w = energy
uniform vec4 light_data[MAX_LIGHTS];
uniform vec4 light_colors[MAX_LIGHTS];

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Snapped to the world pixel grid, so the light edges match the pixel art
	vec2 p = floor(world_pos) + 0.5;
	vec3 light = ambient_color.rgb;
	for (int i = 0; i < light_count; i++) {
		vec4 data = light_data[i];
		vec2 delta = (p - data.xy) * vec2(1.0, GROUND_SQUASH);
		float falloff = 1.0 - dot(delta, delta) / (data.z * data.z);
		if (falloff > 0.0) {
			falloff *= falloff;
			if (light_bands > 0.0) {
				falloff = ceil(falloff * light_bands) / light_bands;
			}
			light += light_colors[i].rgb * data.w * falloff;
		}
	}
	// Above 1 the multiply would clip: scale down keeping the hue (warm lights stay warm instead of turning white)
	float peak = max(light.r, max(light.g, light.b));
	light /= max(peak, 1.0);
	vec2 centered = SCREEN_UV - 0.5;
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	light *= 1.0 - vignette_strength * smoothstep(vignette_start, vignette_start + 0.5, length(centered));
	COLOR = vec4(max(light, vec3(min_brightness)), 1.0);
}
