shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float amount = clamp(glitch_intensity, 0.0, 1.0);
	vec2 uv = SCREEN_UV;
	vec3 color = texture(screen_texture, uv).rgb;
	if (amount > 0.0) {
		float tick = floor(TIME * 30.0);
		float row = floor(uv.y / SCREEN_PIXEL_SIZE.y);
		float band = hash(vec2(floor(row / 4.0), tick));
		float tear = step(1.0 - amount * 0.65, band);
		uv.x = clamp(uv.x + (band - 0.5) * amount * 0.25 * tear, 0.0, 1.0);
		vec2 split = vec2(amount * (0.008 + tear * 0.018), 0.0);
		color = vec3(texture(screen_texture, uv + split).r,
			texture(screen_texture, uv).g, texture(screen_texture, uv - split).b);
		vec2 block = floor(SCREEN_UV / (SCREEN_PIXEL_SIZE * vec2(16.0, 8.0)));
		float corruption = hash(block + vec2(tick, -tick));
		float mask = step(1.0 - amount * 0.3, corruption);
		vec3 noise = vec3(hash(block + tick), hash(block + tick + 19.0), hash(block + tick + 47.0));
		color = mix(color, noise, mask * amount);
		color *= 1.0 - amount * 0.2 * mod(row, 2.0);
	}
	COLOR = vec4(color, 1.0);
}
