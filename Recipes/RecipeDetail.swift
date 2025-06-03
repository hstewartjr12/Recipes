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
                if let source = recipe.source_url,
                   let url = URL(string: source) {
                    Link("Source", destination: url)
                        .buttonStyle(.borderedProminent)
                        .padding()
                }
                if let youtube = recipe.youtube_url,
                   let url = URL(string: youtube) {
                    Link("YouTube", destination: url)
                        .buttonStyle(.borderedProminent)
                        .padding()
                }
            }
            Spacer()
        }
    }
}

#Preview {
    RecipeDetail(recipe: .sample)
}
