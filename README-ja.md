# Composa VJ Plugin SDK

[Composa VJ](https://composavj.qrnk.jp) 向けのプラグイン開発キットです。
ComposaSDK.framework を使って、カスタム **Effect**・**Transition**・**Source** プラグインを開発できます。

**[English documentation](./README.md)**

## Contents

| Directory | Description |
|-----------|-------------|
| `ComposaSDK.framework/` | SDK バイナリ（macOS, arm64/x86_64） |
| `ComposaSampleEffects/` | Effect プラグインサンプル（Pixelate, RGB Shift, Mirror） |
| `ComposaSampleTransitions/` | Transition プラグインサンプル（Zoom, Slide） |
| `ComposaYouTubePlugin/` | YouTube ソースプラグイン（ソースコード + Xcode プロジェクト） |
| `ComposaYouTubePlugin.bundle/` | YouTube ソースプラグイン（ビルド済みバイナリ） |

## Quick Start

### 1. プロジェクト作成

Xcode で **macOS Bundle** ターゲットを作成します。

### 2. SDK をリンク

`ComposaSDK.framework` をプロジェクトにドラッグし、Frameworks に追加します。

Build Settings:
- **Framework Search Paths**: SDK の親ディレクトリを指定
- **Runpath Search Paths**: `@loader_path/../Frameworks`

### 3. エントリポイントを実装

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

### 4. Info.plist に設定

```xml
<key>ComposaPluginClass</key>
<string>MyPluginEntry</string>
```

> `ComposaPluginClass` の値は `@objc(...)` で指定した名前と一致させてください。

### 5. ビルド & インストール

ビルドした `.bundle` を Plugins フォルダに配置します:

```
~/Library/Application Support/ComposaVJ/Plugins/
```

Composa VJ の config メニュー → **Open Plugins Folder** で Finder から開けます。

---

## Plugin Types

### Effect Plugin

映像にリアルタイムエフェクトを適用します。Metal シェーダーで実装します。

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
            // エフェクト処理をここに実装
            return color;
        }
        """
    }
}
```

**登録:**

```swift
manager.registerEffect(MyEffect())               // "Custom" Bank に登録
manager.registerEffect(MyEffect(), bank: "My FX") // Bank 名を指定
```

#### EffectParameter

XY Pad やスライダーから制御される値です。`parameters` 配列の順序で Uniform にバインドされます。

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | パラメータ ID |
| `label` | `String` | UI 表示名 |
| `defaultValue` | `Double` | 初期値 |
| `min` | `Double` | 最小値 |
| `max` | `Double` | 最大値 |

---

### Transition Plugin

Bus A/B の映像を合成するトランジションです。Metal シェーダーで実装します。

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

**登録:**

```swift
manager.registerTransition(MyTransition())
```

#### TransitionControlType

| Value | Description |
|-------|-------------|
| `.smooth` | Crossfader に追従（連続値） |
| `.snap` | 閾値で瞬時切替 |

---

### Source Plugin

外部ソース（ストリーミング、ジェネレーター等）から映像を取得します。

```swift
class MySourcePlugin: SourcePlugin {
    let id = "my-source"
    let name = "My Source"
    let sourceType: SourceType = .generator

    // ソース追加時のフォーム定義（nil なら即作成）
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
        // FrameProvider を返す
        return nil
    }

    func prepare(source: SourceDefinition) async throws -> SourceDefinition {
        return source
    }
}
```

**登録:**

```swift
manager.register(MySourcePlugin())
```

#### PluginFormField

ソース追加時のフォーム UI を宣言的に定義します。

| Case | Parameters | Description |
|------|-----------|-------------|
| `.text` | `id`, `label`, `placeholder` | テキスト入力 |
| `.number` | `id`, `label`, `min`, `max`, `defaultValue` | 数値入力 |
| `.selection` | `id`, `label`, `options: [SelectionOption]` | ドロップダウン選択 |

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
| `PluginEntry` | プラグインのエントリポイント。`registerPlugins(manager:)` を実装 |
| `EffectShader` | エフェクトの定義（Metal シェーダー + パラメータ） |
| `TransitionShader` | トランジションの定義（Metal シェーダー + controlType） |
| `SourcePlugin` | ソースプラグインの定義（フォーム + FrameProvider 生成） |
| `FrameProvider` | フレーム供給（`frame(at:)` で CVPixelBuffer を返す） |

### PluginManager (Registration)

| Method | Description |
|--------|-------------|
| `register(_ plugin: SourcePlugin)` | Source Plugin を登録 |
| `registerEffect(_ effect: EffectShader)` | Effect を "Custom" Bank に登録 |
| `registerEffect(_ effect: EffectShader, bank: String)` | Effect を指定 Bank に登録 |
| `registerTransition(_ transition: TransitionShader)` | Transition を登録 |

### Data Types

| Type | Description |
|------|-------------|
| `VideoFrame` | `timestamp: TimeInterval` + `pixelBuffer: CVPixelBuffer` |
| `SourceDefinition` | ソースの定義（ID, 名前, タイプ, ロケーター, メタデータ） |
| `SourceType` | `.videoFile`, `.image`, `.generator`, `.youtube` 等 |
| `EffectParameter` | エフェクトパラメータ（ID, ラベル, 範囲, デフォルト値） |
| `EffectInstance` | エフェクトの実行インスタンス（パラメータ値を保持） |

### CommandServiceClient

サンドボックス環境で外部コマンドを実行するための XPC クライアントです。

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

3つのサンプルエフェクトを含みます:

| Effect | Description |
|--------|-------------|
| Pixelate | モザイクエフェクト |
| RGB Shift | RGB チャンネルずらし |
| Mirror | 左右反転 |

### ComposaSampleTransitions

2つのサンプルトランジションを含みます:

| Transition | Description |
|------------|-------------|
| Zoom | ズームイン切替 |
| Slide | スライド切替 |

---

## YouTube Plugin

YouTube 動画をリアルタイムソースとして再生するプラグインです。
外部ツールのインストールは不要です。URLSession で YouTube API に直接アクセスします。

ソースコードは `ComposaYouTubePlugin/` ディレクトリに含まれています。

**インストール:**

`ComposaYouTubePlugin.bundle` を Plugins フォルダにコピー:

```
~/Library/Application Support/ComposaVJ/Plugins/
```

---

## Requirements

- macOS 14.0+
- Xcode 15.0+
- Composa VJ（Free 版では Built-in Plugin のみ、Pro でカスタム Plugin 対応）

## License

[LICENSE](./LICENSE) を参照してください。（[日本語版](./LICENSE-ja.md)）

- **SDK バイナリ / YouTube Plugin**: Composa SDK License（プラグイン開発・販売自由、改変・再配布禁止）
- **サンプルコード**: MIT License
