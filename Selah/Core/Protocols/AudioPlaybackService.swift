import Foundation

/// Audio playback service for cached sentence audio.
protocol AudioPlaybackService {
    /// Play an audio asset at the given speed.
    func play(asset: AudioAsset, speed: PlaybackSpeed) async throws

    /// Stop current playback.
    func stop()

    /// Pause current playback.
    func pause()

    /// Seek to a position in seconds.
    func seek(to time: TimeInterval)

    /// Current playback position in seconds.
    var currentTime: TimeInterval { get }

    /// Total duration of the current asset in seconds.
    var duration: TimeInterval { get }

    /// Whether audio is currently playing.
    var isPlaying: Bool { get }
}

// MARK: - Errors

enum AudioPlaybackError: Error, LocalizedError {
    case fileNotFound
    case fileCorrupted
    case invalidLoopRange
    case playbackFailed(Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "找不到可播放的音檔。"
        case .fileCorrupted: return "音檔已損壞或無法播放。"
        case .invalidLoopRange: return "A-B 循環區間無效。"
        case .playbackFailed: return "音檔播放失敗。"
        }
    }
}
