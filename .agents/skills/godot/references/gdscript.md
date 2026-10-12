# GDScript, Signals, Lifecycle, and Data

> Native GDScript only. No C#. Target Godot 4.7 stable. Verify uncertain APIs via `references/api-verification.md` + `scripts/api_lookup.gd`.

## Language essentials

GDScript is indentation-based, dynamically-typed with optional static typing. A file is a class extending a base (`extends Node3D`, `extends Resource`, etc.). `class_name MyType` registers a global type; otherwise use `preload("res://path.gd")`.

```gdscript
extends CharacterBody3D
class_name Player

signal health_changed(old_hp: int, new_hp: int)
@export var max_hp: int = 5
var hp: int = 5

func _ready() -> void:
    hp = max_hp
```

Key rules:

- Tabs for indent (editor default). 4-space also parses but keep repo convention.
- `5 / 2 == 2` (int division). Use `5 / 2.0` or `float(x) / y` for fractional.
- `%` is int-only; floats use `fmod()`, `fposmod()` / `posmod()` for wrapping.
- Compare floats with `is_equal_approx()`, `is_zero_approx()`, not `==`.
- `null` only for Object-derived / Variant. `int`/`float`/`Vector2` etc. have zero-values, never `null`.
- Arrays/Dictionaries/PackedArrays are passed by reference. `duplicate()` / `duplicate_deep()` for independent copies.
- Prefer `StringName (&"id")` for signal/action/group/class names used repeatedly; `String` for display text; `NodePath (^"A/B")` for serialized paths.

Official: <https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_basics.html>

## Static typing

Prefer typed API boundaries and gameplay code. `Variant` only at intentional dynamic boundaries.

```gdscript
var speed: float = 6.0
var target: Node3D
var targets: Array[Node3D] = []
var stats: Dictionary[String, int] = {"hp": 5}
func apply_effect(amount: int) -> void: ...
func get_player() -> CharacterBody3D: ...
```

- `var x := Vector2.ZERO` infers when RHS type is known. Inference from `Variant` return (e.g. `front()`) is disallowed — annotate explicitly.
- Typed arrays `Array[T]` checked on write. `Array` == `Array[Variant]`. Converting `Array[Node2D]` → `Array[Node]` requires `b.assign(a)`, not `=`.
- Typed dictionaries (4.4+): `Dictionary[String, int]`. Nested typed collections unsupported.
- Cast objects with `as` (returns `null` on failure); check with `is`:
  ```gdscript
  var body := $Enemy as CharacterBody3D
  if body is CharacterBody3D: ...
  if is_instance_valid(cached): ...
  ```
- Overriding a typed-base method inherits return type — include explicit `return` on all paths.

Official: <https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/static_typing.html>

## Exports (Inspector interface)

`@export` exposes serializable fields. Keep exported state separate from derived runtime state.

```gdscript
@export var speed: float = 6.0
@export_range(1, 10, 0.5, "or_greater") var level: int = 1
@export_file("*.json") var data_path: String
@export var player: CharacterBody3D  # editor-assigned reference
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var group: bool
```

- `@export` + `@onready` on same var is an error by default (`ONREADY_WITH_EXPORT`). Choose one.
- Use setters only for bounded side effects:
  ```gdscript
  @export var max_hp: int = 5:
      set(v): max_hp = maxi(1, v)
  ```
- Exported `Resource` sub-resources (`@export var stats: EnemyStats`) are preferred over many loose ints.
- `## Doc comment` above an export shows in Inspector tooltip + script docs.

Official: <https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_exports.html>

## Lifecycle and processing

Order for `Node`: `_enter_tree()` (every entry) → children ready → `_ready()` (once unless `request_ready()`) → `_process/_physics_process` → `_exit_tree()` on removal.

