import SwiftUI
import WidgetKit

private struct WidgetSnapshot: Codable {
    let todaySentenceCount: Int
    let listenedCount: Int
    let dueReviewCount: Int
    let recommendation: String
    let companionDisplayName: String
    let generatedAt: Date
}

private struct SelahWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

private struct SelahWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SelahWidgetEntry {
        entry()
    }

    func getSnapshot(in context: Context, completion: @escaping (SelahWidgetEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SelahWidgetEntry>) -> Void) {
        let current = entry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1_800)
        completion(Timeline(entries: [current], policy: .after(next)))
    }

    private func entry() -> SelahWidgetEntry {
        let defaults = UserDefaults(suiteName: "group.com.kdagentic.selah")
        let snapshot = defaults?.data(forKey: "widget-ready-snapshot")
            .flatMap { try? JSONDecoder().decode(WidgetSnapshot.self, from: $0) }
            ?? WidgetSnapshot(
                todaySentenceCount: 0,
                listenedCount: 0,
                dueReviewCount: 0,
                recommendation: "今天留一句給自己",
                companionDisplayName: "語言精靈",
                generatedAt: Date()
            )
        return SelahWidgetEntry(date: Date(), snapshot: snapshot)
    }
}

private struct SelahWidgetEntryView: View {
    let entry: SelahWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🌱 \(entry.snapshot.companionDisplayName)")
                .font(.headline)
            Text(entry.snapshot.recommendation)
                .font(.subheadline)
                .lineLimit(2)
            Spacer()
            HStack {
                Label("\(entry.snapshot.todaySentenceCount)", systemImage: "text.bubble")
                Spacer()
                Label("\(entry.snapshot.dueReviewCount)", systemImage: "checkmark.circle")
            }
            .font(.caption)
        }
        .containerBackground(.background, for: .widget)
    }
}

@main
struct SelahLearningWidget: Widget {
    let kind = "SelahLearningWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SelahWidgetProvider()) { entry in
            SelahWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Selah 今日學習")
        .description("顯示不含個人句子內容的學習進度。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
