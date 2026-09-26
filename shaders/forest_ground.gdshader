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

	// Mid-scale pools where the canopy lets the low sun through. Three
	// incommensurate wave sets, because two of them beat into visible rows
	// across the clearing: at a ~10 world-unit period the floor read as mown
	// stripes rather than as light falling through leaves.
	float dapple = sin(p.x * 0.41 + p.y * 0.17) * sin(p.y * 0.33 - p.x * 0.23) * sin((p.x - p.y) * 0.11);
	float pool = smoothstep(-0.04, 0.60, dapple);

	// Fine grass/clover speckle. Kept low-frequency on purpose: a ~1.4 unit
	// blade term aliased into a crawling shimmer at the far end of the room.
	float fleck = pow(max(0.0, sin(p.x * 1.31) * sin(p.y * 1.17)), 18.0);

	vec3 moss = mix(deep_patch.rgb, base_color.rgb, broad);
	moss = mix(moss, light_patch.rgb, pool * 0.22);
	moss *= COLOR.rgb;
	moss += vec3(0.10, 0.09, 0.025) * fleck;

	ALBEDO = moss;
	ROUGHNESS = 0.96;
	SPECULAR = 0.10;
}
