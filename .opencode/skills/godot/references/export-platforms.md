# Export, Platforms, Packaging, and Security

## Export model

Godot export has three parts:

1. **Project resources**: scenes/scripts/assets selected by an export preset.
2. **Platform wrapper/template**: executable, Java/Xcode project, Web files, or other platform package.
3. **Export preset**: platform settings, included resources, icons, signing, feature tags, and output options in `export_presets.cfg`.

Use the native editor to create/manage presets. The editor needs matching export templates. Exporting is not a substitute for running the project.

### Common workflow

1. Confirm `godot --version` and project `config/features`.
2. Create an export preset for the target platform.
3. Install the matching export templates through **Editor → Manage Export Templates**.
4. Configure the platform SDK/signing/permissions.
5. Import the project and run headless/debug checks.
6. Export debug first when diagnosing platform behavior.
7. Export release and run the actual artifact on target hardware.
8. Verify save paths, input, rendering, audio, permissions, packaging, and deep links.

`export_presets.cfg` is normally version-controllable. Godot 4.1+ stores export credentials in `.godot/export_credentials.cfg`; never commit that file. Inspect presets for environment-specific paths, keystores, passwords, tokens, and private keys.

### CLI

```bash
godot --headless --path <project> --import

godot --headless --path <project> \
    --export-debug "Preset Name" builds/game-debug

godot --headless --path <project> \
    --export-release "Preset Name" builds/game

godot --headless --path <project> \
    --export-pack "Preset Name" builds/game.pck

godot --headless --path <project> \
    --export-patch "Preset Name" builds/patch.pck
```

- Use the editor binary, not an export template, to import/export.
- Relative output paths are relative to the directory containing `project.godot`, not the shell's current directory.
- Destination directories must exist.
- Unknown flags can silently do nothing; check `godot --help`.
- Export templates must match the editor's 4.7 patch. A mismatched template can fail or behave unpredictably.
- `--export-debug` implies import; release does not necessarily imply a fresh import, so run import explicitly in CI.

## Feature tags and overrides

Feature tags let one project adapt settings/code/resources by platform/configuration. Query at runtime:

```gdscript
if OS.has_feature("mobile"):
    apply_mobile_quality()
if OS.has_feature("dedicated_server"):
    start_headless_server()
```

Common tags include `android`, `ios`, `linux`, `macos`, `windows`, `web`, `mobile`, `pc`, `debug`, `release`, `editor`, `template`, `threads`, `nothreads`, and `dedicated_server`. Tags are case-sensitive. Custom export tags exist only in exported builds, not the editor.

`ProjectSettings.get_setting_with_override("full/key")` applies the active feature override. `get_setting()` alone may return the base value. Keep platform branches intentional and test both the branch and the fallback.

For a Web export running on a phone, use `web_android`/`web_ios` rather than assuming generic `mobile` identifies the host.

## Desktop exports

### Windows

Architectures: x86_64, x86_32, arm64. Configure `SignTool.exe` on Windows or `osslsigncode` elsewhere for code signing. Set identity/version/icon metadata in the preset. Test clean machines, missing Visual C++ dependencies, high-DPI, multiple monitors, fullscreen, controllers, and save locations.

### Linux

Architectures include x86_64, x86_32, arm64, arm32, rv64, ppc64, and loongarch64. Official templates are not provided for every niche architecture; custom templates may be required. Test the target libc, GPU driver, desktop environment, Wayland/X11, audio, and file permissions.

### macOS

Official templates produce a Universal 2 `.app` for Intel/Apple Silicon. Requires a unique reverse-DNS bundle identifier. Signing/notarization is required for comfortable distribution. Xcode tools/`notarytool`/`rcodesign` may be required depending on host. App Sandbox restricts filesystem/process/network/device access; configure entitlements and helper executables deliberately. Do not ship a Debugging entitlement in a notarized production build. Godot 4.7 minimum macOS is 11.

## Android

Android export can use a prebuilt APK workflow or Gradle build workflow. Gradle and current Play publishing require a configured Android environment.

Recommended 4.7 host tools:

- OpenJDK 17
- Android SDK Platform 35
- Build-Tools 35.0.1
- Platform-Tools 35+
- Command-line tools
- NDK r28b
- CMake 3.10.2.4988404 (as documented)

Configure Java/SDK paths in Editor Settings. New apps generally publish an AAB; use a non-debug keystore and keep credentials outside source control. Networking needs the INTERNET permission. Other permissions, orientation, immersive mode, screen orientation, icon/splash, and privacy declarations are product/platform decisions.

Godot 4.7 supports Android picture-in-picture, configurable splash screens, Perfetto tracing, Android XR, and `JavaClassWrapper`/`AndroidRuntime` access. `JavaClassWrapper` is Android-only; call `get_exception()` after JNI/Java operations because failures may not become GDScript errors.

