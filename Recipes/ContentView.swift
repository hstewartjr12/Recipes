import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var favorites: [Favorite]
    @State private var catalog = RecipeCatalog()
    @State private var search = ""
    @State private var cookbookSearch = ""
    @State private var cuisine = "All cuisines"
    @State private var category = "All dishes"
    @State private var sort = "A–Z"
    @State private var error: String?

    private var savedIDs: Set<String> { Set(favorites.map(\.recipeID)) }
    private var cookbook: [Recipe] {
        RecipeCatalog.unique(favorites.compactMap(\.recipe) + catalog.recipes.filter { savedIDs.contains($0.id) })
    }
    private var cuisines: [String] { ["All cuisines"] + Set(catalog.recipes.map(\.cuisine)).sorted() }
    private var categories: [String] { ["All dishes"] + Set(catalog.recipes.map(\.category).filter { !$0.isEmpty }).sorted() }
    private var shownRecipes: [Recipe] {
        filter(catalog.recipes).filter { (cuisine == "All cuisines" || $0.cuisine == cuisine) && (category == "All dishes" || $0.category == category) }
    }
    private func filter(_ recipes: [Recipe], query search: String? = nil) -> [Recipe] {
        let query = (search ?? self.search).trimmingCharacters(in: .whitespacesAndNewlines)
        return recipes.filter { recipe in
            query.isEmpty || ([recipe.name, recipe.cuisine, recipe.category] + recipe.ingredients.map(\.name))
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }.sorted { sort == "Cuisine" ? ($0.cuisine, $0.name) < ($1.cuisine, $1.name) : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        KitchenHeader(eyebrow: "A LITTLE INSPIRATION", title: "What sounds good?", subtitle: "Discover something worth making.")
                        if search.isEmpty, cuisine == "All cuisines", category == "All dishes", let recipe = featuredRecipe {
                            NavigationLink { RecipeDetail(recipe: recipe) } label: { FeaturedRecipe(recipe: recipe) }
                                .buttonStyle(.plain)
                        }
                        if let message = catalog.message { statusBanner(message) }
                        HStack {
                            Menu { ForEach(cuisines, id: \.self) { value in Button(value) { cuisine = value } } } label: { Label(cuisine, systemImage: "globe") }
                            Spacer()
                            Menu { ForEach(categories, id: \.self) { value in Button(value) { category = value } } } label: { Label(category, systemImage: "fork.knife") }
                        }
                        .font(.subheadline.weight(.medium))
                        HStack {
                            Text("Explore the kitchen").font(.title3.weight(.bold))
                            Spacer()
                            Menu { Button("A–Z") { sort = "A–Z" }; Button("Cuisine") { sort = "Cuisine" } } label: { Image(systemName: "arrow.up.arrow.down") }
                                .accessibilityLabel("Sort recipes, currently \(sort)")
                        }
                        if catalog.isLoading && catalog.recipes.isEmpty {
                            ProgressView("Opening the kitchen…").frame(maxWidth: .infinity).padding(50)
                        } else if shownRecipes.isEmpty {
                            ContentUnavailableView {
                                Label(catalog.recipes.isEmpty ? "The kitchen is quiet" : "No matching dishes", systemImage: "fork.knife")
                            } description: {
                                Text(catalog.recipes.isEmpty ? "Connect to load your first recipes." : "Try another ingredient, cuisine, or dish.")
                            } actions: {
                                Button(catalog.recipes.isEmpty ? "Try again" : "Clear filters") {
                                    if catalog.recipes.isEmpty { Task { await catalog.load(force: true) } }
                                    else { search = ""; cuisine = "All cuisines"; category = "All dishes" }
                                }.buttonStyle(.borderedProminent).tint(KitchenStyle.accentFill)
                            }
                        } else {
                            RecipeGrid(recipes: shownRecipes, favoriteIDs: savedIDs, onToggleFavorite: toggleFavorite)
                        }
                        Text("\(shownRecipes.count) recipes • Powered by TheMealDB")
                            .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                        Link("Recipe catalogue & attribution", destination: URL(string: "https://www.themealdb.com")!)
                            .font(.caption).frame(maxWidth: .infinity)
                    }.padding(20).frame(maxWidth: 1050).frame(maxWidth: .infinity)
                }
                .background(KitchenStyle.background)
                .navigationTitle("Discover").kitchenInlineTitle()
                .searchable(text: $search, prompt: "Dish, cuisine, or ingredient")
                .refreshable { await catalog.load(force: true) }
                .toolbar { ToolbarItem { Button { Task { await catalog.load(force: true) } } label: { Image(systemName: "arrow.clockwise") }.disabled(catalog.isLoading).accessibilityLabel("Refresh recipes") } }
            }.tabItem { Label("Discover", systemImage: "leaf") }

            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        KitchenHeader(eyebrow: "YOUR OWN COLLECTION", title: "The cookbook", subtitle: "The dishes you want to come back to.")
                        FavoriteRecipesView(recipes: filter(cookbook, query: cookbookSearch), favoriteIDs: savedIDs, hasSavedRecipes: !cookbook.isEmpty, onClearSearch: { cookbookSearch = "" }, onToggleFavorite: toggleFavorite)
                        let legacy = favorites.filter { favorite in favorite.recipe == nil && !catalog.recipes.contains(where: { $0.id == favorite.recipeID }) }
                        if !legacy.isEmpty {
                            Text("\(legacy.count) saves from the previous catalogue are retained. That service is no longer available; their IDs have not been deleted.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(20).frame(maxWidth: 1050).frame(maxWidth: .infinity)
                }.background(KitchenStyle.background)
                .navigationTitle("Cookbook").kitchenInlineTitle()
                .searchable(text: $cookbookSearch, prompt: "Search your saved recipes")
            }.tabItem { Label("Cookbook", systemImage: "book.closed") }

            NavigationStack { MealPlannerView() }.tabItem { Label("Plan", systemImage: "calendar") }
            NavigationStack { ShoppingListView() }.tabItem { Label("Shopping", systemImage: "basket") }
        }
        .task { await catalog.load() }
        .alert("Couldn't save your change", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private var featuredRecipe: Recipe? {
        guard !catalog.recipes.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return catalog.recipes.sorted { $0.id < $1.id }[day % catalog.recipes.count]
    }
    @ViewBuilder private func statusBanner(_ text: String) -> some View {
        Label(text, systemImage: "wifi.slash").font(.subheadline).foregroundStyle(.secondary)
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(KitchenStyle.surface, in: RoundedRectangle(cornerRadius: 16))
    }
    private func toggleFavorite(_ recipe: Recipe) {
        if let favorite = favorites.first(where: { $0.recipeID == recipe.id }) { context.delete(favorite) }
        else { context.insert(Favorite(recipe: recipe)) }
        do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription }
    }
}

#Preview {
    ContentView().modelContainer(for: [Favorite.self, PlannedMeal.self, ShoppingItem.self, KitchenNote.self, CookingEvent.self], inMemory: true)
}
