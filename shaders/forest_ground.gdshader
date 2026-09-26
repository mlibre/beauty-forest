shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// The open forest floor. A single plane instead of a tile grid, so all of the
// interest has to come from the shader: broad moss/sun variation at room
// scale, a mid-scale canopy dapple so the floor is never one flat colour, and
// a fine speckle that reads as grass and clover close to the hero.

uniform vec4 base_color : source_color = vec4(0.48, 0.72, 0.32, 1.0);
uniform vec4 light_patch : source_color = vec4(0.70, 0.77, 0.39, 1.0);
uniform vec4 deep_patch : source_color = vec4(0.36, 0.56, 0.28, 1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;

	// Broad drifts of colour across several metres.
	float broad = sin(p.x * 0.22 + sin(p.y * 0.13) * 1.7);
	broad += sin(p.y * 0.31 - p.x * 0.08) * 0.72;
	broad += sin((p.x + p.y) * 0.09) * 0.55;
	broad = clamp(broad / 2.27 * 0.5 + 0.5, 0.0, 1.0);

	// Mid-scale pools where the canopy lets the low sun through. Two rotated
	// wave sets beat against each other so the pattern never tiles visibly.
	float dapple = sin(p.x * 0.63 + p.y * 0.21) * sin(p.y * 0.57 - p.x * 0.19);
	float pool = smoothstep(-0.15, 0.85, dapple);

	// Fine grass/clover speckle, only visible near the camera.
	float fleck = pow(max(0.0, sin(p.x * 1.31) * sin(p.y * 1.17)), 18.0);
	float blade = pow(max(0.0, sin(p.x * 3.7 + p.y * 2.9)), 24.0);

	vec3 moss = mix(deep_patch.rgb, base_color.rgb, broad);
	moss = mix(moss, light_patch.rgb, pool * 0.34);
	moss *= COLOR.rgb;
	moss += vec3(0.10, 0.09, 0.025) * fleck;
	moss += vec3(0.06, 0.08, 0.02) * blade * 0.5;

	ALBEDO = moss;
	ROUGHNESS = 0.96;
	SPECULAR = 0.10;
}
