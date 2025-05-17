//
//  ContentView.swift
//  Recipes
//
//  Created by Henry Stewart on 5/16/25.
//

import SwiftUI

struct ContentView: View {
    @State private var recipes: [Recipe] = []
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    @State private var response: RecipesJSONResponse = .init(recipes: [])
    
    var body: some View {
        Group {
            NavigationStack {
                Text("Recipes")
                    .font(.largeTitle)
                    .padding()
                ScrollView(.vertical) {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(recipes) { recipe in
                            NavigationLink(destination: RecipeDetail(recipe: recipe)) {
                                VStack {
                                    AsyncImage(url: URL(string: recipe.photo_url_large)) { image in
                                        image.resizable()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 150, height: 150)
                                    HStack {
                                        Text(recipe.name).bold() + Text(": \(recipe.cuisine)")
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .refreshable {
                    do {
                        response = try await fetchData()
                        recipes = response.recipes
                    } catch {
                        // Handle the error appropriately (e.g., show an alert or log it)
                        print("Failed to fetch recipes:", error)
                    }
                }
            } .overlay {
                if recipes.isEmpty {
                    ContentUnavailableView("No Recipes Found", systemImage: "fork.knife.circle.fill")
                }
            } 
        } .task {
            do {
                response = try await fetchData()
                recipes = response.recipes
            } catch {
                // Handle the error appropriately (e.g., show an alert or log it)
                print("Failed to fetch recipes:", error)
            }
        }
    }
    
    func fetchData() async throws -> RecipesJSONResponse {
        let url = URL(string: "https://d3jbb8n5wk0qxi.cloudfront.net/recipes.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(RecipesJSONResponse.self, from: data)
    }
}



#Preview {
    ContentView()
}
