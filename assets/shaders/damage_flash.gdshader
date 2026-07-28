shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert;

// UlTRANOKIA Damage Flash Shader — red flash on hit
uniform vec4 base_color : source_color = vec4(0.5, 0.1, 0.1, 1.0);
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Lerp from red flash to base color based on flash_intensity
	vec3 flash = vec3(1.0, 0.0, 0.0);
	vec3 result = mix(base_color.rgb, flash, flash_intensity);
	
	ALBEDO = result;
	
	// Add emission during flash
	EMISSION = flash * flash_intensity * 2.0;
	
	METALLIC = 0.3;
	ROUGHNESS = 0.7;
}
