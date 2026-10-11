extends "res://tests/support/test_case.gd"
## Focused checks for the procedural VFX sprites and minimap safe area.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyContent := preload("res://scripts/beauty_content.gd")
const CozyMinimap := preload("res://scripts/cozy_minimap.gd")
const CozyVFX := preload("res://scripts/cozy_vfx.gd")
const DungeonGenerator := preload("res://scripts/dungeon_generator.gd")
const WorldScenery := preload("res://scripts/world_scenery.gd")

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_GRAPHICS"
    call_deferred("_run")

func _run() -> void:
    await _check_soft_motes()
    _check_minimap_safe_area()
    _check_sunbeam_actually_emits()
    await _check_no_particle_writes_a_color_it_cannot_draw()
    finish(null, "BEAUTY_FOREST_GRAPHICS")

func _check_sunbeam_actually_emits() -> void:
    ## The beam is an OPEN cone, so every fragment sits exactly on the cone
    ## surface. A brightness term built from distance-from-axis is therefore
    ## 1.0 everywhere and the shader emitted literally nothing: measured peak
    ## emission 0.0 against a working 0.137, with 4-5 dead beams per floor.
    ## The soft rim has to come from how squarely a patch faces the camera.
    var shader: Shader = load("res://shaders/sunbeam.gdshader")
    if not ok(shader != null, "the sunbeam shader failed to load"):
        return
    var code: String = shader.code
    ok(not code.contains("v_radial"),
        "the sunbeam still derives brightness from distance-from-axis, which is constant on an open cone")
    ok(code.contains("v_facing"),
        "the sunbeam needs a view-facing term to have any soft rim at all")
    ok(not code.contains("VIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)"),
        "the sunbeam probed the camera forward through raw VIEW_MATRIX, so two reference frames got dotted")
    ok(code.contains("INV_VIEW_MATRIX"),
        "the sunbeam needs the camera forward in world space: INV_VIEW_MATRIX * (0,0,-1,0).xyz")

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
    if not ok(not normals.is_empty(), "the beam mesh produced no normals"):
        return
    var to_view := Vector3(0.707, 0.55, 0.707).normalized()
    var lowest := 1.0
    var highest := 0.0
    for index in range(normals.size()):
        var facing: float = absf(normals[index].normalized().dot(to_view))
        lowest = minf(lowest, facing)
        highest = maxf(highest, facing)
    ok(highest > 0.5, "no patch of the beam faces the camera, so it would never glow")
    ok(lowest < 0.35, "every patch faces the camera equally, so the beam has no soft edge")
    ok(highest - lowest > 0.2, "the facing term is nearly constant, so the rim fade would not read")

func _check_soft_motes() -> void:
    var parent := Node3D.new()
    root.add_child(parent)
    var particles := CozyVFX.spawn_ambient_motes(parent, {"accent": "#fff0a5"}, 12)
    if ok(particles != null, "the ambient mote emitter was not spawned"):
        await _check_mote_sprite(particles)
    await _discard(parent)

func _check_mote_sprite(emitter: GPUParticles3D) -> void:
    var quad := emitter.draw_pass_1 as QuadMesh
    if not ok(quad != null, "the mote emitter has no quad to draw"):
        return
    var material := quad.material as StandardMaterial3D
    if not ok(material != null, "the mote quad has no material"):
        return
    var texture := material.albedo_texture as GradientTexture2D
    if not ok(texture != null, "the mote material has no gradient texture"):
        return
    ok(texture.fill == GradientTexture2D.FILL_RADIAL,
        "the mote texture is not radial, so it reads as a hard disc")
    if not ok(texture.gradient != null, "the mote texture has no gradient to fade through"):
        return
    ok(texture.gradient.colors[0].a > texture.gradient.colors[-1].a,
        "the mote sprite does not fade out")
    ok(is_equal_approx(texture.gradient.colors[-1].a, 0.0),
        "the mote sprite does not fade to fully transparent")

## Frees a probe node and records whether it actually went away, so a leak is a
## failure rather than an assert that only prints.
func _discard(node: Node) -> void:
    var label := str(node.name)
    node.queue_free()
    await frames(1)
    ok(not is_instance_valid(node), "the probe node %s was not freed" % label)

func _check_minimap_safe_area() -> void:
    var minimap := CozyMinimap.new()
    minimap.size = Vector2(172, 184)
    for dimensions: int in [50, 54, 60, 66, 72]:
        var layout := minimap._map_layout(dimensions, dimensions)
        var map_size: Vector2 = layout["map_size"]
        var origin: Vector2 = layout["origin"]
        # The grove texture is blitted CELL_BLEED past its rect on every side,
        # so the painted edge is what has to stay inside the margin.
        var painted := Rect2(origin - Vector2(CozyMinimap.CELL_BLEED, CozyMinimap.CELL_BLEED),
            map_size + Vector2(CozyMinimap.CELL_BLEED, CozyMinimap.CELL_BLEED) * 2.0)
        ok(painted.position.y >= CozyMinimap.MAP_MARGIN,
            "the grove map paints %.2fpx above its top margin" % (CozyMinimap.MAP_MARGIN - painted.position.y))
        ok(painted.position.x >= CozyMinimap.MAP_MARGIN,
            "the grove map paints %.2fpx left of its margin" % (CozyMinimap.MAP_MARGIN - painted.position.x))
        ok(painted.end.x <= minimap.size.x - CozyMinimap.MAP_MARGIN,
            "the grove map paints %.2fpx past its right margin" % (painted.end.x - (minimap.size.x - CozyMinimap.MAP_MARGIN)))
        ok(painted.end.y <= minimap.size.y - CozyMinimap.MAP_MARGIN,
            "the grove map paints %.2fpx past its bottom margin" % (painted.end.y - (minimap.size.y - CozyMinimap.MAP_MARGIN)))
    minimap.free()
