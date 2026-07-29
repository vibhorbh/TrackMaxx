//
//  JSONValue.swift
//  CalorieAI
//
//  A generic, Codable, Sendable JSON tree — used for tool `input_schema`
//  definitions, for re-encoding a tool call's arguments when we echo it back
//  to Claude as an assistant `tool_use` block, and anywhere else we need to
//  move arbitrary JSON through Swift's type system without hand-modeling
//  every shape.
//

import Foundation

indirect enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    /// Bridges a `JSONSerialization`-style `Any` (as produced by
    /// `JSONSerialization.jsonObject`) into a `JSONValue` tree.
    init(any: Any) {
        switch any {
        case let value as String:
            self = .string(value)
        case let value as Bool:
            self = .bool(value)
        case let value as NSNumber:
            // NSNumber conflates Bool/Int/Double — Bool is caught above,
            // this covers everything numeric.
            self = .number(value.doubleValue)
        case let value as [String: Any]:
            self = .object(value.mapValues(JSONValue.init(any:)))
        case let value as [Any]:
            self = .array(value.map(JSONValue.init(any:)))
        default:
            self = .null
        }
    }

    /// Convenience accessors used by AgentTools when reading decoded tool
    /// input without round-tripping through a strict Codable struct.
    var stringValue: String? { if case .string(let v) = self { v } else { nil } }
    var doubleValue: Double? { if case .number(let v) = self { v } else { nil } }
    var intValue: Int? { doubleValue.map { Int($0.rounded()) } }
    var boolValue: Bool? { if case .bool(let v) = self { v } else { nil } }
    var objectValue: [String: JSONValue]? { if case .object(let v) = self { v } else { nil } }
    var arrayValue: [JSONValue]? { if case .array(let v) = self { v } else { nil } }

    subscript(key: String) -> JSONValue? { objectValue?[key] }

    /// Parses raw JSON bytes (as streamed back from a `tool_use` block) into
    /// a `JSONValue`, defaulting to an empty object on empty/invalid input
    /// (Claude sometimes sends `{}` for zero-argument tools).
    static func parse(_ data: Data) -> JSONValue {
        guard !data.isEmpty, let object = try? JSONSerialization.jsonObject(with: data) else {
            return .object([:])
        }
        return JSONValue(any: object)
    }
}
