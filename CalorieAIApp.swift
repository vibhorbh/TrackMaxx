//
//  CalorieAIApp.swift
//  CalorieAI
//

import SwiftUI
import SwiftData

@main
struct CalorieAIApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AppRootSwitch()
                .environment(appState)
                .preferredColorScheme(.dark)
                .onAppear { HapticsEngine.prepareAll() }
        }
        .modelContainer(PersistenceController.shared)
    }
}

/// Shows onboarding until a profile marks itself complete, then the real
/// app. Kept as its own tiny view so `CalorieAIApp` stays a plain scene
/// definition.
private struct AppRootSwitch: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if profile.didCompleteOnboarding {
                RootView()
            } else {
                OnboardingView(profile: profile)
            }
        }
        .animation(MotionSpring.gentle, value: profile.didCompleteOnboarding)
    }

    private var profile: UserProfile {
        // Reading `profiles` here (rather than only inside the fallback)
        // keeps this view subscribed to profile changes via @Query.
        if let existing = profiles.first { return existing }
        return PersistenceController.currentProfile(in: modelContext)
    }
}
