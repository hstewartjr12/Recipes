import Foundation
import SwiftData

@Model
final class Favorite {
    @Attribute(.unique) var recipeID: String
    var recipeData: Data?
    
    init(recipeID: String) {
        self.recipeID = recipeID
    }

    init(recipe: Recipe) {
        recipeID = recipe.id
        recipeData = try? JSONEncoder().encode(recipe)
    }

    var recipe: Recipe? {
        recipeData.flatMap { try? JSONDecoder().decode(Recipe.self, from: $0) }
    }
}
