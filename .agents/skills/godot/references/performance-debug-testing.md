# Performance, Debugging, and Testing

## Optimize from evidence

Use this loop:

1. Reproduce the issue on a representative target/device.
2. Profile the same scene/action with the same settings.
3. Identify the largest CPU/GPU/memory/physics/navigation cost.
4. Change one root cause.
5. Reprofile and verify gameplay/visual behavior.

Do not “optimize” by adding camera shake, hiding errors, deleting tests, or making an unrelated quality cut. A frame-time improvement that breaks readability, input, physics, or a product constraint is not a fix.

## Profiler and monitors

Open **Debugger → Profiler → Start**, reproduce, and inspect:

- Frame Time
- Physics Time/Frame
- Idle/Process Time
- Navigation Time
- Self vs inclusive time
- Object/Node/Rendering stats
- Memory/VRAM
- Draw calls/objects
- Physics active objects, pairs, islands
- Navigation regions/agents/polygons/edges/obstacles
- Shader/pipeline compilation counts

`Performance.get_monitor()` is useful for lightweight telemetry. Examples:

```gdscript
print(Performance.get_monitor(Performance.TIME_FPS))
print(Performance.get_monitor(Performance.TIME_PROCESS))
print(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
print(Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS))
print(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
print(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
```

Some monitors are debug-only or delayed. Use `Performance.add_custom_monitor()` for a domain-specific count/cost, with a callback returning nonnegative int/float. The Visual Profiler focuses on rendering CPU/GPU work and does not replace the standard whole-frame profiler.

For a targeted hot path, measure `Time.get_ticks_usec()` around the suspect function, but avoid leaving noisy timing in production.

## CPU optimization

- Every Node and per-frame callback has cost. Remove inactive nodes or disable processing when practical.
- Prefer fewer, better-owned nodes for large repeated systems when profiling shows SceneTree overhead.
- Use signals, timers, and event-driven updates rather than polling all objects each frame.
- Avoid allocation-heavy loops, temporary arrays/dictionaries, string concatenation, and dynamic property/ClassDB access in hot paths.
- Cache local references, use typed data, and choose packed arrays for large homogeneous primitive/vector storage.
- Use `Array`/Dictionary/algorithm choices based on operation count, not aesthetics.
- Reuse expensive resources/materials/meshes. Pool short-lived VFX/audio/projectiles only with complete reset and signal contracts.
- Do not use `Object`/Node per datum for large static data when packed/resource/data containers suffice.

Measure before replacing a readable O(n) loop with a complex spatial structure. For large all-pairs systems, profile first; then use spatial hashing, A*, groups with deferred fan-out, or bounded queries with a correctness contract.

## GPU/rendering optimization

- Reduce draw calls/material changes by reusing materials and batching compatible geometry.
- Use texture atlases, mipmaps, and VRAM compression appropriately for 3D.
- Keep fragment shaders simple on mobile; avoid expensive loops/noise/screen reads.
- Reduce overlapping transparent geometry; use alpha scissor/alpha hash for foliage where appropriate.
- Use MultiMesh, LOD, visibility ranges, and spatial chunking for repeated/large 3D content.
- Use occlusion culling for large scenes, not for every small scene.
- Reduce shadow casters, light ranges, shadow map resolution, decals, and post effects based on target measurements.
- Test small-window/full-window scaling to identify fill-rate limits; 3D resolution scaling can preserve 2D/UI sharpness.
- Warm important shader/material feature combinations before gameplay to avoid pipeline compilation stutter. Forward+/Mobile use ubershaders/precompilation; Compatibility/Web/headless have different support.
- Do not enable advanced renderer features for a single decorative object without checking its per-pixel/per-light cost.

## Physics performance

- Simplify collision shapes and avoid detailed trimesh collision for dynamic actors.
- Remove off-screen/inactive bodies; watch active objects, pairs, and islands.
- Reuse simple physics bodies only when signals, contacts, sleep, transforms, and ownership are reset.
- Keep `max_contacts_reported` low.
- Use fixed physics ticks consistently and interpolation if visual smoothness requires it.
- Do not raise max physics steps to mask a physics spiral of death; fix the work that exceeds the budget.
- Jolt can improve stacking/cylinders, but Jolt and Godot Physics have different margins/joints/queries. Benchmark and regression-test the selected backend.

