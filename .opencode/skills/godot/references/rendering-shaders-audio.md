# Rendering, Shaders, and Audio

## Choose a renderer for the target

Godot 4 has three rendering methods:

| Renderer | Best fit | Important limits |
| --- | --- | --- |
| Forward+ | Modern desktop 3D, highest feature set | Requires RenderingDevice-capable GPU; highest base cost |
| Mobile | Mobile, standalone XR, modern desktop 3D | Most advanced features with mobile limits; not Web |
| Compatibility | Low-end desktop/mobile, Web, 2D, broad hardware | Lowest feature set; OpenGL; no RenderingDevice, compute, normal/roughness screen texture, many advanced effects |

Renderer selection is a target decision. A desktop development GPU does not prove a mobile/Web target works. Forward+ and Mobile use RenderingDevice with Vulkan/D3D12/Metal; Compatibility uses OpenGL. Godot may fall back from a RenderingDevice driver to Compatibility unless the fallback setting is disabled; that fallback changes visual features and performance.

Verify the active renderer in the editor, `ProjectSettings`, and the target export. Test each renderer the project claims to support. A feature being present in the editor does not mean it is present on every renderer/platform.

### Renderer feature reminders

Per the official 4.7 renderers comparison:

- Compatibility: no SDFGI, SSIL, volumetric fog, screen-space reflections, compute shaders, decals, trails, depth of field, TAA/FXAA/SMAA, or HDR output. Normal/roughness screen texture is unavailable. SSAO **is** supported in Compatibility (it is Mobile that lacks SSAO); screen/depth textures themselves are available in all three renderers.
- Mobile: many effects are available but hardware/performance constrained; volumetric fog, SSIL, and SDFGI are unavailable; SSAO is unavailable; PCSS is available for omni/spot but not directional.
- Forward+: full advanced set including clustered lighting, SDFGI, SSIL, SSAO, volumetric fog, screen-space reflections, TAA/FSR2, and normal/roughness screen texture; desktop only.
- MSAA 2D and alpha antialiasing have renderer-specific behavior. Test transparency/foliage in the target renderer.
- Compute shaders and RenderingDevice are unavailable in Compatibility/Web. Web is Compatibility only and single-threaded by default.

## RenderingServer and render resources

`RenderingServer` is the engine-facing rendering API. Most game code should manipulate nodes/resources rather than call low-level RIDs directly. Use RenderingServer for advanced rendering tools, custom render resources, global rendering settings, and performance diagnostics.

- `CanvasItem`/`Node2D` draw in Canvas space; `Node3D`/`MeshInstance3D` draw in 3D world space.
- `CanvasLayer` separates UI/background layers from camera movement.
- Materials/shaders are Resources. Reuse them to reduce state changes; `material_override` applies only to one node, while mesh material applies to every use of that mesh.
- Material overlays render over the base material. They are useful for shields/VFX but can create extra transparent draw work.
- Keep alpha/transparency and depth modes intentional. Alpha-blended 3D materials cannot cast shadows, are expensive/sorting-limited, and are not in screen-space reflections; alpha scissor/alpha hash are better for foliage/fences when hard edges are acceptable.

## StandardMaterial3D / ORMMaterial3D

`StandardMaterial3D` and `ORMMaterial3D` cover most 3D content without custom shader code. Key areas:

- Albedo/base color and textures
- Metallic, roughness, normal, ORM, emission, AO
- UV1/UV2 selection and per-channel texture-channel/offset/scale/triplanar settings (`BaseMaterial3D` exposes UV1/UV2 offset/scale/triplanar members; there is no UV3 layer) plus texture filtering/repeat
- Transparency: Disabled, Alpha, Alpha Scissor, Alpha Hash, Depth Pre-Pass
- Cull mode, depth draw/test, no-depth-test, render priority
- Shading mode: Per-Pixel, Per-Vertex, Unshaded
- Diffuse/specular modes, toon options, vertex color, ambient/fog flags
- Distance/proximity fade and billboard/particles settings

