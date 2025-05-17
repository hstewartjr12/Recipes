//
//  RecipesTests.swift
//  RecipesTests
//
//  Created by Henry Stewart on 5/16/25.
//
import Foundation
import Testing
@testable import Recipes

struct RecipesTests {

    @Test func testFetchDataSuccess() async throws {
            // Assume fetchData can be injected/mocked for testability
            let json = """
            {
              "recipes": [
                {
                  "cuisine": "Mexican", 
                  "name": "Tacos", 
                  "photo_url_large": "", 
                  "photo_url_small": "", 
                  "source_url": "Please provide a source URL", 
                  "uuid": "UUID().uuidString", 
                  "youtube_url": "Please provide a YouTube URL"
                }
              ]
            }
            """
            let data = json.data(using: .utf8)!
            // Simulate network call by directly decoding
            let decoded = try JSONDecoder().decode(RecipesJSONResponse.self, from: data)
            #expect(decoded.recipes.first?.name == "Tacos")
        }
    
    @Test func testEmptyRecipes() {
            let emptyResponse = RecipesJSONResponse(recipes: [])
            #expect(emptyResponse.recipes.isEmpty)
        }

}
