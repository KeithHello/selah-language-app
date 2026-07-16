import Foundation

struct SelahRuntimeConfiguration: Equatable {
    let supabaseURL: String
    let publishableKey: String

    static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) -> SelahRuntimeConfiguration? {
        let values = [
            "SELAH_SUPABASE_URL": environment["SELAH_SUPABASE_URL"]
                ?? bundle.object(forInfoDictionaryKey: "SELAH_SUPABASE_URL") as? String,
            "SELAH_SUPABASE_PUBLISHABLE_KEY": environment["SELAH_SUPABASE_PUBLISHABLE_KEY"]
                ?? bundle.object(forInfoDictionaryKey: "SELAH_SUPABASE_PUBLISHABLE_KEY") as? String,
        ]
        return load(values: values.compactMapValues { $0 })
    }

    static func load(values: [String: String]) -> SelahRuntimeConfiguration? {
        guard let rawURL = values["SELAH_SUPABASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              let key = values["SELAH_SUPABASE_PUBLISHABLE_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: rawURL),
              url.scheme == "https",
              url.host != nil,
              !key.isEmpty else {
            return nil
        }
        return SelahRuntimeConfiguration(supabaseURL: rawURL, publishableKey: key)
    }
}