## A ParticleProcessMaterial's color only reaches the screen when the draw
## material sets vertex_color_use_as_albedo. Every emitter in this game is
## unshaded with a fixed albedo, so a process.color line was a write nobody
## read: three emitters carried one, including the falling leaves, where it
## read as though leaf color were varied per particle and was not.
##
## Both halves are pinned -- an emitter may not write a color it cannot draw,
## and the multimesh emitters that legitimately carry per-instance colors must
## keep vertex_color_use_as_albedo, or their colors silently vanish.
func _check_no_particle_writes_a_color_it_cannot_draw() -> void:
    var default_color: Color = ParticleProcessMaterial.new().color

    var parent := Node3D.new()
    root.add_child(parent)
    var emitters: Array[GPUParticles3D] = []
    emitters.append(CozyVFX.spawn_ambient_motes(parent, {"accent": "#fff0a5"}, 12))
    CozyVFX.burst(parent, Vector3.ZERO, Color("#ffe6a0"), 6, 1.0)
    await frames(1)
    # burst() is fire-and-forget, so collect it by its distinguishing lifetime.
    for child in parent.get_children():
        if child is GPUParticles3D:
            var candidate := child as GPUParticles3D
            if float(candidate.lifetime) < 1.0:
                emitters.append(candidate)

    ok(emitters.size() >= 2,
        "expected the mote and burst emitters, found %d" % emitters.size())
    var mismatched: Array[String] = []
    for emitter in emitters:
        _particle_color_mismatch(emitter, default_color, mismatched)
    if mismatched.size() > 0:
        print("GRAPHICS_PARTICLE_COLOR_MISMATCH %s" % str(mismatched))
    ok(mismatched.is_empty(),
        "%d emitter(s) write a particle color they cannot draw: %s" % [
            mismatched.size(), str(mismatched)])

    parent.queue_free()
    await frames(1)

    # The multimesh emitters carry real per-instance colors and must keep
    # opting in. GlowingPetals lost this once and every flower bloomed white.
    # Everything here is built through the real scenery factory, not a fixture
    # -- a hand-built material would only prove what I wrote five lines
    # earlier, and the leaf emitter is the whole point of this check.
    var world := WorldScenery.new()
    world.name = "ProbeWorld"
    root.add_child(world)
    world.dungeon = DungeonGenerator.generate(20260930)
    world.region = BeautyContent.REGIONS[0]
    world.floor_number = 1
    world._build_grove_visual()
    world._build_decor()
    world._build_ambient_life()
    await frames(1)

    var checked_petals := 0
    for child in world.get_children():
        if not child is MultiMeshInstance3D:
            continue
        var instance := child as MultiMeshInstance3D
        var material := instance.material_override as StandardMaterial3D
        if material == null:
            continue
        var multimesh := instance.multimesh
        var carries_colors: bool = multimesh != null and multimesh.use_colors
        var draws_colors: bool = material.vertex_color_use_as_albedo
        if not carries_colors:
            continue
        checked_petals += 1
        ok(draws_colors,
            "%s carries per-instance colors but its material does not read them; it renders one flat color" % str(instance.name))
    ok(checked_petals >= 2,
        "expected at least two multimesh emitters carrying per-instance colors, found %d" % checked_petals)

    # Now the same class rule against the emitters the floor itself builds.
    var floor_mismatched: Array[String] = []
    var floor_checked := 0
    for node in world.get_children():
        if not node is GPUParticles3D:
            continue
        var emitter := node as GPUParticles3D
        if _particle_color_mismatch(emitter, default_color, floor_mismatched):
            floor_checked += 1
    ok(floor_checked >= 2,
        "expected the floor's mote and leaf emitters, found %d" % floor_checked)
    if floor_mismatched.size() > 0:
        print("GRAPHICS_FLOOR_PARTICLE_COLOR_MISMATCH %s" % str(floor_mismatched))
    ok(floor_mismatched.is_empty(),
        "%d floor emitter(s) write a particle color they cannot draw: %s" % [
            floor_mismatched.size(), str(floor_mismatched)])

    world.queue_free()
    await frames(1)

## The particle-color class rule, stated once: a process material that writes a
## per-particle color needs a draw material set to read it. Appends a line to
## `mismatches` when an emitter breaks the rule; returns whether the emitter
## was checkable at all (a caller counting checked emitters uses the boolean).
func _particle_color_mismatch(emitter: GPUParticles3D, default_color: Color, mismatches: Array[String]) -> bool:
    var mesh := emitter.draw_pass_1 as Mesh
    if mesh == null:
        return false
    var material := mesh.material as StandardMaterial3D
    if material == null:
        return false
    var process := emitter.process_material as ParticleProcessMaterial
    if process == null:
        return false
    var draws_vertex_color: bool = material.vertex_color_use_as_albedo
    var writes_process_color: bool = process.color != default_color
    if writes_process_color != draws_vertex_color:
        mismatches.append("amount=%d draws_vertex=%s writes_process_color=%s" % [
            int(emitter.amount), str(draws_vertex_color), str(writes_process_color)])
    return true
