shader_type canvas_item;

// ULTRANOKIA Vignette — darkens screen edges for atmosphere
// Applied as a fullscreen ColorRect overlay in the HUD
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float vignette_size : hint_range(0.1, 1.0) = 0.55;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = UV;
	vec2 center = uv - vec2(0.5);
	float dist = length(center);
	
	// Radial vignette: 0 at center, 1 at edges
	float vignette = smoothstep(vignette_size * 0.6, vignette_size, dist);
	
	COLOR = vec4(vignette_color.rgb, vignette_color.a * vignette * vignette_intensity);
}
