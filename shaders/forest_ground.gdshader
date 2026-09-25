shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.48, 0.72, 0.32, 1.0);
uniform vec4 light_patch : source_color = vec4(0.70, 0.77, 0.39, 1.0);
varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 p = world_position.xz;
    float broad = sin(p.x * 0.22 + sin(p.y * 0.13) * 1.7);
    broad += sin(p.y * 0.31 - p.x * 0.08) * 0.72;
    broad += sin((p.x + p.y) * 0.09) * 0.55;
    broad = broad / 2.27 * 0.5 + 0.5;
    float soft_fleck = pow(max(0.0, sin(p.x * 1.31) * sin(p.y * 1.17)), 18.0);
    vec3 instance_tint = COLOR.rgb;
    vec3 moss = mix(base_color.rgb, light_patch.rgb, broad * 0.24);
    moss *= instance_tint;
    moss += vec3(0.10, 0.09, 0.025) * soft_fleck;
    ALBEDO = moss;
    ROUGHNESS = 0.96;
    SPECULAR = 0.10;
}
