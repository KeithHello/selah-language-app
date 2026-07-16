import XCTest
@testable import Selah

final class RuntimeAndAuthSessionTests: XCTestCase {
    func testRuntimeConfigurationRequiresHTTPSURLAndPublishableKey() {
        XCTAssertNil(SelahRuntimeConfiguration.load(values: [:]))
        XCTAssertNil(SelahRuntimeConfiguration.load(values: [
            "SELAH_SUPABASE_URL": "http://example.com",
            "SELAH_SUPABASE_PUBLISHABLE_KEY": "public-key",
        ]))
        XCTAssertEqual(
            SelahRuntimeConfiguration.load(values: [
                "SELAH_SUPABASE_URL": "https://project.supabase.co",
                "SELAH_SUPABASE_PUBLISHABLE_KEY": "public-key",
            ]),
            SelahRuntimeConfiguration(
                supabaseURL: "https://project.supabase.co",
                publishableKey: "public-key"
            )
        )
    }

    func testAuthSessionCodableRoundTrip() throws {
        let session = AuthSession(accessToken: "access", refreshToken: "refresh")
        let data = try JSONEncoder().encode(session)
        XCTAssertEqual(try JSONDecoder().decode(AuthSession.self, from: data), session)
    }
}
