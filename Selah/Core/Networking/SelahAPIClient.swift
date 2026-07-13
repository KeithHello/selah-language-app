import Foundation

// MARK: - Selah API Error

enum SelahAPIError: Error, LocalizedError {
    case notAuthenticated
    case invalidResponse
    case decodingFailed(Error)
    case networkError(Error)
    case serverError(Int, String)
    case tokenRefreshFailed(String)
    case rateLimited(retryAfter: TimeInterval?)
    case circuitOpen(ReliabilityCapability)

    var failureKind: NetworkFailureKind {
        switch self {
        case .notAuthenticated, .tokenRefreshFailed: return .authentication
        case .invalidResponse, .decodingFailed: return .decoding
        case .networkError(let error):
            guard let urlError = error as? URLError else { return .permanent }
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost: return .offline
            case .timedOut: return .timeout
            default: return .permanent
            }
        case .serverError(let code, _):
            switch code {
            case 401, 403: return .authentication
            case 400, 404, 409, 422: return .clientInput
            case 429: return .rateLimited
            case 500...599: return .serverTransient
            default: return .permanent
            }
        case .rateLimited: return .rateLimited
        case .circuitOpen: return .serverTransient
        }
    }

    var isRetryable: Bool {
        switch failureKind {
        case .offline, .timeout, .rateLimited, .serverTransient: return true
        case .authentication, .clientInput, .decoding, .permanent: return false
        }
    }

    var safeUserMessage: String {
        switch failureKind {
        case .offline, .timeout:
            return "目前連不上服務，這句話先留在本機，稍後會自動再試。"
        case .rateLimited, .serverTransient:
            return "服務現在有點忙，這句話先留在本機，稍後會自動再試。"
        case .authentication:
            return "登入狀態需要更新，但本機學習資料不會消失。"
        case .clientInput:
            return "這段內容目前無法處理，請稍微修改後再試。"
        case .decoding, .permanent, .circuitOpen:
            return "這次沒有完成，請稍後再試。"
        }
    }

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "尚未登入，請先註冊或登入。"
        case .invalidResponse:
            return "伺服器回應格式異常。"
        case .decodingFailed(let error):
            return "資料解析失敗：\(error.localizedDescription)"
        case .networkError(let error):
            return "網路連線異常：\(error.localizedDescription)"
        case .serverError(let code, let message):
            return "伺服器錯誤 (\(code))：\(message)"
        case .tokenRefreshFailed(let reason):
            return "登入已過期：\(reason)"
        case .rateLimited:
            return "服務現在有點忙，這句話先留在本機，稍後會自動再試。"
        case .circuitOpen:
            return "服務暫時忙碌，這句話先留在本機，稍後會自動再試。"
        }
    }
}

// MARK: - Request / Response DTOs

private struct SentenceGenerateRequest: Encodable {
    let sourceText: String
    let sourceLanguage: String
    let targetLanguage: String
    let categoryHint: String?
}

private struct AudioGenerateRequest: Encodable {
    let sentenceId: String
    let targetText: String
    let voiceProfile: String
    let reason: String
}

private struct SignInRequest: Encodable {
    let email: String
    let password: String
}

private struct SignUpRequest: Encodable {
    let email: String
    let password: String
}

private struct RefreshTokenRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

// MARK: - Selah API Client

@MainActor
final class SelahAPIClient: SelahAPIClientProtocol {

    private let supabaseURL: String
    private let publishableKey: String
    private let retryPolicy: RetryPolicy
    private let sentenceBreaker = CapabilityCircuitBreaker()
    private let audioBreaker = CapabilityCircuitBreaker()
    private var authToken: String?
    private var refreshTokenValue: String?

    private lazy var jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private lazy var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    /// Whether the client has an active authenticated session.
    var isAuthenticated: Bool {
        authToken != nil
    }

    // MARK: - Init

    init(supabaseURL: String, publishableKey: String, retryPolicy: RetryPolicy = RetryPolicy()) {
        self.supabaseURL = supabaseURL.hasSuffix("/") ? String(supabaseURL.dropLast()) : supabaseURL
        self.publishableKey = publishableKey
        self.retryPolicy = retryPolicy
    }

    // MARK: - Session Management

    func setSession(accessToken: String, refreshToken: String) {
        self.authToken = accessToken
        self.refreshTokenValue = refreshToken
    }

    func clearSession() {
        self.authToken = nil
        self.refreshTokenValue = nil
    }

    // MARK: - Auth

    func signIn(email: String, password: String) async throws {
        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password")!
        let body = SignInRequest(email: email, password: password)
        let response: AuthResponse = try await performAuthRequest(url: url, body: body)
        setSession(accessToken: response.accessToken, refreshToken: response.refreshToken)
    }

