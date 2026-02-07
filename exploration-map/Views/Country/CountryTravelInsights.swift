import Foundation
import FoundationModels

@Generable(description: "Travel insights for a destination: best time to visit, how to get there, and what to know")
struct TravelInsights: Codable {
    @Guide(description: "Best time of year to visit: seasons and weather in 2–4 concise sentences")
    var bestTimeToVisit: String

    @Guide(description: "How to get there: main flight hubs, routes, and practical tips in 2–4 sentences")
    var gettingThere: String

    @Guide(description: "What to know: recent context, travel tips, or things travelers should know in 2–4 sentences")
    var whatToKnow: String
}

enum TravelInsightsService: Sendable {
    private static let model = SystemLanguageModel.default
    private static let cacheKey = "TravelInsightsByCountryId"

    static var isAvailable: Bool {
        switch model.availability {
        case .available:
            return true
        case .unavailable:
            return false
        }
    }

    static func cachedInsights(for countryId: String) -> TravelInsights? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([String: TravelInsights].self, from: data),
              let insights = decoded[countryId] else { return nil }
        return insights
    }

    static func saveInsights(_ insights: TravelInsights, for countryId: String) {
        var decoded = (try? UserDefaults.standard.data(forKey: cacheKey).flatMap { try? JSONDecoder().decode([String: TravelInsights].self, from: $0) }) ?? [:]
        decoded[countryId] = insights
        guard let data = try? JSONEncoder().encode(decoded) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    static func generateInsights(for countryName: String) async throws -> TravelInsights {
        let instructions = """
        You are a concise travel assistant. Respond only with the requested structured travel insights for the given country. \
        Be factual and helpful. Keep each section to 2–4 sentences.
        """
        let session = LanguageModelSession(instructions: instructions)
        let prompt = """
        Provide travel insights for \(countryName). \
        Include: best time to visit (seasons, weather), how to get there (flight hubs, tips), and what to know (recent context or travel tips).
        """
        let response = try await session.respond(
            to: prompt,
            generating: TravelInsights.self
        )
        return response.content
    }
}
