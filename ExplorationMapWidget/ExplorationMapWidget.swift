import SwiftUI
import WidgetKit

// MARK: - Snapshot (must match main app’s WidgetStatsSnapshot encoding)

private let appGroupSuiteName = "group.www.exploration-map"
private let snapshotKey = "WidgetStatsSnapshot"

struct WidgetStatsSnapshot: Codable {
    var totalCountries: Int
    var visitedCount: Int
    var wantToVisitCount: Int
    var visitedPercentage: Double
    var continentStats: [ContinentStatEntry]

    struct ContinentStatEntry: Codable {
        var name: String
        var percentage: Double
    }

    static var placeholder: WidgetStatsSnapshot {
        WidgetStatsSnapshot(
            totalCountries: 0,
            visitedCount: 0,
            wantToVisitCount: 0,
            visitedPercentage: 0,
            continentStats: []
        )
    }

    static func load() -> WidgetStatsSnapshot {
        guard let data = UserDefaults(suiteName: appGroupSuiteName)?.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetStatsSnapshot.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }
}

// MARK: - Goals snapshot (must match main app’s WidgetGoalsSnapshot encoding)

private let goalsSnapshotKey = "WidgetGoalsSnapshot"

struct WidgetGoalsSnapshot: Codable {
    var goals: [WidgetGoalEntry]
    struct WidgetGoalEntry: Codable {
        var label: String
        var progressDescription: String
        var isComplete: Bool
        var targetDate: TimeInterval?
        var customTitle: String?
    }
    static var placeholder: WidgetGoalsSnapshot { WidgetGoalsSnapshot(goals: []) }
    static func load() -> WidgetGoalsSnapshot {
        guard let data = UserDefaults(suiteName: appGroupSuiteName)?.data(forKey: goalsSnapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetGoalsSnapshot.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }
}

// MARK: - Timeline

struct StatsEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetStatsSnapshot
}

struct StatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        let snapshot = WidgetStatsSnapshot.load()
        completion(StatsEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        let snapshot = WidgetStatsSnapshot.load()
        let entry = StatsEntry(date: Date(), snapshot: snapshot)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Goals timeline

struct GoalsEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetGoalsSnapshot
}

struct GoalsProvider: TimelineProvider {
    func placeholder(in context: Context) -> GoalsEntry {
        GoalsEntry(date: Date(), snapshot: .placeholder)
    }
    func getSnapshot(in context: Context, completion: @escaping (GoalsEntry) -> Void) {
        completion(GoalsEntry(date: Date(), snapshot: WidgetGoalsSnapshot.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GoalsEntry>) -> Void) {
        let snapshot = WidgetGoalsSnapshot.load()
        let entry = GoalsEntry(date: Date(), snapshot: snapshot)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Views

struct StatsWidgetSmallView: View {
    var entry: StatsEntry
    var body: some View {
        let s = entry.snapshot
        VStack(alignment: .leading, spacing: 4) {
            Text("Exploration map")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Text("\(s.visitedCount) visited · \(String(format: "%.1f%%", s.visitedPercentage * 100)) of world")
                .font(.subheadline)
                .fontWeight(.medium)
            if s.wantToVisitCount > 0 {
                Text("\(s.wantToVisitCount) want to visit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct StatsWidgetMediumView: View {
    var entry: StatsEntry
    var body: some View {
        let s = entry.snapshot
        let top2 = Array(s.continentStats.prefix(2).filter { $0.percentage > 0 })
        let otherPercentage = s.continentStats.dropFirst(2).reduce(0.0) { $0 + $1.percentage }
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Stats")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            VStack(spacing: 0) {
                StatRowView(title: "Visited or lived", value: "\(s.visitedCount)")
                StatDividerView()
                StatRowView(
                    title: "World visited or lived",
                    value: String(format: "%.1f%%", s.visitedPercentage * 100.0)
                )
                ForEach(Array(top2.enumerated()), id: \.offset) { _, stat in
                    StatDividerView()
                    StatRowView(
                        title: stat.name,
                        value: String(format: "%.1f%%", stat.percentage * 100.0)
                    )
                }
                if otherPercentage > 0.0 {
                    StatDividerView()
                    StatRowView(
                        title: "Other",
                        value: String(format: "%.1f%%", otherPercentage * 100.0)
                    )
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct StatDividerView: View {
    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.3))
            .frame(height: 1)
    }
}

private struct StatRowView: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.8))
            Spacer(minLength: 8)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Widget

struct ExplorationMapStatsWidget: Widget {
    let kind: String = "ExplorationMapStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsProvider()) { entry in
            if #available(iOS 17.0, *) {
                StatsWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                StatsWidgetView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Exploration Stats")
        .description("Your visited countries and world percentage.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct StatsWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: StatsEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                StatsWidgetSmallView(entry: entry)
            case .systemMedium:
                StatsWidgetMediumView(entry: entry)
            default:
                StatsWidgetSmallView(entry: entry)
            }
        }
        .widgetURL(URL(string: "exploration-map://"))
    }
}

// MARK: - Goals widget views

struct GoalsWidgetSmallView: View {
    var entry: GoalsEntry
    var body: some View {
        let goals = entry.snapshot.goals
        VStack(alignment: .leading, spacing: 4) {
            Text("Goals")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            if goals.isEmpty {
                Text("No goals yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let g = goals[0]
                Text(g.customTitle ?? g.label)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(g.progressDescription)
                    .font(.caption)
                    .foregroundStyle(g.isComplete ? .green : .secondary)
                if goals.count > 1 {
                    Text("+\(goals.count - 1) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct GoalsWidgetMediumView: View {
    var entry: GoalsEntry
    var body: some View {
        let goals = entry.snapshot.goals
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Goals")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            if goals.isEmpty {
                Text("No goals yet. Open the app to add one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(goals.prefix(4).enumerated()), id: \.offset) { index, g in
                        HStack {
                            Image(systemName: g.isComplete ? "checkmark.circle.fill" : "circle")
                                .font(.subheadline)
                                .foregroundStyle(g.isComplete ? .green : .secondary)
                            Text(g.customTitle ?? g.label)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(g.progressDescription)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(g.isComplete ? .green : .secondary)
                        }
                        .padding(.vertical, 4)
                        if index < min(3, goals.count - 1) {
                            Rectangle()
                                .fill(.primary.opacity(0.2))
                                .frame(height: 1)
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct GoalsWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: GoalsEntry
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                GoalsWidgetSmallView(entry: entry)
            case .systemMedium:
                GoalsWidgetMediumView(entry: entry)
            default:
                GoalsWidgetSmallView(entry: entry)
            }
        }
        .widgetURL(URL(string: "exploration-map://"))
    }
}

struct ExplorationMapGoalsWidget: Widget {
    let kind: String = "ExplorationMapGoalsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GoalsProvider()) { entry in
            if #available(iOS 17.0, *) {
                GoalsWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                GoalsWidgetView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Goals")
        .description("Your exploration goals and progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Bundle

@main
struct ExplorationMapWidgetBundle: WidgetBundle {
    var body: some Widget {
        ExplorationMapStatsWidget()
        ExplorationMapGoalsWidget()
    }
}
