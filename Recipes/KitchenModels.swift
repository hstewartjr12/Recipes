import Foundation
import SwiftData

@Model final class PlannedMeal {
    var recipeData: Data
    var plannedDate: Date
    var cookedAt: Date?

    init(recipe: Recipe, date: Date) throws {
        recipeData = try JSONEncoder().encode(recipe)
        plannedDate = Calendar.current.startOfDay(for: date)
    }
    var recipe: Recipe? { try? JSONDecoder().decode(Recipe.self, from: recipeData) }
}

@Model final class ShoppingItem {
    var name: String
    var measure: String
    var recipeName: String
    var recipeID: String
    var checked: Bool = false
    var createdAt: Date = Date()

    init(name: String, measure: String = "", recipeName: String = "", recipeID: String = "") {
        self.name = name; self.measure = measure; self.recipeName = recipeName; self.recipeID = recipeID
    }
    var display: String { [measure, name].filter { !$0.isEmpty }.joined(separator: " ") }
}

@Model final class KitchenNote {
    @Attribute(.unique) var recipeID: String
    var notes: String = ""
    var cookedCount: Int = 0
    var lastCooked: Date?
    init(recipeID: String) { self.recipeID = recipeID }
}


@Model final class CookingEvent {
    var recipeID: String
    var cookedAt: Date
    var plan: PlannedMeal?
    init(recipeID: String, date: Date, plan: PlannedMeal?) {
        self.recipeID = recipeID; cookedAt = date; self.plan = plan
    }
}

@MainActor enum CookingHistory {
    @discardableResult static func log(recipeID: String, plan: PlannedMeal? = nil, context: ModelContext, now: Date = Date()) throws -> Bool {
        guard plan?.cookedAt == nil else { return false }
        do {
            let record = try context.fetch(FetchDescriptor<KitchenNote>()).first { $0.recipeID == recipeID } ?? KitchenNote(recipeID: recipeID)
            if record.modelContext == nil { context.insert(record) }
            context.insert(CookingEvent(recipeID: recipeID, date: now, plan: plan))
            record.cookedCount += 1; record.lastCooked = now; plan?.cookedAt = now
            try context.save(); return true
        } catch { context.rollback(); throw error }
    }

    static func undo(plan: PlannedMeal, context: ModelContext) throws {
        guard plan.cookedAt != nil, let recipeID = plan.recipe?.id else { return }
        do {
            let events = try context.fetch(FetchDescriptor<CookingEvent>())
            let event = events.first { $0.plan?.persistentModelID == plan.persistentModelID }
            if let record = try context.fetch(FetchDescriptor<KitchenNote>()).first(where: { $0.recipeID == recipeID }) {
                record.cookedCount = max(0, record.cookedCount - 1)
                let otherDates = events.filter { $0.recipeID == recipeID && $0.persistentModelID != event?.persistentModelID }.map(\.cookedAt)
                record.lastCooked = record.cookedCount == 0 ? nil : otherDates.max()
            }
            if let event { context.delete(event) }
            plan.cookedAt = nil; try context.save()
        } catch { context.rollback(); throw error }
    }
}
