import Foundation
import ComposaSDK

/// YouTube ストリーミングソース Plugin。
/// URLSession で YouTube ページからストリーム URL を解決し、AVPlayer でストリーミング再生する。
final class YouTubeSourcePlugin: SourcePlugin {
    let id = "youtube"
    let name = "YouTube"
    let sourceType: SourceType = .youtube

    private let resolver = YouTubeURLResolver()
    /// 辞書アクセスの排他制御用ロック
    private let lock = NSLock()
    /// 解決済みストリーム URL のキャッシュ（SourceID → stream URL）
    private var streamURLCache: [String: URL] = [:]
    /// プリバッファ済み FrameProvider のキャッシュ（SourceID → provider）
    private var prebufferedProviders: [String: YouTubeStreamSource] = [:]

    /// Plugin が利用可能か（URLSession ベースなので常に利用可能）
    var isAvailable: Bool {
        resolver.isAvailable()
    }

    // MARK: - ソース追加フォーム

    /// YouTube URL 入力フォームの定義。
    var addSourceForm: [PluginFormField]? {
        [.text(id: "url", label: "YouTube URL", placeholder: "https://youtu.be/...")]
    }

    /// フォームの入力値から SourceDefinition を作成する。
    /// 1回のリクエストでストリーム URL とタイトルをまとめて取得する。
    func createSource(from values: [String: String]) async throws -> SourceDefinition {
        guard let urlString = values["url"], !urlString.isEmpty else {
            throw YouTubeError.invalidStreamURL
        }

        // ストリーム URL とタイトルを1回のリクエストで取得
        let result = try await resolver.resolve(youtubeURL: urlString)

        let sourceID = UUID().uuidString
        lock.lock()
        streamURLCache[sourceID] = result.streamURL
        lock.unlock()

        return SourceDefinition(
            id: sourceID,
            name: result.title,
            type: .youtube,
            locator: .youtubeURL(urlString),
            metadata: nil,
            cache: nil
        )
    }

    // MARK: - FrameProvider

    /// SourceDefinition から FrameProvider を生成する。
    /// プリバッファ済みがあればそれを返す。なければキャッシュ URL から新規作成。
    func createFrameProvider(for source: SourceDefinition) -> FrameProvider? {
        guard case .youtubeURL = source.locator else { return nil }

        lock.lock()
        // プリバッファ済みプロバイダがあればそれを使用（初回のみ）
        if let prebuffered = prebufferedProviders.removeValue(forKey: source.id) {
            lock.unlock()
            #if DEBUG
            print("[YouTubeSourcePlugin] Using prebuffered provider for \(source.name)")
            #endif
            return prebuffered
        }

        if let cached = streamURLCache[source.id] {
            lock.unlock()
            return YouTubeStreamSource(streamURL: cached)
        }

        lock.unlock()
        return nil
    }

    /// ソースの準備。ストリーム URL を解決してキャッシュし、プリバッファする。
    /// Session 読み込み時に呼ばれる（ストリーム URL は数時間で失効するため毎回再解決）。
    func prepare(source: SourceDefinition) async throws -> SourceDefinition {
        guard case .youtubeURL(let url) = source.locator else { return source }

        let result = try await resolver.resolve(youtubeURL: url)
        try Task.checkCancellation()
        lock.lock()
        streamURLCache[source.id] = result.streamURL
        lock.unlock()

        // プリバッファ: FrameProvider を事前作成して preroll
        let provider = YouTubeStreamSource(streamURL: result.streamURL)
        try await provider.prepare()
        try Task.checkCancellation()
        lock.lock()
        prebufferedProviders[source.id] = provider
        lock.unlock()

        return source
    }
}
