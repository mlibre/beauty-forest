class_name CozyTheme
extends RefCounted

## The forest's wardrobe: the one place the game's type dressing lives. Every
## screen inherits this Theme from the interface root, so a heading wears the
## same rounded, storybook face on the menu, the pause card and Peddle's cart,
## and nothing can drift back to the engine's default system font.

const BALOO_PATH := "res://assets/fonts/Baloo2.ttf"
const NUNITO_PATH := "res://assets/fonts/Nunito.ttf"

## Headings and buttons wear Baloo 2 — rounded, warm, a little hand-lettered.
## Body text wears Nunito, whose soft terminals keep long lines calm at small
## sizes. Both are variable fonts under the SIL Open Font License
## (assets/fonts/OFL-*.txt), pinned here to their friendliest weights.
static func build() -> Theme:
    var theme := Theme.new()
    theme.default_font = _weighted(NUNITO_PATH, 400.0)
    theme.default_font_size = 18
    theme.set_type_variation("HeadingLabel", "Label")
    theme.set_font("font", "HeadingLabel", _weighted(BALOO_PATH, 500.0))
    theme.set_font("font", "Button", _weighted(BALOO_PATH, 500.0))
    return theme

static func _weighted(path: String, weight: float) -> FontVariation:
    var font := FontVariation.new()
    font.base_font = load(path) as FontFile
    font.variation_opentype = {"wght": weight}
    return font
