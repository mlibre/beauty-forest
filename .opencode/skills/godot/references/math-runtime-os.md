# Math, Curves, RNG, OS, and Runtime Integration

> Native GDScript only. Target Godot 4.7. Verify uncertain members with `references/api-verification.md` + `scripts/api_lookup.gd`. Global-scope helpers (`lerp`, `randf`, `randi`) live in `@GlobalScope` docs, not `ClassDB` — the lookup helper cannot list them.

## Vector and transform math

- `Vector2`/`Vector3`: `lerp()`, `cubic_interpolate()`, `normalized()`, `direction_to()`, `distance_to()`, `angle_to()`, `rotated()`, `slerp()` (Vector3). Compare with `is_equal_approx()`.
- `Transform3D.interpolate_with()` for whole-transform blends with uniform scale.
- `Basis` + origin compose `Transform3D`; use local transforms unless world intent is explicit.
- 2D: `Transform2D`, `get_global_transform()`, `affine_inverse()`, `get_screen_transform()` for canvas/world/screen conversion.

```gdscript
var mid: Vector3 = a.lerp(b, 0.5)
var follow: Vector2 = pos.lerp(target, 1.0 - exp(-4.0 * delta))
var blended: Transform3D = t1.interpolate_with(t2, weight)
```

Official: <https://docs.godotengine.org/en/4.7/tutorials/math/vector_math.html>, <https://docs.godotengine.org/en/4.7/tutorials/math/interpolation.html>

## Tweened interpolation (scripted animation)

- Create with `Node.create_tween()` or `SceneTree.create_tween()`; never `Tween.new()` for real work.
- `tween_property(object, "position:x", value, duration)`, `tween_method()`, `tween_callback()`, `tween_interval()`, `tween_subtween()`.
- `tween_await(signal)` (4.7 verified: `Tween.tween_await -> AwaitTweener(signal: Signal)`) pauses the sequence until the signal fires; add `set_timeout()` when emission is uncertain.
- Chain `set_trans()` / `set_ease()`; default is `TRANS_LINEAR` + `EASE_IN_OUT`. Bind with `bind_node(self)` so free/pause behaves.
- `Tween.interpolate_value(initial, delta, elapsed, duration, trans, ease)` for manual easing without a running tween.

```gdscript
var tween := create_tween().bind_node(self)
tween.tween_property(self, "scale", Vector3.ONE * 1.2, 0.15)
tween.tween_await(done_charging)
tween.tween_property(self, "scale", Vector3.ONE, 0.2)
```

Official: <https://docs.godotengine.org/en/4.7/classes/class_tween.html>

## Curves and gradients

- `Curve.sample(offset)` / `sample_baked()` for float shaping (damage falloff, difficulty ramps).
- `Curve2D.sample_baked()` / `samplef()` for path positions; `Curve3D` equivalent in 3D.
- `Gradient` / `GradientTexture1D` / `GradientTexture2D` for color ramps; bake curves when sampled per-frame in hot paths.
- Keep curve domains documented (0–1 vs world units) and clamp inputs.

Official: search `Curve`, `Curve2D`, `Curve3D`, `Gradient` in <https://docs.godotengine.org/en/4.7/classes/index.html>

## Deterministic RNG

- Quick use: global `randi()`, `randf()`, `randi_range(from, to)`, `randf_range(from, to)`, `randfn(mean, deviation)`, `seed()`, `randomize()`.
- Reproducible systems: `RandomNumberGenerator` with explicit `seed` + `state` (verified: `set_seed(seed: int)`, `seed` property). One instance per system (world-gen, loot, AI) so streams stay independent.
- `Array.pick_random()` / `shuffle()` for picks and shuffle-bags; `rand_weighted()` for weighted indices.
- `FastNoiseLite` (`get_noise_1d/2d/3d`) for terrain/cozy variation; set `seed`, `frequency`, `fractal_octaves` deliberately.
- Never use gameplay RNG for crypto/secrets; use `Crypto.generate_random_bytes()` there.

