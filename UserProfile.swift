//
//  UserProfile.swift
//  CalorieAI
//
//  Singleton-ish settings record (there is exactly one, fetched by
//  `PersistenceController.currentProfile`). API keys are NOT stored here —
//  they live only in Keychain (`KeychainStore`) — this just remembers which
//  provider is selected and whether onboarding finished.
//

import Foundation
import SwiftData

enum ImageProviderKind: String, Codable, CaseIterable, Sendable {
    case openAI
    case gemini

    var label: String {
        switch self {
        case .openAI: "OpenAI (gpt-image-1)"
        case .gemini: "Gemini 2.5 Flash Image"
        }
    }
}

@Model
final class UserProfile {
    var displayName: String
    var calorieGoal: Int
    var proteinGoal: Int
    var carbGoal: Int
    var fatGoal: Int
    var imageProviderRaw: String
    var didCompleteOnboarding: Bool
    var createdAt: Date

    var imageProvider: ImageProviderKind {
        get { ImageProviderKind(rawValue: imageProviderRaw) ?? .openAI }
        set { imageProviderRaw = newValue.rawValue }
    }

    var goals: MacroGoals {
        get { MacroGoals(calories: calorieGoal, proteinG: proteinGoal, carbG: carbGoal, fatG: fatGoal) }
        set {
            calorieGoal = newValue.calories
            proteinGoal = newValue.proteinG
            carbGoal = newValue.carbG
            fatGoal = newValue.fatG
        }
    }

    init(
        displayName: String = "",
        goals: MacroGoals = .defaultGoals,
        imageProvider: ImageProviderKind = .openAI,
        didCompleteOnboarding: Bool = false
    ) {
        self.displayName = displayName
        self.calorieGoal = goals.calories
        self.proteinGoal = goals.proteinG
        self.carbGoal = goals.carbG
        self.fatGoal = goals.fatG
        self.imageProviderRaw = imageProvider.rawValue
        self.didCompleteOnboarding = didCompleteOnboarding
        self.createdAt = .now
    }
}
