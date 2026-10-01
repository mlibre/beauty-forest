extends SceneTree

## Focused checks for the procedural VFX sprites and minimap safe area.

func _initialize() -> void:
    call_deferred("_run")

## assert() only logs a SCRIPT ERROR here and keeps going, so this suite would
## print OK even with a failed check. Anything that must fail the run collects
## into _failures and exits non-zero, matching regression_audio.gd.
var _failures: Array[String] = []

func _check(condition: bool, message: String) -> void:
    if not condition:
        _failures.append(message)

func _run() -> void:
    _check_soft_motes()
    _check_minimap_safe_area()
    _check_sunbeam_actually_emits()
    if _failures.is_empty():
        print("BEAUTY_FOREST_GRAPHICS_OK")
        quit(0)
        return
    for failure in _failures:
        printerr("GRAPHICS_REGRESSION_FAIL: " + failure)
    quit(1)

func _check_sunbeam_actually_emits() -> void:
    ## The beam is an OPEN cone, so every fragment sits exactly on the cone
    ## surface. A brightness term built from distance-from-axis is therefore
    ## 1.0 everywhere and the shader emitted literally nothing: measured peak
    ## emission 0.0 against a working 0.137, with 4-5 dead beams per floor.
    ## The soft rim has to come from how squarely a patch faces the camera.
    var shader: Shader = load("res://shaders/sunbeam.gdshader")
    _check(shader != null, "the sunbeam shader failed to load")
    if shader == null:
        return
    var code: String = shader.code
    _check(not code.contains("v_radial"),
        "the sunbeam still derives brightness from distance-from-axis, which is constant on an open cone")
    _check(code.contains("v_facing"),
        "the sunbeam needs a view-facing term to have any soft rim at all")

    # Reproduce the builder's geometry and confirm the facing term has range.
    var base_radius := 0.84
    var height := 11.0
    var mesh := CylinderMesh.new()
    mesh.top_radius = base_radius * 0.30
    mesh.bottom_radius = base_radius
    mesh.height = height
    mesh.radial_segments = 14
    mesh.cap_top = false
    mesh.cap_bottom = false
    var arrays: Array = mesh.get_mesh_arrays()
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    _check(not normals.is_empty(), "the beam mesh produced no normals")
    if normals.is_empty():
        return
    var to_view := Vector3(0.707, 0.55, 0.707).normalized()
    var lowest := 1.0
    var highest := 0.0
    for index in range(normals.size()):
        var facing: float = absf(normals[index].normalized().dot(to_view))
        lowest = minf(lowest, facing)
        highest = maxf(highest, facing)
    _check(highest > 0.5, "no patch of the beam faces the camera, so it would never glow")
    _check(lowest < 0.35, "every patch faces the camera equally, so the beam has no soft edge")
    _check(highest - lowest > 0.2, "the facing term is nearly constant, so the rim fade would not read")

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
