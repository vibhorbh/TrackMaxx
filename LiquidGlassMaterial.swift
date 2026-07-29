//
//  LiquidGlassMaterial.swift
//  CalorieAI
//
//  The reusable "glass panel" look used by the composer, day header, and
//  any floating chrome: `.ultraThinMaterial` base + a top specular
//  highlight + a hairline inner-stroke gradient, with an optional live
//  distortion while the panel is being dragged.
//

import SwiftUI

struct LiquidGlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = Theme.Radius.lg
    /// Local-space touch point while dragging; nil when at rest.
    var activeTouch: CGPoint?
    /// 0 at rest, eases up while dragging, eases back down on release.
    var distortionIntensity: Double = 0
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Top specular highlight — light catching the top edge of glass.
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.Colors.glassHighlight, .clear],
                                startPoint: .top,
                                endPoint: .init(x: 0.5, y: 0.45)
                            )
                        )
                        .blendMode(.plusLighter)

                    // Hairline inner stroke.
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Theme.Colors.glassStroke, .clear, Theme.Colors.glassStroke.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .modifier(
                ConditionalDistortion(
                    touch: activeTouch,
                    intensity: distortionIntensity,
                    cornerRadius: cornerRadius
                )
            )
    }
}

/// Only wraps content in the (relatively expensive) distortion shader while
/// it's actually needed, so idle glass panels cost nothing extra per frame.
private struct ConditionalDistortion: ViewModifier {
    let touch: CGPoint?
    let intensity: Double
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if let touch, intensity > 0.001 {
            content.liquidGlassDistortion(touch: touch, intensity: intensity)
        } else {
            content
        }
    }
}

#Preview {
    ZStack {
        Theme.backgroundGradient().ignoresSafeArea()
        LiquidGlassPanel {
            Text("Glass panel")
                .font(Theme.Font.body(16))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(Theme.Space.l)
        }
        .padding()
    }
}
