import Foundation
import SwiftData

/// Coordinates manifest generation, verified local cache, and AudioAsset state.
/// TTS generation and cache download are intentionally separate: a sentence
/// remains usable even when later audio delivery fails.
@MainActor
final class AudioDeliveryCoordinator {
    private let audioService: AudioGenerationService
    private let cacheService: AudioCacheService
    private let modelContext: ModelContext

    init(
        audioService: AudioGenerationService,
        cacheService: AudioCacheService,
        modelContext: ModelContext
    ) {
        self.audioService = audioService
        self.cacheService = cacheService
        self.modelContext = modelContext
    }

    func generateAndCache(
        asset: AudioAsset,
        sentenceID: UUID,
        targetText: String,
        reason: AudioGenerationReason = .initialGeneration
    ) async throws -> URL {
        asset.generationStatus = .generating
        try modelContext.save()

        do {
            let result = try await audioService.generateAudio(
                sentenceID: sentenceID,
                targetText: targetText,
                voiceProfile: asset.voiceProfile,
                reason: reason
            )

            guard result.isReady,
                  let manifestID = result.manifestID,
                  let remoteURL = result.downloadURL else {
                asset.generationStatus = .failed
                try? modelContext.save()
                throw AudioCacheError.invalidDownloadURL
            }

            let localURL = try await cacheService.cache(
                manifestID: manifestID,
                from: remoteURL,
                expectedSHA256: result.sha256,
                expectedByteSize: result.byteSize
            )

            asset.localFilePath = localURL.path
            asset.remoteAssetID = result.manifestID?.uuidString
            asset.fileSizeBytes = result.byteSize
            asset.durationMs = result.durationMs
            asset.downloadedAt = Date()
            asset.generationStatus = .ready
            try modelContext.save()
            return localURL
        } catch {
            asset.generationStatus = .failed
            try? modelContext.save()
            throw error
        }
    }

    /// Existing audio is retained until a regeneration has passed verification.
    func regenerate(
        existingAsset: AudioAsset,
        sentenceID: UUID,
        targetText: String
    ) async throws -> URL {
        let replacement = AudioAsset(
            sentenceID: sentenceID,
            voiceProfile: existingAsset.voiceProfile,
            generationReason: .manualRegeneration
        )
        modelContext.insert(replacement)
        return try await generateAndCache(
            asset: replacement,
            sentenceID: sentenceID,
            targetText: targetText,
            reason: .manualRegeneration
        )
    }
}
