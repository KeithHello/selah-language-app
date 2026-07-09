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

enum AudioPlaybackError: Error {
    case fileNotFound
    case fileCorrupted
    case playbackFailed(Error)
}
