//
//  AgentService.swift
//  CalorieAI
//
//  One `AgentService` per open `ThreadView` (one per `Day`). Owns the
//  Claude-format conversation state for that day, drives the streaming
//  tool-use loop, and writes results straight into SwiftData — `ChatMessage`
//  objects are mutated in place while streaming so any SwiftUI view holding
//  a reference (via @Query) updates live, no manual pub/sub needed.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AgentService {
    private(set) var isStreaming = false
    private(set) var lastError: String?

    private var claudeHistory: [ClaudeMessageParam]
    private let day: Day
    private let modelContext: ModelContext

    init(day: Day, modelContext: ModelContext) {
        self.day = day
        self.modelContext = modelContext
        self.claudeHistory = Self.rebuildHistory(from: day)
    }

    /// Documented simplification (see ARCHITECTURE.md): we don't replay
    /// exact `tool_use`/`tool_result` blocks across app launches. A day's
    /// `FoodEntry` rows are the durable source of truth for what got
    /// logged; replaying just the plain user/agent text turns gives Claude
    /// enough conversational continuity without fragile block-id bookkeeping.
    private static func rebuildHistory(from day: Day) -> [ClaudeMessageParam] {
        var result: [ClaudeMessageParam] = []
        for message in day.sortedMessages {
            switch message.role {
            case .user where !message.text.isEmpty:
                result.append(ClaudeMessageParam(role: "user", content: [.text(message.text)]))
            case .agent where !message.text.isEmpty:
                result.append(ClaudeMessageParam(role: "assistant", content: [.text(message.text)]))
            default:
                continue
            }
        }
        return result
    }

    static let systemPrompt = """
    You are the nutrition companion inside CalorieAI, a conversational calorie tracker. You talk \
    like a warm, sharp friend who happens to know food and nutrition well — not a form, not a \
    clinical assistant. Keep replies short and conversational (1-3 sentences) unless the user \
    clearly wants detail. Never lecture, never moralize about food choices.

    Your job in each conversation is to help the user log what they ate today and understand \
    their day at a glance. When they mention eating something, log it with log_food_entry — don't \
    ask permission first, just do it and confirm briefly ("Logged it — 610 cal"). Ask a clarifying \
    question only when the quantity or dish is genuinely ambiguous.

    Always try search_nutrition before guessing numbers for a common/generic food. If it returns a \
    good match, log using that match's exact figures via `nutritionMatch` + `quantityMultiplier`. \
    If nothing relevant comes back (a specific restaurant dish, a home recipe, etc.), estimate \
    calories and macros yourself from general nutrition knowledge — you're good at this, don't \
    hedge or apologize for estimating.

    Every log_food_entry call needs a vivid, concrete imageDescription of the food itself (not the \
    plate/table/hands) — this becomes a generated photo, so be specific: ingredients, preparation, \
    how it's plated.

    When the user corrects something ("actually that was a large fries") use update_food_entry \
    rather than logging a duplicate. Use delete_food_entry for outright mistakes.

    Use get_day_summary / get_history when the user asks how they're doing, references a past day, \
    or asks about trends — don't guess at numbers you can look up.

    If the user hasn't set goals yet and it comes up naturally, offer to estimate them via \
    estimate_goals rather than making them fill out a form.
    """

    func send(text: String, imageData: Data? = nil, imageMediaType: String = "image/jpeg") async {
        guard !isStreaming else { return }
        isStreaming = true
        lastError = nil
        defer { isStreaming = false }

        let effectiveText = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && imageData != nil
            ? "What's in this photo?"
            : text

        var sequence = (day.messages.map(\.sequence).max() ?? -1) + 1
        let userMessage = ChatMessage(role: .user, text: effectiveText, sequence: sequence)
        userMessage.day = day
        modelContext.insert(userMessage)
        sequence += 1

        var userContent: [ClaudeContentBlock] = []
        if let imageData {
            userContent.append(.image(mediaType: imageMediaType, base64: imageData.base64EncodedString()))
        }
        userContent.append(.text(effectiveText))
        claudeHistory.append(ClaudeMessageParam(role: "user", content: userContent))
        try? modelContext.save()

        var iterations = 0

        agentTurn: while iterations < AppConfig.maxToolIterationsPerTurn {
            iterations += 1

            let agentMessage = ChatMessage(role: .agent, text: "", sequence: sequence, isStreaming: true)
            agentMessage.day = day
            modelContext.insert(agentMessage)
            sequence += 1
            try? modelContext.save()

            var accumulatedText = ""
            var pendingToolCalls: [ClaudeToolCall] = []
            var streamFailed = false

            do {
                let stream = ClaudeClient.stream(
                    messages: claudeHistory,
                    tools: AgentTools.definitions,
                    system: Self.systemPrompt
                )
                for try await event in stream {
                    switch event {
                    case .textDelta(let delta):
                        accumulatedText += delta
                        agentMessage.text = accumulatedText
                    case .toolCallCompleted(let call):
                        pendingToolCalls.append(call)
                    case .turnCompleted:
                        break
                    case .failed(let message):
                        lastError = message
                        streamFailed = true
                    }
                }
            } catch {
                lastError = error.localizedDescription
                streamFailed = true
            }

            agentMessage.isStreaming = false
            if streamFailed && accumulatedText.isEmpty {
                agentMessage.text = "Sorry — I had trouble reaching the model just now. Mind trying again?"
            }
            try? modelContext.save()

            if streamFailed { break agentTurn }

            var assistantContent: [ClaudeContentBlock] = []
            if !accumulatedText.isEmpty { assistantContent.append(.text(accumulatedText)) }
            for call in pendingToolCalls {
                assistantContent.append(.toolUse(id: call.id, name: call.name, input: call.input))
            }
            if !assistantContent.isEmpty {
                claudeHistory.append(ClaudeMessageParam(role: "assistant", content: assistantContent))
            }

            guard !pendingToolCalls.isEmpty else { break agentTurn }

            let profile = PersistenceController.currentProfile(in: modelContext)
            let toolContext = AgentToolContext(modelContext: modelContext, day: day, profile: profile)

            var resultBlocks: [ClaudeContentBlock] = []
            for call in pendingToolCalls {
                let outcome = await AgentTools.execute(call, context: toolContext)
                resultBlocks.append(.toolResult(toolUseId: call.id, content: outcome.resultForModel))

                if let note = outcome.toolNote {
                    let noteMessage = ChatMessage(
                        role: .toolNote,
                        text: note,
                        sequence: sequence,
                        linkedFoodEntryID: outcome.linkedFoodEntryID
                    )
                    noteMessage.day = day
                    modelContext.insert(noteMessage)
                    sequence += 1
                    HapticsEngine.foodLogged()
                }
            }
            claudeHistory.append(ClaudeMessageParam(role: "user", content: resultBlocks))
            try? modelContext.save()
            // Loop again so Claude can respond to the tool results.
        }
    }
}
