shader_type canvas_item;

// ULTRANOKIA Vignette — darkens screen edges for atmosphere
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float vignette_size : hint_range(0.0, 1.0) = 0.5;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = uv - vec2(0.5);
	float dist = length(center);
	
	float vignette = smoothstep(vignette_size, vignette_size * 0.3, dist);
	vec4 screen_color = texture(SCREEN_TEXTURE, uv);
	
	COLOR = mix(screen_color, vignette_color, vignette * vignette_intensity);
}
