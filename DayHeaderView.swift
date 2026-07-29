//
//  DayHeaderView.swift
//  CalorieAI
//
//  Sticky glass header for a thread: date title + macro rings. Reacts to
//  the day-pager drag (see `DayPagerView`) with a touch of liquid-glass
//  distortion so the whole thing feels tactile while swiping between days,
//  not just the page underneath it.
//

import SwiftUI

struct DayHeaderView: View {
    let day: Day
    /// 0 at rest; driven by `DayPagerView` while the user is actively
    /// dragging between days.
    var dragDistortionIntensity: Double = 0
    var dragTouchPoint: CGPoint = .zero

    var body: some View {
        LiquidGlassPanel(
            cornerRadius: Theme.Radius.xl,
            activeTouch: dragTouchPoint,
            distortionIntensity: dragDistortionIntensity
        ) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.displayTitle)
                            .font(Theme.Font.dayTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        if !day.isToday {
                            Text(day.date, format: .dateTime.year())
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                    }
                    Spacer()
                }
                MacroRingView(day: day)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.m)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.s)
    }
}

#Preview {
    ZStack {
        Theme.backgroundGradient().ignoresSafeArea()
        DayHeaderView(day: Day(date: .now, goals: .defaultGoals))
    }
}
