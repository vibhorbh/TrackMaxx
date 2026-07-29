//
//  CoreLogicTests.swift
//  CalorieAITests
//
//  Pure-logic unit tests using Swift Testing (no UI, no network, no
//  Bundle-resource dependency) — the parts of the app that are cheapest and
//  most valuable to keep correct with automated coverage: JSON bridging,
//  goal math, signature normalization, and serving-size scaling.
//

import Testing
import Foundation
@testable import CalorieAI

@Suite("JSONValue")
struct JSONValueTests {
    @Test("Round-trips a mixed object through encode/decode")
    func roundTrip() throws {
        let json = """
        {"name":"Banana","calories":105,"ripe":true,"tags":["fruit","snack"],"note":null}
        """
        let data = Data(json.utf8)
        let value = JSONValue.parse(data)

        #expect(value["name"]?.stringValue == "Banana")
        #expect(value["calories"]?.intValue == 105)
        #expect(value["ripe"]?.boolValue == true)
        #expect(value["tags"]?.arrayValue?.count == 2)
        #expect(value["note"] == .null || value["note"] == nil)
    }

    @Test("Empty/invalid input parses to an empty object, not a crash")
    func emptyInputIsSafe() {
        let value = JSONValue.parse(Data())
        #expect(value.objectValue?.isEmpty == true)
    }

    @Test("Bridges JSONSerialization Any values correctly")
    func bridgesFoundationTypes() {
        let any: [String: Any] = ["a": 1, "b": "two", "c": true, "d": [1, 2, 3]]
        let value = JSONValue(any: any)
        #expect(value["a"]?.intValue == 1)
        #expect(value["b"]?.stringValue == "two")
        #expect(value["c"]?.boolValue == true)
        #expect(value["d"]?.arrayValue?.count == 3)
    }
}

@Suite("MacroGoals.estimate")
struct MacroGoalsEstimateTests {
    @Test("Produces sane, positive numbers for a typical input")
    func sanePositiveOutput() {
        let goals = MacroGoals.estimate(
            sex: .female, ageYears: 30, heightCm: 165, weightKg: 62,
            activity: .moderate, goal: .maintain
        )
        #expect(goals.calories > 1200 && goals.calories < 3500)
        #expect(goals.proteinG > 0)
        #expect(goals.carbG > 0)
        #expect(goals.fatG > 0)
    }

    @Test("A 'lose' goal yields fewer calories than 'gain' for identical stats")
    func loseIsLowerThanGain() {
        let base: (MacroGoals.Sex, Int, Double, Double, MacroGoals.ActivityLevel) = (.male, 35, 178, 80, .active)
        let losing = MacroGoals.estimate(sex: base.0, ageYears: base.1, heightCm: base.2, weightKg: base.3, activity: base.4, goal: .lose)
        let gaining = MacroGoals.estimate(sex: base.0, ageYears: base.1, heightCm: base.2, weightKg: base.3, activity: base.4, goal: .gain)
        #expect(losing.calories < gaining.calories)
    }

    @Test("More active yields more calories at the same weight goal")
    func moreActiveYieldsMoreCalories() {
        let sedentary = MacroGoals.estimate(sex: .male, ageYears: 40, heightCm: 175, weightKg: 75, activity: .sedentary, goal: .maintain)
        let veryActive = MacroGoals.estimate(sex: .male, ageYears: 40, heightCm: 175, weightKg: 75, activity: .veryActive, goal: .maintain)
        #expect(veryActive.calories > sedentary.calories)
    }
}

@Suite("FoodEntry.signature")
struct FoodEntrySignatureTests {
    @Test("Normalizes case, punctuation, and whitespace consistently")
    func normalizesConsistently() {
        #expect(FoodEntry.signature(for: "Grilled Chicken Bowl") == "grilled-chicken-bowl")
        #expect(FoodEntry.signature(for: "  Grilled   Chicken Bowl!! ") == "grilled-chicken-bowl")
        #expect(FoodEntry.signature(for: "Banana") == FoodEntry.signature(for: "banana"))
    }

    @Test("Never returns an empty signature")
    func neverEmpty() {
        #expect(!FoodEntry.signature(for: "").isEmpty)
        #expect(!FoodEntry.signature(for: "!!!").isEmpty)
    }
}

@Suite("NutritionInfo.scaled(by:)")
struct NutritionInfoScalingTests {
    @Test("Scaling by 1 is a no-op; scaling by 2 doubles every field")
    func scalesLinearly() {
        let base = NutritionInfo(
            name: "Test Food", servingDescription: "1 serving", calories: 200,
            proteinG: 10, carbG: 20, fatG: 5, aliases: []
        )
        let unscaled = base.scaled(by: 1)
        #expect(unscaled.calories == 200)
        #expect(unscaled.proteinG == 10)

        let doubled = base.scaled(by: 2)
        #expect(doubled.calories == 400)
        #expect(doubled.proteinG == 20)
        #expect(doubled.carbG == 40)
        #expect(doubled.fatG == 10)
    }

    @Test("Half servings round sensibly")
    func halfServing() {
        let base = NutritionInfo(
            name: "Test Food", servingDescription: "1 serving", calories: 101,
            proteinG: 3.3, carbG: 7.7, fatG: 1.1, aliases: []
        )
        let half = base.scaled(by: 0.5)
        #expect(half.calories == 51) // 50.5 rounded
        #expect(abs(half.proteinG - 1.65) < 0.05)
    }
}
