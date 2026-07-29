//
//  Chip.swift
//  CalorieAI
//

import SwiftUI

/// A small pill used for macro values on food cards ("31g protein") and
/// meal-slot labels. One shared component so spacing/type never drifts
/// between call sites.
struct Chip: View {
    var text: String
    var tint: Color = Theme.Colors.textSecondary
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(Theme.Font.microCaption)
            .foregroundStyle(filled ? Theme.Colors.ink : tint)
            .padding(.horizontal, Theme.Space.s)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(filled ? tint : tint.opacity(0.14))
            }
    }
}

#Preview {
    ZStack {
        Theme.backgroundGradient().ignoresSafeArea()
        HStack {
            Chip(text: "610 cal", tint: Theme.Colors.calorieRing, filled: true)
            Chip(text: "38g protein", tint: Theme.Colors.proteinRing)
            Chip(text: "Lunch", tint: Theme.Colors.textSecondary)
        }
    }
}
