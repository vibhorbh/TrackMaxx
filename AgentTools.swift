//
//  AgentTools.swift
//  CalorieAI
//
//  Every tool the agent can call, and their implementations. Tools read and
//  write real SwiftData — this is the only place outside `PersistenceController`
//  that mutates `Day`/`FoodEntry`/`ChatMessage`. Kept on `@MainActor` since
//  SwiftData's `ModelContext` is not meant to be hopped across threads.
//

import Foundation
import SwiftData

/// Everything a tool call needs to act on the active thread.
struct AgentToolContext {
    let modelContext: ModelContext
    let day: Day
    let profile: UserProfile
}

/// What a tool execution hands back to `AgentService`.
struct AgentToolOutcome {
    /// Sent back to Claude as the `tool_result` content — plain text/JSON,
    /// written for a language model to read, not a human.
    var resultForModel: String
    /// If non-nil, a compact system line rendered inline in the thread
    /// ("Logged Grilled chicken bowl · 610 cal").
    var toolNote: String?
    /// If this call created/updated a `FoodEntry`, its id — lets the
    /// message link to a `FoodEntryCardView`.
    var linkedFoodEntryID: UUID?
}

enum AgentTools {

    // MARK: - Schema helpers

    private static func schema(_ properties: [String: JSONValue], required: [String] = []) -> JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object(properties),
            "required": .array(required.map(JSONValue.string)),
        ])
    }

    private static func prop(_ type: String, _ description: String, enumValues: [String]? = nil) -> JSONValue {
        var object: [String: JSONValue] = ["type": .string(type), "description": .string(description)]
        if let enumValues { object["enum"] = .array(enumValues.map(JSONValue.string)) }
        return .object(object)
    }

    // MARK: - Definitions sent to Claude

    static let definitions: [ToolDefinition] = [
        ToolDefinition(
            name: "search_nutrition",
            description: """
            Fuzzy-search the local nutrition database for a food by name. Always call this \
            before log_food_entry when the food might be a common, generic item — if a good \
            match comes back, reuse its exact `name`, `caloriesPerServing`, etc. via \
            log_food_entry's `nutritionMatch` + `quantityMultiplier` instead of guessing \
            numbers yourself. If nothing relevant comes back, estimate the nutrition yourself \
            from general knowledge and pass explicit calories/macros to log_food_entry.
            """,
            inputSchema: schema([
                "query": prop("string", "Food name to search for, e.g. 'grilled chicken' or 'banana'."),
                "limit": prop("number", "Max results to return (default 5)."),
            ], required: ["query"])
        ),
        ToolDefinition(
            name: "log_food_entry",
            description: """
            Log a food the user ate today. Use `nutritionMatch` (the exact `name` field from a \
            prior search_nutrition result) with `quantityMultiplier` when you matched a database \
            item; otherwise pass explicit calories/proteinG/carbG/fatG from your own estimate. \
            Always include a vivid, concrete `imageDescription` (what it looks like on a plate/in \
            a bowl/etc — this drives a generated studio photo, so be specific about the food \
            itself, not the plate or setting).
            """,
            inputSchema: schema([
                "name": prop("string", "Short food name, e.g. 'Grilled chicken bowl'."),
                "quantityDescription": prop("string", "Human quantity, e.g. '1 bowl', '2 slices', '1.5 cups'."),
                "quantityMultiplier": prop("number", "Multiplier vs. the matched database serving (default 1)."),
                "mealSlot": prop("string", "breakfast, lunch, dinner, or snack. Infer from context/time if unstated.", enumValues: MealSlot.allCases.map(\.rawValue)),
                "nutritionMatch": prop("string", "Exact `name` of a search_nutrition result this entry is based on, if any."),
                "calories": prop("number", "Total calories, if not using nutritionMatch."),
                "proteinG": prop("number", "Protein grams, if not using nutritionMatch."),
                "carbG": prop("number", "Carb grams, if not using nutritionMatch."),
                "fatG": prop("number", "Fat grams, if not using nutritionMatch."),
                "imageDescription": prop("string", "Vivid, concrete visual description of the food for photo generation."),
            ], required: ["name", "quantityDescription", "imageDescription"])
        ),
        ToolDefinition(
            name: "update_food_entry",
            description: "Correct a food entry already logged today (e.g. 'actually make that a large'). Only include fields that changed.",
            inputSchema: schema([
                "entryId": prop("string", "The id of the entry to update."),
                "name": prop("string", "New name, if changed."),
                "quantityDescription": prop("string", "New quantity description, if changed."),
                "quantityMultiplier": prop("number", "New multiplier, if changed."),
                "mealSlot": prop("string", "New meal slot, if changed.", enumValues: MealSlot.allCases.map(\.rawValue)),
                "calories": prop("number", "New total calories, if changed."),
                "proteinG": prop("number", "New protein grams, if changed."),
                "carbG": prop("number", "New carb grams, if changed."),
                "fatG": prop("number", "New fat grams, if changed."),
                "imageDescription": prop("string", "New visual description, if the food itself changed enough to need a new photo."),
            ], required: ["entryId"])
        ),
        ToolDefinition(
            name: "delete_food_entry",
            description: "Remove a food entry the user logged by mistake or asked to undo.",
            inputSchema: schema([
                "entryId": prop("string", "The id of the entry to delete."),
            ], required: ["entryId"])
        ),
        ToolDefinition(
            name: "get_day_summary",
            description: "Get totals and logged foods for a day relative to the one currently open.",
            inputSchema: schema([
                "dayOffset": prop("number", "0 = the day currently open, -1 = the day before it, etc."),
            ])
        ),
        ToolDefinition(
            name: "get_history",
            description: "Get a range of days' totals for trend questions ('how's my protein been this week'). Range is relative to the day currently open.",
            inputSchema: schema([
                "startOffset": prop("number", "Earliest day, e.g. -6 for six days before the open day."),
                "endOffset": prop("number", "Latest day, e.g. 0 for the open day itself."),
            ], required: ["startOffset", "endOffset"])
        ),
        ToolDefinition(
            name: "estimate_goals",
            description: "Estimate and save daily calorie/macro goals from basic stats. Use during onboarding or whenever the user wants their goals recalculated.",
            inputSchema: schema([
                "sex": prop("string", "male or female (for a basic BMR formula only).", enumValues: MacroGoals.Sex.allCases.map(\.rawValue)),
                "ageYears": prop("number", "Age in years."),
                "heightCm": prop("number", "Height in centimeters."),
                "weightKg": prop("number", "Weight in kilograms."),
                "activityLevel": prop("string", "Activity level.", enumValues: MacroGoals.ActivityLevel.allCases.map(\.rawValue)),
                "weightGoal": prop("string", "lose, maintain, or gain.", enumValues: MacroGoals.WeightGoal.allCases.map(\.rawValue)),
            ], required: ["sex", "ageYears", "heightCm", "weightKg", "activityLevel", "weightGoal"])
        ),
    ]

    // MARK: - Dispatch

    @MainActor
    static func execute(_ call: ClaudeToolCall, context: AgentToolContext) async -> AgentToolOutcome {
        switch call.name {
        case "search_nutrition": return searchNutrition(call.input)
        case "log_food_entry": return await logFoodEntry(call.input, context: context)
        case "update_food_entry": return await updateFoodEntry(call.input, context: context)
        case "delete_food_entry": return deleteFoodEntry(call.input, context: context)
        case "get_day_summary": return getDaySummary(call.input, context: context)
        case "get_history": return getHistory(call.input, context: context)
        case "estimate_goals": return estimateGoals(call.input, context: context)
        default:
            return AgentToolOutcome(resultForModel: "Unknown tool '\(call.name)'.", toolNote: nil, linkedFoodEntryID: nil)
        }
    }

    // MARK: - search_nutrition

    private static func searchNutrition(_ input: JSONValue) -> AgentToolOutcome {
        guard let query = input["query"]?.stringValue, !query.isEmpty else {
            return AgentToolOutcome(resultForModel: "Missing 'query'.", toolNote: nil, linkedFoodEntryID: nil)
        }
        let limit = input["limit"]?.intValue ?? 5
        let results = NutritionDatabase.shared.search(query, limit: limit)
        guard !results.isEmpty else {
            return AgentToolOutcome(resultForModel: "No matches for '\(query)'. Estimate the nutrition yourself.", toolNote: nil, linkedFoodEntryID: nil)
        }
        let lines = results.map { item in
            "- name: \"\(item.name)\" | serving: \(item.servingDescription) | \(item.calories) cal | \(item.proteinG)g protein | \(item.carbG)g carb | \(item.fatG)g fat"
        }
        return AgentToolOutcome(resultForModel: lines.joined(separator: "\n"), toolNote: nil, linkedFoodEntryID: nil)
    }

    // MARK: - log_food_entry

    private static func logFoodEntry(_ input: JSONValue, context: AgentToolContext) async -> AgentToolOutcome {
        guard
            let name = input["name"]?.stringValue,
            let quantityDescription = input["quantityDescription"]?.stringValue,
            let imageDescription = input["imageDescription"]?.stringValue
        else {
            return AgentToolOutcome(resultForModel: "Missing required fields for log_food_entry.", toolNote: nil, linkedFoodEntryID: nil)
        }

        let multiplier = input["quantityMultiplier"]?.doubleValue ?? 1.0
        let mealSlot = input["mealSlot"]?.stringValue.flatMap(MealSlot.init(rawValue:)) ?? MealSlot.inferred(from: .now)

        var calories: Int
        var proteinG: Double, carbG: Double, fatG: Double

        if let matchName = input["nutritionMatch"]?.stringValue,
           let match = NutritionDatabase.shared.lookup(exact: matchName) {
            let scaled = match.scaled(by: multiplier)
            calories = scaled.calories
            proteinG = scaled.proteinG
            carbG = scaled.carbG
            fatG = scaled.fatG
        } else {
            calories = input["calories"]?.intValue ?? 0
            proteinG = input["proteinG"]?.doubleValue ?? 0
            carbG = input["carbG"]?.doubleValue ?? 0
            fatG = input["fatG"]?.doubleValue ?? 0
        }

        let signature = FoodEntry.signature(for: "\(name) \(quantityDescription)")
        let entry = FoodEntry(
            name: name,
            quantityDescription: quantityDescription,
            mealSlot: mealSlot,
            calories: calories,
            proteinG: proteinG,
            carbG: carbG,
            fatG: fatG,
            imageSignature: signature
        )
        entry.day = context.day
        context.modelContext.insert(entry)
        try? context.modelContext.save()

        beginImageGeneration(for: entry, description: imageDescription, provider: context.profile.imageProvider, modelContext: context.modelContext)

        let note = "Logged \(quantityDescription) \(name) · \(calories) cal · \(mealSlot.label.lowercased())"
        let resultForModel = """
        Logged. entryId=\(entry.id.uuidString) totals now: \(context.day.totalCalories) cal, \
        \(Int(context.day.totalProteinG))g protein, \(Int(context.day.totalCarbG))g carb, \(Int(context.day.totalFatG))g fat \
        (goal: \(context.day.calorieGoal) cal, \(context.day.proteinGoal)g protein).
        """
        return AgentToolOutcome(resultForModel: resultForModel, toolNote: note, linkedFoodEntryID: entry.id)
    }

    // MARK: - update_food_entry

    private static func updateFoodEntry(_ input: JSONValue, context: AgentToolContext) async -> AgentToolOutcome {
        guard let idString = input["entryId"]?.stringValue, let id = UUID(uuidString: idString),
              let entry = context.day.entries.first(where: { $0.id == id }) else {
            return AgentToolOutcome(resultForModel: "No entry found with that id.", toolNote: nil, linkedFoodEntryID: nil)
        }

        if let name = input["name"]?.stringValue { entry.name = name }
        if let qty = input["quantityDescription"]?.stringValue { entry.quantityDescription = qty }
        if let mealSlot = input["mealSlot"]?.stringValue.flatMap(MealSlot.init(rawValue:)) { entry.mealSlot = mealSlot }
        if let calories = input["calories"]?.intValue { entry.calories = calories }
        if let proteinG = input["proteinG"]?.doubleValue { entry.proteinG = proteinG }
        if let carbG = input["carbG"]?.doubleValue { entry.carbG = carbG }
        if let fatG = input["fatG"]?.doubleValue { entry.fatG = fatG }

        if let imageDescription = input["imageDescription"]?.stringValue {
            let newSignature = FoodEntry.signature(for: "\(entry.name) \(entry.quantityDescription)")
            if newSignature != entry.imageSignature || entry.imageState == .failed {
                entry.imageSignature = newSignature
                entry.imageState = .pending
                entry.localImagePath = nil
                beginImageGeneration(for: entry, description: imageDescription, provider: context.profile.imageProvider, modelContext: context.modelContext)
            }
        }

        try? context.modelContext.save()
        let note = "Updated \(entry.name) · \(entry.calories) cal"
        return AgentToolOutcome(
            resultForModel: "Updated. New totals: \(context.day.totalCalories) cal.",
            toolNote: note,
            linkedFoodEntryID: entry.id
        )
    }

    // MARK: - delete_food_entry

    private static func deleteFoodEntry(_ input: JSONValue, context: AgentToolContext) -> AgentToolOutcome {
        guard let idString = input["entryId"]?.stringValue, let id = UUID(uuidString: idString),
              let entry = context.day.entries.first(where: { $0.id == id }) else {
            return AgentToolOutcome(resultForModel: "No entry found with that id.", toolNote: nil, linkedFoodEntryID: nil)
        }
        let name = entry.name
        context.modelContext.delete(entry)
        try? context.modelContext.save()
        return AgentToolOutcome(resultForModel: "Deleted \(name).", toolNote: "Removed \(name)", linkedFoodEntryID: nil)
    }

    // MARK: - get_day_summary / get_history

    private static func resolvedDay(offset: Int, from day: Day, context: AgentToolContext) -> Day? {
        guard let target = Calendar.current.date(byAdding: .day, value: offset, to: day.date) else { return nil }
        let key = Day.key(for: target)
        var descriptor = FetchDescriptor<Day>(predicate: #Predicate { $0.dateKey == key })
        descriptor.fetchLimit = 1
        return try? context.modelContext.fetch(descriptor).first
    }

    private static func getDaySummary(_ input: JSONValue, context: AgentToolContext) -> AgentToolOutcome {
        let offset = input["dayOffset"]?.intValue ?? 0
        guard let day = offset == 0 ? context.day : resolvedDay(offset: offset, from: context.day, context: context) else {
            return AgentToolOutcome(resultForModel: "No data for that day.", toolNote: nil, linkedFoodEntryID: nil)
        }
        let foods = day.entries.map { "\($0.quantityDescription) \($0.name) (\($0.calories) cal, \($0.mealSlot.label))" }
        let summary = """
        \(day.displayTitle): \(day.totalCalories)/\(day.calorieGoal) cal, \
        \(Int(day.totalProteinG))/\(day.proteinGoal)g protein, \(Int(day.totalCarbG))/\(day.carbGoal)g carb, \
        \(Int(day.totalFatG))/\(day.fatGoal)g fat.
        Foods: \(foods.isEmpty ? "none logged" : foods.joined(separator: "; "))
        """
        return AgentToolOutcome(resultForModel: summary, toolNote: nil, linkedFoodEntryID: nil)
    }

    private static func getHistory(_ input: JSONValue, context: AgentToolContext) -> AgentToolOutcome {
        guard let start = input["startOffset"]?.intValue, let end = input["endOffset"]?.intValue, start <= end else {
            return AgentToolOutcome(resultForModel: "Missing/invalid startOffset or endOffset.", toolNote: nil, linkedFoodEntryID: nil)
        }
        var lines: [String] = []
        for offset in start...end {
            if let day = offset == 0 ? context.day : resolvedDay(offset: offset, from: context.day, context: context) {
                lines.append("\(day.displayTitle): \(day.totalCalories) cal, \(Int(day.totalProteinG))g protein, \(Int(day.totalCarbG))g carb, \(Int(day.totalFatG))g fat")
            }
        }
        guard !lines.isEmpty else {
            return AgentToolOutcome(resultForModel: "No logged days in that range.", toolNote: nil, linkedFoodEntryID: nil)
        }
        return AgentToolOutcome(resultForModel: lines.joined(separator: "\n"), toolNote: nil, linkedFoodEntryID: nil)
    }

    // MARK: - estimate_goals

    private static func estimateGoals(_ input: JSONValue, context: AgentToolContext) -> AgentToolOutcome {
        guard
            let sex = input["sex"]?.stringValue.flatMap(MacroGoals.Sex.init(rawValue:)),
            let age = input["ageYears"]?.intValue,
            let height = input["heightCm"]?.doubleValue,
            let weight = input["weightKg"]?.doubleValue,
            let activity = input["activityLevel"]?.stringValue.flatMap(MacroGoals.ActivityLevel.init(rawValue:)),
            let goal = input["weightGoal"]?.stringValue.flatMap(MacroGoals.WeightGoal.init(rawValue:))
        else {
            return AgentToolOutcome(resultForModel: "Missing/invalid inputs for estimate_goals.", toolNote: nil, linkedFoodEntryID: nil)
        }

        let goals = MacroGoals.estimate(sex: sex, ageYears: age, heightCm: height, weightKg: weight, activity: activity, goal: goal)
        context.profile.goals = goals
        context.day.calorieGoal = goals.calories
        context.day.proteinGoal = goals.proteinG
        context.day.carbGoal = goals.carbG
        context.day.fatGoal = goals.fatG
        try? context.modelContext.save()

        let note = "Set daily goal to \(goals.calories) cal"
        let result = "Saved goals: \(goals.calories) cal, \(goals.proteinG)g protein, \(goals.carbG)g carb, \(goals.fatG)g fat."
        return AgentToolOutcome(resultForModel: result, toolNote: note, linkedFoodEntryID: nil)
    }

    // MARK: - Image generation kickoff

    @MainActor
    private static func beginImageGeneration(
        for entry: FoodEntry,
        description: String,
        provider: ImageProviderKind,
        modelContext: ModelContext
    ) {
        let entryID = entry.id
        entry.imageState = .generating
        try? modelContext.save()

        Task {
            do {
                let path = try await ImageGenerationService.shared.image(
                    signature: entry.imageSignature,
                    foodDescription: description,
                    provider: provider
                )
                await MainActor.run {
                    guard let live = fetchEntry(id: entryID, modelContext: modelContext) else { return }
                    live.localImagePath = path
                    live.imageState = .ready
                    try? modelContext.save()
                    HapticsEngine.photoDeveloped()
                }
            } catch {
                await MainActor.run {
                    guard let live = fetchEntry(id: entryID, modelContext: modelContext) else { return }
                    live.imageState = .failed
                    try? modelContext.save()
                }
            }
        }
    }

    @MainActor
    private static func fetchEntry(id: UUID, modelContext: ModelContext) -> FoodEntry? {
        var descriptor = FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
