//
//  HapticsEngine.swift
//  CalorieAI
//
//  One place for every haptic in the app, named by the moment they
//  accompany rather than by raw feedback style — makes call sites read as
//  intent ("HapticsEngine.dayCrossed()") instead of implementation detail.
//

import UIKit

enum HapticsEngine {
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    static func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        rigidImpact.prepare()
        selection.prepare()
        notification.prepare()
    }

    /// Crossing from one day to the next while paging the thread.
    static func dayCrossed() { lightImpact.impactOccurred(intensity: 0.7) }

    /// Pinch gesture commits to the zoom transition (thread → timeline or
    /// back).
    static func zoomCommitted() { rigidImpact.impactOccurred(intensity: 0.85) }

    /// A food entry finishes logging and its card materializes.
    static func foodLogged() { notification.notificationOccurred(.success) }

    /// The generated photo finishes developing.
    static func photoDeveloped() { lightImpact.impactOccurred(intensity: 0.5) }

    /// Composer send button tap.
    static func sent() { mediumImpact.impactOccurred(intensity: 0.6) }

    /// Meal-slot chip / timeline card selection.
    static func selected() { selection.selectionChanged() }

    /// Something went wrong (failed generation, network error).
    static func failure() { notification.notificationOccurred(.error) }
}
