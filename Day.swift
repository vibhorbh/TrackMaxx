//
//  Day.swift
//  CalorieAI
//
//  One `Day` = one conversation thread + the food entries the agent logged
//  during it. `dateKey` (yyyy-MM-dd, in the user's current calendar/timezone
//  at creation time) is the stable identity used for paging and lookup.
//

import Foundation
import SwiftData

@Model
final class Day {
    @Attribute(.unique) var dateKey: String
    var date: Date
    var calorieGoal: Int
    var proteinGoal: Int
    var carbGoal: Int
    var fatGoal: Int

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.day)
    var messages: [ChatMessage] = []

    @Relationship(deleteRule: .cascade, inverse: \FoodEntry.day)
    var entries: [FoodEntry] = []

    init(date: Date, goals: MacroGoals) {
        self.date = Calendar.current.startOfDay(for: date)
        self.dateKey = Day.key(for: date)
        self.calorieGoal = goals.calories
        self.proteinGoal = goals.proteinG
        self.carbGoal = goals.carbG
        self.fatGoal = goals.fatG
    }

    static func key(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    // MARK: - Derived totals

    var totalCalories: Int { entries.reduce(0) { $0 + $1.calories } }
    var totalProteinG: Double { entries.reduce(0) { $0 + $1.proteinG } }
    var totalCarbG: Double { entries.reduce(0) { $0 + $1.carbG } }
    var totalFatG: Double { entries.reduce(0) { $0 + $1.fatG } }

    var calorieProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(Double(totalCalories) / Double(calorieGoal), 1.4)
    }
    var proteinProgress: Double {
        guard proteinGoal > 0 else { return 0 }
        return min(totalProteinG / Double(proteinGoal), 1.4)
    }
    var carbProgress: Double {
        guard carbGoal > 0 else { return 0 }
        return min(totalCarbG / Double(carbGoal), 1.4)
    }
    var fatProgress: Double {
        guard fatGoal > 0 else { return 0 }
        return min(totalFatG / Double(fatGoal), 1.4)
    }

    var entriesByMeal: [(slot: MealSlot, entries: [FoodEntry])] {
        Dictionary(grouping: entries, by: \.mealSlot)
            .sorted { $0.key.sortOrder < $1.key.sortOrder }
            .map { (slot: $0.key, entries: $0.value.sorted { $0.createdAt < $1.createdAt }) }
    }

    var sortedMessages: [ChatMessage] {
        messages.sorted { $0.sequence < $1.sequence }
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var displayTitle: String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE, MMM d")
        return formatter.string(from: date)
    }
}
