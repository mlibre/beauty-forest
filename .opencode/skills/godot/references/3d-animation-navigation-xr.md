# 3D, Animation, Navigation, and XR

## 3D scene model

Use `Node3D` for spatial hierarchy/behavior. `MeshInstance3D` renders a `Mesh`; `CollisionShape3D` participates in physics; lights, cameras, decals, particles, and navigation regions are separate composable nodes.

- Local transforms compose down the tree: `Transform3D` is a `Basis` plus origin.
- Use `global_position`, `global_basis`, and `global_transform` only when world-space intent is explicit; local transforms are cheaper/clearer for parented objects.
- `Node3D.top_level` ignores parent transform inheritance when needed; insert a plain `Node` when a transform boundary is conceptually cleaner.
- Use `RemoteTransform3D` when one node should copy selected transform components from another while retaining its own scene location.
- Keep visual scale/rotation conventions consistent. Non-uniform scale and mirrored transforms can produce incorrect normals/collision; use known-safe values.
- Use `visible` for rendering, not physics/state. `CollisionShape3D.disabled` controls collision independently.
- For a visible object, include a simple collision shape; for a trigger/detection volume, use an Area3D.

## Meshes and procedural geometry

- Prefer imported glTF 2.0 for authored 3D content. Normalize units, axes, scale, tangents, UVs, and animation ranges upstream.
- `PrimitiveMesh` resources (`BoxMesh`, `SphereMesh`, `CapsuleMesh`, `CylinderMesh`, `PlaneMesh`, `TorusMesh`) are useful for prototypes and procedural content.
- `SurfaceTool` builds indexed triangle surfaces with normals/UVs/colors and optional bones.
- `ArrayMesh`/`ImmediateMesh` are lower-level; use them for runtime geometry where a simple primitive or mesh instance is not enough.
- `MeshDataTool` can optimize/transform/generate tangents/navigation or collision from an existing mesh.
- `MultiMeshInstance3D` draws many instances efficiently. Split into spatial chunks because a MultiMesh is culled as a unit; control `visible_instance_count` and per-instance transforms/colors.
- `GridMap` is useful for mesh-based block layouts, but custom data/authority should not be inferred only from cells.
- CSG is excellent for prototypes/level blocking and can bake meshes; it is not a general runtime level system.

### LOD and visibility

- Use `MeshInstance3D` LOD bias/range and `GeometryInstance3D.visibility_range_*` for distance culling/fading.
- Use occlusion culling for large enclosed scenes; it is not a substitute for frustum culling.
- Disable expensive animation/skinning/process behavior for distant actors instead of only hiding their mesh.
- Test LOD popping, shadow-range artifacts, transparent sorting, and camera cuts.

## Cameras

- `Camera3D` has `projection` (perspective/orthogonal), FOV/keep-height or size, near/far planes, cull mask, and transform.
- Set near/far deliberately. A very small near plane hurts depth precision; a very large far plane wastes precision. Use layers/cull masks and LODs rather than an enormous far range.
- `SpringArm3D` provides a camera boom with collision-aware length and can rotate/move smoothly. It does not replace a deliberate camera controller or safe camera reset.
- For a fixed game camera, parent it to a stable world/player rig and set the offset once. Do not add aim-driven drift or camera shake.
- Use camera-local helpers such as `project_ray_origin()`/`project_ray_normal()` for picking/aiming, but convert the result to the correct world/canvas coordinate.
- For a split screen or picture-in-picture, use SubViewport/Viewport setup and explicit camera/cull masks.

## Environment and lighting

- `WorldEnvironment` holds an `Environment` resource. `Environment.background_mode` chooses background/clear/sky/custom color; `sky` can use `Sky` + `ProceduralSkyMaterial`/Panorama.
- `DirectionalLight3D` is the primary sun/moon. Set direction, energy/color, shadow enabled, shadow bias, distance, and cascades for the scene.
- `OmniLight3D` is local point light; `SpotLight3D` is cone; `AreaLight3D` is the expensive rectangle light added in 4.7.
- 2D lights are separate from 3D lights. Lights are culled/limited by range, layers, and renderer capabilities.
- Enable shadows only on objects that need them. Use `VisualInstance3D` layer masks/cull masks to separate gameplay/render groups.
- Forward+ has clustered lighting, SSAO/SSIL, volumetric fog, SDFGI, and high-quality material features. Mobile supports a different subset. Compatibility is the lowest-feature renderer.
- Keep lighting values physically/coherently scaled after changing energy units, renderer, or environment defaults. Warm/cool light balance and ambient sources affect material readability.

