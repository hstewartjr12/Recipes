//
//  RecipesApp.swift
//  Recipes
//
//  Created by Henry Stewart on 5/16/25.
//

import SwiftUI
import SwiftData

@main
struct RecipesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: Favorite.self)
        }
    }
}
