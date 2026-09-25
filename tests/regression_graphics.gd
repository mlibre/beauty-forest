extends SceneTree

## Focused checks for the procedural VFX sprites and minimap safe area.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _check_soft_motes()
    _check_minimap_safe_area()
    print("BEAUTY_FOREST_GRAPHICS_OK")
    quit(0)

func _check_soft_motes() -> void:
    var parent := Node3D.new()
    root.add_child(parent)
    var particles := CozyVFX.spawn_ambient_motes(parent, {"accent": "#fff0a5"}, 12)
    assert(particles != null)
    var quad := particles.draw_pass_1 as QuadMesh
    assert(quad != null)
    var material := quad.material as StandardMaterial3D
    assert(material != null)
    var texture := material.albedo_texture as GradientTexture2D
    assert(texture != null)
    assert(texture.fill == GradientTexture2D.FILL_RADIAL)
    assert(texture.gradient != null)
    assert(texture.gradient.colors[0].a > texture.gradient.colors[-1].a)
    assert(is_equal_approx(texture.gradient.colors[-1].a, 0.0))
    parent.queue_free()
    await process_frame
    assert(not is_instance_valid(parent))

func _check_minimap_safe_area() -> void:
    var minimap := CozyMinimap.new()
    minimap.size = Vector2(172, 184)
    var title_top := minimap.size.y - 7.0 - ThemeDB.fallback_font.get_ascent(CozyMinimap.TITLE_FONT_SIZE)
    for dimensions: int in [50, 54, 60, 66, 72]:
        var layout := minimap._map_layout(dimensions, dimensions)
        var map_size: Vector2 = layout["map_size"]
        var origin: Vector2 = layout["origin"]
        # Draw rects overlap by 0.35px to avoid seams between cells.
        var cell_bottom := origin.y + map_size.y + 0.35
        assert(cell_bottom <= title_top)
        assert(origin.x >= CozyMinimap.MAP_MARGIN)
        assert(origin.x + map_size.x + 0.35 <= minimap.size.x - CozyMinimap.MAP_MARGIN)
    minimap.free()
