//
//  TimelineMealCard.swift
//  CalorieAI
//
//  One food photo in the catalog — the studio image with a name/calorie
//  caption scrimmed over the bottom, magazine-cover style. Height varies
//  per entry (a stable hash, not random-per-render) so the masonry grid
//  has rhythm instead of a rigid checkerboard.
//

import SwiftUI

struct TimelineMealCard: View {
    var entry: FoodEntry
    var namespace: Namespace.ID
    var onSelect: (CGPoint) -> Void

    @State private var globalCenter: CGPoint = .zero

    private var aspectRatio: Double {
        // Deterministic pseudo-variety in 0.8...1.4 (height / width).
        let bucket = abs(entry.id.hashValue) % 100
        return 0.8 + Double(bucket) / 100.0 * 0.6
    }

    var body: some View {
        Button {
            HapticsEngine.selected()
            onSelect(globalCenter)
        } label: {
            ZStack(alignment: .bottomLeading) {
                AsyncFoodImageView(entry: entry, cornerRadius: Theme.Radius.md)
                    .matchedGeometryEffect(id: entry.id, in: namespace, isSource: false)

                LinearGradient(
                    colors: [.clear, .clear, Color.black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(Theme.Font.cardTitle)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("\(entry.calories) cal")
                        .font(Theme.Font.microCaption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(Theme.Space.s)
            }
        }
        .buttonStyle(TimelineCardButtonStyle())
        .aspectRatio(1 / aspectRatio, contentMode: .fit)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { globalCenter = CGPoint(x: proxy.frame(in: .global).midX, y: proxy.frame(in: .global).midY) }
                    .onChange(of: proxy.frame(in: .global)) { _, frame in
                        globalCenter = CGPoint(x: frame.midX, y: frame.midY)
                    }
            }
        }
    }
}

private struct TimelineCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(MotionSpring.snappy, value: configuration.isPressed)
    }
}