## Animation systems

### AnimationPlayer / AnimationMixer

`AnimationPlayer` is the scene-facing animation mixer in current Godot. It stores `AnimationLibrary` resources and can play named animations, blend, connect method/audio/track events, and expose animation state. In 4.x, verify current `AnimationMixer` callback and library APIs rather than copying old `AnimationPlayer` assumptions.

- Keep source clips in an `AnimationLibrary`; use a stable animation name API.
- `play()` queues/applies according to mixer processing; call `advance(0)` only when a deliberate immediate update is needed.
- Set loop mode, speed scale, and transition behavior in the animation resource/tree, not by rewriting the same clip from multiple systems.
- Use method/audio tracks for deliberate events; do not make every frame a method call.

### AnimationTree

`AnimationTree` is a graph that blends/chooses animations from an `AnimationPlayer`/mixer. Common nodes:

- `AnimationNodeBlendTree` for simple layered blends and additive effects.
- `AnimationNodeStateMachine` for explicit states/transitions.
- `AnimationNodeBlendSpace1D`/`2D` for continuous parameter blending.
- `AnimationNodeOneShot`, `AnimationNodeTimeScale`, `AnimationNodeTimeSeek`, `AnimationNodeSync` for reusable behavior.
- `AnimationNodeTransition` for timed crossfades.

Keep state-machine transitions small and observable: `idle`, `walk`, `run`, `jump`, `fall`, `land`, plus project-specific action states. Set transition conditions and blend times in the graph; avoid a script that starts every clip every frame.

- **A code-built `AnimationNodeBlendTree` must connect into its `output` node.** Godot auto-creates `output`, so `blend.has_node("output")` is true and `animation_tree.active = true` is true even when nothing is wired to it — the graph evaluates happily and drives **no poses at all**. Wire it: `blend_tree.connect_node("output", 0, "Locomotion")`.
- **Verify animation behaviorally, not by parameter.** Asserting `parameters/.../blend_amount > 0` passes on a graph that plays nothing. Sample the actual bone/node transform over several frames and require variation.

In 4.7, blend spaces use `sync_mode` rather than the old boolean `sync`. Set `SYNC_MODE_INDEPENDENT`, `SYNC_MODE_CYCLIC_MUTABLE`, or `SYNC_MODE_CYCLIC_CONSTANT` deliberately.

### Skeletal animation

- `Skeleton3D` contains `Bone` bones; `Skin` binds mesh vertices to bones; `MeshInstance3D` renders the skinned mesh.
- Imported animations should use matching skeleton rest pose/bone names. Fix import/retargeting upstream where possible.
- `BoneAttachment3D` attaches a node to a bone; use it for weapons, VFX, and sockets.
- `PhysicalBoneSimulator3D`/physical bones are for physics-driven ragdolls, not ordinary cosmetic skeletons. Tune joints/constraints carefully.
- Keep animation state presentation-driven: visual swing/attack clips are not input handling. Route gameplay effects through explicit state, timers, and queries, not through the animation clip name alone.

### Procedural/runtime animation

For generated models, build the visible hierarchy, create an `Animation`/`AnimationLibrary`, add property/transform tracks, and connect it to an `AnimationPlayer`/mixer. Set interpolation/loop modes and test transitions in a real runtime. Runtime animation can be useful, but the resulting graph is still responsible for stable state, rest pose, and reset/reuse.

## 3D particles

`GPUParticles3D` is usually the scalable choice for many particles; `CPUParticles3D` is a simpler/flexible fallback and may be more predictable on some targets. Use a `ParticleProcessMaterial` for emission, velocity, gravity, spread, color/scale/rotation over lifetime, turbulence, attractors, and collision settings.

- Choose `local_coords`/process space intentionally. Local particles follow the emitter; global particles remain in world space.
- Set `amount`, lifetime, draw order, mesh/material, visibility AABB, and randomness once. Avoid unbounded particle counts.
- Use sub-emitters/trails/attractors only when the effect needs them; they add GPU/CPU cost.
- For GPU particles, verify target renderer/platform and process-material feature support.
- Burst VFX should pool or reset reusable nodes/materials; frequent node/material/mesh creation is a common bottleneck.

## Navigation

### Choose a model

| Need | Use |
| --- | --- |
| Grid/predefined points | `AStarGrid2D`, `AStar2D`, `AStar3D` |
| Walkable arbitrary area | `NavigationRegion2D/3D` with NavigationPolygon/Mesh |
| Scene actor path following | `NavigationAgent2D/3D` |
| Server/custom queries | `NavigationServer2D/3D` |
| Advanced query object | `NavigationPathQueryParameters2D/3D` (+ `NavigationPathQueryResult2D/3D`) |

