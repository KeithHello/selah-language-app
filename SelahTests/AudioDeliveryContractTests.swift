import XCTest
@testable import Selah

final class AudioDeliveryContractTests: XCTestCase {
    func testStorageAudioResponseDecodesToGeneratedAudioResult() throws {
        let json = """
        {
          "status": "ready",
          "voiceProfile": "gentle-natural",
          "manifestId": "5A734F08-5022-4C29-8CF8-5DD73F4C5B3E",
          "downloadUrl": "https://example.com/signed-audio.mp3",
          "storagePath": "users/user-1/sentence-1/gentle-natural/hash.mp3",
          "sha256": "abc123",
          "byteSize": 4096,
          "durationMs": 2300,
          "cacheHit": true,
          "errorCode": null
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(GeneratedAudioResult.self, from: json)

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.voiceProfile, .gentleNatural)
        XCTAssertEqual(result.manifestID?.uuidString, "5A734F08-5022-4C29-8CF8-5DD73F4C5B3E")
        XCTAssertEqual(result.downloadURL?.host, "example.com")
        XCTAssertEqual(result.byteSize, 4096)
        XCTAssertEqual(result.durationMs, 2300)
        XCTAssertTrue(result.cacheHit)
        XCTAssertTrue(result.isReady)
    }

    func testPendingStorageAudioResponseIsNotReady() throws {
        let json = """
        {
          "status": "generating",
          "voiceProfile": "daily-bright",
          "manifestId": "5A734F08-5022-4C29-8CF8-5DD73F4C5B3E",
          "byteSize": 0,
          "durationMs": 0,
          "cacheHit": false
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(GeneratedAudioResult.self, from: json)
        XCTAssertEqual(result.status, .generating)
        XCTAssertFalse(result.isReady)
        XCTAssertNil(result.downloadURL)
    }
}
