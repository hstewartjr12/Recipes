import Foundation
import SwiftData
import Testing
@testable import Recipes

@MainActor struct RecipesTests {
    func container() throws -> ModelContainer {
        try ModelContainer(for: Favorite.self, PlannedMeal.self, ShoppingItem.self, KitchenNote.self, CookingEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test func legacyCatalogueStillDecodes() throws {
        let data = Data(#"{"recipes":[{"cuisine":"Mexican","name":"Tacos","photo_url_large":"","photo_url_small":"","uuid":"old-id"}]}"#.utf8)
        let recipe = try JSONDecoder().decode(RecipesJSONResponse.self, from: data).recipes[0]
        #expect(recipe.id == "old-id")
        #expect(recipe.ingredients.isEmpty)
        #expect(recipe.instructions.isEmpty)
    }

    @Test func mealDBDecodesIngredientsAndIgnoresNumberOnlyLines() throws {
        let data = Data(#"{"meals":[{"idMeal":"42","strMeal":"  Soup  ","strArea":"French","strCategory":"Starter","strIngredient1":" Onion ","strMeasure1":" 2 ","strIngredient2":" ","strInstructions":"1\r\nChop the onions.\r\n\r\n2\r\nSimmer gently.","strSource":"javascript:alert(1)"}]}"#.utf8)
        let recipe = try JSONDecoder().decode(MealDBResponse.self, from: data).meals![0].recipe
        #expect(recipe.id == "mealdb-42")
        #expect(recipe.name == "Soup")
        #expect(recipe.ingredients == [.init(name: "Onion", measure: "2")])
        #expect(recipe.instructions == ["Chop the onions.", "Simmer gently."])
        #expect(recipe.sourceURL == nil)
    }

    @Test func nullResultsAreValidButMissingMealIdentityIsRejected() throws {
        #expect(try JSONDecoder().decode(MealDBResponse.self, from: Data(#"{"meals":null}"#.utf8)).meals == nil)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(MealDBResponse.self, from: Data(#"{"meals":[{"strMeal":"Soup"}]}"#.utf8))
        }
    }

    @Test func duplicateRecipesAreMergedByIdentity() {
        let recipe = Recipe.sample
        #expect(RecipeCatalog.unique([recipe, recipe]).count == 1)
    }

    @Test func cookbookRetainsRecipeDetailsAndLegacyFavoriteIDs() throws {
        let store = try container()
        let context = ModelContext(store)
        context.insert(Favorite(recipe: .sample))
        context.insert(Favorite(recipeID: "original-api-uuid"))
        try context.save()
        let freshContext = ModelContext(store)
        let records = try freshContext.fetch(FetchDescriptor<Favorite>())
        #expect(records.count == 2)
        #expect(records.first { $0.recipeID == Recipe.sample.id }?.recipe == .sample)
        #expect(records.first { $0.recipeID == "original-api-uuid" }?.recipe == nil)
    }

    @Test func mealPlansKeepTheirRecipeAndNormalizeTheDay() throws {
        let store = try container(), context = ModelContext(store)
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        context.insert(try PlannedMeal(recipe: .sample, date: date))
        try context.save()
        let plan = try ModelContext(store).fetch(FetchDescriptor<PlannedMeal>())[0]
        #expect(plan.recipe == .sample)
        #expect(plan.plannedDate == Calendar.current.startOfDay(for: date))
    }

    @Test func groceryAndCookingNotesSurviveAContextReload() throws {
        let store = try container(), context = ModelContext(store)
        let item = ShoppingItem(name: "Pasta", measure: "200 g", recipeName: "Dinner", recipeID: "one")
        item.checked = true; context.insert(item)
        let note = KitchenNote(recipeID: "one"); note.notes = "Try more basil"; note.cookedCount = 2; context.insert(note)
        try context.save()
        let reloaded = ModelContext(store)
        #expect(try reloaded.fetch(FetchDescriptor<ShoppingItem>())[0].display == "200 g Pasta")
        #expect(try reloaded.fetch(FetchDescriptor<ShoppingItem>())[0].checked)
        #expect(try reloaded.fetch(FetchDescriptor<KitchenNote>())[0].notes == "Try more basil")
        #expect(try reloaded.fetch(FetchDescriptor<KitchenNote>())[0].cookedCount == 2)
    }

    @Test func plannedCookingIsIdempotentAndLeavesNotesAlone() throws {
        let store = try container(), context = ModelContext(store)
        let plan = try PlannedMeal(recipe: .sample, date: Date()); context.insert(plan)
        let note = KitchenNote(recipeID: Recipe.sample.id); note.notes = "Saved by another view"; context.insert(note)
        #expect(try CookingHistory.log(recipeID: Recipe.sample.id, plan: plan, context: context))
        #expect(!(try CookingHistory.log(recipeID: Recipe.sample.id, plan: plan, context: context)))
        #expect(note.cookedCount == 1)
        #expect(note.notes == "Saved by another view")
        #expect(plan.cookedAt != nil)
        #expect(try context.fetch(FetchDescriptor<CookingEvent>()).count == 1)
    }

    @Test func undoPreservesAnEarlierStandaloneCook() throws {
        let store = try container(), context = ModelContext(store)
        let first = Date(timeIntervalSince1970: 100), second = Date(timeIntervalSince1970: 200)
        try CookingHistory.log(recipeID: Recipe.sample.id, context: context, now: first)
        let plan = try PlannedMeal(recipe: .sample, date: second); context.insert(plan)
        try CookingHistory.log(recipeID: Recipe.sample.id, plan: plan, context: context, now: second)
        try CookingHistory.undo(plan: plan, context: context)
        let note = try context.fetch(FetchDescriptor<KitchenNote>())[0]
        #expect(note.cookedCount == 1)
        #expect(note.lastCooked == first)
        #expect(plan.cookedAt == nil)
        #expect(try context.fetch(FetchDescriptor<CookingEvent>()).count == 1)
    }

    @Test func undoAnOlderPlanKeepsTheLatestCookDate() throws {
        let store = try container(), context = ModelContext(store)
        let first = Date(timeIntervalSince1970: 100), second = Date(timeIntervalSince1970: 200)
        let plan = try PlannedMeal(recipe: .sample, date: first); context.insert(plan)
        try CookingHistory.log(recipeID: Recipe.sample.id, plan: plan, context: context, now: first)
        try CookingHistory.log(recipeID: Recipe.sample.id, context: context, now: second)
        try CookingHistory.undo(plan: plan, context: context)
        let note = try context.fetch(FetchDescriptor<KitchenNote>())[0]
        #expect(note.cookedCount == 1)
        #expect(note.lastCooked == second)
    }

    @Test func cacheRestoresCatalogueBeforeNetworkAccess() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        try JSONEncoder().encode(RecipeCatalog.Cache(recipes: [.sample], savedAt: date)).write(to: url)
        let catalog = RecipeCatalog(cacheURL: url)
        #expect(catalog.recipes == [.sample])
        #expect(catalog.lastUpdated == date)
        #expect(!catalog.isLoading)
    }
    @Test func instructionMarkersBecomeFourRealCookSteps() {
        let source = "step 1\r\nTo make the stock, add 2 litres of water.\r\n\r\nSTEP 2\r\nCook for 10-15 mins.\r\n\r\nStep 3:\r\nAdd the vegetables.\r\n\r\nstep 4\r\nServe with bread."
        #expect(Recipe.instructionSteps(from: source) == [
            "To make the stock, add 2 litres of water.", "Cook for 10-15 mins.", "Add the vegetables.", "Serve with bread."
        ])
    }

