shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float wind_speed : hint_range(0.0, 10.0) = 3.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float snow_layer(vec2 p, float scale, float speed) {
	// Rotate into wind coordinates: long streaks travel down and right.
	vec2 wind_uv = vec2(dot(p, vec2(0.8944, 0.4472)), dot(p, vec2(-0.4472, 0.8944)));
	wind_uv = wind_uv * scale - vec2(TIME * wind_speed * speed, 0.0);
	vec2 cell = floor(wind_uv);
	vec2 local = fract(wind_uv);
	float seed = hash(cell);
	float center = 0.2 + 0.6 * seed;
	float streak = (1.0 - smoothstep(0.20, 0.46, abs(local.x - 0.5)))
		* (1.0 - smoothstep(0.015, 0.065, abs(local.y - center)));
	return streak * step(0.55, seed);
}

void fragment() {
	float strength = clamp(intensity, 0.0, 1.0);
	vec2 p = SCREEN_UV;
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float snow = snow_layer(p, 24.0, 2.8) + snow_layer(p + vec2(4.3, 7.1), 42.0, 4.0);
	float pulse = pow(0.5 + 0.5 * sin(TIME * 1.7), 2.0);
	float clouds = 0.5 + 0.5 * sin(p.x * 5.0 + p.y * 3.0 - TIME * wind_speed)
		* sin(p.y * 7.0 + TIME * 0.8);
	float fog = strength * (0.12 + 0.70 * pulse) * (0.8 + 0.2 * clouds);
	float alpha = 1.0 - (1.0 - fog) * (1.0 - clamp(snow * strength, 0.0, 0.95));
	COLOR = vec4(vec3(1.0), clamp(alpha, 0.0, 0.98));
}
