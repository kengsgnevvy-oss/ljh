shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert;

// UlTRANOKIA Glow Shader — emissive pulsing glow for enemies & bosses
uniform vec4 glow_color : source_color = vec4(1.0, 0.3, 0.05, 1.0);
uniform float glow_strength : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_amplitude : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	// Standard albedo
	ALBEDO = glow_color.rgb * 0.3;
	
	// Pulsing emission
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amplitude;
	EMISSION = glow_color.rgb * glow_strength * pulse;
	
	// Metallic/rough for hell-tech look
	METALLIC = 0.6;
	ROUGHNESS = 0.4;
}
