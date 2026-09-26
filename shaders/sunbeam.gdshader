shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, shadows_disabled, depth_draw_never, fog_disabled;

// A soft shaft of golden-hour light for the open forest.
//
// The beam is a capped-off cone whose surface is drawn additively, so the
// brightness has to come from the shader rather than the material: the rim
// must fade to nothing (otherwise the cone silhouette shows up as a hard
// diagonal edge across the screen) and both ends must fade out (otherwise the
// bottom of the cone cuts a visible disc into the moss).
//
// v_radial is the fragment's distance from the beam axis, normalized against
// the cone radius at that height: 0 on the axis, 1 at the surface.

uniform vec3 beam_color : source_color = vec3(1.0, 0.92, 0.66);
uniform float intensity : hint_range(0.0, 1.5) = 0.16;
uniform float edge_softness : hint_range(0.2, 6.0) = 1.7;
uniform float ground_fade : hint_range(0.02, 0.8) = 0.26;
uniform float top_fade : hint_range(0.05, 1.0) = 0.45;
uniform float base_radius = 1.0;
uniform float tip_radius = 0.32;
uniform float beam_height = 10.0;
uniform float drift = 0.0;

varying float v_radial;
varying float v_up;

void vertex() {
	float t = clamp((VERTEX.y + beam_height * 0.5) / max(beam_height, 0.001), 0.0, 1.0);
	float radius = mix(base_radius, tip_radius, t);
	v_radial = clamp(length(VERTEX.xz) / max(radius, 0.0001), 0.0, 1.0);
	v_up = t;
	// A slow lean keeps the light alive without any visible geometry moving.
	float sway = sin(TIME * 0.31 + drift) * 0.035;
	VERTEX.x += sway * beam_height * t;
	VERTEX.z += cos(TIME * 0.24 + drift) * 0.028 * beam_height * t;
}

void fragment() {
	float radial = pow(clamp(1.0 - v_radial, 0.0, 1.0), edge_softness);
	float bottom = smoothstep(0.0, ground_fade, v_up);
	float top = 1.0 - smoothstep(1.0 - top_fade, 1.0, v_up);
	float shimmer = 0.88 + 0.12 * sin(TIME * 0.85 + v_up * 4.5 + drift);
	ALBEDO = vec3(0.0);
	EMISSION = beam_color * (radial * bottom * top * intensity * shimmer);
	ALPHA = 1.0;
}