## Navigation performance

- Bake from simple geometry; avoid high-detail visual meshes.
- Increase cell size/height only with quality testing; use background baking for large maps.
- Reduce polygon/edge counts and unreachable queries.
- Stagger path updates; do not reset every agent in one frame.
- Use `NavigationServer2D/3D` debug/visible navigation to validate map topology.
- If a project has a deterministic grid, A* can be simpler/faster than an unnecessary navmesh. Keep collision, visual exclusion, and gameplay grid semantics synchronized.

## Threading

Use threads for CPU-heavy work that is independent of the scene tree. The SceneTree, Nodes, physics state, and most rendering resources are main-thread-bound.

```gdscript
var worker := Thread.new()

func _ready() -> void:
    worker.start(_run.bind(payload))

func _exit_tree() -> void:
    worker.wait_to_finish()
```

Use `Mutex`, `Semaphore`, and `WorkerThreadPool` correctly. Protect shared state, avoid resizing the same Array/Dictionary concurrently, and have a deterministic shutdown/join path. Build detached resources/nodes off-thread and add them on the main thread. Never assume `WorkerThreadPool.add_group_task()` is cheap for tiny tasks or safe to abandon.

## Debugging tools

- Output panel: `print`, `print_rich`, `printerr`, warnings, errors.
- Debugger: breakpoints, stack frames, locals/members, step/continue, evaluator/REPL.
- Remote scene tree and live property inspection.
- Collision Debug: `--debug-collisions` or editor collision shapes.
- Navigation Debug: `--debug-navigation`/Visible Navigation.
- Path Debug: `--debug-paths`.
- Avoidance Debug: `--debug-avoidance`.
- Canvas item redraw: `--debug-canvas-item-redraw`.
- StringName allocation debug: `--debug-stringnames`.
- GPU profile/validation/abort: `--gpu-profile`, `--gpu-validation`, `--gpu-abort` where supported.
- Movie capture: `--write-movie` with a fixed FPS/quit count; this is a capture tool, not a correctness test.
- Frame limit/diagnostic: `--max-fps`, `--frame-delay`, `--fixed-fps`, `--print-fps` (avoid confusing simulation delay with an FPS limiter).
- When an `extends`/`class_name` chain fails, read the **first** `SCRIPT ERROR`, not the last. Every dependent reports `Could not resolve class` / `Failed to compile depended scripts`; only the first error names the actually broken file.

Use the installed editor's `--help` for available flags. Unknown flags may silently do nothing.

## Logging

Choose severity deliberately:

```gdscript
print("state update")
push_warning("recoverable inconsistency")
push_error("operation failed")
printerr("diagnostic detail")
```

- `push_error`/`push_warning` do not automatically stop execution.
- File logging commonly goes to `user://logs/godot.log`; configure rotation/count and avoid logging secrets or every frame.
- Custom `Logger` callbacks can feed an in-game console/telemetry, but logger callbacks may run on worker threads. Synchronize shared state.
- Release call-stack tracking can be enabled through Debug settings with a performance cost. Test release diagnostics separately.
- `assert()` is debug-only and is not error handling.

## Test layers

Godot's built-in `--test` flag does not exist in the standard editor (`godot --help` has no `--test`); engine unit tests require a custom build. For a project, use explicit GDScript test runners and/or a third-party test addon compatible with the installed editor.

### Pure logic tests

Keep rules, calculations, state transitions, and serialization mapping in `RefCounted`/`Resource` classes with no scene dependency. Write a `SceneTree` runner that checks conditions and exits nonzero on failure.

```gdscript
extends SceneTree

var failures := 0

func _init() -> void:
    var rules = preload("res://game/rules.gd").new()
    check(rules.accepts(3), "three should be accepted")
    check(not rules.accepts(-1), "negative should be rejected")
    quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    printerr("FAIL: ", message)
```

Use deterministic inputs, fixed seeds, and no wall-clock assumptions.

### Scene/integration tests

1. Create a minimal test scene.
2. Instantiate the subject.
3. Add it to the tree.
4. Await required signals/physics frames/process frames.
5. Check state and signals.
6. Free/reset and quit with an explicit code.

Test scene changes, pause, input actions, UI focus, physics layers, navigation sync, audio setup where possible, and resource paths. Do not use `assert()` as the only CI failure mechanism because release exports omit it.

