//
//  MacroRingView.swift
//  CalorieAI
//
//  One big calorie ring + three slim macro rings. Custom-drawn rather than
//  `Gauge`/`ProgressView` so the stroke caps, spacing, and glow are exactly
//  tuned to the rest of the app instead of inheriting system chrome.
//

import SwiftUI

private struct SingleRing: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat
    var trackOpacity: Double = 0.16

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.0025, min(progress, 1.0)))
                .stroke(
                    color.gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(progress > 0 ? 0.55 : 0), radius: 6)
            // Overshoot cap — a soft second pass past 100% so hitting/exceeding
            // a goal still reads as "full," not clipped.
            if progress > 1.0 {
                Circle()
                    .trim(from: 0, to: max(0.0025, min(progress - 1.0, 1.0)))
                    .stroke(
                        color.opacity(0.55),
                        style: StrokeStyle(lineWidth: lineWidth * 0.45, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
        .animation(MotionSpring.gentle, value: progress)
    }
}

struct MacroRingView: View {
    let day: Day

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.l) {
            ZStack {
                SingleRing(progress: day.calorieProgress, color: Theme.Colors.calorieRing, lineWidth: 9)
                    .frame(width: 74, height: 74)
                VStack(spacing: 0) {
                    Text("\(day.totalCalories)")
                        .font(Theme.Font.ringValue)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .contentTransition(.numericText())
                    Text("of \(day.calorieGoal)")
                        .font(Theme.Font.microCaption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Space.s) {
                macroRow(label: "Protein", value: day.totalProteinG, goal: day.proteinGoal, progress: day.proteinProgress, color: Theme.Colors.proteinRing)
                macroRow(label: "Carbs", value: day.totalCarbG, goal: day.carbGoal, progress: day.carbProgress, color: Theme.Colors.carbRing)
                macroRow(label: "Fat", value: day.totalFatG, goal: day.fatGoal, progress: day.fatProgress, color: Theme.Colors.fatRing)
            }
        }
        .padding(.vertical, Theme.Space.s)
    }

    private func macroRow(label: String, value: Double, goal: Int, progress: Double, color: Color) -> some View {
        HStack(spacing: Theme.Space.s) {
            SingleRing(progress: progress, color: color, lineWidth: 4)
                .frame(width: 18, height: 18)
            Text(label)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 52, alignment: .leading)
            Text("\(Int(value))/\(goal)g")
                .font(Theme.Font.caption.weight(.medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.numericText())
        }
    }
}

#Preview {
    ZStack {
        Theme.backgroundGradient().ignoresSafeArea()
        LiquidGlassPanel {
            MacroRingView(day: Day(date: .now, goals: .defaultGoals))
                .padding(Theme.Space.l)
        }
        .padding()
    }
}
