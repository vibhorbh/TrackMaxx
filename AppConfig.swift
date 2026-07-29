//
//  AppConfig.swift
//  CalorieAI
//
//  Small, non-secret constants. Anything secret (API keys) lives in
//  `KeychainStore`, never here.
//

import Foundation

enum AppConfig {
    /// The Claude model used by the conversational agent. Swap freely —
    /// nothing else in the codebase hard-codes a model string.
    static let claudeModel = "claude-sonnet-4-5"
    static let claudeAPIVersion = "2023-06-01"
    static let claudeMaxTokens = 1024
    static let claudeEndpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// Soft ceiling on tool-use round-trips per user turn, so a
    /// misbehaving loop can't spin forever.
    static let maxToolIterationsPerTurn = 6
}
