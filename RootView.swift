//
//  RootView.swift
//  CalorieAI
//
//  Owns the one gesture that connects the app's two screens: pinch out on
//  the thread to zoom out into the Timeline catalog, spread back in (or tap
//  a card) to zoom back into that exact day's conversation. Both screens
//  stay mounted simultaneously during the transition so the `rippleZoom`
//  shader and shared `matchedGeometryEffect` (see `cardNamespace`) can
//  connect them, then the loser is hit-test-disabled once settled.
//

import SwiftUI
import SwiftData

struct RootView: View {
    private enum Mode { case thread, timeline }

    @State private var dayOffset = 0
    @State private var mode: Mode = .thread
    @State private var zoomProgress: Double = 0 // 0 = thread, 1 = timeline
    @State private var zoomFocal: CGPoint = .zero
    @State private var gestureBaseline: Double = 0
    @State private var showSettings = false
    @Namespace private var cardNamespace

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var profiles: [UserProfile]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                DayPagerView(dayOffset: $dayOffset, namespace: cardNamespace)
                    .opacity(1 - zoomProgress)
                    .scaleEffect(1 - zoomProgress * 0.08)
                    .rippleZoom(progress: zoomProgress, focal: zoomFocal)
                    .allowsHitTesting(mode == .thread)

                TimelineCatalogView(namespace: cardNamespace) { entry, focal in
                    jumpToThread(entry: entry, focal: focal)
                }
                .opacity(zoomProgress)
                .scaleEffect(0.94 + zoomProgress * 0.06)
                .rippleZoom(progress: 1 - zoomProgress, focal: zoomFocal)
                .allowsHitTesting(mode == .timeline)

                affordance(size: geo.size)

                if let banner = appState.banner {
                    VStack {
                        bannerView(banner)
                        Spacer()
                    }
                    .padding(.top, Theme.Space.xl)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
                    .allowsHitTesting(false)
                }
            }
            .animation(MotionSpring.bouncy, value: appState.banner)
            .contentShape(Rectangle())
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        zoomFocal = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.4)
                        zoomProgress = min(max(gestureBaseline + (1 - value), 0), 1)
                    }
                    .onEnded { _ in settle() }
            )
        }
        .background(Theme.backgroundGradient().ignoresSafeArea())
        .onChange(of: mode) { _, _ in gestureBaseline = mode == .timeline ? 1 : 0 }
        .sheet(isPresented: $showSettings) {
            if let profile = profiles.first {
                SettingsView(profile: profile)
            }
        }
    }

    private func affordance(size: CGSize) -> some View {
        VStack {
            HStack(spacing: Theme.Space.s) {
                Spacer()
                circleButton(system: "gearshape.fill") { showSettings = true }
                circleButton(system: mode == .thread ? "square.grid.2x2.fill" : "bubble.left.and.bubble.right.fill") {
                    zoomFocal = CGPoint(x: size.width / 2, y: size.height * 0.4)
                    toggleModeProgrammatically()
                }
            }
            .padding(.trailing, Theme.Space.l)
            Spacer()
        }
        .padding(.top, Theme.Space.xxl)
    }

    private func bannerView(_ banner: AppState.Banner) -> some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: banner.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(banner.isError ? Color.red.opacity(0.85) : Theme.Colors.accent)
            Text(banner.message)
                .font(Theme.Font.caption.weight(.medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(2)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.m)
        .background {
            Capsule().fill(.ultraThinMaterial)
        }
        .padding(.horizontal, Theme.Space.xxxl)
    }

    private func circleButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 40, height: 40)
                .background {
                    Circle().fill(.ultraThinMaterial)
                }
        }
    }

    private func settle() {
        let committingToTimeline = zoomProgress > 0.5
        HapticsEngine.zoomCommitted()
        mode = committingToTimeline ? .timeline : .thread
        withAnimation(MotionSpring.gentle) {
            zoomProgress = committingToTimeline ? 1 : 0
        }
    }

    private func toggleModeProgrammatically() {
        let goingToTimeline = mode == .thread
        HapticsEngine.zoomCommitted()
        mode = goingToTimeline ? .timeline : .thread
        withAnimation(MotionSpring.gentle) {
            zoomProgress = goingToTimeline ? 1 : 0
        }
    }

    private func jumpToThread(entry: FoodEntry, focal: CGPoint) {
        if let entryDate = entry.day?.date {
            let startOfToday = Calendar.current.startOfDay(for: .now)
            let startOfEntry = Calendar.current.startOfDay(for: entryDate)
            dayOffset = Calendar.current.dateComponents([.day], from: startOfToday, to: startOfEntry).day ?? 0
        }
        zoomFocal = focal
        HapticsEngine.zoomCommitted()
        mode = .thread
        withAnimation(MotionSpring.gentle) { zoomProgress = 0 }
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.preview())
}