`ORMMaterial3D` packs occlusion/roughness/metallic into texture channels. Ensure channel packing is correct at import/export.

### Transparency choices

- Opaque: fastest, all features, correct depth.
- Alpha: partial transparency, particles/VFX, no shadows/screen-space reflections, sorting problems when overlapping.
- Alpha Scissor: hard cutout, faster, can cast shadows, good for foliage/fences. Tune `alpha_scissor_threshold` and alpha antialias edge; MSAA improves alpha-to-coverage.
- Alpha Hash: dithered hard transparency, can cast shadows, useful for hair/foliage where scissor is not enough.
- Depth Pre-Pass: renders opaque portions first, improves many transparency cases but does not fully solve all sorting.

Avoid non-Mix blend modes unless the effect needs Add/Subtract/Multiply/Premultiplied Alpha; any non-Mix blend normally enters the transparent pipeline.

## Environment and global illumination

`WorldEnvironment` + `Environment` controls background/sky, ambient light, tonemap, fog, glow, SSAO/SSIL, SDFGI, volumetric fog, adjustments, and compositor resources. A `ReflectionProbe` captures local reflections. LightmapGI, VoxelGI, SDFGI, and SSIL have different renderer and bake requirements.

- Use `ProceduralSkyMaterial` or a panorama sky intentionally; check sky contribution to 2D/3D materials.
- Glow is a post effect; keep bloom thresholds/strength tuned after renderer/lighting changes. It can make a warm scene inviting without changing gameplay state.
- SSAO/SSIL/fog are visual effects, not collision/occlusion gameplay truth. Do not use visual darkening as a stealth/damage mechanic without a deterministic gameplay query.
- LightmapGI bakes static illumination; moving objects/dynamic lights still need real lights. Voxel/SDFGI are Forward+ features with bake/performance costs.
- Use reflection probes and roughness-aware material settings. Do not assume a reflection probe is visible in every material/transparency mode.
- Keep shadow casters and shadow atlas sizes deliberate; every additional shadow-casting light has cost.

## 2D rendering

- CanvasItem materials/shaders can tint, add outlines, and deform. Screen/depth texture reads are spatial-shader features: a `canvas_item` shader cannot directly sample the 3D depth buffer. Use a spatial shader with `hint_screen_texture`/`hint_depth_texture`, or route the 3D view through a `SubViewport` texture, when a 2D element needs 3D depth.
- `CanvasItem` draw order, z-index, Y-sorting, CanvasLayer, and parent transform determine 2D composition.
- Use `BackBufferCopy` when multiple 2D screen-reading effects need different source regions. Screen texture auto-copy occurs only at the first relevant draw in a frame; overlapping readers may otherwise see the wrong buffer.
- `hint_screen_texture` is a copy/back-buffer operation and is not free. Use it for full-screen/regional effects, not every small sprite.
- Screen texture in 3D is captured after opaque geometry and before transparency; it may include geometry in front and excludes transparent objects. Use a SubViewport with a camera when precise capture is required.
- Screen/depth hints are read-only copies. Depth is nonlinear and must be reconstructed through inverse projection when world position is needed.
- In Compatibility, debug draw modes and several post effects are unsupported; test visual diagnostics separately.

## 3D rendering and materials

- Imported meshes need correct normals/tangents/UVs/material names. Fix source/import issues before writing a shader around bad data.
- Keep triangle/shader/material complexity appropriate for target. A visually simple scene can be GPU-bound through overdraw, transparency, lights, shadows, or post-processing.
- Reuse materials and meshes. Use `MultiMeshInstance3D` for large repeated opaque objects; use LOD/visibility ranges and spatial chunks.
- When a `MultiMesh` carries per-instance colors, keep the color array parallel to the transform array and enable `use_colors` only when the counts match. A mismatch silently drops *all* instance colors — instances render the material default instead of erroring.
- Use `MeshInstance3D.gi_mode`/lightmap/scale settings deliberately for baked GI. Do not use visual-only material emission as a substitute for gameplay illumination.
- `CanvasItem`/UI draw order does not control 3D transparency sorting. Keep transparent surfaces separated and test camera angles.
- `RenderingServer` frame callbacks and render resources are advanced APIs. Verify thread safety and renderer support before using them in a game.

