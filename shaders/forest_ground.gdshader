shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// The open forest floor. A single plane instead of a tile grid, so all of the
// interest has to come from the shader: broad moss/sun variation at room
// scale, a mid-scale canopy dapple so the floor is never one flat colour, and
// a fine speckle that reads as grass and clover close to the hero. All three
// scales run through one value-noise field so they blend like moss rather
// than layered wallpaper, and a sparse glitter lights the pools where the low
// sun lands near the hero.

uniform vec4 base_color : source_color = vec4(0.48, 0.72, 0.32, 1.0);
uniform vec4 light_patch : source_color = vec4(0.70, 0.77, 0.39, 1.0);
uniform vec4 deep_patch : source_color = vec4(0.36, 0.56, 0.28, 1.0);
uniform float sparkle_strength : hint_range(0.0, 1.0) = 0.30;
// How strongly the sun pools light the floor. The compatibility renderer has
// no SSAO/SSIL, so the pools it paints flat read brighter than the same
// numbers on Forward+; the web calibration turns this down instead of
// darkening the whole moss (which would flatten the drifts too).
uniform float pool_strength : hint_range(0.0, 1.0) = 1.0;

varying vec3 world_position;
varying float view_depth;

float hash12(vec2 p) {
        p = fract(p * vec2(123.34, 345.45));
        p += dot(p, p + 34.345);
        return fract(p.x * p.y);
}

float value_noise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        float a = hash12(i);
        float b = hash12(i + vec2(1.0, 0.0));
        float c = hash12(i + vec2(0.0, 1.0));
        float d = hash12(i + vec2(1.0, 1.0));
        return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
        world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
        vec2 p = world_position.xz;

        // Broad drifts of colour across several metres, domain-warped by a
        // second noise field so the drifts curl instead of running straight.
        float broad = value_noise(p * 0.09 + value_noise(p * 0.16 + vec2(31.4)) * 1.6);

        // Very large patchiness: whole yards of floor lean a little richer or
        // a little sunnier than their neighbours, and bias both the drift mix
        // and the pool strength below.
        float drift = value_noise(p * 0.045 + vec2(4.7));

        // Mid-scale pools where the canopy lets the low sun through. Two
        // incommensurate noise scales, because a single wave set beat into
        // visible rows across the clearing: at a ~10 world-unit period the
        // floor read as mown stripes rather than as light falling through
        // leaves.
        float dapple = value_noise(p * 0.33) * 0.68 + value_noise(p * 0.21 + vec2(9.1)) * 0.32;
        float pool = smoothstep(0.42, 0.78, dapple);

        // Fine grass/clover speckle. Kept low-frequency on purpose: a ~1.4 unit
        // blade term aliased into a crawling shimmer at the far end of the room.
        float fleck = pow(max(0.0, sin(p.x * 1.31) * sin(p.y * 1.17)), 18.0);

        vec3 moss = mix(deep_patch.rgb, base_color.rgb, clamp(broad * (0.82 + 0.36 * drift), 0.0, 1.0));
        moss = mix(moss, light_patch.rgb, pool * (0.16 + 0.14 * drift) * pool_strength);
        moss *= COLOR.rgb;
        moss *= 0.94 + 0.10 * drift;
        moss += vec3(0.10, 0.09, 0.025) * fleck;

        // Faint dew glitter: a sparse field of facets, lit mostly inside the
        // sun pools and only near the hero. The camera is fixed isometric, so
        // a true view-angle term is constant across a flat floor; distance
        // from the eye is what keeps the effect where the player is looking
        // and keeps far-off glints from crawling.
        float near_field = 1.0 - smoothstep(5.0, 20.0, view_depth);
        float glint = smoothstep(0.87, 0.96, value_noise(p * 2.35 + vec2(17.3)));
        EMISSION = vec3(1.0, 0.88, 0.58) * glint * near_field * (0.15 + 0.85 * pool) * sparkle_strength * 2.2;

        ALBEDO = moss;
        ROUGHNESS = 0.96;
        SPECULAR = 0.10;
}
