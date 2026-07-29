//
//  AppState.swift
//  CalorieAI
//
//  App-wide, non-persisted UI state — currently just a lightweight banner
//  channel any layer can post to without threading a callback through every
//  view. Persisted state (profile, goals, keys) lives in SwiftData/Keychain,
//  not here.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    struct Banner: Identifiable, Equatable {
        let id = UUID()
        var message: String
        var isError: Bool = false
    }

    private(set) var banner: Banner?

    func show(_ message: String, isError: Bool = false) {
        banner = Banner(message: message, isError: isError)
        if isError { HapticsEngine.failure() }
        Task {
            try? await Task.sleep(for: .seconds(3))
            if banner?.message == message { banner = nil }
        }
    }
}