```gdscript
func _enter_tree() -> void: add_to_group(&"interactable")
func _ready() -> void:
    child_signal.connect(_on_child_event)  # wire before behavior starts
func _process(delta: float) -> void:  # variable frame delta; visuals/UI
    rotate_visual(delta)
func _physics_process(delta: float) -> void:  # fixed step; movement/collision
    velocity.x = input_dir.x * speed
    move_and_slide()
func _exit_tree() -> void:  # undo subscriptions owned here
    pass
func _notification(what: int) -> void:
    if what == NOTIFICATION_PAUSED: ...
```

- Children `_ready()` before parent. Never rely on sibling order — inject dependencies or await explicitly.
- `@onready var label: Label = %HealthLabel` defers to `_ready()`. Required nodes should fail visibly; `get_node_or_null()` only for truly optional refs.
- `_process` vs `_physics_process`: visuals/input-smoothing in `_process`; `CharacterBody` motion, `Area` queries, navigation in `_physics_process`. See <https://docs.godotengine.org/en/4.7/tutorials/scripting/idle_and_physics_processing.html>
- Overridables list: <https://docs.godotengine.org/en/4.7/tutorials/scripting/overridable_functions.html>
- Disable unused callbacks with `set_process(false)`, `set_physics_process(false)`, `set_process_input(false)` for scale.

## Signals

Prefer signals for notifications, direct calls for commands. Child reports up via signal; parent commands down via method call.

```gdscript
# emitter
signal collected(by: Node3D)
func collect(by: Node3D) -> void:
    collected.emit(by)

# listener (Godot 4 Callable style — never use 3.x connect("x", self, "y"))
pickup.collected.connect(_on_pickup_collected)
pickup.collected.connect(_on_pickup_collected_once.bind(extra_arg), CONNECT_ONE_SHOT)
if pickup.collected.is_connected(_on_pickup_collected): ...
pickup.collected.disconnect(_on_pickup_collected)
```

- Connect before behavior that may emit immediately (e.g. before `add_child()` starts timers).
- One-shot + `bind()` for single-fire with context. Remove persistent connections when owner invalid; connections to freed nodes are auto-cleaned but explicit disconnect clarifies ownership.
- `await signal` turns caller into coroutine:
  ```gdscript
  await get_tree().create_timer(0.5).timeout
  # after await, node may be freed or scene changed — always guard:
  if not is_instance_valid(pickup): return
  ```
- Never `await` without handling cancellation / freed / scene-change. For level/area transitions use generation tokens.
- `SceneTreeTimer` (`create_timer`) and `Tween` are bound to the tree, not the node — they survive node free unless bound: `tween.bind_node(self)` or check validity.

Official: <https://docs.godotengine.org/en/4.7/getting_started/step_by_step/signals.html>

## Autoloads vs composition

Autoload = root child surviving scene changes. Use only for independent-lifetime services (save, audio director, session coordinator) with narrow API. Prefer first: scene-local node + signals, injected dependency, shared `Resource`, `class_name` static helper.

Each autoload needs: init order, pause mode, scene-transition behavior, test cleanup. Access via global name; remember extra instances can still be created manually.

Official: <https://docs.godotengine.org/en/4.7/tutorials/scripting/singletons_autoload.html>

## Groups, SceneTree, scene changes

```gdscript
add_to_group(&"enemies")
get_tree().get_nodes_in_group(&"enemies")  # untyped Array — validate
get_tree().call_group(&"enemies", "tick_behavior", delta)
get_tree().change_scene_to_file("res://levels/level_01.tscn")  # end of frame
```

- Groups are untyped registries — validate uniqueness/lifetime for gameplay-critical lookups.
- `change_scene_to_file()` replaces at end of frame. Save + grab persistent refs first. For controlled transitions instantiate → init → swap child in persistent root → `queue_free()` old.
- Pause: `get_tree().paused = true` + per-node `process_mode` (`INHERIT/PAUSABLE/WHEN_PAUSED/ALWAYS/DISABLED`). UI/menus that must run while paused use `WHEN_PAUSED`/`ALWAYS`.

