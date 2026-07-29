//
//  MacroGoals.swift
//  CalorieAI
//

import Foundation

/// A day's nutrition targets. Snapshotted onto each `Day` at creation time so
/// changing your goals tomorrow doesn't rewrite history.
struct MacroGoals: Codable, Hashable, Sendable {
    var calories: Int
    var proteinG: Int
    var carbG: Int
    var fatG: Int

    static let defaultGoals = MacroGoals(calories: 2100, proteinG: 130, carbG: 220, fatG: 70)

    /// Quick Mifflin-St Jeor + activity-multiplier estimate, used by the
    /// agent's `estimate_goals` tool during onboarding. Intentionally
    /// simple — this is a starting point the user (and the agent, in later
    /// conversation) can refine, not a clinical calculation.
    static func estimate(
        sex: Sex,
        ageYears: Int,
        heightCm: Double,
        weightKg: Double,
        activity: ActivityLevel,
        goal: WeightGoal
    ) -> MacroGoals {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(ageYears) + (sex == .male ? 5 : -161)
        var calories = base * activity.multiplier
        calories += goal.calorieAdjustment
        let calorieInt = Int(calories.rounded())

        // 30% protein / 40% carb / 30% fat split, protein biased slightly
        // up for a body-recomposition-friendly default.
        let proteinG = Int((calories * 0.30 / 4).rounded())
        let carbG = Int((calories * 0.40 / 4).rounded())
        let fatG = Int((calories * 0.30 / 9).rounded())
        return MacroGoals(calories: calorieInt, proteinG: proteinG, carbG: carbG, fatG: fatG)
    }

    enum Sex: String, Codable, CaseIterable { case male, female }

    enum ActivityLevel: String, Codable, CaseIterable {
        case sedentary, light, moderate, active, veryActive

        var multiplier: Double {
            switch self {
            case .sedentary: 1.2
            case .light: 1.375
            case .moderate: 1.55
            case .active: 1.725
            case .veryActive: 1.9
            }
        }

        var label: String {
            switch self {
            case .sedentary: "Mostly sitting"
            case .light: "Light activity"
            case .moderate: "Moderately active"
            case .active: "Active"
            case .veryActive: "Very active"
            }
        }
    }

    enum WeightGoal: String, Codable, CaseIterable {
        case lose, maintain, gain

        var calorieAdjustment: Double {
            switch self {
            case .lose: -450
            case .maintain: 0
            case .gain: 350
            }
        }

        var label: String {
            switch self {
            case .lose: "Lose weight"
            case .maintain: "Maintain"
            case .gain: "Gain weight"
            }
        }
    }
}
