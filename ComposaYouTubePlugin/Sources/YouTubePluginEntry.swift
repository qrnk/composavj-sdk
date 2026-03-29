import Foundation
import ComposaSDK

/// YouTube Plugin バンドルのエントリポイント。
/// Info.plist の ComposaPluginClass で指定され、PluginLoader がインスタンス化する。
@objc(ComposaYouTubePluginEntry)
class YouTubePluginEntry: NSObject, PluginEntry {
    @objc func registerPlugins(manager: PluginManager) {
        let plugin = YouTubeSourcePlugin()
        manager.register(plugin)
        #if DEBUG
        print("[YouTubePluginEntry] Registered YouTubeSourcePlugin")
        #endif
    }
}
