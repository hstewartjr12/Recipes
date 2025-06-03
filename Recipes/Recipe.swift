//
//  Recipe.swift
//  Recipes
//
//  Created by Henry Stewart on 5/16/25.
//

import Foundation

struct Recipe: Codable, Identifiable {
    let cuisine: String
    let name: String
    let photo_url_large: String
    let photo_url_small: String
    let source_url: String?
    let id: String
    let youtube_url: String?
    
    private enum CodingKeys: String, CodingKey {
        case cuisine
        case name
        case photo_url_large
        case photo_url_small
        case source_url
        case id = "uuid"
        case youtube_url
    }
}


extension Recipe {
    /// Convenience sample data used for SwiftUI previews.
    static let sample = Recipe(
        cuisine: "Italian",
        name: "Chicken Parmesan",
        photo_url_large: "https://example.com/large.jpg",
        photo_url_small: "https://example.com/small.jpg",
        source_url: "https://example.com",
        id: UUID().uuidString,
        youtube_url: "https://youtube.com/watch?v=1234"
    )
}

struct RecipesJSONResponse: Codable {
    let recipes: [Recipe]
}
