import Foundation
import AVFoundation
import CoreVideo
import ComposaSDK

/// YouTube ストリーミング再生用の FrameProvider。
/// AVPlayer でストリーム URL を再生し、フレームを取得する。
/// VideoFileSource と同じ仕組み（AVPlayer + AVPlayerItemVideoOutput + フレームキャッシュ）。
final class YouTubeStreamSource: FrameProvider {
    private let streamURL: URL
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var _duration: TimeInterval = .infinity  // ストリームは duration 不明の場合がある
    private var isPrepared = false
    private var lastPixelBuffer: CVPixelBuffer?
    private var isPlaying = false
    private var lastPlayhead: TimeInterval = 0

    var duration: TimeInterval { _duration }

    init(streamURL: URL) {
        self.streamURL = streamURL
    }

    func prepare() async throws {
        guard !isPrepared else { return }
        prepareSync()

        // AVPlayer が readyToPlay になるまで待機してからプリバッファ
        if let player = self.player, let item = self.playerItem {
            // status が readyToPlay になるのを待つ
            if item.status != .readyToPlay {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    var observer: NSKeyValueObservation?
                    observer = item.observe(\.status, options: [.new]) { item, _ in
                        switch item.status {
                        case .readyToPlay:
                            observer?.invalidate()
                            continuation.resume()
                        case .failed:
                            observer?.invalidate()
                            continuation.resume(throwing: item.error ?? YouTubeError.invalidStreamURL)
                        default:
                            break
                        }
                    }
                }
            }

            // readyToPlay 後にプリロール
            await withCheckedContinuation { continuation in
                player.preroll(atRate: 1.0) { _ in
                    continuation.resume()
                }
            }
            #if DEBUG
            print("[YouTubeStreamSource] Preroll completed for \(streamURL.lastPathComponent)")
            #endif
        }
    }

    private func prepareSync() {
        guard !isPrepared else { return }
        isPrepared = true

        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: outputSettings)

        let item = AVPlayerItem(url: streamURL)
        item.add(output)

        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.rate = 0

        // duration を取得（取得可能な場合）
        let asset = item.asset
        let cmDuration = asset.duration
        if cmDuration.isValid && !cmDuration.isIndefinite {
            _duration = CMTimeGetSeconds(cmDuration)
        }

        self.player = player
        self.playerItem = item
        self.videoOutput = output
    }

    func frame(at playhead: TimeInterval) -> VideoFrame? {
        if !isPrepared { prepareSync() }
        guard let player = player, let output = videoOutput else { return nil }

        if !isPlaying {
            player.rate = 1.0
            isPlaying = true
            lastPlayhead = playhead
        }

        // ループ検出
        if playhead < lastPlayhead - 0.5 {
            let seekTime = CMTime(seconds: playhead, preferredTimescale: 600)
            player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        lastPlayhead = playhead

        let currentTime = output.itemTime(forHostTime: CACurrentMediaTime())
        if output.hasNewPixelBuffer(forItemTime: currentTime) {
            if let pixelBuffer = output.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) {
                lastPixelBuffer = pixelBuffer
                return VideoFrame(timestamp: playhead, pixelBuffer: pixelBuffer)
            }
        }

        // フレームキャッシュ（点滅防止）
        if let cached = lastPixelBuffer {
            return VideoFrame(timestamp: playhead, pixelBuffer: cached)
        }

        return nil
    }
}
