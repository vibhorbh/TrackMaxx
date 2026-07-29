//
//  MotionSpring.swift
//  CalorieAI
//
//  Every animation in the app should come from here. Thin wrappers over
//  SwiftUI's built-in spring presets (iOS 17+) plus one hand-tuned "gentle"
//  spring for large, slow surfaces (the zoom transition, the day header).
//  Centralizing this means the whole app moves with one consistent hand.
//

import SwiftUI

enum MotionSpring {

    /// Quick, precise, minimal overshoot. Composer send button, chip taps,
    /// macro ring ticking up.
    static let snappy: Animation = .snappy(duration: 0.32, extraBounce: 0.05)

    /// Playful overshoot. Day-page settle, food card entrance, gesture
    /// release moments — anywhere the UI should feel like it has a little
    /// life in it.
    static let bouncy: Animation = .bouncy(duration: 0.5, extraBounce: 0.12)

    /// Slow, weighty, no overshoot. The thread↔timeline zoom, background
    /// gradient shifts, anything full-screen where overshoot would feel
    /// cheap rather than premium.
    static let gentle: Animation = .interpolatingSpring(mass: 1.1, stiffness: 90, damping: 18)

    /// Smooth, no bounce — for continuous drag-following values (glass
    /// distortion intensity, drag offsets) where a spring's overshoot would
    /// fight the user's finger.
    static let tracking: Animation = .smooth(duration: 0.2)

    /// Haptic-paired micro-interaction for toggle-like state (meal chip
    /// selection, goal ring focus).
    static let tap: Animation = .snappy(duration: 0.22, extraBounce: 0.15)
}

extension AnyTransition {
    /// Used for the food-entry card materializing into the thread: a soft
    /// rise + scale + blur clearing, paired with `photoDevelop` on the image
    /// itself.
    static var materialize: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: MaterializeModifier(progress: 0),
                identity: MaterializeModifier(progress: 1)
            ),
            removal: .opacity.combined(with: .scale(scale: 0.94))
        )
    }
}

private struct MaterializeModifier: ViewModifier {
    let progress: Double
    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .scaleEffect(0.92 + 0.08 * progress)
            .offset(y: (1 - progress) * 14)
            .blur(radius: (1 - progress) * 6)
    }
}
