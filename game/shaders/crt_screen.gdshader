shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool enable_crt = true;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.22;
uniform float curvature : hint_range(0.0, 0.2) = 0.04;
uniform float glitch_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 color = texture(screen_texture, uv).rgb;
	if (enable_crt) {
		vec2 centered = uv * 2.0 - 1.0;
		uv = (centered * (1.0 + curvature * dot(centered, centered)) + 1.0) * 0.5;
		float row = floor(uv.y / SCREEN_PIXEL_SIZE.y);
		float tick = floor(TIME * 24.0);
		float jitter = fract(sin(floor(row / 8.0) * 127.1 + tick * 311.7) * 43758.5453);
		uv.x += (jitter - 0.5) * 0.04 * glitch_amount * step(0.8, jitter);
		// Nearest sampling preserves the source pixel art.
		vec2 split = vec2(SCREEN_PIXEL_SIZE.x * 0.6, 0.0);
		color = vec3(texture(screen_texture, uv + split).r,
			texture(screen_texture, uv).g, texture(screen_texture, uv - split).b);
		color *= 1.0 - clamp(scanline_strength, 0.0, 1.0) * mod(row, 2.0);
		color *= 1.0 - 0.48 * smoothstep(0.35, 1.5, dot(centered, centered));
		float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
		color *= inside;
	}
	COLOR = vec4(color, 1.0);
}
