//
//  TimelineCatalogView.swift
//  CalorieAI
//
//  The "zoomed out" view: every meal ever logged, as a scrollable magazine
//  catalog grouped by day, most recent first. Named `...Catalog...` rather
//  than `TimelineView` to avoid colliding with SwiftUI's own `TimelineView`.
//

import SwiftUI
import SwiftData

struct TimelineCatalogView: View {
    var namespace: Namespace.ID
    var onSelectEntry: (FoodEntry, CGPoint) -> Void

    @Query(sort: \Day.date, order: .reverse) private var allDays: [Day]

    private var daysWithEntries: [Day] {
        allDays.filter { !$0.entries.isEmpty }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Space.l) {
                if daysWithEntries.isEmpty {
                    emptyState
                }
                ForEach(daysWithEntries) { day in
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        TimelineSectionHeader(day: day)
                        MasonryLayout(columns: 2, spacing: Theme.Space.s) {
                            ForEach(day.entries.sorted(by: { $0.createdAt < $1.createdAt })) { entry in
                                TimelineMealCard(entry: entry, namespace: namespace) { focal in
                                    onSelectEntry(entry, focal)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.top, Theme.Space.xxxl + Theme.Space.m)
            .padding(.bottom, Theme.Space.xxxl)
        }
        .background(Theme.backgroundGradient().ignoresSafeArea())
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.s) {
            Image(systemName: "photo.stack")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("Your catalog will fill in as you log meals.")
                .font(Theme.Font.body(15))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Space.xxxl)
    }
}
