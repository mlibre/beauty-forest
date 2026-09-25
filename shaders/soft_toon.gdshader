shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.62, 0.83, 0.47, 1.0);
uniform vec3 rim_color : source_color = vec3(1.0, 0.87, 0.52);
uniform float rim_strength : hint_range(0.0, 3.0) = 0.38;
uniform float glow : hint_range(0.0, 4.0) = 0.18;
uniform float band_softness : hint_range(0.01, 0.5) = 0.13;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.72;

void fragment() {
    vec3 n = normalize(NORMAL);
    vec3 l = normalize(vec3(-0.42, 0.82, -0.36));
    float ndl = clamp(dot(n, l) * 0.5 + 0.5, 0.0, 1.0);
    float band = smoothstep(0.48 - band_softness, 0.48 + band_softness, ndl);
    float soft = mix(0.72, 1.10, band);
    float view_rim = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 2.25);
    ALBEDO = base_color.rgb * soft;
    ROUGHNESS = roughness_value;
    SPECULAR = 0.22;
    EMISSION = rim_color * (view_rim * rim_strength + glow);
}
