import XCTest
@testable import Selah

final class AudioCacheAndPlaybackTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SelahAudioCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
    }

    func testCacheLocalURL_isStableForSameManifestAndHash() async throws {
        let cache = try AudioCacheService(baseDirectory: temporaryDirectory)
        let manifestID = UUID()

        let first = await cache.localURL(manifestID: manifestID, sha256: "abc")
        let second = await cache.localURL(manifestID: manifestID, sha256: "abc")

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.pathExtension, "mp3")
        XCTAssertTrue(first.lastPathComponent.contains(manifestID.uuidString.lowercased()))
    }

    func testCacheLocalURL_changesWhenIntegrityHashChanges() async throws {
        let cache = try AudioCacheService(baseDirectory: temporaryDirectory)
        let manifestID = UUID()

        let first = await cache.localURL(manifestID: manifestID, sha256: "first")
        let second = await cache.localURL(manifestID: manifestID, sha256: "second")

        XCTAssertNotEqual(first, second)
    }

    func testCacheSizeStartsAtZero() async throws {
        let cache = try AudioCacheService(baseDirectory: temporaryDirectory)
        let size = try await cache.cacheSizeBytes()
        XCTAssertEqual(size, 0)
    }

    func testClearAllRemovesCachedMP3ButLeavesNonAudioFiles() async throws {
        let cache = try AudioCacheService(baseDirectory: temporaryDirectory)
        let mp3 = temporaryDirectory.appendingPathComponent("sample.mp3")
        let text = temporaryDirectory.appendingPathComponent("keep.txt")
        try Data(repeating: 1, count: 1024).write(to: mp3)
        try Data("keep".utf8).write(to: text)

        try await cache.clearAll()

        XCTAssertFalse(FileManager.default.fileExists(atPath: mp3.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: text.path))
    }

    func testEvictionProtectsSpecifiedFile() async throws {
        let cache = try AudioCacheService(maximumBytes: 1024, baseDirectory: temporaryDirectory)
        let protected = temporaryDirectory.appendingPathComponent("protected.mp3")
        try Data(repeating: 1, count: 800).write(to: protected)

        do {
            try await cache.evictIfNeeded(reserving: 800, protectedURLs: [protected])
            XCTFail("Expected insufficient storage error")
        } catch AudioCacheError.insufficientStorage {
            // Expected: protected audio cannot be evicted.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: protected.path))
    }

    @MainActor
    func testAudioPlaybackStateTransitions() {
        let playback = AudioPlaybackServiceImpl()
        XCTAssertEqual(playback.state, .idle)
        XCTAssertFalse(playback.isPlaying)

        playback.pause()
        XCTAssertEqual(playback.state, .paused)
        XCTAssertFalse(playback.isPlaying)

        playback.stop()
        XCTAssertEqual(playback.state, .idle)
        XCTAssertEqual(playback.currentTime, 0)
    }

    @MainActor
    func testInvalidABLoopIsRejected() {
        let playback = AudioPlaybackServiceImpl()
        XCTAssertThrowsError(try playback.setABLoop(start: 1, end: 1)) { error in
            guard case AudioPlaybackError.invalidLoopRange = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}
