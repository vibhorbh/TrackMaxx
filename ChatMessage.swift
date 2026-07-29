//
//  ChatMessage.swift
//  CalorieAI
//

import Foundation
import SwiftData

enum MessageRole: String, Codable, Sendable {
    case user
    case agent
    /// A compact, human-readable line describing a tool call/result
    /// ("Logged grilled chicken bowl · 610 cal"), rendered as a quiet inline
    /// system note rather than raw JSON.
    case toolNote
}

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var roleRaw: String
    var text: String
    var createdAt: Date
    /// True only for the in-flight agent message currently being streamed;
    /// persisted false once the turn completes.
    var isStreaming: Bool
    /// If this message caused a FoodEntry to be created, its id — lets the
    /// timeline deep-link back to this exact point in the thread.
    var linkedFoodEntryID: UUID?
    /// Ordinal position within the day, since createdAt alone can collide
    /// for rapid tool-note sequences.
    var sequence: Int

    var day: Day?

    var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .agent }
        set { roleRaw = newValue.rawValue }
    }

    init(
        role: MessageRole,
        text: String,
        sequence: Int,
        createdAt: Date = .now,
        isStreaming: Bool = false,
        linkedFoodEntryID: UUID? = nil
    ) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.text = text
        self.sequence = sequence
        self.createdAt = createdAt
        self.isStreaming = isStreaming
        self.linkedFoodEntryID = linkedFoodEntryID
    }
}
