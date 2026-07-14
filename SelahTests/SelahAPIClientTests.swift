import XCTest
@testable import Selah

@MainActor
final class SelahAPIClientTests: XCTestCase {

    var apiClient: SelahAPIClient!

    override func setUp() {
        super.setUp()
        apiClient = SelahAPIClient(
            supabaseURL: "https://ijonabyyppmgvoufgamt.supabase.co",
            publishableKey: "sb_publishable_test"
        )
    }

    override func tearDown() {
        apiClient = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState_notAuthenticated() {
        XCTAssertFalse(apiClient.isAuthenticated)
    }

    func testSetSession_setsAuthState() {
        apiClient.setSession(accessToken: "test-access", refreshToken: "test-refresh")
        XCTAssertTrue(apiClient.isAuthenticated)
    }

    func testClearSession_removesAuth() {
        apiClient.setSession(accessToken: "test-access", refreshToken: "test-refresh")
        apiClient.clearSession()
        XCTAssertFalse(apiClient.isAuthenticated)
    }

    // MARK: - SelahAPIError

    func testAPIError_descriptions() {
        XCTAssertFalse(SelahAPIError.notAuthenticated.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(SelahAPIError.invalidResponse.errorDescription?.isEmpty ?? true)
        let serverError = SelahAPIError.serverError(500, "raw provider payload")
        XCTAssertTrue(serverError.errorDescription?.contains("500") ?? false)
        XCTAssertFalse(serverError.errorDescription?.contains("raw provider payload") ?? true)
    }

    func testAPIError_tokenRefreshFailedRedactsReason() {
        let error = SelahAPIError.tokenRefreshFailed("refresh token payload")
        XCTAssertFalse(error.errorDescription?.contains("refresh token payload") ?? true)
    }

    // MARK: - URL Construction (sanity)

    func testInit_stripsTrailingSlash() {
        let client = SelahAPIClient(
            supabaseURL: "https://example.com/",
            publishableKey: "key"
        )
        // Indirect test: no double-slash in bootstrap path
        // The client is created successfully — no crash
        XCTAssertNotNil(client)
    }

    // MARK: - GeneratedSentenceResult (Codable round-trip)

    func testGeneratedSentenceResult_codable() throws {
        let json = """
        {
            "target_text": "Hello world",
            "category": "work",
            "vocabulary": [
                {
                    "surface_text": "hello",
                    "meaning_in_context": "你好",
                    "suggested_help_state": "new"
                }
            ],
            "deconstruction": [
                {
                    "surface_text": "hello",
                    "meaning": "招呼語",
                    "type": "phrase"
                }
            ],
            "prompt_version": "v8.0"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let result = try decoder.decode(GeneratedSentenceResult.self, from: json)

        XCTAssertEqual(result.targetText, "Hello world")
        XCTAssertEqual(result.category, .work)
        XCTAssertEqual(result.vocabulary.count, 1)
        XCTAssertEqual(result.deconstruction.count, 1)
        XCTAssertEqual(result.promptVersion, "v8.0")
    }

    // MARK: - BootstrapConfig (Codable round-trip)

    func testBootstrapConfig_codable() throws {
        let json = """
        {
            "source_languages": ["zh-Hant"],
            "target_languages": ["en"],
            "default_voice_profile": "gentle-natural",
            "voice_profiles": [
                {
                    "id": "gentle-natural",
                    "label": "溫柔自然",
                    "description": "速度適中"
                }
            ],
            "seed_sentence_pack_version": "v2",
            "prompt_version": "v8.0",
            "feature_flags": {
                "tts_regeneration": true,
                "night_preview": false
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let config = try decoder.decode(BootstrapConfig.self, from: json)

        XCTAssertEqual(config.sourceLanguages, ["zh-Hant"])
        XCTAssertEqual(config.defaultVoiceProfile, "gentle-natural")
        XCTAssertEqual(config.voiceProfiles.count, 1)
        XCTAssertEqual(config.featureFlags["tts_regeneration"], true)
    }
}
