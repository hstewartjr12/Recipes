//
//  RecipeDetail.swift
//  Recipes
//
//  Created by Henry Stewart on 5/17/25.
//

import SwiftUI

struct RecipeDetail: View {
    let recipe: Recipe
    
    var body: some View {
        VStack {
            Text(recipe.name)
                .font(.title)
                .fontWeight(.bold)
            AsyncImage(url: URL(string: recipe.photo_url_large)) { image in
                image.resizable()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 350, height: 350)
            HStack {
                if recipe.source_url != nil {
                    Link("Source", destination: URL(string: recipe.source_url!)!)
                        .buttonStyle(.borderedProminent)
                        .padding()
                }
                if recipe.youtube_url != nil {
                    Link("YouTube", destination: URL(string: recipe.youtube_url!)!)
                        .buttonStyle(.borderedProminent)
                        .padding()
                }
            }
            Spacer()
        }
    }
}

#Preview {
}
