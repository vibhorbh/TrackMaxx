//
//  FoodEntryCardView.swift
//  CalorieAI
//
//  Inline card the agent's log_food_entry produces in the thread — studio
//  photo + name/quantity + macro chips. This is the same visual unit reused
//  (at a different scale) as `TimelineMealCard`, so a food you logged looks
//  identical whether you're scrolling the conversation or the catalog.
//

import SwiftUI

struct FoodEntryCardView: View {
    var entry: FoodEntry
    var namespace: Namespace.ID

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.m) {
            AsyncFoodImageView(entry: entry)
                .frame(width: 84, height: 84)
                .matchedGeometryEffect(id: entry.id, in: namespace, isSource: true)

            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(entry.name)
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
                Text(entry.quantityDescription)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)

                HStack(spacing: Theme.Space.xs) {
                    Chip(text: "\(entry.calories) cal", tint: Theme.Colors.calorieRing, filled: true)
                    Chip(text: "\(Int(entry.proteinG))g P", tint: Theme.Colors.proteinRing)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Space.m)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.Colors.agentBubble)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.Colors.glassStroke, lineWidth: 1)
        }
        .transition(.materialize)
    }
}
