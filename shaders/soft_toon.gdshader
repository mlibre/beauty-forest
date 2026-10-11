shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.62, 0.83, 0.47, 1.0);
uniform vec3 rim_color : source_color = vec3(1.0, 0.87, 0.52);
uniform float rim_strength : hint_range(0.0, 3.0) = 0.38;
uniform float glow : hint_range(0.0, 4.0) = 0.18;
uniform float band_softness : hint_range(0.01, 0.5) = 0.13;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.72;
// New uniforms below all default to the polished look itself, so materials
// that only set the originals (everything through CozyMaterials.toon) pick
// the upgrade up without any code change.
uniform float rim_width : hint_range(0.5, 4.0) = 1.7;
uniform vec3 warmth_color : source_color = vec3(1.0, 0.80, 0.58);
uniform float warmth_strength : hint_range(0.0, 1.0) = 0.16;
uniform float warmth_height : hint_range(0.2, 8.0) = 1.6;

varying vec3 v_world;

void vertex() {
    v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 n = normalize(NORMAL);
    vec3 l = normalize(vec3(-0.42, 0.82, -0.36));
    float ndl = clamp(dot(n, l) * 0.5 + 0.5, 0.0, 1.0);
    // One wide smooth ramp carries the whole shading and a toon band rides on
    // top of it, meeting at the same 0.48 terminator: the old single hard
    // step between two flats is gone, but every painted creature keeps its
    // toon silhouette. A faint sheen near the top of the ramp keeps the lit
    // side from reading as one flat fill.
    float ramp = smoothstep(0.08, 0.94, ndl);
    float band = smoothstep(0.48 - band_softness, 0.48 + band_softness, ndl);
    float soft = mix(mix(0.70, 1.05, ramp), 1.10, band * 0.55);
    soft += 0.05 * smoothstep(0.74, 0.94, ndl);
    // A soft, wide rim reads as lantern warmth: a low-exponent fresnel eased
    // through one more smoothstep so the glow melts into the silhouette
    // instead of stopping at a band.
    float view_rim = smoothstep(0.0, 1.0, pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), rim_width));
    // Subtle height warmth: within lantern reach of the moss the colour leans
    // a touch more golden, fading out above the wisp line.
    float warmth = 1.0 - smoothstep(warmth_height * 0.3, warmth_height, v_world.y);
    ALBEDO = base_color.rgb * soft * mix(vec3(1.0), warmth_color, warmth * warmth_strength);
    ROUGHNESS = roughness_value;
    SPECULAR = 0.22;
    EMISSION = rim_color * (view_rim * rim_strength + glow);
}
