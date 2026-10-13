shader_type canvas_item;
// An ink wash that reveals a label top-to-bottom without touching layout:
// the label is laid out and drawn in full every frame; this mask only decides
// which rows of it show. Typewriting visible_ratio instead made the autowrap
// label's minimum size dance while it typed (zero visible glyphs report a
// zero-width longest word, and the card's height chased it) -- the battery
// caught exactly that, so the reveal lives here, in draw space.

uniform float reveal : hint_range(0.0, 1.0) = 1.0;
// The feather: how far below the ink line a row is still partly visible,
// as a fraction of the label's height. Keeps the wipe a wash, not a scanline.
uniform float feather : hint_range(0.01, 0.5) = 0.14;

void fragment() {
    vec4 ink = texture(TEXTURE, UV) * COLOR;
    float edge = reveal * (1.0 + feather);
    float distance_below = UV.y - edge + feather;
    float visible = 1.0 - clamp(distance_below / feather, 0.0, 1.0);
    ink.a *= visible;
    // A faintly warm tail rides the ink line, so the reveal reads as a wash
    // of lamplight moving down the page rather than a hard mask sliding.
    float line_glow = exp(-abs(distance_below) * 26.0) * step(0.001, 1.0 - reveal);
    ink.rgb += vec3(1.0, 0.92, 0.62) * line_glow * 0.35;
    COLOR = ink;
}
