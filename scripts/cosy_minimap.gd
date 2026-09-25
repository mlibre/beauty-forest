class_name CozyMinimap
extends Control

const MAP_MARGIN := 9.0
const MAP_FOOTER := 24.0
const TITLE_FONT_SIZE := 9

var dungeon: Dictionary = {}
var player_position := Vector3.ZERO
var markers: Array[Dictionary] = []
var high_contrast := false
## The grove grid never changes between floors, but GameUI queues a redraw
## every frame for the moving player dot. Rasterizing 2.5k-5.2k `draw_rect`
## calls per frame for a static layer measured 43-119 ms/frame (2.5-7x a whole
## 60 fps frame budget), so the grid is baked into a texture once per
## map/size/contrast change and blitted with a single draw call.
var _grid_texture: ImageTexture
var _grid_cache_key := ""
var _map_revision := 0

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func set_map(value: Dictionary, player: Vector3) -> void:
    dungeon = value
    player_position = player
    # Grid dimensions repeat across the campaign (the generator caps width), so
    # the cache key needs floor identity too — otherwise floor 10 would draw
    # floor 9's grove.
    _map_revision += 1
    queue_redraw()

func set_markers(value: Array[Dictionary]) -> void:
    markers = value
    queue_redraw()

func _draw() -> void:
    var background := Color("#15281e") if high_contrast else Color(0.10, 0.20, 0.14, 0.84)
    draw_style_box(_style(background, Color("#ffe7a0"), 12, 2), Rect2(Vector2.ZERO, size))
    if dungeon.is_empty():
        return
    var width := int(dungeon["width"])
    var height := int(dungeon["height"])
    var layout := _map_layout(width, height)
    var scale: float = layout["scale"]
    var map_size: Vector2 = layout["map_size"]
    var origin: Vector2 = layout["origin"]
    var floor_color := Color("#b7cf73") if high_contrast else Color(0.57, 0.72, 0.35, 0.72)
    var wall_color := Color("#304c35") if high_contrast else Color(0.16, 0.34, 0.21, 0.88)
    _ensure_grid_texture(width, height, floor_color, wall_color)
    if _grid_texture != null:
        # Half a pixel of overlap keeps neighbouring cells from showing seams
        # at non-integer scales (the old per-cell draw_rects overlapped 0.35).
        draw_texture_rect(_grid_texture, Rect2(origin - Vector2(0.5, 0.5), map_size + Vector2(1.0, 1.0)), false)
    for marker: Dictionary in markers:
        var marker_position := origin + Vector2(float(marker["x"]), float(marker["z"])) * scale
        draw_circle(marker_position, 2.8, marker.get("color", Color("#ffe9a0")))
    var player_map := origin + Vector2(player_position.x, player_position.z) * scale
    draw_circle(player_map, 3.8, Color("#fff7d4"))
    draw_circle(player_map, 1.8, Color("#e89562"))
    draw_string(ThemeDB.fallback_font, Vector2(10, size.y - 7), "GROVE MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FONT_SIZE, Color("#ffe9a0"))

func _ensure_grid_texture(width: int, height: int, floor_color: Color, wall_color: Color) -> void:
    ## Rebuild the static grove layer only when it actually changes: a new
    ## floor, a resized minimap, or a contrast-palette flip.
    var key := "%d|seed%d|%dx%d|%.1fx%.1f|%s" % [_map_revision, int(dungeon.get("seed", 0)), width, height, size.x, size.y, "hc" if high_contrast else "nc"]
    if _grid_texture != null and key == _grid_cache_key:
        return
    _grid_cache_key = key
    var image := Image.create(maxi(1, width), maxi(1, height), false, Image.FORMAT_RGBA8)
    var grid: PackedInt32Array = dungeon["grid"]
    for z in height:
        for x in width:
            image.set_pixel(x, z, floor_color if grid[z * width + x] == 1 else wall_color)
    _grid_texture = ImageTexture.create_from_image(image)

func _map_layout(width: int, height: int) -> Dictionary:
    var map_area := Rect2(
        Vector2(MAP_MARGIN, MAP_MARGIN),
        Vector2(
            maxf(1.0, size.x - MAP_MARGIN * 2.0),
            maxf(1.0, size.y - MAP_MARGIN - MAP_FOOTER)
        )
    )
    var safe_width := maxi(1, width)
    var safe_height := maxi(1, height)
    var scale := minf(map_area.size.x / float(safe_width), map_area.size.y / float(safe_height))
    var map_size := Vector2(float(safe_width), float(safe_height)) * scale
    var origin := map_area.position + (map_area.size - map_size) * 0.5
    return {"scale": scale, "map_size": map_size, "origin": origin}

func _style(fill: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(radius)
    return style