## Shaders

### Shader types

The first line selects a shader type:

- `spatial` for 3D materials
- `canvas_item` for 2D/UI
- `particles` for GPU particle process visuals
- `sky` for sky radiance
- `fog` for volumetric fog
- `texture_blit` for `DrawableTexture2D` GPU blitting

Render modes are on the second line, for example:

```glsl
shader_type spatial;
render_mode unshaded, cull_disabled;
```

Render modes and built-ins differ by type; read the exact shader reference. Do not copy a spatial uniform/render mode into canvas_item.

### Spatial shader skeleton

```glsl
shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
    ALBEDO = texture(albedo_texture, UV).rgb * tint.rgb;
    ROUGHNESS = roughness;
    METALLIC = 0.0;
}
```

`light()` is the optional spatial-shader per-light processor (alongside `vertex()`/`fragment()`). Godot calls it once per light per pixel; omit it and the renderer lights `fragment()` outputs (`ALBEDO`, `ROUGHNESS`, etc.) automatically. It is skipped with `unshaded` or `vertex_lighting`. When custom per-light response is needed, write `DIFFUSE_LIGHT`/`SPECULAR_LIGHT` (usually `+=`) using `LIGHT`, `LIGHT_COLOR`, `ATTENUATION`, `NORMAL`, and related light built-ins — verify the exact spatial-shader reference entry before copying a `light()` block.

Common built-ins include `ALBEDO`, `NORMAL`, `ROUGHNESS`, `METALLIC`, `EMISSION`, `SPECULAR`, `RIM`, `AO`, `AO_LIGHT_AFFECT`, and `BACKLIGHT`. Assign only what the effect needs so the shader compiler can remove unused work.

### CanvasItem shader skeleton

```glsl
shader_type canvas_item;

uniform sampler2D texture_source : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float softness : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 texel = texture(texture_source, UV);
    COLOR = texel * tint;
    COLOR.a *= 1.0 - softness;
}
```

CanvasItem built-ins include `COLOR`, `TEXTURE`, `UV`; `COLOR` is the final fragment output. `hint_screen_texture` can read a copied screen texture. Screen-reading and depth reconstruction are advanced and renderer-sensitive.

### Particles, sky, and fog

- Particle shaders use `start()` once per particle and `process()` repeatedly; use built-in particle varyings/uniforms and avoid hidden per-frame allocations.
- Sky shaders run when radiance cubemaps/current sky screen update. Keep them simple and verify the sky material mode.
- Fog shaders run over volumetric fog froxels; supported in the exact fog/renderer path and not a generic 2D blur.
- `DrawableTexture2D` and `texture_blit` are specialized GPU blitting. Godot 4.7 marks `blit_rect`/`blit_rect_multi` experimental; do not depend on them for a baseline path without tests.

### Shader performance and correctness

- Shaders run many times in parallel; no normal sequential state. Keep fragment work bounded and avoid expensive loops/noise at mobile resolutions.
- Prefer a StandardMaterial/material effect before a custom spatial shader.
- Alpha, screen reads, depth reconstruction, compute, and advanced hints have renderer/platform restrictions.
- Use `hint_range`, `source_color`, `filter_*`, and `repeat_*` hints so Inspector/UI presents the correct values and sampling behavior.
- Compile/import and inspect shader errors. A valid scene can still contain a shader that fails on a target renderer.
- Avoid enabling new material features during gameplay if Forward+/Mobile pipeline precompilation can stutter; warm/load important variants.
- For 4.7 ubershaders/pipeline precompilation, instantiate important material/feature combinations during loading. Shader baking is for supported Forward+/Mobile paths, not Compatibility/Web/headless export.

## Viewports, resolution, and display

