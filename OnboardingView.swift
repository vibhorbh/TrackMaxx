//
//  OnboardingView.swift
//  CalorieAI
//
//  Three quick, glass-styled steps: who you are, what your goals are (typed
//  in, or estimated from a few basics), and the API keys the agent and
//  image generation need. No forms-inside-forms — one focused screen at a
//  time, paged with the same spring the rest of the app uses.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @State private var step = 0
    @State private var useEstimate = false

    // Estimate inputs
    @State private var sex: MacroGoals.Sex = .female
    @State private var age = "28"
    @State private var heightCm = "168"
    @State private var weightKg = "65"
    @State private var activity: MacroGoals.ActivityLevel = .moderate
    @State private var weightGoal: MacroGoals.WeightGoal = .maintain

    // Keys
    @State private var claudeKey = ""
    @State private var openAIKey = ""
    @State private var geminiKey = ""

    private let totalSteps = 3

    var body: some View {
        ZStack {
            Theme.backgroundGradient().ignoresSafeArea()

            VStack(spacing: Theme.Space.xl) {
                HStack(spacing: Theme.Space.xs) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Capsule()
                            .fill(index <= step ? Theme.Colors.accent : Theme.Colors.textTertiary.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.top, Theme.Space.xxl)

                ScrollView {
                    Group {
                        switch step {
                        case 0: welcomeStep
                        case 1: goalsStep
                        default: keysStep
                        }
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    .id(step)
                }

                continueButton
            }
            .padding(.horizontal, Theme.Space.xl)
            .padding(.bottom, Theme.Space.l)
        }
        .animation(MotionSpring.bouncy, value: step)
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            Text("Hey. I'm your\nnutrition companion.")
                .font(Theme.Font.display(30, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Tell me what you eat and I'll keep track — no forms, no barcode scanning. What should I call you?")
                .font(Theme.Font.body(15))
                .foregroundStyle(Theme.Colors.textSecondary)

            TextField("Your name", text: $profile.displayName)
                .textFieldStyle(.plain)
                .font(Theme.Font.body(18, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(Theme.Space.m)
                .background {
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Space.xxxl)
    }

    // MARK: - Step 2: Goals

    private var goalsStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            Text("What are we\naiming for?")
                .font(Theme.Font.display(28, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            Picker("", selection: $useEstimate) {
                Text("I'll estimate").tag(true)
                Text("I know my numbers").tag(false)
            }
            .pickerStyle(.segmented)

            if useEstimate {
                estimateForm
            } else {
                manualGoalsForm
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Space.xl)
    }

    private var estimateForm: some View {
        VStack(spacing: Theme.Space.m) {
            Picker("Sex", selection: $sex) {
                ForEach(MacroGoals.Sex.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)

            fieldRow("Age", text: $age, suffix: "yrs")
            fieldRow("Height", text: $heightCm, suffix: "cm")
            fieldRow("Weight", text: $weightKg, suffix: "kg")

            Picker("Activity", selection: $activity) {
                ForEach(MacroGoals.ActivityLevel.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .tint(Theme.Colors.accent)

            Picker("Goal", selection: $weightGoal) {
                ForEach(MacroGoals.WeightGoal.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .onChange(of: age) { applyEstimate() }
        .onChange(of: heightCm) { applyEstimate() }
        .onChange(of: weightKg) { applyEstimate() }
        .onChange(of: sex) { applyEstimate() }
        .onChange(of: activity) { applyEstimate() }
        .onChange(of: weightGoal) { applyEstimate() }
        .onAppear { applyEstimate() }
    }

    private var manualGoalsForm: some View {
        VStack(spacing: Theme.Space.m) {
            intFieldRow("Calories", value: $profile.calorieGoal, suffix: "cal")
            intFieldRow("Protein", value: $profile.proteinGoal, suffix: "g")
            intFieldRow("Carbs", value: $profile.carbGoal, suffix: "g")
            intFieldRow("Fat", value: $profile.fatGoal, suffix: "g")
        }
    }

    private func applyEstimate() {
        guard let ageInt = Int(age), let height = Double(heightCm), let weight = Double(weightKg) else { return }
        let goals = MacroGoals.estimate(sex: sex, ageYears: ageInt, heightCm: height, weightKg: weight, activity: activity, goal: weightGoal)
        profile.goals = goals
    }

    // MARK: - Step 3: API keys

    private var keysStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            Text("Almost there.")
                .font(Theme.Font.display(28, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("The conversation runs on Claude; food photos on OpenAI or Gemini. Keys stay on this device, in Keychain.")
                .font(Theme.Font.body(15))
                .foregroundStyle(Theme.Colors.textSecondary)

            secureFieldRow("Claude API key", text: $claudeKey)

            Picker("Image model", selection: $profile.imageProvider) {
                ForEach(ImageProviderKind.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            if profile.imageProvider == .openAI {
                secureFieldRow("OpenAI API key", text: $openAIKey)
            } else {
                secureFieldRow("Gemini API key", text: $geminiKey)
            }

            Text("You can skip this and add keys later in Settings — the thread will just let you know when it needs one.")
                .font(Theme.Font.microCaption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Space.xl)
    }

    // MARK: - Shared field styles

    private func fieldRow(_ label: String, text: Binding<String>, suffix: String) -> some View {
        HStack {
            Text(label).font(Theme.Font.body(15)).foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            TextField("", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(suffix).font(Theme.Font.caption).foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding(Theme.Space.m)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).fill(.ultraThinMaterial))
    }

    private func intFieldRow(_ label: String, value: Binding<Int>, suffix: String) -> some View {
        fieldRow(label, text: Binding(
            get: { String(value.wrappedValue) },
            set: { value.wrappedValue = Int($0) ?? value.wrappedValue }
        ), suffix: suffix)
    }

    private func secureFieldRow(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(Theme.Font.body(15))
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(Theme.Space.m)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).fill(.ultraThinMaterial))
    }

    // MARK: - Navigation

    private var continueButton: some View {
        Button(action: advance) {
            Text(step == totalSteps - 1 ? "Start tracking" : "Continue")
                .font(Theme.Font.display(16, weight: .semibold))
                .foregroundStyle(Theme.Colors.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.m)
                .background(Capsule().fill(Theme.Colors.accent))
        }
        .buttonStyle(.plain)
    }

    private func advance() {
        HapticsEngine.selected()
        if step < totalSteps - 1 {
            step += 1
        } else {
            KeychainStore.setAPIKey(claudeKey, for: .anthropic)
            if profile.imageProvider == .openAI {
                KeychainStore.setAPIKey(openAIKey, for: .openAI)
            } else {
                KeychainStore.setAPIKey(geminiKey, for: .gemini)
            }
            profile.didCompleteOnboarding = true
            try? modelContext.save()
        }
    }
}