### Headless runner gotchas (verified 4.7.2)

- A `Control` parented to a `CanvasLayer` is re-fitted to the **viewport rect** every layout pass, so assigning `control.size` to fake a window resize is silently overwritten. Drive a resize by setting the root window size, then **poll until the control's parent rect actually matches** before measuring, and skip/report the size honestly if the headless viewport never adopts it. `root.size` and `root.content_scale_size` do not reliably track each other headless; `get_visible_rect()` may differ from `root.size`.
- `await process_frame` does not advance physics. Use `await physics_frame` for movement, Area3D overlap, and `move_and_slide()` assertions.
- Calling a coroutine (a function that `await`s) requires `await` at the call site, and its return type is not usable in an expression — make it return `Array`/values and `await` it into a typed local.
- `quit(0)`-by-design runners print no success marker; assert the **exit code** instead, and remember `push_error` output does not by itself set a nonzero exit.
- A hard `free()` of a node with a pending deferred call or timer lambda triggers engine "Lambda capture ... was freed" errors; `queue_free()` does not. See `references/gdscript.md` for the capture rule.
- When a `--quit-after` run warns about leaked `ObjectDB` instances but the graceful shutdown path does not, the leak is an artifact of the forced kill — verify against the real exit path before "fixing" it.
- Verify API signatures with `references/api-verification.md` before relying on names: `AnimationNode.has_connections()` takes a **signal name** (not graph edges), `get_incoming_connections()` takes no arguments, and `HFlowContainer`/`FlowContainer` alignment constants differ from `BoxContainer`'s.

### Project smoke tests

A `SceneTree` script can exercise the main scene and print a stable success marker, but it may touch real `user://` saves/settings. Isolate user data with a test profile or backup/restore. Do not run tests that mutate the player's actual profile without explicit consent.

## CI checks

```bash
# Import/resources/filesystem
godot --headless --path <project> --import

# Parse a standalone script and its preloaded dependencies
godot --headless --path <project> \
    --check-only --script res://tools/validate.gd

# Run a headless smoke/integration test
godot --headless --path <project> \
    --script res://tests/runtime_smoke.gd

# Export a real preset after the above
godot --headless --path <project> \
    --export-release "Linux/X11" builds/game.x86_64
```

`--check-only --script` is not a whole-project linter. A temporary parser probe can statically preload every GDScript, but scene instantiation, exported wiring, signal behavior, shader compilation, and platform paths still need runtime/export checks.

For CI, capture stdout/stderr and exit code, fail on engine errors/warnings according to project policy, and isolate generated user data. Do not use shell pipelines that hide the Godot process status.

## Release verification

Before claiming a release is working, verify:

- Editor/import/runtime/export use the intended 4.7 patch.
- No script errors, missing resources, invalid paths, or shader errors.
- Main scene and every important scene start cleanly.
- Input actions, keyboard/controller/touch, focus, pause, quit, and window modes.
- Save/settings failure and recovery paths.
- Renderer/platform visuals, audio, haptics, permissions, lifecycle, and performance.
- Release export launches on a clean target device.
- No secrets, credentials, test-only data, or debug logging are shipped unintentionally.

## Official sources

- Performance: <https://docs.godotengine.org/en/4.7/tutorials/performance/index.html>
- CPU optimization: <https://docs.godotengine.org/en/4.7/tutorials/performance/cpu_optimization.html>
- GPU optimization: <https://docs.godotengine.org/en/4.7/tutorials/performance/gpu_optimization.html>
- 3D performance: <https://docs.godotengine.org/en/4.7/tutorials/performance/optimizing_3d_performance.html>
- Physics performance: <https://docs.godotengine.org/en/4.7/tutorials/physics/using_physics_for_2d_games.html>
- Debugging: <https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/index.html>
- Profiler: <https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/the_profiler.html>
- Logging: <https://docs.godotengine.org/en/4.7/tutorials/scripting/logging.html>
- Threads: <https://docs.godotengine.org/en/4.7/tutorials/performance/using_multiple_threads.html>
- Thread-safe APIs: <https://docs.godotengine.org/en/4.7/tutorials/performance/thread_safe_apis.html>
- CLI: <https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html>
- Unit testing (engine context): <https://docs.godotengine.org/en/4.7/engine_details/architecture/unit_testing.html>
