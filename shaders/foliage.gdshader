shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.43, 0.76, 0.31, 1.0);
uniform vec4 tip_color : source_color = vec4(0.72, 0.91, 0.38, 1.0);
uniform float wind_time = 0.0;
uniform float wind_strength : hint_range(0.0, 0.2) = 0.025;
uniform float glow_amount : hint_range(0.0, 1.0) = 0.08;

void vertex() {
    vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    float phase = origin.x * 0.31 + origin.z * 0.23;
    float sway = sin(wind_time * 1.15 + phase) + 0.42 * sin(wind_time * 2.17 + phase * 1.7);
    float height_mask = smoothstep(-0.2, 2.8, VERTEX.y);
    VERTEX.x += sway * wind_strength * height_mask;
    VERTEX.z += cos(wind_time * 0.83 + phase) * wind_strength * 0.45 * height_mask;
}

void fragment() {
    float variation = clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0);
    ALBEDO = mix(base_color.rgb, tip_color.rgb, variation * 0.52) * COLOR.rgb;
    ROUGHNESS = 0.88;
    EMISSION = tip_color.rgb * glow_amount;
    BACKLIGHT = vec3(0.12, 0.18, 0.04);
}