```gdscript
var rng := RandomNumberGenerator.new()
rng.seed = 12345
var roll: int = rng.randi_range(1, 100)
var jitter: float = rng.randf_range(-0.5, 0.5)
```

Official: <https://docs.godotengine.org/en/4.7/tutorials/math/random_number_generation.html>

## OS, display, and windows

- `OS.has_feature("web")` / `"android"` / `"mobile"` / `"dedicated_server"` / `"editor"` — query each tag separately; `OS.has_feature("web/android")` is invalid.
- `OS.get_locale()` / `get_locale_language()` only as an initial preference; keep explicit user choice.
- `DisplayServer.window_set_size(size, window_id)` (verified) for runtime size; base viewport + stretch (`canvas_items` + `expand` in new 4.7 projects) remain the layout source of truth.
- `Engine.get_version_info()` for runtime version guards; `ProjectSettings.get_setting_with_override()` for feature-aware settings.
- `Time.get_ticks_usec()` for local profiling; `Time.get_unix_time_from_system()` for wall-clock only where appropriate.

```gdscript
if OS.has_feature("web"):
    apply_web_quality()
var version := Engine.get_version_info()
if version.major != 4 or version.minor < 7:
    push_warning("Expects Godot 4.7+")
```

Official: <https://docs.godotengine.org/en/4.7/classes/class_os.html>, <https://docs.godotengine.org/en/4.7/classes/class_displayserver.html>, <https://docs.godotengine.org/en/4.7/tutorials/rendering/multiple_resolutions.html>

## Window close requests and graceful shutdown

A window close (or any OS quit request) does **not** reach game code through `SceneTree` propagation. Verified delivery chain (4.7.2 editor; `scene/main/window.cpp`, `scene/main/scene_tree.cpp`, `main/main.cpp`):

- The root `Window` recursively delivers `Node.NOTIFICATION_WM_CLOSE_REQUEST` (`= 1006`, verified in `ClassDB`) to every non-`Window` node, then emits its own `close_requested` signal.
- `SceneTree` connects to `close_requested` and quits automatically **only** when `SceneTree.auto_accept_quit` is `true` — which mirrors the `application/config/auto_accept_quit` project setting (registered default `true`).
- `SceneTree.quit()` itself is unaffected by the setting; only the automatic close-request path is gated.

Graceful-shutdown pattern (verified working):

- Set `config/auto_accept_quit=false` under `[application]` in `project.godot` so close requests reach game code instead of quitting mid-frame.
- Handle `func _notification(what: int)` and run teardown when `what == NOTIFICATION_WM_CLOSE_REQUEST` (equivalently, connect to `get_tree().root.close_requested`).
- Run async teardown first (hush audio, flush saves), then `get_tree().quit()` after a drain window; guard with a flag because repeated close requests re-fire the notification.
- Never call `get_tree().quit()` directly from leave/exit buttons when teardown matters — route every exit through the same graceful path.

Headless runs cannot deliver a real OS close request, so exercise the path in tests with `node.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)`.

Official: <https://docs.godotengine.org/en/4.7/classes/class_scenetree.html>, <https://docs.godotengine.org/en/4.7/classes/class_window.html>, <https://docs.godotengine.org/en/4.7/classes/class_node.html>

## Official sources

- Math index: <https://docs.godotengine.org/en/4.7/tutorials/math/index.html>
- Interpolation: <https://docs.godotengine.org/en/4.7/tutorials/math/interpolation.html>
- Curves/paths: <https://docs.godotengine.org/en/4.7/tutorials/math/beziers_and_curves.html>
- RNG: <https://docs.godotengine.org/en/4.7/tutorials/math/random_number_generation.html>
- Tween: <https://docs.godotengine.org/en/4.7/classes/class_tween.html>
- OS: <https://docs.godotengine.org/en/4.7/classes/class_os.html>
