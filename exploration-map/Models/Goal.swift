import Foundation
import Observation

enum GoalKind: Equatable {
    case countries(Int)
    case percentage(Double)
    case specificCountries([String]) // country IDs

    var label: String {
        switch self {
        case .countries(let n): return "Visit \(n) countries"
        case .percentage(let p): return "Reach \(String(format: "%.1f", p))% of the world"
        case .specificCountries(let ids): return "Visit \(ids.count) specific countries"
        }
    }
}

extension GoalKind: Codable {
    private enum CodingKeys: String, CodingKey { case countries, percentage, specificCountries }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let n = try c.decodeIfPresent(Int.self, forKey: .countries) {
            self = .countries(n)
            return
        }
        if let p = try c.decodeIfPresent(Double.self, forKey: .percentage) {
            self = .percentage(p)
            return
        }
        if let ids = try c.decodeIfPresent([String].self, forKey: .specificCountries) {
            self = .specificCountries(ids)
            return
        }
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: c.codingPath, debugDescription: "Invalid GoalKind"))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .countries(let n): try c.encode(n, forKey: .countries)
        case .percentage(let p): try c.encode(p, forKey: .percentage)
        case .specificCountries(let ids): try c.encode(ids, forKey: .specificCountries)
        }
    }
}

struct Goal: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: GoalKind
    var title: String?
    var targetDate: Date?
    var createdAt: Date

    init(id: UUID = UUID(), kind: GoalKind, title: String? = nil, targetDate: Date? = nil, createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.title = title
        self.targetDate = targetDate
        self.createdAt = createdAt
    }
}

private let goalsDefaultsKey = "ExplorationMapGoals"

@Observable
@MainActor
final class GoalStore {
    var goals: [Goal] = []

    init() {
        load()
    }

    func add(_ goal: Goal) {
        goals.append(goal)
        goals.sort { $0.createdAt > $1.createdAt }
        save()
    }

    func remove(_ goal: Goal) {
        goals.removeAll { $0.id == goal.id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: goalsDefaultsKey),
              let decoded = try? JSONDecoder().decode([Goal].self, from: data) else {
            goals = []
            return
        }
        goals = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(goals) else { return }
        UserDefaults.standard.set(data, forKey: goalsDefaultsKey)
    }
}
