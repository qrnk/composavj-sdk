import Foundation
import ComposaSDK

/// Sample Effects Plugin のエントリポイント。
/// 3つのサンプルエフェクト（Pixelate, RGB Shift, Mirror）を登録する。
@objc(ComposaSampleEffectsEntry)
class SampleEffectsEntry: NSObject, PluginEntry {
    @objc func registerPlugins(manager: PluginManager) {
        manager.registerEffect(PixelateEffect(), bank: "Sample")
        manager.registerEffect(RGBShiftEffect(), bank: "Sample")
        manager.registerEffect(MirrorEffect(), bank: "Sample")
        #if DEBUG
        print("[SampleEffectsEntry] Registered 3 sample effects in 'Sample' bank")
        #endif
    }
}
