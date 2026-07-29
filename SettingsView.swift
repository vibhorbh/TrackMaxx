//
//  SettingsView.swift
//  CalorieAI
//
//  Reachable any time from the gear affordance in `RootView` — the same
//  goals/keys fields as onboarding, for when a key needs rotating or goals
//  need adjusting later.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var claudeKey = KeychainStore.apiKey(for: .anthropic) ?? ""
    @State private var openAIKey = KeychainStore.apiKey(for: .openAI) ?? ""
    @State private var geminiKey = KeychainStore.apiKey(for: .gemini) ?? ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $profile.displayName)
                }

                Section("Daily goals") {
                    Stepper("Calories: \(profile.calorieGoal)", value: $profile.calorieGoal, in: 1000...5000, step: 50)
                    Stepper("Protein: \(profile.proteinGoal) g", value: $profile.proteinGoal, in: 20...300, step: 5)
                    Stepper("Carbs: \(profile.carbGoal) g", value: $profile.carbGoal, in: 20...500, step: 5)
                    Stepper("Fat: \(profile.fatGoal) g", value: $profile.fatGoal, in: 10...200, step: 5)
                }

                Section("Claude (conversation)") {
                    SecureField("API key", text: $claudeKey)
                }

                Section("Food photos") {
                    Picker("Model", selection: $profile.imageProvider) {
                        ForEach(ImageProviderKind.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    if profile.imageProvider == .openAI {
                        SecureField("OpenAI API key", text: $openAIKey)
                    } else {
                        SecureField("Gemini API key", text: $geminiKey)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        KeychainStore.setAPIKey(claudeKey, for: .anthropic)
                        KeychainStore.setAPIKey(openAIKey, for: .openAI)
                        KeychainStore.setAPIKey(geminiKey, for: .gemini)
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
