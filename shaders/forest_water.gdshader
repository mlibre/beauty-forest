shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.30, 0.78, 0.72, 0.72);
uniform vec4 deep_color : source_color = vec4(0.16, 0.52, 0.48, 0.82);
uniform float time_seconds = 0.0;

void fragment() {
    float moving = 0.5 + 0.5 * sin((UV.x * 13.0 + UV.y * 8.0) + time_seconds * 0.75);
    float islands = smoothstep(0.12, 0.88, moving);
    float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
    ALBEDO = mix(shallow_color.rgb, deep_color.rgb, islands);
    ALPHA = mix(shallow_color.a, deep_color.a, islands) * (0.88 + fresnel * 0.12);
    ROUGHNESS = 0.18;
    METALLIC = 0.08;
    EMISSION = vec3(0.10, 0.25, 0.22) * islands;
}
