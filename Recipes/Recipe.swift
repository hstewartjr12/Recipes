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

//extension Recipe {
//    static let sample = Recipe(cuisine: "Italian", name: "Chicken Parmesan", photo_url_large: "", photo_url_small: "", source_url: "Please provide a source URL", id: UUID().uuidString, youtube_url: "Please provide a YouTube URL")
//}

struct RecipesJSONResponse: Codable {
    let recipes: [Recipe]
}