Test on physical devices: touch/IME, back button, lifecycle/backgrounding, permissions, low-memory, thermal throttling, audio focus, haptics, orientation, safe areas, and 32/64-bit packaging. A desktop editor's mobile renderer does not prove mobile performance.

## iOS and visionOS

iOS export requires macOS, Xcode, templates, an App Store Team ID, and a unique bundle identifier. Godot produces an Xcode project; build/deploy through Xcode. The iOS simulator is Compatibility-only. Apple Silicon Macs can run exported iOS apps natively, but test physical devices for camera/AR/sensors/permissions/performance.

Godot 4.7 uses SDL3 for iOS controller backend. Configure privacy usage descriptions, entitlements, icons, launch screen, signing, and capabilities. Godot 4.7 visionOS export is similar to iOS and supports flat-plane apps inside the headset; immersive experiences are not supported by the current export path.

## Web

Web exports require a secure hosting context for many features and use:

- WebAssembly
- WebGL 2
- Compatibility renderer only
- single-threaded operation by default

Forward+, Mobile, WebGPU, RenderingDevice-only features, 2D HDR, and HDR output are unsupported. Thread support requires cross-origin isolation headers:

```http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Without threads, no `SharedArrayBuffer` requirement applies, but performance and APIs are limited. Web limitations include browser storage/cookie/private-browsing behavior, background tab throttling, CORS, clipboard/gamepad permissions, user-gesture requirements, and browser audio sample/stream constraints. Low-level TCP/UDP is unavailable; use HTTP/WebSocket/WebRTC as appropriate. A custom HTML shell is supported; do not edit generated HTML because re-export overwrites it.

Always test the final hosted build over HTTPS, not only a local file/server shortcut.

## Dedicated servers

A headless server can run:

```bash
godot --headless --path <project>
```

For production, use a dedicated export preset with **Export as dedicated server**. This adds the `dedicated_server` feature tag, forces headless behavior, and can strip/remove visual resources. Detect with `OS.has_feature("dedicated_server")` or DisplayServer name. Test resource removal: a removed visual resource referenced by code can fail to load.

Do not expose a server binary as a trusted client authority by assumption. Implement authentication/authorization and rate limits in server code.

## PCK, ZIP, and patches

- PCK is uncompressed/faster; ZIP is compressed/inspectable and useful for modding.
- ZIP-pack launch requires `--main-pack file.zip` in the documented workflow.
- `ProjectSettings.load_resource_pack()` loads packs. A later pack can replace the same path; choose replacement policy intentionally.
- Generate a patch against the exact base PCK and preserve patch order. Re-exporting can be nondeterministic, so do not regenerate the base accidentally.
- Sign patches/mods with an asymmetric signature. Keep the private key outside the client and validate every downloaded pack.

## Console platforms

Godot's public end-user export presets do not provide normal console support. Consoles require vendor SDKs, contracts, and usually a custom port. Do not invent public console commands, assume standard templates exist, or claim a console build from a desktop/Web export.

## Security checklist

- Treat all network input, files, packs, translations, and user content as untrusted.
- Never put database credentials, signing keys, or privileged tokens in an exported client.
- Keep `SceneMultiplayer.allow_object_decoding` disabled; never deserialize untrusted object Variants.
- Validate RPC type/size/range/ownership/authorization and rate-limit expensive actions.
- Validate/sanitize user-visible text and file paths; do not allow arbitrary filesystem access from a client.
- Use TLS certificate validation and keep private keys on servers.
- Check Android/iOS/macOS permissions and privacy declarations.
- Do not commit `.godot/export_credentials.cfg`, keystores, passwords, or CI secrets.
- Sign patches with a public-key verification scheme and fail closed on invalid signatures.
- Treat editor/tool scripts as trusted code; do not execute downloaded arbitrary scripts.

## Official sources

- Export index: <https://docs.godotengine.org/en/4.7/tutorials/export/index.html>
- Export projects: <https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html>
- PCK/patches/mods: <https://docs.godotengine.org/en/4.7/tutorials/export/exporting_pcks.html>
- Feature tags: <https://docs.godotengine.org/en/4.7/tutorials/export/feature_tags.html>
- Windows: <https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_windows.html>
- Linux: <https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_linux.html>
- macOS: <https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_macos.html>
- Android: <https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html>
- iOS: <https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html>
- Web: <https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html>
- Dedicated servers: <https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_dedicated_servers.html>
- Android platform APIs: <https://docs.godotengine.org/en/4.7/tutorials/platform/android/javaclasswrapper_and_androidruntimeplugin.html>
