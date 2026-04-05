import SwiftUI
import SwiftData

// MARK: - HistoryView

struct HistoryView: View {
    @Query(sort: \JudgementHistory.date, order: .reverse) private var histories: [JudgementHistory]
    @Environment(\.modelContext) private var modelContext

    // MARK: Computed

    private var calendar: Calendar { Calendar.current }

    private var currentMonthHistories: [JudgementHistory] {
        histories.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }

    private var currentMonthSaved: Int {
        currentMonthHistories
            .filter { !$0.didBuy }
            .compactMap { $0.savedAmount }
            .reduce(0, +)
    }

    private var currentMonthStoppedCount: Int {
        currentMonthHistories.filter { !$0.didBuy }.count
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if histories.isEmpty {
                    EmptyHistoryView()
                } else {
                    List {
                        // 今月のサマリーカード
                        Section {
                            MonthlySummaryCard(
                                savedAmount: currentMonthSaved,
                                stoppedCount: currentMonthStoppedCount
                            )
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)

                        // 履歴一覧
                        Section {
                            ForEach(histories) { item in
                                HistoryRowView(item: item)
                                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                            }
                            .onDelete(perform: deleteItems)
                        } header: {
                            Text("すべての履歴")
                                .textCase(nil)
                                .font(.subheadline)
                                .foregroundColor(Color(.secondaryLabel))
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("履歴")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: Delete

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(histories[index])
        }
    }
}

// MARK: - Monthly Summary Card

private struct MonthlySummaryCard: View {
    let savedAmount: Int
    let stoppedCount: Int

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    private var formattedAmount: String {
        Self.numberFormatter.string(from: NSNumber(value: savedAmount)) ?? "0"
    }

    private var currentMonthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月"
        f.locale = Locale(identifier: "ja_JP")
        return f.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(currentMonthLabel)
                .font(.caption)
                .foregroundColor(.white.opacity(0.75))

            if savedAmount > 0 {
                VStack(spacing: 4) {
                    Text("¥\(formattedAmount)")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("守った💰")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.9))
                }
                if stoppedCount > 0 {
                    Text("踏みとどまった: \(stoppedCount)回")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 2)
                }
            } else if stoppedCount > 0 {
                VStack(spacing: 4) {
                    Text("\(stoppedCount)回")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("踏みとどまった🐬")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.9))
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.65))
                    Text("まだ今月の判定がありません")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            LinearGradient(
                colors: [Color(hex: "4A90D9"), Color(hex: "2C5F8A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
    }
}

// MARK: - History Row

private struct HistoryRowView: View {
    let item: JudgementHistory

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale(identifier: "ja_JP")
        return f
    }()

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 商品名 + ステータスバッジ
            HStack(alignment: .center) {
                Text(item.productName)
                    .font(.headline)
                    .foregroundColor(Color(.label))
                    .lineLimit(1)
                Spacer()
                StatusBadge(didBuy: item.didBuy)
            }

            // イルカコメント（2行まで）
            Text(item.irukaComment)
                .font(.subheadline)
                .foregroundColor(Color(.secondaryLabel))
                .lineLimit(2)

            // 日時 + 守った金額
            HStack {
                Text(Self.dateFormatter.string(from: item.date))
                    .font(.caption)
                    .foregroundColor(Color(.tertiaryLabel))

                Spacer()

                if let saved = item.savedAmount,
                   let formatted = Self.numberFormatter.string(from: NSNumber(value: saved)) {
                    Text("¥\(formatted) 守った")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "27AE60"))
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let didBuy: Bool

    var body: some View {
        Text(didBuy ? "買った" : "踏みとどまった")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(didBuy ? Color(hex: "E67E22") : Color(hex: "27AE60"))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(
                        didBuy
                            ? Color(hex: "E67E22").opacity(0.12)
                            : Color(hex: "27AE60").opacity(0.12)
                    )
            )
    }
}

// MARK: - Empty State

private struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 64))
                .foregroundColor(Color(.systemGray3))

            VStack(spacing: 6) {
                Text("履歴がありません")
                    .font(.headline)
                    .foregroundColor(Color(.secondaryLabel))
                Text("商品を判定すると\nここに自動で記録されます")
                    .font(.subheadline)
                    .foregroundColor(Color(.tertiaryLabel))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
        .modelContainer(for: JudgementHistory.self, inMemory: true)
}
