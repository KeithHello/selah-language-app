import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

struct WidgetSnapshotStore {
    static let appGroupIdentifier = "group.com.kdagentic.selah"
    static let snapshotKey = "widget-ready-snapshot"

    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: Self.appGroupIdentifier)) {
        self.defaults = defaults
    }

    func save(_ snapshot: WidgetReadySnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        defaults?.set(data, forKey: Self.snapshotKey)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "SelahLearningWidget")
        #endif
    }
}
