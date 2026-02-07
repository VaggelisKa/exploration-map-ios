//
//  WidgetGoalsSnapshot.swift
//  exploration-map
//
//  Snapshot and writer for the goals widget. The widget extension
//  reads from the same App Group key.
//

import Foundation
import WidgetKit

/// UserDefaults key for the encoded goals snapshot.
let widgetGoalsSnapshotKey = "WidgetGoalsSnapshot"

/// Widget kind for reloadTimelines(ofKind:).
let explorationMapGoalsWidgetKind = "ExplorationMapGoalsWidget"

/// Single goal entry for the widget (display-only).
struct WidgetGoalEntry: Codable {
    var label: String
    var progressDescription: String
    var isComplete: Bool
    var targetDate: TimeInterval?
    var customTitle: String?
}

/// Snapshot of goals with progress, written by the app and read by the widget.
struct WidgetGoalsSnapshot: Codable {
    var goals: [WidgetGoalEntry]
}

/// Builds and writes the goals snapshot to the App Group and reloads the goals widget.
func writeWidgetGoalsSnapshot(countryStore: CountryStore, goalStore: GoalStore) {
    let entries = goalStore.goals.map { goal -> WidgetGoalEntry in
        let (progressDescription, isComplete): (String, Bool) = {
            switch goal.kind {
            case .countries(let target):
                let current = countryStore.visitedCount
                return ("\(current)/\(target)", current >= target)
            case .percentage(let target):
                let current = countryStore.visitedPercentage * 100
                return (String(format: "%.1f%%/%.1f%%", current, target), current >= target)
            case .specificCountries(let ids):
                let visited = ids.filter { countryStore.status(for: $0) == .visited }.count
                return ("\(visited)/\(ids.count)", visited >= ids.count)
            }
        }()
        return WidgetGoalEntry(
            label: goal.kind.label,
            progressDescription: progressDescription,
            isComplete: isComplete,
            targetDate: goal.targetDate?.timeIntervalSince1970,
            customTitle: goal.title
        )
    }
    let snapshot = WidgetGoalsSnapshot(goals: entries)
    guard let data = try? JSONEncoder().encode(snapshot) else { return }
    UserDefaults(suiteName: widgetStatsAppGroupSuiteName)?.set(data, forKey: widgetGoalsSnapshotKey)

    #if canImport(WidgetKit)
    WidgetCenter.shared.reloadTimelines(ofKind: explorationMapGoalsWidgetKind)
    #endif
}