    func signUp(email: String, password: String) async throws {
        let url = URL(string: "\(supabaseURL)/auth/v1/signup")!
        let body = SignUpRequest(email: email, password: password)
        // Sign-up returns the user object; we don't auto-sign-in here.
        // The caller should follow up with signIn().
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try jsonEncoder.encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SelahAPIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw SelahAPIError.serverError(httpResponse.statusCode, "註冊失敗")
        }
    }

    // MARK: - SelahAPIClientProtocol

    func generateSentence(
        sourceText: String,
        sourceLanguage: SourceLanguage,
        targetLanguage: TargetLanguage,
        categoryHint: SentenceCategory?
    ) async throws -> GeneratedSentenceResult {
        let body = SentenceGenerateRequest(
            sourceText: sourceText,
            sourceLanguage: sourceLanguage.rawValue,
            targetLanguage: targetLanguage.rawValue,
            categoryHint: categoryHint?.rawValue
        )
        return try await performRequest(
            path: "/functions/v1/sentences-generate",
            method: "POST",
            body: body,
            capability: .sentenceGeneration
        )
    }

    func generateAudio(
        sentenceID: UUID,
        targetText: String,
        voiceProfile: VoiceProfile,
        reason: AudioGenerationReason
    ) async throws -> GeneratedAudioResult {
        let body = AudioGenerateRequest(
            sentenceId: sentenceID.uuidString,
            targetText: targetText,
            voiceProfile: voiceProfile.rawValue,
            reason: reason.rawValue
        )
        return try await performRequest(
            path: "/functions/v1/audio-generate",
            method: "POST",
            body: body,
            capability: .audioGeneration
        )
    }

    func fetchBootstrap() async throws -> BootstrapConfig {
        return try await performRequest(
            path: "/functions/v1/config-bootstrap",
            method: "GET",
            body: Optional<Never>.none,
            capability: nil
        )
    }

    // MARK: - Private Helpers

    /// Perform an auth-specific request (sign-in, refresh) that uses the publishable key
    /// instead of the Bearer token.
    private func performAuthRequest<T: Decodable>(url: URL, body: Encodable) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try jsonEncoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SelahAPIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SelahAPIError.serverError(httpResponse.statusCode, message)
        }

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw SelahAPIError.decodingFailed(error)
        }
    }

    /// Refresh the auth token using the stored refresh token.
    private func refreshAuth() async throws {
        guard let refreshTokenValue else {
            throw SelahAPIError.notAuthenticated
        }

        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token")!
        let body = RefreshTokenRequest(refreshToken: refreshTokenValue)
        let response: AuthResponse = try await performAuthRequest(url: url, body: body)
        self.authToken = response.accessToken
        self.refreshTokenValue = response.refreshToken
    }

    /// Generic request performer with automatic token refresh on 401.
    private func performRequest<T: Decodable>(
        path: String,
        method: String,
        body: (any Encodable)?,
        capability: ReliabilityCapability? = nil
    ) async throws -> T {
        let url = URL(string: "\(supabaseURL)\(path)")!
        let breaker = capability.map { $0 == .sentenceGeneration ? sentenceBreaker : audioBreaker }
        var attempt = 1
        var didRefreshToken = false
        while true {
            if let breaker, !(await breaker.canProceed(now: Date())) {
                throw SelahAPIError.circuitOpen(capability!)
            }
            do {
                let request = try buildRequest(url: url, method: method, body: body)
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SelahAPIError.invalidResponse
                }

                if httpResponse.statusCode == 401 && !didRefreshToken {
                    didRefreshToken = true
                    try await refreshAuth()
                    continue
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { TimeInterval($0) }
                    throw SelahAPIError.classified(statusCode: httpResponse.statusCode, retryAfter: retryAfter)
                }

                let result: T = try decodeResponse(data)
                await breaker?.recordSuccess()
                return result
            } catch let error as SelahAPIError {
                if error.isRetryable, attempt < retryPolicy.maxAttempts {
                    await breaker?.recordFailure(kind: error.failureKind)
                    let retryAfter: TimeInterval?
                    if case .rateLimited(let value) = error {
                        retryAfter = value
                    } else {
                        retryAfter = nil
                    }
                    let delay = retryPolicy.delay(afterAttempt: attempt, retryAfter: retryAfter)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    attempt += 1
                    continue
                }
                await breaker?.recordFailure(kind: error.failureKind)
                throw error
            } catch {
                let classified = SelahAPIError.networkError(error)
                if classified.isRetryable, attempt < retryPolicy.maxAttempts {
                    await breaker?.recordFailure(kind: classified.failureKind)
                    let delay = retryPolicy.delay(afterAttempt: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    attempt += 1
                    continue
                }
                await breaker?.recordFailure(kind: classified.failureKind)
                throw classified
            }
        }
    }

    private func buildRequest(url: URL, method: String, body: (any Encodable)?) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try jsonEncoder.encode(AnyEncodable(body))
        }

        return request
    }

    private func decodeResponse<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw SelahAPIError.decodingFailed(error)
        }
    }
}

// MARK: - Type-erased Encodable Wrapper

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ wrapped: any Encodable) {
        self._encode = { encoder in
            try wrapped.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