A Viewport is a render surface. `SubViewport` can render 3D-in-2D, 2D-in-3D, dynamic textures, multiple cameras, split screen, or procedural output. Cameras render to the closest parent Viewport; only one active camera per Viewport.

- Set `SubViewport.size`, `render_target_update_mode`, transparent background, MSAA, positional shadow atlas, and `disable_3d` deliberately.
- Use `SubViewportContainer` for UI/container integration. It must be at least the SubViewport size when stretching.
- `SubViewport` can share/inherit or own a `World3D`; owning a world separates rendering/physics from the parent world.
- To capture the root viewport, await `RenderingServer.frame_post_draw` before `get_viewport().get_texture().get_image()`; `_ready()` can return an empty texture.
- A SubViewport's texture is cleared every frame by default. Set clear mode/update mode carefully for persistence/one-shot capture.
- For 3D inside 2D, render a SubViewport texture through a TextureRect/Sprite; do not expect the editor viewport to display the SubViewport directly.
- Enable the SubViewport listener for 2D/3D audio if it contains a separate world and you expect audio.

### Multiple resolutions

- Base viewport size is a design size, not a monitor-resolution change request.
- `canvas_items` scales 2D/UI while 3D remains tied to the target render surface; `viewport` scales the whole rendered viewport; `disabled` is 1:1 scene unit/pixel.
- Aspect options: Ignore, Keep, Keep Width, Keep Height, Expand. Expand shows more content without nonuniform distortion. Use containers/anchors to handle the extra area.
- `content_scale_factor` and stretch scale mode are user-adjustable. Integer scale mode prevents uneven pixel-art scaling at the cost of bars/less used area.
- Use resolution scaling to render 3D below the 2D/UI resolution for GPU-bound games; test UI sharpness and input coordinates.
- Use anchors/containers and safe-area-aware layouts rather than fixed 1280×720 coordinates.
- Godot 4.7 new projects default to `canvas_items` + `expand`; existing projects may still have older values.

## Post-processing and compositor

CanvasLayer/ColorRect/Viewport-based fullscreen shader effects are broadly portable. The `Compositor` resource is configured on a `WorldEnvironment` (applies to all Viewports) or on a `Camera3D` (applies only to the Viewport using that camera) — the resource itself is not owned by the renderer — and compositor execution is supported in Forward+/Mobile only. `CompositorEffect` callbacks execute on the rendering thread; protect shared data with a Mutex, create/free RenderingDevice resources correctly, and do not touch the scene tree from the render callback.

- Screen-reading 2D effects can require BackBufferCopy ordering.
- 3D screen/depth effects can include unexpected foreground objects and exclude transparency.
- HDR output is supported on Windows/macOS/iOS/visionOS/Linux Wayland with supported Forward+/Mobile drivers, not Android/Linux X11/Web/Compatibility. Remove SDR-only Filmic/ACES, soft-light glow, and color correction before enabling. Use `Window.get_output_max_linear_value()` and `output_max_linear_value_changed`; do not assume HDR values are stable across displays or settings.
- Treat bloom, SSAO, fog, TAA, and resolution scaling as quality settings with a low-cost fallback. Do not solve gameplay readability by shaking the camera.

## Audio

### Players and streams

- `AudioStreamPlayer`: non-positional UI/music/global sound.
- `AudioStreamPlayer2D`: positional in 2D world; panning relative to screen/listener.
- `AudioStreamPlayer3D`: positional in 3D; panning, attenuation, reverb, Doppler.
- `AudioStreamRandomizer`: chooses from streams and applies random pitch/volume variation.
- WAV is low decode CPU but large; Ogg is compressed/long-content friendly but more decode CPU; MP3 is compressed with lower decode cost than Ogg. Choose based on memory/CPU/platform and test.
- Set bus, volume_db, pitch_scale, stream, playback type, and max polyphony deliberately. A one-shot manager can pool players for overlapping effects; a single player interrupts itself.

### Buses and effects

