import Foundation
import WidgetKit

let widgetStatsAppGroupSuiteName = "group.www.exploration-map"
let widgetStatsSnapshotKey = "WidgetStatsSnapshot"
let explorationMapWidgetKind = "ExplorationMapStatsWidget"

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
}

func writeWidgetStatsSnapshot(from store: CountryStore) {
    let snapshot = WidgetStatsSnapshot(
        totalCountries: store.totalCountries,
        visitedCount: store.visitedCount,
        wantToVisitCount: store.wantToVisitCount,
        visitedPercentage: store.visitedPercentage,
        continentStats: store.continentStats.map { stat in
            WidgetStatsSnapshot.ContinentStatEntry(name: stat.name, percentage: stat.percentage)
        }
    )
    guard let data = try? JSONEncoder().encode(snapshot) else { return }
    UserDefaults(suiteName: widgetStatsAppGroupSuiteName)?.set(data, forKey: widgetStatsSnapshotKey)

    #if canImport(WidgetKit)
    WidgetCenter.shared.reloadTimelines(ofKind: explorationMapWidgetKind)
    #endif
}
