//
//  StreamingTextView.swift
//  CalorieAI
//
//  Text that re-triggers the `shimmerReveal` shader every time new content
//  streams in, so a growing agent reply reads as "alive" rather than a
//  plain typewriter appending characters.
//

import SwiftUI

struct StreamingTextView: View {
    var text: String
    var isStreaming: Bool

    @State private var revealProgress: Double = 1

    var body: some View {
        Text(text.isEmpty ? " " : text)
            .font(Theme.Font.bubble)
            .foregroundStyle(Theme.Colors.textPrimary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .shimmerReveal(progress: revealProgress)
            .onChange(of: text) { _, _ in
                guard isStreaming else { return }
                revealProgress = 0
                withAnimation(MotionSpring.snappy) { revealProgress = 1 }
            }
    }
}
