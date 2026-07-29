//
//  ChatBubbleView.swift
//  CalorieAI
//
//  Renders one `ChatMessage`. Three looks for three roles: a solid bubble
//  for the user (right-aligned), plain floating text for the agent
//  (left-aligned, no bubble chrome — it reads like a message from a
//  person, not a system), and a quiet centered pill for tool notes.
//

import SwiftUI

struct ChatBubbleView: View {
    var message: ChatMessage
    var onTapToolNote: (() -> Void)? = nil

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(Theme.Font.bubble)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.vertical, Theme.Space.m)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                            .fill(Theme.Colors.userBubble)
                    }
            }

        case .agent:
            HStack {
                StreamingTextView(text: message.text, isStreaming: message.isStreaming)
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.vertical, Theme.Space.s)
                Spacer(minLength: 40)
            }

        case .toolNote:
            HStack {
                Spacer()
                Button {
                    onTapToolNote?()
                } label: {
                    HStack(spacing: Theme.Space.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                        Text(message.text)
                            .font(Theme.Font.microCaption)
                    }
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.horizontal, Theme.Space.m)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.05)))
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
    }
}
