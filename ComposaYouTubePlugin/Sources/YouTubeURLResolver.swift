import Foundation

/// YouTube 動画のストリーム URL とメタデータを取得する。
/// Web ページから VISITOR_DATA を取得し、ANDROID_VR クライアントとして
/// innertube API を呼び出すことで、スロットリングのない URL を取得する。
/// URLSession のみで動作し、サンドボックス環境と完全に互換。
final class YouTubeURLResolver {

    /// 解決結果（ストリーム URL + タイトルをまとめて返す）
    struct ResolveResult {
        let streamURL: URL
        let title: String
    }

    /// VISITOR_DATA のキャッシュ（同一セッション内で再利用）
    private var cachedVisitorData: String?

    /// ストリーム URL とタイトルを取得する。
    func resolve(youtubeURL: String) async throws -> ResolveResult {
        guard let videoID = extractVideoID(from: youtubeURL) else {
            throw YouTubeError.invalidStreamURL
        }
        #if DEBUG
        print("[YouTubeURLResolver] Resolving videoID: \(videoID)")
        #endif

        // 1. Web ページから VISITOR_DATA を取得
        let visitorData = try await fetchVisitorData(videoID: videoID)

        // 2. ANDROID_VR クライアントとして innertube API を呼び出す
        let playerResponse = try await fetchPlayerAPI(videoID: videoID, visitorData: visitorData)

        // 3. ストリーム URL とタイトルを抽出
        let streamURL = try extractStreamURL(from: playerResponse)
        let title = extractTitle(from: playerResponse)

        #if DEBUG
        print("[YouTubeURLResolver] Resolved: \(title)")
        #endif

        return ResolveResult(streamURL: streamURL, title: title)
    }

    /// YouTube が利用可能かどうか。
    func isAvailable() -> Bool {
        return true
    }

    // MARK: - Visitor Data

    /// YouTube 動画ページの HTML から VISITOR_DATA を取得する。
    private func fetchVisitorData(videoID: String) async throws -> String {
        if let cached = cachedVisitorData {
            return cached
        }

        guard let pageURL = URL(string: "https://www.youtube.com/watch?v=\(videoID)") else {
            throw YouTubeError.invalidStreamURL
        }

        var request = URLRequest(url: pageURL)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            throw YouTubeError.networkError
        }

        // "VISITOR_DATA":"..." を抽出
        guard let regex = try? NSRegularExpression(pattern: "\"VISITOR_DATA\"\\s*:\\s*\"([^\"]+)\""),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) else {
            throw YouTubeError.resolutionFailed
        }

        let visitorData = (html as NSString).substring(with: match.range(at: 1))
        cachedVisitorData = visitorData

        #if DEBUG
        print("[YouTubeURLResolver] Got visitor data: \(visitorData.prefix(30))...")
        #endif

        return visitorData
    }

    // MARK: - Innertube API

    /// ANDROID_VR クライアントとして innertube player API を呼び出す。
    private func fetchPlayerAPI(videoID: String, visitorData: String) async throws -> [String: Any] {
        guard let apiURL = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            throw YouTubeError.networkError
        }

        let body: [String: Any] = [
            "videoId": videoID,
            "context": [
                "client": [
                    "clientName": "ANDROID_VR",
                    "clientVersion": "1.65.10",
                    "deviceMake": "Oculus",
                    "deviceModel": "Quest 3",
                    "androidSdkVersion": 32,
                    "osName": "Android",
                    "osVersion": "12L",
                    "hl": "en",
                    "gl": "US",
                    "visitorData": visitorData
                ]
            ],
            "contentCheckOk": true,
            "racyCheckOk": true
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip", forHTTPHeaderField: "User-Agent")
        request.setValue("28", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.65.10", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue(visitorData, forHTTPHeaderField: "X-Goog-Visitor-Id")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw YouTubeError.networkError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YouTubeError.resolutionFailed
        }

        // playabilityStatus を確認
        if let status = (json["playabilityStatus"] as? [String: Any])?["status"] as? String,
           status != "OK" {
            #if DEBUG
            let reason = (json["playabilityStatus"] as? [String: Any])?["reason"] as? String ?? "unknown"
            print("[YouTubeURLResolver] Playability status: \(status), reason: \(reason)")
            #endif
            throw YouTubeError.resolutionFailed
        }

        return json
    }

    // MARK: - ストリーム URL 抽出

    /// playerResponse から最適なストリーミング URL を抽出する。
    private func extractStreamURL(from response: [String: Any]) throws -> URL {
        guard let streamingData = response["streamingData"] as? [String: Any] else {
            throw YouTubeError.resolutionFailed
        }

        // formats（音声+映像の結合ストリーム）を優先
        let combinedFormats = (streamingData["formats"] as? [[String: Any]] ?? [])
            .filter { ($0["url"] as? String) != nil }
            .sorted { ($0["height"] as? Int ?? 0) > ($1["height"] as? Int ?? 0) }

        // adaptiveFormats（映像のみ）をフォールバック
        let adaptiveFormats = (streamingData["adaptiveFormats"] as? [[String: Any]] ?? [])
            .filter { format in
                guard let mime = format["mimeType"] as? String, mime.hasPrefix("video/") else { return false }
                guard let height = format["height"] as? Int, height <= 1080 else { return false }
                return format["url"] as? String != nil
            }
            .sorted { ($0["height"] as? Int ?? 0) > ($1["height"] as? Int ?? 0) }

        let best = combinedFormats.first ?? adaptiveFormats.first

        guard let urlString = best?["url"] as? String,
              let url = URL(string: urlString) else {
            throw YouTubeError.resolutionFailed
        }

        #if DEBUG
        let height = best?["height"] as? Int ?? 0
        let mime = best?["mimeType"] as? String ?? "?"
        print("[YouTubeURLResolver] Selected format: \(height)p, \(mime)")
        #endif

        return url
    }

    /// playerResponse からタイトルを抽出する。
    private func extractTitle(from response: [String: Any]) -> String {
        if let videoDetails = response["videoDetails"] as? [String: Any],
           let title = videoDetails["title"] as? String {
            return title
        }
        return "YouTube Video"
    }

    // MARK: - Video ID 抽出

    /// YouTube URL から動画 ID を抽出する。
    private func extractVideoID(from urlString: String) -> String? {
        if let url = URL(string: urlString),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value {
            return videoID
        }
        if let url = URL(string: urlString), url.host == "youtu.be" {
            let id = url.lastPathComponent
            return id.isEmpty ? nil : id
        }
        if let url = URL(string: urlString), url.pathComponents.contains("embed") {
            return url.lastPathComponent
        }
        return nil
    }
}

/// YouTube Plugin のエラー型。
enum YouTubeError: Error, LocalizedError {
    case resolutionFailed
    case invalidStreamURL
    case networkError

    var errorDescription: String? {
        switch self {
        case .resolutionFailed: return "Failed to resolve YouTube stream URL"
        case .invalidStreamURL: return "Invalid stream URL returned"
        case .networkError: return "Network error"
        }
    }
}
