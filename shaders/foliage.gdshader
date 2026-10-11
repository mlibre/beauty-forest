shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.43, 0.76, 0.31, 1.0);
uniform vec4 tip_color : source_color = vec4(0.72, 0.91, 0.38, 1.0);
uniform float wind_time = 0.0;
uniform float wind_strength : hint_range(0.0, 0.2) = 0.025;
uniform float glow_amount : hint_range(0.0, 1.0) = 0.08;
// How strongly the upper shell of each crown leans toward the tip colour.
uniform float tip_gradient : hint_range(0.0, 1.0) = 0.22;

varying float v_lift;

void vertex() {
    vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    // Per-instance phase: where the crown stands drifts the wave phase, and a
    // hash of that spot de-correlates the neighbours the wave phase alone
    // would keep swaying in lockstep.
    float seed = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
    float phase = origin.x * 0.31 + origin.z * 0.23 + seed * 6.2831;
    // Two frequencies carry the gust -- a slow lean and a quick flutter --
    // and a third, much slower one breathes across whole groves, so the
    // canopy ripples in passing waves instead of twitching in place.
    float sway = sin(wind_time * 1.15 + phase) + 0.42 * sin(wind_time * 2.17 + phase * 1.7);
    sway += 0.45 * sin(wind_time * 0.47 + origin.x * 0.09 + origin.z * 0.07);
    float height_mask = smoothstep(-0.2, 2.8, VERTEX.y);
    VERTEX.x += sway * wind_strength * height_mask;
    VERTEX.z += (cos(wind_time * 0.83 + phase) + 0.30 * sin(wind_time * 0.61 + phase * 1.3)) * wind_strength * 0.45 * height_mask;
    // Local height over the crown: the tip-lightening gradient hangs off the
    // untransformed vertex, so instance scaling cannot stretch it. The grove
    // crown is a 1.6-tall sphere, so this spans 0 at the underside to 1 at
    // the crown top.
    v_lift = clamp(VERTEX.y / 1.6 + 0.5, 0.0, 1.0);
}

void fragment() {
    float variation = clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0);
    // Gentle tip-lightening: the low sun pools on the upper shells of crowns.
    float tip_light = smoothstep(0.25, 0.95, v_lift) * tip_gradient;
    ALBEDO = mix(base_color.rgb, tip_color.rgb, clamp(variation * 0.52 + tip_light, 0.0, 1.0)) * COLOR.rgb;
    ROUGHNESS = 0.88;
    // The tip glow breathes with the same gradient, centred on the old flat
    // emission so the mean brightness stays where callers tuned it.
    EMISSION = tip_color.rgb * glow_amount * (0.8 + 0.4 * smoothstep(0.25, 0.95, v_lift));
    BACKLIGHT = vec3(0.16, 0.18, 0.05);
}
