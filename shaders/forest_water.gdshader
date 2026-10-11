shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.30, 0.78, 0.72, 0.72);
uniform vec4 deep_color : source_color = vec4(0.16, 0.52, 0.48, 0.82);
uniform float time_seconds = 0.0;
// New uniforms below default to the polished look itself, so the wishing pool
// picks the upgrade up without any code change: the dusk-sky tint the rim
// catches, and how much of it.
uniform vec3 edge_color : source_color = vec3(1.0, 0.87, 0.60);
uniform float edge_strength : hint_range(0.0, 1.0) = 0.30;

void fragment() {
    // Two slow wave sets crossing at an angle, so the light drifts in
    // shifting cells instead of marching in one direction.
    float waves = sin(UV.x * 13.0 + UV.y * 8.0 + time_seconds * 0.75)
        * cos(UV.x * 6.0 - UV.y * 11.0 + time_seconds * 0.41);
    float moving = 0.5 + 0.5 * waves;
    float islands = smoothstep(0.12, 0.88, moving);

    // The pool's disc spans UV 0..1 across its cap, so distance from the UV
    // centre is distance from the shore. A soft, broken band there reads as
    // water lapping at the stones.
    float from_shore = length(UV - vec2(0.5)) * 2.0;
    float lap = smoothstep(0.60, 0.94, from_shore);
    float arcs = 0.5 + 0.5 * sin(UV.x * 19.0 + time_seconds * 0.9) * sin(UV.y * 17.0 - time_seconds * 1.1);

    float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.4);

    ALBEDO = mix(shallow_color.rgb, deep_color.rgb, islands);
    // Nicer edge: right at the rim the surface catches the dusk sky, a
    // whisper warmer and brighter than the body of the pool.
    ALBEDO += edge_color * (lap * 0.08 + fresnel * edge_strength * 0.45);

    float alpha = mix(shallow_color.a, deep_color.a, islands);
    ALPHA = clamp(alpha * (0.88 + fresnel * 0.12) + lap * arcs * 0.05, 0.0, 1.0);

    ROUGHNESS = 0.18;
    METALLIC = 0.08;

    // Gentle sparkle riding the wave crests themselves: glints only where
    // both wave sets peak, so it twinkles with the drift instead of against
    // it, and no new high frequencies are added to crawl at grazing views.
    float glint = pow(max(0.0, waves), 8.0);
    EMISSION = vec3(0.10, 0.25, 0.22) * islands
        + edge_color * (glint * 0.45 + lap * arcs * 0.16 + fresnel * 0.22) * edge_strength;
}