Official: <https://docs.godotengine.org/en/4.7/tutorials/scripting/scene_tree.html>, <https://docs.godotengine.org/en/4.7/tutorials/scripting/pausing_games.html>

## Coroutines, threads, logging, errors

- `await` = coroutine. Do not call scene-tree objects from `Thread`/`WorkerThreadPool` — they are main-thread bound. Threads only for pure data; see `references/assets-data-networking.md`.
- Logging: `print()`, `push_warning()`, `push_error()`, `printerr()`. `print_rich()` for colored CLI. `assert(cond, "invariant")` for debug-only invariants, never for user errors/security.
- `breakpoint` keyword = persistent debugger breakpoint (version-controllable).
- Warnings: Project Settings `debug/gdscript/warnings/...`. Enable in Inspector; `@warning_ignore("rule")` only with adjacent reason, never globally. See <https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/warning_system.html>
- Style: follow <https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_styleguide.html> — `snake_case` vars/funcs/files, `PascalCase` classes/nodes, `SCREAMING_SNAKE` constants, `and/or/not` over `&&/||/!`, one statement per line, max ~100 cols.

## Lambdas and callables (verified 4.7.2)

- **Locals are captured by value.** Writing to a captured local inside a lambda mutates the copy, never the outer variable. Mutate through a reference type instead:
  ```gdscript
  var count := 0
  button.pressed.connect(func() -> void: count += 1)   # BUG: count stays 0
  var hits := [0]                                        # correct
  button.pressed.connect(func() -> void: hits[0] += 1)
  ```
- **A freed `Object` capture errors before the body runs.** The engine logs `Lambda capture at index N was freed. Passed "null" instead.` while *resolving* captures — so an `is_instance_valid()` guard inside the lambda never gets a chance to run. Reproduces with an immediate `free()` between `call_deferred()` and the deferred call, and with any pending `create_timer().timeout` lambda whose target is freed before it fires. Capture an `int` and resolve it, which cannot be freed:
  ```gdscript
  var target_id := control.get_instance_id()      # int, always safe
  var grab := func() -> void:
      var target := instance_from_id(target_id) as Control
      if target == null or not is_instance_valid(target): return
      target.grab_focus()
  grab.call_deferred()
  ```
  `queue_free()` is deferred, so it usually stays valid through the same frame's deferred calls; a hard `free()` does not. Same rule for SceneTreeTimer callbacks and `tween_callback` lambdas.
- Capture `self` implicitly by touching a member; that is safe only while the node lives. For work that must outlive the node, bind a method on a long-lived owner or disconnect on teardown.

## Static vars (verified 4.7.2)

A `static var` on a script outlives every node. Never let one hold a `Callable` that captured an engine Object (directly, or via a lambda that touched a member like `audio`): the capture pins the instance in the ObjectDB, every test that frees the game leaks it, and destruction of the stale static at process exit corrupts the native heap ("corrupted size vs. prev_size in fastbins" / "double free or corruption" after `ALL CHECKS OK`). Route such callbacks through an instance member whose lifetime matches the node instead (this project: `GameUI.ui_sound`, set by the director at boot). Also seen: a `--check-only` parse is not enough to catch this; only a full battery run at process exit shows it.

## Common 3.x traps (4.7)

`Spatial`→`Node3D`, `KinematicBody`→`CharacterBody3D`, `export var`→`@export var`, `onready var`→`@onready var`, `yield`→`await`, `instance()`→`instantiate()`, `connect("s",t,"m")`→`signal.connect(callable)`. Packed-array element assignment no longer triggers whole-property setter (4.7). Overriding typed-return base method requires explicit return.

## Official sources

- Basics: <https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_basics.html>
- Static typing: <https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/static_typing.html>
- Exports: <https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_exports.html>
- Style: <https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_styleguide.html>
- Warnings: <https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/warning_system.html>
- Advanced/dynamic: <https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_advanced.html>
- Processing: <https://docs.godotengine.org/en/4.7/tutorials/scripting/idle_and_physics_processing.html>
