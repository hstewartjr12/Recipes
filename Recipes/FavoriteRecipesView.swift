import SwiftUI

struct FavoriteRecipesView: View {
    let recipes: [Recipe]
    let favoriteIDs: Set<String>
    let hasSavedRecipes: Bool
    let onClearSearch: () -> Void
    let onToggleFavorite: (Recipe) -> Void
    var body: some View {
        if recipes.isEmpty {
            ContentUnavailableView {
                Label(hasSavedRecipes ? "No matching saves" : "Make it your own", systemImage: "bookmark")
            } description: {
                Text(hasSavedRecipes ? "Try another dish, cuisine, or ingredient." : "Save a recipe in Discover to start your cookbook. Saved ingredients and directions stay available offline.")
            } actions: {
                if hasSavedRecipes { Button("Clear search", action: onClearSearch).buttonStyle(.borderedProminent) }
            }
                .padding(.vertical, 40)
        } else {
            Text("\(recipes.count) saved \(recipes.count == 1 ? "recipe" : "recipes")").font(.subheadline).foregroundStyle(.secondary)
            RecipeGrid(recipes: recipes, favoriteIDs: favoriteIDs, onToggleFavorite: onToggleFavorite)
        }
    }
}
