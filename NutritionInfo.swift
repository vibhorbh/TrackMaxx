//
//  NutritionInfo.swift
//  CalorieAI
//
//  Plain value type returned by `NutritionDatabase` — not a persisted
//  SwiftData model. A `FoodEntry` copies the numbers it needs out of one of
//  these at log time so later edits to the seed database never retroactively
//  change history.
//

import Foundation

struct NutritionInfo: Codable, Hashable, Sendable, Identifiable {
    var id: String { name.lowercased() }

    var name: String
    /// Human-readable default serving, e.g. "1 medium (118 g)".
    var servingDescription: String
    var calories: Int
    var proteinG: Double
    var carbG: Double
    var fatG: Double
    /// Loose keywords to help fuzzy search surface this entry for related
    /// queries ("pb" → "peanut butter").
    var aliases: [String]

    /// Scale this record's macros by a multiplier of its default serving
    /// (e.g. 1.5 servings, or half).
    func scaled(by multiplier: Double) -> (calories: Int, proteinG: Double, carbG: Double, fatG: Double) {
        (
            Int((Double(calories) * multiplier).rounded()),
            (proteinG * multiplier * 10).rounded() / 10,
            (carbG * multiplier * 10).rounded() / 10,
            (fatG * multiplier * 10).rounded() / 10
        )
    }
}
