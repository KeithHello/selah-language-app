import Foundation
import SwiftData

/// Drives the four-stage M2 listening flow using real local AudioAsset records.
@MainActor
final class ListenViewModel: ObservableObject {
    @Published private(set) var collection: [ListenCollectionItem] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var stage = 1
    @Published private(set) var blindListenCount = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedSpeed: PlaybackSpeed = .learning

    private let builder: ListenCollectionBuilder
    private let playback: AudioPlaybackServiceImpl

    init(
        modelContext: ModelContext,
        playback: AudioPlaybackServiceImpl? = nil,
        memoryUnlockService: SpriteMemoryUnlockService? = nil,
        companionID: UUID? = nil
    ) {
        self.builder = ListenCollectionBuilder(
            modelContext: modelContext,
            memoryUnlockService: memoryUnlockService,
            companionID: companionID
        )
        self.playback = playback ?? AudioPlaybackServiceImpl()
    }

    var currentItem: ListenCollectionItem? {
        guard collection.indices.contains(currentIndex) else { return nil }
        return collection[currentIndex]
    }

    var isComplete: Bool {
        !collection.isEmpty && currentIndex >= collection.count
    }

    var canAdvanceFromBlindListen: Bool {
        blindListenCount >= 3
    }

    func load() {
        isLoading = true
        defer { isLoading = false }
        do {
            collection = try builder.build(limit: 3)
            currentIndex = 0
            stage = 1
            blindListenCount = 0
            errorMessage = nil
        } catch {
            collection = []
            errorMessage = "無法準備今天的聆聽內容，請稍後再試。"
        }
    }

    func playCurrent() {
        guard let item = currentItem else { return }
        Task {
            do {
                try await playback.play(asset: item.audioAsset, speed: selectedSpeed)
            } catch {
                errorMessage = "音訊播放暫時沒有完成，請再試一次。"
            }
        }
    }

    func pauseOrResume() {
        if playback.isPlaying {
            playback.pause()
        } else {
            playCurrent()
        }
    }

    func seek(to seconds: TimeInterval) {
        playback.seek(to: seconds)
    }

    func setSpeed(_ speed: PlaybackSpeed) {
        selectedSpeed = speed
        playback.setSpeed(speed)
    }

    func confirmBlindListen() {
        blindListenCount += 1
        if blindListenCount >= 3 {
            stage = 2
        }
    }

    func advanceStage() {
        stage = min(stage + 1, 4)
    }

    func completeCurrentSentence() {
        guard let item = currentItem else { return }
        do {
            try builder.markListened(item)
            playback.stop()
            currentIndex += 1
            stage = 1
            blindListenCount = 0
            if currentIndex >= collection.count {
                errorMessage = nil
            }
        } catch {
            errorMessage = "無法儲存聆聽進度，請稍後再試。"
        }
    }

    func retryCurrentAudio() {
        // M2 manual regeneration is initiated from the sentence detail UI.
        // Here we retry only loading a ready local asset after a cache issue.
        errorMessage = nil
        load()
    }

    func stop() {
        playback.stop()
    }
}
