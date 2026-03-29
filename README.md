# Composa VJ Plugin SDK

Plugin development kit for [Composa VJ](https://composavj.qrnk.jp) — a real-time visual performance instrument for macOS.
Build custom **Effect**, **Transition**, and **Source** plugins with ComposaSDK.framework.

**[日本語ドキュメント](./README-ja.md)**

## Contents

| Directory | Description |
|-----------|-------------|
| `ComposaSDK.framework/` | SDK binary (macOS, arm64/x86_64) |
| `ComposaSampleEffects/` | Effect plugin samples (Pixelate, RGB Shift, Mirror) |
| `ComposaSampleTransitions/` | Transition plugin samples (Zoom, Slide) |
| `ComposaYouTubePlugin/` | YouTube source plugin (source code + Xcode project) |
| `ComposaYouTubePlugin.bundle/` | YouTube source plugin (pre-built binary) |

## Quick Start

### 1. Create a Project

Create a new **macOS Bundle** target in Xcode.

### 2. Link the SDK

Drag `ComposaSDK.framework` into your project and add it to Frameworks.

Build Settings:
- **Framework Search Paths**: path to the SDK's parent directory
- **Runpath Search Paths**: `@loader_path/../Frameworks`

### 3. Implement the Entry Point

```swift
import Foundation
import ComposaSDK

@objc(MyPluginEntry)
class MyPluginEntry: NSObject, PluginEntry {
    @objc func registerPlugins(manager: PluginManager) {
        manager.registerEffect(MyEffect(), bank: "My Effects")
    }
}
```

### 4. Configure Info.plist

```xml
<key>ComposaPluginClass</key>
<string>MyPluginEntry</string>
```

> The value of `ComposaPluginClass` must match the name specified in `@objc(...)`.

### 5. Build & Install

Place the built `.bundle` in the Plugins folder:

```
~/Library/Application Support/ComposaVJ/Plugins/
```

In Composa VJ, go to the config menu → **Open Plugins Folder** to reveal it in Finder.

---

## Plugin Types

### Effect Plugin

Apply real-time effects to video. Implemented with Metal shaders.

```swift
struct MyEffect: EffectShader {
    let id = "my-effect"
    let name = "My Effect"
    let fragmentFunctionName = "myEffectFragment"

    let parameters = [
        EffectParameter(id: "intensity", label: "Intensity",
                        defaultValue: 0.5, min: 0.0, max: 1.0)
    ]

    var fragmentShaderSource: String {
        """
        #include <metal_stdlib>
        using namespace metal;

        struct EffectUniforms {
            float intensity;
        };

        fragment float4 myEffectFragment(
            float4 position [[position]],
            texture2d<float> inputTexture [[texture(0)]],
            constant EffectUniforms &uniforms [[buffer(0)]]
        ) {
            constexpr sampler s(filter::linear);
            float2 uv = position.xy / float2(inputTexture.get_width(),
                                              inputTexture.get_height());
            float4 color = inputTexture.sample(s, uv);
            // Apply your effect here
            return color;
        }
        """
    }
}
```

**Registration:**

```swift
manager.registerEffect(MyEffect())               // Register to "Custom" bank
manager.registerEffect(MyEffect(), bank: "My FX") // Register to a named bank
```

#### EffectParameter

Values controlled by the XY Pad or sliders. Bound to uniforms in the order they appear in the `parameters` array.

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Parameter ID |
| `label` | `String` | Display name |
| `defaultValue` | `Double` | Initial value |
| `min` | `Double` | Minimum value |
| `max` | `Double` | Maximum value |

---

### Transition Plugin

Composite Bus A/B visuals with a transition. Implemented with Metal shaders.

```swift
struct MyTransition: TransitionShader {
    let id = "my-transition"
    let name = "My Transition"
    let fragmentFunctionName = "myTransitionFragment"
    let controlType: TransitionControlType = .smooth

    var fragmentShaderSource: String {
        """
        #include <metal_stdlib>
        using namespace metal;

        struct TransitionUniforms {
            float progress;
        };

        fragment float4 myTransitionFragment(
            float4 position [[position]],
            texture2d<float> textureA [[texture(0)]],
            texture2d<float> textureB [[texture(1)]],
            constant TransitionUniforms &uniforms [[buffer(0)]]
        ) {
            constexpr sampler s(filter::linear);
            float2 uv = position.xy / float2(textureA.get_width(),
                                              textureA.get_height());
            float4 colorA = textureA.sample(s, uv);
            float4 colorB = textureB.sample(s, uv);
            // progress (0.0 = Bus A, 1.0 = Bus B)
            return mix(colorA, colorB, uniforms.progress);
        }
        """
    }
}
```

**Registration:**

```swift
manager.registerTransition(MyTransition())
```

#### TransitionControlType

| Value | Description |
|-------|-------------|
| `.smooth` | Follows crossfader (continuous) |
| `.snap` | Instant switch at threshold |

---

### Source Plugin

Fetch video from external sources (streaming, generators, etc.).

```swift
class MySourcePlugin: SourcePlugin {
    let id = "my-source"
    let name = "My Source"
    let sourceType: SourceType = .generator

    // Form displayed when adding a source (nil for immediate creation)
    var addSourceForm: [PluginFormField]? {
        [
            .text(id: "url", label: "URL", placeholder: "https://..."),
            .selection(id: "quality", label: "Quality", options: [
                SelectionOption(id: "720", label: "720p"),
                SelectionOption(id: "1080", label: "1080p"),
            ])
        ]
    }

    func createSource(from values: [String: String]) async throws -> SourceDefinition {
        let url = values["url"] ?? ""
        return SourceDefinition(
            id: UUID().uuidString,
            name: "My Source",
            type: sourceType,
            locator: .generatorID(url),
            metadata: nil,
            cache: nil
        )
    }

    func createFrameProvider(for source: SourceDefinition) -> FrameProvider? {
        // Return your FrameProvider implementation
        return nil
    }

    func prepare(source: SourceDefinition) async throws -> SourceDefinition {
        return source
    }
}
```

**Registration:**

```swift
manager.register(MySourcePlugin())
```

#### PluginFormField

Declaratively define form UI for source creation.

| Case | Parameters | Description |
|------|-----------|-------------|
| `.text` | `id`, `label`, `placeholder` | Text input |
| `.number` | `id`, `label`, `min`, `max`, `defaultValue` | Number input |
| `.selection` | `id`, `label`, `options: [SelectionOption]` | Dropdown selection |

#### FrameProvider Protocol

```swift
public protocol FrameProvider {
    func frame(at playhead: TimeInterval) -> VideoFrame?
    func prepare() async throws
    var duration: TimeInterval { get }
}
```

---

## API Reference

### Core Protocols

| Protocol | Description |
|----------|-------------|
| `PluginEntry` | Plugin entry point. Implement `registerPlugins(manager:)` |
| `EffectShader` | Effect definition (Metal shader + parameters) |
| `TransitionShader` | Transition definition (Metal shader + controlType) |
| `SourcePlugin` | Source plugin definition (form + FrameProvider creation) |
| `FrameProvider` | Frame supply (`frame(at:)` returns CVPixelBuffer) |

### PluginManager (Registration)

| Method | Description |
|--------|-------------|
| `register(_ plugin: SourcePlugin)` | Register a Source Plugin |
| `registerEffect(_ effect: EffectShader)` | Register an Effect to "Custom" bank |
| `registerEffect(_ effect: EffectShader, bank: String)` | Register an Effect to a named bank |
| `registerTransition(_ transition: TransitionShader)` | Register a Transition |

### Data Types

| Type | Description |
|------|-------------|
| `VideoFrame` | `timestamp: TimeInterval` + `pixelBuffer: CVPixelBuffer` |
| `SourceDefinition` | Source definition (ID, name, type, locator, metadata) |
| `SourceType` | `.videoFile`, `.image`, `.generator`, `.youtube`, etc. |
| `EffectParameter` | Effect parameter (ID, label, range, default value) |
| `EffectInstance` | Runtime effect instance (holds parameter values) |

### CommandServiceClient

XPC client for executing external commands in a sandboxed environment.

```swift
let client = CommandServiceClient.shared
let (output, exitCode) = try client.execute(
    command: "/usr/bin/curl",
    arguments: ["-s", "https://example.com"]
)
```

---

## Sample Projects

### ComposaSampleEffects

Includes 3 sample effects:

| Effect | Description |
|--------|-------------|
| Pixelate | Mosaic effect |
| RGB Shift | RGB channel offset |
| Mirror | Horizontal flip |

### ComposaSampleTransitions

Includes 2 sample transitions:

| Transition | Description |
|------------|-------------|
| Zoom | Zoom-in transition |
| Slide | Slide transition |

---

## YouTube Plugin

A plugin that plays YouTube videos as a real-time source.
No additional installation is required. The plugin uses URLSession to access YouTube's API directly.

Full source code is available in the `ComposaYouTubePlugin/` directory.

**Installation:**

Copy `ComposaYouTubePlugin.bundle` to the Plugins folder:

```
~/Library/Application Support/ComposaVJ/Plugins/
```

---

## Requirements

- macOS 14.0+
- Xcode 15.0+
- Composa VJ (Free supports built-in plugins only; Pro required for custom plugins)

## License

See [LICENSE](./LICENSE) ([Japanese](./LICENSE-ja.md))

- **SDK binary / YouTube Plugin**: Composa SDK License (free to develop & sell plugins; modification & redistribution prohibited)
- **Sample code**: MIT License
