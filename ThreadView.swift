//
//  ThreadView.swift
//  CalorieAI
//
//  One day's conversation. A fixed glass `DayHeaderView` up top, the
//  scrolling message feed (agent replies, user turns, and inline
//  `FoodEntryCardView`s in place of raw tool notes) in the middle, and a
//  fixed `ComposerView` pinned to the bottom.
//

import SwiftUI
import SwiftData

private enum ThreadItem: Identifiable {
    case message(ChatMessage)
    case foodCard(ChatMessage, FoodEntry)

    var id: PersistentIdentifier {
        switch self {
        case .message(let m): m.persistentModelID
        case .foodCard(let m, _): m.persistentModelID
        }
    }
}

struct ThreadView: View {
    let day: Day
    var namespace: Namespace.ID
    /// Driven by the enclosing `DayPagerView` while the user is dragging
    /// between days, so the header reacts too.
    var dragDistortionIntensity: Double = 0
    var dragTouchPoint: CGPoint = .zero

    @Environment(\.modelContext) private var modelContext
    @State private var agentService: AgentService?
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            DayHeaderView(
                day: day,
                dragDistortionIntensity: dragDistortionIntensity,
                dragTouchPoint: dragTouchPoint
            )

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.Space.m) {
                        if items.isEmpty {
                            emptyState
                        }
                        ForEach(items) { item in
                            itemView(item)
                                .id(item.id)
                                .transition(.materialize)
                        }
                    }
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.vertical, Theme.Space.l)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: items.count) { _, _ in
                    guard let last = items.last?.id else { return }
                    withAnimation(MotionSpring.bouncy) { proxy.scrollTo(last, anchor: .bottom) }
                }
            }

            ComposerView(draft: $draft, isStreaming: agentService?.isStreaming ?? false) { text, image in
                Task { await agentService?.send(text: text, imageData: image) }
            }
        }
        .background(Theme.backgroundGradient(for: day.date).ignoresSafeArea())
        .onAppear {
            if agentService == nil {
                agentService = AgentService(day: day, modelContext: modelContext)
            }
        }
    }

    private var items: [ThreadItem] {
        day.sortedMessages.map { message in
            if message.role == .toolNote,
               let id = message.linkedFoodEntryID,
               let entry = day.entries.first(where: { $0.id == id }) {
                return .foodCard(message, entry)
            }
            return .message(message)
        }
    }

    @ViewBuilder
    private func itemView(_ item: ThreadItem) -> some View {
        switch item {
        case .message(let message):
            ChatBubbleView(message: message)
        case .foodCard(_, let entry):
            HStack {
                FoodEntryCardView(entry: entry, namespace: namespace)
                Spacer(minLength: 40)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.s) {
            Text(day.isToday ? "What did you have?" : "Nothing logged this day.")
                .font(Theme.Font.display(18, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
            if day.isToday {
                Text("Tell me, snap a photo, or just say hi.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Space.xxxl)
    }
}
