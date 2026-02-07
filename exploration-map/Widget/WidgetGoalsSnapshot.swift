import Foundation
import WidgetKit

let widgetGoalsSnapshotKey = "WidgetGoalsSnapshot"
let explorationMapGoalsWidgetKind = "ExplorationMapGoalsWidget"

struct WidgetGoalEntry: Codable {
    var label: String
    var progressDescription: String
    var isComplete: Bool
    var targetDate: TimeInterval?
    var customTitle: String?
}

struct WidgetGoalsSnapshot: Codable {
    var goals: [WidgetGoalEntry]
}

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
