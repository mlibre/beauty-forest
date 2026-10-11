# Physics: Bodies, Collisions, Queries, Jolt, Interpolation

> Native end-user only. No C#. Target Godot 4.7. Verify with `scripts/api_lookup.gd`.

## Body types (pick one)

| Need | Use | Notes |
|---|---|---|
| Static world, walls | `StaticBody3D/2D` | cheapest, never moves in physics |
| Doors/platforms by script/anim | `AnimatableBody3D/2D` (`sync_to_physics=true`) | move in `_physics_process` or via animation |
| Player/NPC with code control | `CharacterBody3D/2D` | `move_and_slide()` / `move_and_collide()`, floor/snap/wall settings |
| Simulated crates, ragdoll | `RigidBody3D/2D` (+ `VehicleBody3D` arcade cars, `SoftBody3D`) | forces/impulses, `freeze`, contact monitor |
| Detection, pickup, trigger | `Area3D/2D` (`monitoring/monitorable`) | `body_entered/exited`, `area_entered/exited`, overlaps |
| Hinges, springs, ropes | `Joint3D/2D` family | pin/hinge/slider/cone/groove |

```gdscript
extends CharacterBody3D
@export var speed := 6.0
func _physics_process(delta: float) -> void:
    var dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
    var cam_basis := get_viewport().get_camera_3d().global_transform.basis
    var fwd := -cam_basis.z; fwd.y = 0; fwd = fwd.normalized()
    var right := cam_basis.x; right.y = 0; right = right.normalized()
    # get_vector y is -1 for forward/up, so negate it: Up must give +fwd.
    var wish := (right * dir.x + fwd * -dir.y)
    velocity.x = wish.x * speed
    velocity.z = wish.z * speed
    if not is_on_floor(): velocity.y -= 24.0 * delta
    move_and_slide()
```

- `move_and_slide()` uses `velocity`, slides, sets `is_on_floor/wall/ceiling`, `get_slide_collision()`. `move_and_collide(motion)` returns `KinematicCollision` once, no slide.
- Character settings: `floor_snap_length`, `floor_max_angle`, `floor_block_on_wall`, `slide_on_ceiling`, `safe_margin`, `motion_mode` (grounded/floating for fly/swim).
- Animatable: move with `move_and_slide`-equivalent via physics sync; do not set `global_position` every `_process`.
- Rigid: `apply_central_impulse()`, `linear_damp/angular_damp`, `center_of_mass_mode`, `freeze_mode` STATIC/KINEMATIC. `contact_monitor + max_contacts_reported` for `body_entered` on rigid. Never directly set rigid transform in physics — use impulses or `freeze`.

Official: <https://docs.godotengine.org/en/4.7/tutorials/physics/physics_introduction.html>, <https://docs.godotengine.org/en/4.7/tutorials/physics/using_character_body_2d.html>, <https://docs.godotengine.org/en/4.7/tutorials/physics/rigid_body.html>

## Layers, masks, shapes

Layers = "what I am", Mask = "what I scan". Name them Project Settings → Layer Names 3D/2D Physics, document in code.

```gdscript
# example: 1 world, 2 player, 4 enemy, 8 pickup, 16 projectile
collision_layer = 4
collision_mask = 1
```

- Shapes: 3D Box/Sphere/Capsule/Cylinder/WorldBoundary; 2D Line/Box/Circle/Capsule/WorldBoundary + Convex/Concave polygons. Generate convex from mesh in editor; concave (trimesh) static only, never for character/rigid dynamic.
- One `CollisionShape3D/2D` per body minimum; `CollisionPolygon3D` for authored volumes. `debug/visible_collision_shapes` + F6 in editor to see.
- Areas need shapes too. `Area.monitoring` scans; `monitorable` can be seen. Overlap params: `input_ray_pickable`, `audio_bus_override` (note: 4.7 changed `AudioStreamPlayer2D/3D.area_mask` default 1→0, so set the player mask explicitly if using overrides).

Official: <https://docs.godotengine.org/en/4.7/tutorials/physics/collision_shapes_2d.html>, <https://docs.godotengine.org/en/4.7/tutorials/physics/collision_shapes_3d.html>

## Queries: raycasts and overlaps

