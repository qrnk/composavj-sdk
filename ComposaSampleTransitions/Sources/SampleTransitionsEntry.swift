import Foundation
import ComposaSDK

/// Sample Transitions Plugin のエントリポイント。
/// 2つのサンプルトランジション（Zoom, Slide）を登録する。
@objc(ComposaSampleTransitionsEntry)
class SampleTransitionsEntry: NSObject, PluginEntry {
    @objc func registerPlugins(manager: PluginManager) {
        manager.registerTransition(ZoomTransition())
        manager.registerTransition(SlideTransition())
        #if DEBUG
        print("[SampleTransitionsEntry] Registered 2 sample transitions")
        #endif
    }
}
