//
//  TimelineSectionHeader.swift
//  CalorieAI
//

import SwiftUI

struct TimelineSectionHeader: View {
    let day: Day

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(day.displayTitle)
                .font(Theme.Font.display(20, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Text("\(day.totalCalories) cal")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding(.horizontal, Theme.Space.xs)
        .padding(.top, Theme.Space.m)
        .padding(.bottom, Theme.Space.xs)
        .background(Theme.backgroundGradient(for: day.date).opacity(0.001)) // keeps header hit-testable/readable over content when pinned
    }
}