    @Test func numberedInstructionsPreserveQuantitiesAndContinuationLines() {
        let source = "1. Add 1.5 litres of stock.\nStir until combined.\n\n2) Bake at 180°C.\n3\n2 tablespoons of oil go in last."
        #expect(Recipe.instructionSteps(from: source) == [
            "Add 1.5 litres of stock.\nStir until combined.", "Bake at 180°C.", "2 tablespoons of oil go in last."
        ])
        #expect(Recipe.instructionSteps(from: "1.5 litres of stock\n2 tablespoons of oil\n10-15 mins of cooking") == [
            "1.5 litres of stock", "2 tablespoons of oil", "10-15 mins of cooking"
        ])
    }

    @Test func storedRecipeDirectionsAreCleanedWithoutChangingTheirMeaning() throws {
        let recipe = Recipe(cuisine: "Test", name: "Soup", photo_url_large: "", photo_url_small: "", source_url: nil, id: "soup", youtube_url: nil)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(recipe)) as? [String: Any])
        object["instructions"] = ["step 1", "Add the stock.", "step 2", "Simmer for 15 mins."]
        let decoded = try JSONDecoder().decode(Recipe.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.instructions == ["Add the stock.", "Simmer for 15 mins."])
    }

    @Test func wrappedAPIDirectionsKeepTheirStepsThroughSnapshotsAndReloads() throws {
        let source = "STEP 1\r\nAdd 1.5 litres of stock.\r\nStir until combined.\r\n\r\nSTEP 2\r\nBake at 180°C.\r\nServe with bread."
        let data = try JSONSerialization.data(withJSONObject: ["meals": [[
            "idMeal": "wrapped-directions", "strMeal": "Wrapped soup", "strInstructions": source
        ]]])
        let recipe = try #require(JSONDecoder().decode(MealDBResponse.self, from: data).meals?.first?.recipe)
        let expected = ["Add 1.5 litres of stock.\nStir until combined.", "Bake at 180°C.\nServe with bread."]
        #expect(recipe.instructions == expected)
        let reopenedRecipe = try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(recipe))
        #expect(reopenedRecipe.instructions == expected)

        let store = try container(), context = ModelContext(store)
        context.insert(Favorite(recipe: recipe))
        context.insert(try PlannedMeal(recipe: recipe, date: Date()))
        try context.save()
        let reopenedContext = ModelContext(store)
        #expect(try reopenedContext.fetch(FetchDescriptor<Favorite>()).first?.recipe?.instructions == expected)
        #expect(try reopenedContext.fetch(FetchDescriptor<PlannedMeal>()).first?.recipe?.instructions == expected)
    }

    @Test func existingStepArraysPreserveEmbeddedParagraphs() throws {
        let steps = ["  Chop the vegetables.\nStir in the oil.\n\nFold gently.  ", "  Simmer for 10 mins.  "]
        let expected = ["Chop the vegetables.\nStir in the oil.\n\nFold gently.", "Simmer for 10 mins."]
        let recipe = Recipe(cuisine: "Test", name: "Soup", photo_url_large: "", photo_url_small: "", source_url: nil, id: "wrapped-soup", youtube_url: nil, instructions: steps)
        #expect(recipe.instructions == expected)
        #expect(try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(recipe)).instructions == expected)
    }

}
