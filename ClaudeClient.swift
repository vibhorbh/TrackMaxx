//
//  ClaudeClient.swift
//  CalorieAI
//
//  Thin SSE streaming client for the Claude Messages API. No SDK
//  dependency — just `URLSession.bytes(for:)` read line-by-line, since
//  Anthropic's stream is plain server-sent events. Emits a small,
//  UI-friendly `ClaudeStreamEvent` rather than raw SSE payloads.
//

import Foundation

enum ClaudeClient {

    private struct BlockState {
        var type: String
        var toolId: String?
        var toolName: String?
        var jsonBuffer: String = ""
    }

    static func stream(
        messages: [ClaudeMessageParam],
        tools: [ToolDefinition],
        system: String
    ) -> AsyncThrowingStream<ClaudeStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                guard let apiKey = KeychainStore.apiKey(for: .anthropic), !apiKey.isEmpty else {
                    continuation.yield(.failed("No Claude API key saved yet — add one in Settings."))
                    continuation.finish()
                    return
                }

                do {
                    var request = URLRequest(url: AppConfig.claudeEndpoint)
                    request.httpMethod = "POST"
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue(AppConfig.claudeAPIVersion, forHTTPHeaderField: "anthropic-version")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let body = ClaudeRequestBody(
                        model: AppConfig.claudeModel,
                        maxTokens: AppConfig.claudeMaxTokens,
                        system: system,
                        messages: messages,
                        tools: tools
                    )
                    request.httpBody = try JSONEncoder().encode(body)

                    let (byteStream, response) = try await URLSession.shared.bytes(for: request)

                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        var errorBody = ""
                        for try await line in byteStream.lines { errorBody += line }
                        continuation.yield(.failed("Claude API error \(http.statusCode): \(errorBody.prefix(400))"))
                        continuation.finish()
                        return
                    }

                    var blocks: [Int: BlockState] = [:]

                    for try await line in byteStream.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        guard !payload.isEmpty,
                              let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type = json["type"] as? String
                        else { continue }

                        switch type {
                        case "content_block_start":
                            guard let index = json["index"] as? Int,
                                  let block = json["content_block"] as? [String: Any],
                                  let blockType = block["type"] as? String
                            else { continue }
                            blocks[index] = BlockState(
                                type: blockType,
                                toolId: block["id"] as? String,
                                toolName: block["name"] as? String
                            )

                        case "content_block_delta":
                            guard let index = json["index"] as? Int,
                                  let delta = json["delta"] as? [String: Any],
                                  let deltaType = delta["type"] as? String
                            else { continue }
                            if deltaType == "text_delta", let text = delta["text"] as? String {
                                continuation.yield(.textDelta(text))
                            } else if deltaType == "input_json_delta", let partial = delta["partial_json"] as? String {
                                blocks[index]?.jsonBuffer += partial
                            }

                        case "content_block_stop":
                            guard let index = json["index"] as? Int, let state = blocks[index] else { continue }
                            if state.type == "tool_use", let id = state.toolId, let name = state.toolName {
                                let inputData = state.jsonBuffer.data(using: .utf8) ?? Data()
                                continuation.yield(.toolCallCompleted(
                                    ClaudeToolCall(id: id, name: name, input: JSONValue.parse(inputData))
                                ))
                            }
                            blocks[index] = nil

                        case "message_delta":
                            if let delta = json["delta"] as? [String: Any],
                               let stopReason = delta["stop_reason"] as? String {
                                continuation.yield(.turnCompleted(stopReason: stopReason))
                            }

                        case "error":
                            let message = (json["error"] as? [String: Any])?["message"] as? String
                            continuation.yield(.failed(message ?? "Unknown streaming error"))

                        default:
                            break
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.yield(.failed(error.localizedDescription))
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
