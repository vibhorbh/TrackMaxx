//
//  NutritionDatabase.swift
//  CalorieAI
//
//  A small, bundled, offline nutrition database (Resources/nutrition_seed.json,
//  ~150 common foods). This stands in for a real nutrition API — the agent
//  calls `search_nutrition` (see AgentTools.swift) against this rather than
//  the network, so the app works with zero external nutrition-data
//  dependency. Swapping in a live API later (USDA FoodData Central, Nutritionix,
//  Edamam, ...) means implementing this same `NutritionProviding` protocol.
//

import Foundation

protocol NutritionProviding: Sendable {
    /// Best-effort fuzzy search; returns results ordered best-match first.
    func search(_ query: String, limit: Int) -> [NutritionInfo]
    /// Exact lookup by name (used when the agent already knows the canonical
    /// name from a prior search).
    func lookup(exact name: String) -> NutritionInfo?
}

final class NutritionDatabase: NutritionProviding, @unchecked Sendable {
    static let shared = NutritionDatabase()

    private let items: [NutritionInfo]
    private let byLowercaseName: [String: NutritionInfo]

    private init() {
        let loaded = Self.loadSeed()
        self.items = loaded
        var map: [String: NutritionInfo] = [:]
        for item in loaded {
            map[item.name.lowercased()] = item
        }
        self.byLowercaseName = map
    }

    private static func loadSeed() -> [NutritionInfo] {
        guard let url = Bundle.main.url(forResource: "nutrition_seed", withExtension: "json") else {
            assertionFailure("nutrition_seed.json missing from bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([NutritionInfo].self, from: data)
        } catch {
            assertionFailure("Failed to decode nutrition_seed.json: \(error)")
            return []
        }
    }

    func lookup(exact name: String) -> NutritionInfo? {
        byLowercaseName[name.lowercased()]
    }

    func search(_ query: String, limit: Int = 6) -> [NutritionInfo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }

        let queryTokens = Set(trimmed.split(separator: " ").map(String.init))

        let scored: [(NutritionInfo, Double)] = items.compactMap { item in
            let score = matchScore(query: trimmed, queryTokens: queryTokens, item: item)
            return score > 0 ? (item, score) : nil
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    /// Simple, explainable scoring — no external fuzzy-match dependency:
    /// exact name/alias match scores highest, then prefix match, then
    /// substring, then loose token overlap (handles multi-word queries like
    /// "grilled chicken" matching "Chicken Breast (grilled)").
    private func matchScore(query: String, queryTokens: Set<String>, item: NutritionInfo) -> Double {
        let name = item.name.lowercased()
        let aliases = item.aliases.map { $0.lowercased() }
        var best = 0.0

        for candidate in [name] + aliases {
            if candidate == query { best = max(best, 100) }
            else if candidate.hasPrefix(query) || query.hasPrefix(candidate) { best = max(best, 80) }
            else if candidate.contains(query) { best = max(best, 60) }
        }

        if best == 0 {
            let nameTokens = Set(name.split(separator: " ").map(String.init))
            let aliasTokens = Set(aliases.joined(separator: " ").split(separator: " ").map(String.init))
            let overlap = queryTokens.intersection(nameTokens.union(aliasTokens))
            if !overlap.isEmpty {
                best = 20 + Double(overlap.count) * 10
            }
        }

        return best
    }
}
