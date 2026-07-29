//
//  ClaudeMessageTypes.swift
//  CalorieAI
//
//  Wire types for the Claude Messages API (`POST /v1/messages`, streamed).
//  Kept deliberately close to the raw API shape — `AgentService` is the
//  layer that translates to/from our own `ChatMessage`/`FoodEntry` models.
//

import Foundation

struct ClaudeMessageParam: Encodable, Sendable {
    var role: String // "user" | "assistant"
    var content: [ClaudeContentBlock]
}

enum ClaudeContentBlock: Encodable, Sendable {
    case text(String)
    case image(mediaType: String, base64: String)
    case toolUse(id: String, name: String, input: JSONValue)
    case toolResult(toolUseId: String, content: String, isError: Bool = false)

    private enum CodingKeys: String, CodingKey {
        case type, text, source, id, name, input, tool_use_id, content, is_error
    }
    private enum SourceKeys: String, CodingKey {
        case type, media_type, data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)

        case .image(let mediaType, let base64):
            try container.encode("image", forKey: .type)
            var source = container.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
            try source.encode("base64", forKey: .type)
            try source.encode(mediaType, forKey: .media_type)
            try source.encode(base64, forKey: .data)

        case .toolUse(let id, let name, let input):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(input, forKey: .input)

        case .toolResult(let toolUseId, let content, let isError):
            try container.encode("tool_result", forKey: .type)
            try container.encode(toolUseId, forKey: .tool_use_id)
            try container.encode(content, forKey: .content)
            if isError { try container.encode(true, forKey: .is_error) }
        }
    }
}

/// A tool the agent can call. `inputSchema` is a JSON-Schema object encoded
/// via `JSONValue` (see `AgentTools.definitions`).
struct ToolDefinition: Encodable, Sendable {
    var name: String
    var description: String
    var inputSchema: JSONValue

    private enum CodingKeys: String, CodingKey {
        case name, description, input_schema
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(inputSchema, forKey: .input_schema)
    }
}

struct ClaudeRequestBody: Encodable, Sendable {
    var model: String
    var maxTokens: Int
    var system: String
    var messages: [ClaudeMessageParam]
    var tools: [ToolDefinition]
    var stream: Bool = true

    private enum CodingKeys: String, CodingKey {
        case model, system, messages, tools, stream
        case maxTokens = "max_tokens"
    }
}

/// A fully-formed tool call as delivered by the stream once its input JSON
/// has finished arriving.
struct ClaudeToolCall: Sendable {
    var id: String
    var name: String
    var input: JSONValue
}

enum ClaudeStreamEvent: Sendable {
    case textDelta(String)
    case toolCallCompleted(ClaudeToolCall)
    /// `stopReason` is one of "end_turn", "tool_use", "max_tokens", etc.
    case turnCompleted(stopReason: String?)
    case failed(String)
}