```gdscript
func los(from: Vector3, to: Vector3) -> bool:
    var q := PhysicsRayQueryParameters3D.create(from, to, 1)  # mask world
    q.collide_with_areas = false
    var hit := get_world_3d().direct_space_state.intersect_ray(q)
    return hit.is_empty()

func scan(radius: float) -> void:
    var q := PhysicsShapeQueryParameters3D.new()
    q.shape = SphereShape3D.new()
    q.shape.radius = radius
    q.collision_mask = 4  # enemies
    q.transform = global_transform
    for hit in get_world_3d().direct_space_state.intersect_shape(q, 32):
        (hit.collider as Node3D).call("apply_effect", self)
```

- Always in physics (or `call_deferred`), with explicit `collision_mask`, `exclude` self RID, `collide_with_bodies/areas` flags.
- `intersect_ray/shape/get_rest_info/cast_motion` on `direct_space_state`. Shape queries need owned `Shape3D` resource.
- Avoid per-frame all-pairs scans; use Area signals + spatial hash (grid) + cooldowns for repeated scans.

Official: <https://docs.godotengine.org/en/4.7/tutorials/physics/ray-casting.html>, <https://docs.godotengine.org/en/4.7/tutorials/physics/using_area_2d.html>

## Ticks, interpolation, large worlds

- Project Settings → Physics → Common: `physics_ticks_per_second` (default 60), `max_physics_steps_per_frame` (default 8). Fixed `delta` in `_physics_process`.
- Jitter when display Hz ≠ tick: enable interpolation per-node (`Node.reset_physics_interpolation()`, `Node.physics_interpolation_mode` INHERIT/ON/OFF). The project key is `physics/common/physics_interpolation` (default `false`; verified present-but-unset in 4.7.2 — absence means off, not on). After teleports call `reset_physics_interpolation()`.
- Large worlds: `large_world_coordinates` + floating-origin rebase beyond ~100k units; prefer `float` double-check for shader `TIME` rollover.
- Debug: `Engine.physics_jitter_fix`, visible shapes, Debugger → Monitors (physics objects, active bodies).

Official: <https://docs.godotengine.org/en/4.7/tutorials/physics/interpolation/using_physics_interpolation.html>

## Jolt vs GodotPhysics (4.7)

Project Settings → Physics → 3D `physics_engine`: `GodotPhysics3D` (stable, soft-body + vehicle) vs `Jolt Physics` (faster stacking, now bundled; default for projects newly created since 4.6). Existing projects keep whichever engine is pinned in `physics/3d/physics_engine` — inspect it rather than assuming from the editor version.

- Jolt notes 4.7: `WorldBoundaryShape3D.plane.d` sign now matches Godot (flip old Jolt projects); `SoftBody3D` mass default 1 kg total (was per-point) + `linear_stiffness` remapped — re-tweak; `Area3D` now reports `SoftBody3D` overlaps (fix masks if noisy).
- One-way: `PhysicsServer2D.body_set_shape_as_one_way_collision(..., direction)` gained an optional 2D `direction` (verified: `direction: Vector2 = (0.0, 1.0)`). There is no matching 3D-server method (verified: no `one_way` method on `PhysicsServer3D` in 4.7.2).
- Do not switch engines mid-milestone without re-testing 2D+3D + ragdoll + joints + raycasts.

Official: <https://docs.godotengine.org/en/4.7/tutorials/physics/using_jolt_physics.html>

## Troubleshooting checklist

Stuck/fall-through → shape missing/disabled, mask mismatch, `motion_mode`, `floor_snap`, moving in `_process` not physics, scaling parent (never scale physics bodies non-uniformly). Tunneling → `continuous_cd` on Rigid, smaller `safe_margin`, higher ticks, raycast for bullets. Perf → too many active rigids/areas per frame, concave dynamic, per-frame shape queries without cooldown.

Official: <https://docs.godotengine.org/en/4.7/tutorials/physics/troubleshooting_physics_issues.html>

## Official sources

- Physics: <https://docs.godotengine.org/en/4.7/tutorials/physics/index.html>
- Interpolation: <https://docs.godotengine.org/en/4.7/tutorials/physics/interpolation/index.html>
