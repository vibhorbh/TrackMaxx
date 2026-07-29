//
//  PersistenceController.swift
//  CalorieAI
//
//  Owns the SwiftData `ModelContainer`. One place to change storage
//  strategy (e.g. adding CloudKit sync later) without touching call sites.
//

import Foundation
import SwiftData

@MainActor
enum PersistenceController {
    static let schema = Schema([Day.self, ChatMessage.self, FoodEntry.self, UserProfile.self])

    static let shared: ModelContainer = {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Fall back to an in-memory store rather than crashing the app —
            // a corrupt on-disk store shouldn't make the whole thing unusable.
            assertionFailure("Falling back to in-memory store: \(error)")
            let memoryOnly = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [memoryOnly])
        }
    }()

    /// Previews / tests use an isolated in-memory container so they never
    /// touch the real on-disk store.
    static func preview() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    /// Fetches the single `UserProfile`, creating one on first launch.
    static func currentProfile(in context: ModelContext) -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let fresh = UserProfile()
        context.insert(fresh)
        try? context.save()
        return fresh
    }

    /// Fetches (or creates, snapshotting the profile's current goals) the
    /// `Day` for a given date.
    @discardableResult
    static func day(for date: Date, in context: ModelContext) -> Day {
        let key = Day.key(for: date)
        var descriptor = FetchDescriptor<Day>(predicate: #Predicate { $0.dateKey == key })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let profile = currentProfile(in: context)
        let fresh = Day(date: date, goals: profile.goals)
        context.insert(fresh)
        try? context.save()
        return fresh
    }

    /// All days with at least one message or entry, most recent first —
    /// backs both the day pager's index and the timeline's sections.
    static func allDays(in context: ModelContext) -> [Day] {
        let descriptor = FetchDescriptor<Day>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
