//
//  DayPagerView.swift
//  CalorieAI
//
//  Horizontal paging between days, one `ThreadView` per page. Custom drag
//  handling (not `TabView(.page)`) so we get rubber-band resistance at the
//  "today" edge, a haptic tick per day crossed, and a live liquid-glass
//  parallax on the day header while dragging.
//
//  Convention: `dayOffset` is 0 for today, negative for the past. Swiping
//  left advances toward more recent days (never past today); swiping right
//  goes further back, unbounded.
//

import SwiftUI
import SwiftData

struct DayPagerView: View {
    @Binding var dayOffset: Int
    var namespace: Namespace.ID

    @Environment(\.modelContext) private var modelContext
    @GestureState private var dragTranslation: CGFloat = 0
    @State private var touchPoint: CGPoint = .zero
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let pageWidth = max(geo.size.width, 1)
            let rubberBanded = rubberBand(dragTranslation, pageWidth: pageWidth)

            HStack(spacing: 0) {
                page(for: dayOffset - 1).frame(width: pageWidth)
                page(for: dayOffset).frame(width: pageWidth)
                page(for: dayOffset + 1).frame(width: pageWidth)
            }
            .frame(width: pageWidth * 3, height: geo.size.height, alignment: .leading)
            .offset(x: -pageWidth + rubberBanded)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation.width
                    }
                    .onChanged { value in
                        isDragging = true
                        touchPoint = value.location
                    }
                    .onEnded { value in
                        commitDrag(translation: value.translation.width, velocity: value.predictedEndTranslation.width, pageWidth: pageWidth)
                    }
            )
            .animation(MotionSpring.bouncy, value: dayOffset)
        }
    }

    /// Dead-zone resistance: dragging further "into the future" than today
    /// only moves a fraction as far, so it visibly refuses rather than
    /// silently doing nothing.
    private func rubberBand(_ translation: CGFloat, pageWidth: CGFloat) -> CGFloat {
        guard dayOffset >= 0, translation < 0 else { return translation }
        let resisted = translation * 0.3
        return max(resisted, -pageWidth * 0.22)
    }

    private func commitDrag(translation: CGFloat, velocity: CGFloat, pageWidth: CGFloat) {
        isDragging = false
        let threshold = pageWidth * 0.24
        let strongSwipe = abs(velocity) > pageWidth * 1.2

        if (translation < -threshold || (translation < 0 && strongSwipe)), dayOffset < 0 {
            dayOffset += 1
            HapticsEngine.dayCrossed()
        } else if translation > threshold || (translation > 0 && strongSwipe) {
            dayOffset -= 1
            HapticsEngine.dayCrossed()
        }
    }

    private func page(for offset: Int) -> some View {
        DayPageHost(
            offset: offset,
            namespace: namespace,
            dragDistortionIntensity: isDragging ? min(abs(dragTranslation) / 400, 0.55) : 0,
            dragTouchPoint: touchPoint
        )
    }
}

/// Resolves (and lazily creates) the `Day` for a relative offset and hosts
/// its `ThreadView`. Kept separate from `DayPagerView` so each page only
/// re-fetches its own day, not the whole trio, when data changes.
private struct DayPageHost: View {
    let offset: Int
    var namespace: Namespace.ID
    var dragDistortionIntensity: Double
    var dragTouchPoint: CGPoint

    @Environment(\.modelContext) private var modelContext
    @State private var day: Day?

    var body: some View {
        Group {
            if let day {
                ThreadView(
                    day: day,
                    namespace: namespace,
                    dragDistortionIntensity: dragDistortionIntensity,
                    dragTouchPoint: dragTouchPoint
                )
            } else {
                Color.clear
            }
        }
        .task(id: offset) {
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: .now) else { return }
            day = PersistenceController.day(for: date, in: modelContext)
        }
    }
}