Audio flows through named buses to Master. Bus layout is a Resource and effects execute in order. Bus names are used by players; renaming a referenced bus loses the reference. Use buses for meaningful categories: Master, Music, SFX, Voice, UI, Ambience.

Useful effects: Amplify, Compressor, HardLimiter, EQ, high/low/band/notch filters, Delay, Reverb, Chorus, Distortion, PitchShift, StereoEnhance, Panner, Phaser, and SpectrumAnalyzer. Put a limiter near the end of Master to prevent clipping; do not use volume as a substitute for mix headroom. On Web, area reverb buses and Doppler work only when the player's playback mode is **Stream** rather than the default **Sample** (Stream costs extra latency without threads); verify the export audio mode.

`Area2D`/`Area3D` can override bus/reverb for contained players. 4.7 changed `AudioStreamPlayer2D/3D.area_mask` default from layer 1 to 0; set it explicitly if using area overrides. Web area-reverb/Doppler have the Sample/Stream limitation above.

### Listener and 3D audio

The active Camera/Viewport listener determines 2D/3D sound. Keep a listener in every SubViewport that should hear its world. For 3D, set attenuation, max distance, unit size, bus, area mask/reverb, and Doppler tracking. Enable Doppler tracking with the correct process mode (idle vs physics) for the node's movement.

### Timing/synchronization

Audio begins on a mix chunk, not exactly at `play()`. For rhythm/gameplay sync:

- Estimate initial delay with `AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()`.
- For long playback, use `get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()`, rejecting values that move backward.
- Audio buffer size trades latency against CPU and dropouts. Do not lower it casually.
- Use `AudioServer`/stream playback data for visualizers; spectrum effects need `AudioEffectSpectrumAnalyzerInstance`.
- Web audio uses the browser Web Audio API with a Sample (default) vs Stream playback-type choice, cross-origin/thread limits, and a user-gesture requirement before playback.

### Teardown and exit hygiene

The audio server releases stopped playbacks asynchronously. Freeing players or quitting while voices are live leaks `AudioStreamWAV`/`AudioStreamPlaybackWAV` entries, reported at exit as `N ObjectDB instances were leaked at exit` (observed with the 4.7.2 editor, including headless runs with dummy audio).

- On teardown, `stop()` every player and detach with `player.stream = null`; child players receive `tree_exiting` before their parent's `_exit_tree`, which is a reliable hook for this.
- Drop cached/generated streams so no reference keeps playbacks alive.
- Block new `play()` calls once shutdown starts, then wait a short drain window before `quit()` (verified sufficient: ~0.5 s, or ~30 process frames headless).
- Verify by running headless and grepping stderr for `leaked at exit`; a parse-clean project can still fail this runtime check.

## Official sources

- Renderers: <https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html>
- Viewports: <https://docs.godotengine.org/en/4.7/tutorials/rendering/viewports.html>
- Multiple resolutions: <https://docs.godotengine.org/en/4.7/tutorials/rendering/multiple_resolutions.html>
- Compositor: <https://docs.godotengine.org/en/4.7/tutorials/rendering/compositor.html>
- HDR output: <https://docs.godotengine.org/en/4.7/tutorials/rendering/hdr_output.html>
- Standard materials: <https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html>
- Shaders: <https://docs.godotengine.org/en/4.7/tutorials/shaders/index.html>
- Shader introduction: <https://docs.godotengine.org/en/4.7/tutorials/shaders/introduction_to_shaders.html>
- Screen-reading shaders: <https://docs.godotengine.org/en/4.7/tutorials/shaders/screen-reading_shaders.html>
- Audio streams: <https://docs.godotengine.org/en/4.7/tutorials/audio/audio_streams.html>
- Audio buses: <https://docs.godotengine.org/en/4.7/tutorials/audio/audio_buses.html>
- Audio effects: <https://docs.godotengine.org/en/4.7/tutorials/audio/audio_effects.html>
- Audio synchronization: <https://docs.godotengine.org/en/4.7/tutorials/audio/sync_with_audio.html>