A `NavigationAgent` does **not** move its parent. The character script moves after reading the next path position.

### Setup and synchronization

1. Add a `NavigationRegion2D/3D`.
2. Assign/draw/bake a NavigationPolygon/Mesh from simple collision or source geometry.
3. Add collision to the actor.
4. Add `NavigationAgent2D/3D` under the actor.
5. Wait for navigation synchronization before the first query.
6. Set target and follow in physics processing.

Navigation server changes synchronize on the physics frame. A query immediately in `_ready()` can see an empty/unsynchronized map. Use `call_deferred()` plus `await get_tree().physics_frame` when setup is dynamic, then query again after map changes.

```gdscript
func _physics_process(_delta: float) -> void:
    if agent.is_navigation_finished():
        return
    var next := agent.get_next_path_position()
    velocity = global_position.direction_to(next) * speed
    move_and_slide()
```

Set `path_desired_distance`, `target_desired_distance`, and `path_max_distance` to the actor's scale and movement behavior. Do not request a new path every frame; update moving targets only when the agent is too far from the ideal path.

Navigation layers are separate from physics layers. Use `NavigationLink` for one/two-way connections and `NavigationObstacle` for avoidance, not path geometry.

### Avoidance

Enable `avoidance_enabled`, connect `velocity_computed`, set desired velocity in physics processing, and use the safe velocity to move the parent. Configure radius, neighbor distance, max neighbors, time horizons, max speed, layers/mask, priority, and height. The agent still needs a target position for avoidance. Navigation avoidance is not physics collision resolution.

### Navigation performance

- Bake from simple geometry; do not use high-detail visual meshes.
- Increase cell size/height only when quality permits.
- Use background baking when possible.
- Reduce polygon/edge counts and unreachable queries.
- Stagger agent path updates and debug with Visible Navigation/`NavigationServer*.set_debug_enabled()` in debug builds.
- If a procedural grid already represents walls, an A* grid may be simpler and more deterministic than baking a navmesh. Do not maintain two contradictory wall systems without a clear contract.

## XR

XR is a specialized target, not a normal camera mode.

- Use `XROrigin3D` as the spatial reference, an `XRCamera3D` for the head/device view, and `XRController3D`/hand trackers for tracked input.
- `OpenXR` startup/initialization and the active runtime are platform/runtime dependent. Never assume desktop XR classes are active in a normal build.
- Use the project/XR action map to bind controller profiles and interactions. Keep gameplay input semantic and separate from device/profile details.
- Set near/far, render scale, foveation, and Mobile/Forward+ quality for the headset. Mobile is commonly recommended for standalone Android XR.
- Composition layers can be attached to world geometry or the XR camera for HUDs; verify layer ordering and supported compositor features.
- Test room-scale origin, recenter/rescale, boundary, hand/controller disconnect, tracking loss, comfort, and real device thermals/battery.
- Do not apply a normal third-person camera or desktop post-processing assumption to XR without checking the XR camera/compositor path.

## Official sources

- 3D manual: <https://docs.godotengine.org/en/4.7/tutorials/3d/index.html>
- 3D transforms: <https://docs.godotengine.org/en/4.7/tutorials/3d/using_transforms.html>
- Spring arm camera: <https://docs.godotengine.org/en/4.7/tutorials/3d/spring_arm.html>
- Environment/post-processing: <https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html>
- Lights and shadows: <https://docs.godotengine.org/en/4.7/tutorials/3d/lights_and_shadows.html>
- Mesh LOD: <https://docs.godotengine.org/en/4.7/tutorials/3d/mesh_lod.html>
- MultiMesh: <https://docs.godotengine.org/en/4.7/tutorials/3d/using_multi_mesh_instance.html>
- 3D particles: <https://docs.godotengine.org/en/4.7/tutorials/3d/particles/index.html>
- Animation index: <https://docs.godotengine.org/en/4.7/tutorials/animation/index.html>
- AnimationTree: <https://docs.godotengine.org/en/4.7/tutorials/animation/animation_tree.html>
- 3D navigation: <https://docs.godotengine.org/en/4.7/tutorials/navigation/navigation_introduction_3d.html>
- Navigation optimization: <https://docs.godotengine.org/en/4.7/tutorials/navigation/navigation_optimizing_performance.html>
- XR manual: <https://docs.godotengine.org/en/4.7/tutorials/xr/index.html>
