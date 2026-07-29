//
//  ComposerView.swift
//  CalorieAI
//
//  The bottom input bar: a glass pill with a camera/photo attach menu, a
//  growing text field, and a send button that only lights up once there's
//  something to send. Snapping a photo hands it straight to the agent as
//  vision input (see ARCHITECTURE.md → "Snapping a photo of your plate").
//

import PhotosUI
import SwiftUI

struct ComposerView: View {
    @Binding var draft: String
    var isStreaming: Bool
    var onSend: (String, Data?) -> Void

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingImageData: Data?
    @State private var showCamera = false
    @FocusState private var isFocused: Bool
    @State private var wakeIntensity: Double = 0
    @Environment(AppState.self) private var appState

    private var canSend: Bool {
        !isStreaming && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingImageData != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let pendingImageData, let uiImage = UIImage(data: pendingImageData) {
                attachmentPreview(uiImage)
            }

            LiquidGlassPanel(cornerRadius: Theme.Radius.pill, distortionIntensity: wakeIntensity) {
                HStack(spacing: Theme.Space.s) {
                    Menu {
                        Button { showCamera = true } label: {
                            Label("Take a photo", systemImage: "camera")
                        }
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Choose a photo", systemImage: "photo")
                        }
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(width: 32, height: 32)
                    }

                    TextField("Tell me what you ate…", text: $draft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(Theme.Font.body(16))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1...4)
                        .focused($isFocused)
                        .tint(Theme.Colors.accent)

                    Button(action: send) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.Colors.ink)
                            .frame(width: 30, height: 30)
                            .background {
                                Circle().fill(canSend ? Theme.Colors.accent : Theme.Colors.textTertiary.opacity(0.4))
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .animation(MotionSpring.tap, value: canSend)
                }
                .padding(.horizontal, Theme.Space.m)
                .padding(.vertical, Theme.Space.s)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.bottom, Theme.Space.s)
        }
        .onChange(of: isFocused) { _, focused in
            guard focused else { return }
            wakeIntensity = 0.5
            withAnimation(MotionSpring.gentle) { wakeIntensity = 0 }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                guard let newItem else { return }
                guard let data = try? await newItem.loadTransferable(type: Data.self) else {
                    appState.show("Couldn't load that photo — mind trying again?", isError: true)
                    return
                }
                pendingImageData = data
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { data in pendingImageData = data }
                .ignoresSafeArea()
        }
    }

    private func attachmentPreview(_ image: UIImage) -> some View {
        HStack {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                Button {
                    withAnimation(MotionSpring.snappy) {
                        pendingImageData = nil
                        selectedPhotoItem = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, Theme.Colors.ink)
                }
                .offset(x: 6, y: -6)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.bottom, Theme.Space.xs)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func send() {
        guard canSend else { return }
        HapticsEngine.sent()
        let text = draft
        let image = pendingImageData
        draft = ""
        withAnimation(MotionSpring.snappy) { pendingImageData = nil }
        selectedPhotoItem = nil
        onSend(text, image)
    }
}
