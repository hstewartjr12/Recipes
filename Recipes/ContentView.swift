//
//  ContentView.swift
//  Recipes
//
//  Created by Henry Stewart on 5/16/25.
//

import SwiftUI
import SwiftData

extension LinearGradient {
    static let backgroundGradient = LinearGradient(
        colors: [Color.accentColor.opacity(0.25), .orange.opacity(0.12), .white],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var recipes: [Recipe] = []
    @State private var response: RecipesJSONResponse = .init(recipes: [])
    @Query(sort: \Favorite.recipeID) private var favorites: [Favorite]
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var favoriteIDs: Set<String> { Set(favorites.map { $0.recipeID }) }
    
    var body: some View {
        TabView {
            NavigationStack {
                HomeRecipesGrid(
                    recipes: recipes,
                    favoriteIDs: favoriteIDs,
                    onToggleFavorite: toggleFavorite
                )
                .navigationTitle("")
                .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            
            NavigationStack {
                FavoriteRecipesView(
                    recipes: recipes,
                    favoriteIDs: favoriteIDs,
                    onToggleFavorite: toggleFavorite
                )
                .navigationTitle("")
                .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem {
                Label("Favorites", systemImage: "heart.fill")
            }
        }
        .task {
            do {
                response = try await fetchData()
                recipes = response.recipes
            } catch {
                print("Failed to fetch recipes:", error)
            }
        }
    }
    
    func toggleFavorite(_ recipe: Recipe) {
        if let favorite = favorites.first(where: { $0.recipeID == recipe.id }) {
            modelContext.delete(favorite)
        } else {
            let newFavorite = Favorite(recipeID: recipe.id)
            modelContext.insert(newFavorite)
        }
    }
    
    func fetchData() async throws -> RecipesJSONResponse {
        let url = URL(string: "https://d3jbb8n5wk0qxi.cloudfront.net/recipes.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(RecipesJSONResponse.self, from: data)
    }
}

struct HomeRecipesGrid: View {
    let recipes: [Recipe]
    let favoriteIDs: Set<String>
    let onToggleFavorite: (Recipe) -> Void
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ZStack {
            LinearGradient.backgroundGradient
                .ignoresSafeArea()
            VStack(spacing: 4) {
                Text("Recipes")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(LinearGradient(
                        colors: [.accentColor, .orange],
                        startPoint: .leading, endPoint: .trailing))
                    .shadow(radius: 3)
                Text("Discover & cook delicious meals")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
                ScrollView(.vertical) {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(recipes) { recipe in
                            NavigationLink(destination: RecipeDetail(recipe: recipe)) {
                                ZStack(alignment: .topTrailing) {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(.ultraThickMaterial)
                                        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
                                    VStack(alignment: .leading, spacing: 10) {
                                        ZStack(alignment: .topTrailing) {
                                            AsyncImage(url: URL(string: recipe.photo_url_large)) { image in
                                                image.resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 150, height: 150)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                                    .overlay(
                                                        LinearGradient(colors: [.clear, Color.black.opacity(0.15)], startPoint: .top, endPoint: .bottom)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                    )
                                            } placeholder: {
                                                ProgressView()
                                                    .frame(width: 150, height: 150)
                                            }
                                            Button(action: { onToggleFavorite(recipe) }) {
                                                Image(systemName: favoriteIDs.contains(recipe.id) ? "heart.fill" : "heart")
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor(.red.opacity(0.7))
                                                    .padding(8)
                                                    .background(Color.white.opacity(0.85))
                                                    .clipShape(Circle())
                                                    .shadow(radius: 2)
                                            }
                                            .padding([.top, .trailing], 8)
                                        }
                                        Text(recipe.name)
                                            .font(.headline)
                                            .bold()
                                            .foregroundColor(Color.primary)
                                        Text(recipe.cuisine)
                                            .font(.subheadline)
                                            .foregroundColor(.accentColor)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                                        Spacer(minLength: 10)
                                    }
                                    .padding(10)
                                }
                                .padding(6)
                            }
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    ContentView()
}
