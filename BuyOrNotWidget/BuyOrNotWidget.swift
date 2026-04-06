import WidgetKit
import SwiftUI

// MARK: - Shared Data Keys

private let appGroupID  = "group.com.irukasore.app"
private let savedAmountKey  = "widget.savedAmount"
private let stoppedCountKey = "widget.stoppedCount"

// MARK: - Entry

struct IrukaEntry: TimelineEntry {
    let date: Date
    let savedAmount: Int
    let stoppedCount: Int
}

// MARK: - Provider

struct IrukaProvider: TimelineProvider {

    func placeholder(in context: Context) -> IrukaEntry {
        IrukaEntry(date: .now, savedAmount: 12800, stoppedCount: 5)
    }

    func getSnapshot(in context: Context, completion: @escaping (IrukaEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<IrukaEntry>) -> Void) {
        let entry = makeEntry()
        // 1時間ごとに更新（アプリ起動時にも reloadAllTimelines で即時更新される）
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func makeEntry() -> IrukaEntry {
        let defaults = UserDefaults(suiteName: appGroupID)
        let savedAmount  = defaults?.integer(forKey: savedAmountKey)  ?? 0
        let stoppedCount = defaults?.integer(forKey: stoppedCountKey) ?? 0
        return IrukaEntry(date: .now, savedAmount: savedAmount, stoppedCount: stoppedCount)
    }
}

// MARK: - Widget Views

struct BuyOrNotWidgetEntryView: View {
    var entry: IrukaEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: Small

private struct SmallWidgetView: View {
    let entry: IrukaEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🐬")
                .font(.system(size: 28))

            Spacer()

            Text("今月守った金額")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(entry.savedAmount == 0 ? "¥0" : "¥\(entry.savedAmount.formatted())")
                .font(.title2)
                .fontWeight(.black)
                .foregroundColor(Color(hex: "4A90D9"))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text("\(entry.stoppedCount)回 止めた")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }
}

// MARK: Medium

private struct MediumWidgetView: View {
    let entry: IrukaEntry

    var body: some View {
        HStack(spacing: 16) {
            // 左：イルカ
            VStack {
                Text("🐬")
                    .font(.system(size: 44))
                Text("イルカソレ")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 右：数値
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("今月守った金額")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.savedAmount == 0 ? "¥0" : "¥\(entry.savedAmount.formatted())")
                        .font(.title)
                        .fontWeight(.black)
                        .foregroundColor(Color(hex: "4A90D9"))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "2ECC71"))
                    Text("今月 \(entry.stoppedCount)回 の衝動買いを阻止")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(16)
    }
}

// MARK: - Color extension (hex support in widget)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double((int      ) & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Widget Configuration

struct BuyOrNotWidget: Widget {
    let kind = "BuyOrNotWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: IrukaProvider()) { entry in
            BuyOrNotWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("イルカ貯金")
        .description("今月イルカに止めてもらって守った金額を確認できます。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    BuyOrNotWidget()
} timeline: {
    IrukaEntry(date: .now, savedAmount: 12800, stoppedCount: 5)
}

#Preview(as: .systemMedium) {
    BuyOrNotWidget()
} timeline: {
    IrukaEntry(date: .now, savedAmount: 12800, stoppedCount: 5)
}
