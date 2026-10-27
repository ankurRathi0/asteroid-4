shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float fear = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float ca = 0.002 + fear * 0.008;
	vec3 col;
	col.r = texture(screen, uv + c * ca).r;
	col.g = texture(screen, uv).g;
	col.b = texture(screen, uv - c * ca).b;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), fear * 0.45);
	float vig = 1.0 - smoothstep(0.3 - fear * 0.15, 0.85, length(c));
	col *= mix(0.2, 1.0, vig);
	col.r += fear * 0.05 * (1.0 - vig);
	float g = fract(sin(dot(uv * 913.7 + fract(TIME * 7.13), vec2(12.9898, 78.233))) * 43758.5453);
	col += (g - 0.5) * (0.05 + fear * 0.05);
	COLOR = vec4(col, 1.0);
}
