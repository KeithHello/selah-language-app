import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Playback state for UI observation without exposing AVFoundation details.
enum AudioPlaybackState: Equatable {
    case idle
    case playing
    case paused
    case finished
    case failed(String)
}

/// Native audio playback implementation. AVAudioPlayer is used only when
/// AVFoundation supports it; macOS Swift Package builds retain a safe fallback.
@MainActor
final class AudioPlaybackServiceImpl: NSObject, AudioPlaybackService {
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isPlaying = false
    private(set) var state: AudioPlaybackState = .idle
    private(set) var playbackSpeed: PlaybackSpeed = .learning
    private(set) var loopStart: TimeInterval?
    private(set) var loopEnd: TimeInterval?

    #if canImport(AVFoundation)
    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    #endif

    func play(asset: AudioAsset, speed: PlaybackSpeed) async throws {
        guard let localFilePath = asset.localFilePath else {
            throw AudioPlaybackError.fileNotFound
        }
        try await play(url: URL(fileURLWithPath: localFilePath), speed: speed)
    }

    func play(url: URL, speed: PlaybackSpeed) async throws {
        #if canImport(AVFoundation)
        do {
            if player?.url != url {
                stop()
                player = try AVAudioPlayer(contentsOf: url)
                player?.delegate = self
                player?.enableRate = true
                duration = player?.duration ?? 0
            }

            guard let player else { throw AudioPlaybackError.fileNotFound }
            playbackSpeed = speed
            player.rate = Float(speed.rawValue)
            player.play()
            isPlaying = true
            state = .playing
            startProgressTimer()
        } catch let error as AudioPlaybackError {
            state = .failed(error.localizedDescription)
            throw error
        } catch {
            state = .failed("播放暫時沒有完成")
            throw AudioPlaybackError.playbackFailed(error)
        }
        #else
        throw AudioPlaybackError.fileCorrupted
        #endif
    }

    func stop() {
        #if canImport(AVFoundation)
        player?.stop()
        progressTimer?.invalidate()
        progressTimer = nil
        #endif
        currentTime = 0
        isPlaying = false
        state = .idle
        clearABLoop()
    }

    func pause() {
        #if canImport(AVFoundation)
        player?.pause()
        progressTimer?.invalidate()
        progressTimer = nil
        currentTime = player?.currentTime ?? currentTime
        #endif
        isPlaying = false
        state = .paused
    }

    func seek(to time: TimeInterval) {
        let clamped = min(max(0, time), duration)
        #if canImport(AVFoundation)
        player?.currentTime = clamped
        #endif
        currentTime = clamped
    }

    func setSpeed(_ speed: PlaybackSpeed) {
        playbackSpeed = speed
        #if canImport(AVFoundation)
        player?.rate = Float(speed.rawValue)
        #endif
    }

    /// Enables repeating a valid [start, end] interval.
    func setABLoop(start: TimeInterval, end: TimeInterval) throws {
        guard start >= 0, start < end, end <= duration else {
            throw AudioPlaybackError.invalidLoopRange
        }
        loopStart = start
        loopEnd = end
    }

    func clearABLoop() {
        loopStart = nil
        loopEnd = nil
    }

    #if canImport(AVFoundation)
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            self.currentTime = player.currentTime
            self.duration = player.duration

            if let start = self.loopStart, let end = self.loopEnd, player.currentTime >= end {
                player.currentTime = start
                player.play()
            }
        }
    }
    #endif
}

#if canImport(AVFoundation)
extension AudioPlaybackServiceImpl: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        progressTimer?.invalidate()
        progressTimer = nil
        currentTime = duration
        isPlaying = false
        state = flag ? .finished : .failed("播放未完成")
    }
}
#endif
