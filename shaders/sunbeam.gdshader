shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, shadows_disabled, depth_draw_never, fog_disabled;

// A soft shaft of golden-hour light for the open forest.
//
// The beam is an OPEN cone (no caps) whose surface is drawn additively, so
// there is no geometry to shade "solid" — every fragment lives exactly on the
// cone's surface. That makes distance-from-axis useless as a brightness term:
// it is 1.0 everywhere, by construction. What actually varies across the
// surface is how squarely each fragment faces the camera, so that is what the
// soft rim is built from. Back-facing fragments fall to zero and the cone
// silhouette never shows up as a hard diagonal edge, while both ends fade out
// so the bottom does not cut a visible disc into the moss.

uniform vec3 beam_color : source_color = vec3(1.0, 0.92, 0.66);
uniform float intensity : hint_range(0.0, 1.5) = 0.16;
uniform float edge_softness : hint_range(0.2, 6.0) = 1.7;
uniform float ground_fade : hint_range(0.02, 0.8) = 0.26;
uniform float top_fade : hint_range(0.05, 1.0) = 0.45;
uniform float base_radius = 1.0;
uniform float tip_radius = 0.32;
uniform float beam_height = 10.0;
uniform float drift = 0.0;

varying float v_facing;
varying float v_up;

void vertex() {
	float t = clamp((VERTEX.y + beam_height * 0.5) / max(beam_height, 0.001), 0.0, 1.0);
	// How squarely this patch of the cone surface points at the camera.
	// Abs() so the inside of the far wall glows too: cull_disabled means we
	// draw both sides, and a one-sided beam would look like a paper triangle.
	// VIEW_MATRIX is world->view, so the camera forward vector is already in
	// world space once the matrix is applied: no inverse needed.
	vec3 to_view = normalize((VIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	v_facing = abs(dot(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz), to_view));
	v_up = t;
	// A slow lean keeps the light alive without any visible geometry moving.
	float sway = sin(TIME * 0.31 + drift) * 0.035;
	VERTEX.x += sway * beam_height * t;
	VERTEX.z += cos(TIME * 0.24 + drift) * 0.028 * beam_height * t;
}

void fragment() {
	float radial = pow(clamp(v_facing, 0.0, 1.0), edge_softness);
	float bottom = smoothstep(0.0, ground_fade, v_up);
	float top = 1.0 - smoothstep(1.0 - top_fade, 1.0, v_up);
	float shimmer = 0.88 + 0.12 * sin(TIME * 0.85 + v_up * 4.5 + drift);
	ALBEDO = vec3(0.0);
	EMISSION = beam_color * (radial * bottom * top * intensity * shimmer);
	ALPHA = 1.0;
}