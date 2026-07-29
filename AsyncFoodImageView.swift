//
//  AsyncFoodImageView.swift
//  CalorieAI
//
//  Renders a `FoodEntry`'s generated photo through its full lifecycle:
//  shimmering skeleton while pending/generating, a one-time `photoDevelop`
//  reveal the instant it's ready, or a quiet fallback glyph if generation
//  failed. Observes the entry directly (SwiftData models are Observable),
//  so it updates the moment `AgentTools` flips `imageState`.
//

import SwiftUI

struct AsyncFoodImageView: View {
    var entry: FoodEntry
    var cornerRadius: CGFloat = Theme.Radius.md

    @State private var developProgress: Double = 0
    @State private var loadedImage: UIImage?
    @State private var loadedPath: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.Colors.paperSoft.opacity(0.08))

            switch entry.imageState {
            case .pending, .generating:
                shimmerSkeleton
            case .ready:
                if let loadedImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFill()
                        .photoDevelop(progress: developProgress)
                } else {
                    shimmerSkeleton
                }
            case .failed:
                fallbackGlyph
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: entry.localImagePath) { await loadIfNeeded() }
    }

    private func loadIfNeeded() async {
        guard entry.imageState == .ready, let path = entry.localImagePath, path != loadedPath else { return }
        guard let data = FileManager.default.contents(atPath: path), let image = UIImage(data: data) else { return }
        loadedPath = path
        loadedImage = image
        developProgress = 0
        withAnimation(MotionSpring.gentle) { developProgress = 1 }
    }

    private var shimmerSkeleton: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = (sin(t * 1.6) + 1) / 2 // 0...1, loops forever
            LinearGradient(
                colors: [Theme.Colors.inkSoft, Theme.Colors.userBubble, Theme.Colors.inkSoft],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .shimmerReveal(progress: pulse)
            .overlay {
                Image(systemName: "fork.knife")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .opacity(0.5 + pulse * 0.2)
            }
        }
    }

    private var fallbackGlyph: some View {
        ZStack {
            Rectangle().fill(Theme.Colors.inkSoft)
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }
}
