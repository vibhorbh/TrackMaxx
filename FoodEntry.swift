//
//  FoodEntry.swift
//  CalorieAI
//

import Foundation
import SwiftData

enum MealSlot: String, Codable, CaseIterable, Sendable {
    case breakfast, lunch, dinner, snack

    var label: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snack"
        }
    }

    var sortOrder: Int {
        switch self {
        case .breakfast: 0
        case .lunch: 1
        case .dinner: 2
        case .snack: 3
        }
    }

    /// Rough default bucket based on time of day, used when the agent logs
    /// something without an explicit meal slot.
    static func inferred(from date: Date) -> MealSlot {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 4..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<21: return .dinner
        default: return .snack
        }
    }
}

enum ImageGenerationState: String, Codable, Sendable {
    case pending      // just logged, image request not sent yet
    case generating   // request in flight
    case ready        // localImagePath is valid
    case failed       // will show a stylized fallback glyph instead
}

@Model
final class FoodEntry {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantityDescription: String
    var mealSlotRaw: String
    var calories: Int
    var proteinG: Double
    var carbG: Double
    var fatG: Double
    var createdAt: Date
    /// Normalized cache key ("grilled-chicken-bowl") used to dedupe image
    /// generation across repeated foods.
    var imageSignature: String
    var imageStateRaw: String
    var localImagePath: String?
    /// The `ChatMessage.id` this entry was created from, so the timeline can
    /// jump back to the exact point in the conversation.
    var sourceMessageID: UUID?

    var day: Day?

    var mealSlot: MealSlot {
        get { MealSlot(rawValue: mealSlotRaw) ?? .snack }
        set { mealSlotRaw = newValue.rawValue }
    }

    var imageState: ImageGenerationState {
        get { ImageGenerationState(rawValue: imageStateRaw) ?? .pending }
        set { imageStateRaw = newValue.rawValue }
    }

    init(
        name: String,
        quantityDescription: String,
        mealSlot: MealSlot,
        calories: Int,
        proteinG: Double,
        carbG: Double,
        fatG: Double,
        imageSignature: String,
        createdAt: Date = .now,
        sourceMessageID: UUID? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.quantityDescription = quantityDescription
        self.mealSlotRaw = mealSlot.rawValue
        self.calories = calories
        self.proteinG = proteinG
        self.carbG = carbG
        self.fatG = fatG
        self.imageSignature = imageSignature
        self.imageStateRaw = ImageGenerationState.pending.rawValue
        self.createdAt = createdAt
        self.sourceMessageID = sourceMessageID
    }

    /// Normalizes a free-text food name into a stable cache/lookup key —
    /// lowercased, punctuation stripped, whitespace collapsed to hyphens.
    static func signature(for name: String) -> String {
        let lowered = name.lowercased()
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let cleaned = lowered.unicodeScalars.filter { allowed.contains($0) }
        let collapsed = String(String.UnicodeScalarView(cleaned))
            .split(separator: " ")
            .joined(separator: "-")
        return collapsed.isEmpty ? "food" : collapsed
    }
}
