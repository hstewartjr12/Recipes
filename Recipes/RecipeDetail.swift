//
//  RecipeDetail.swift
//  Recipes
//
//  Created by Henry Stewart on 5/17/25.
//

import SwiftUI

struct RecipeDetail: View {
    let recipe: Recipe
    let favoriteIDs: Set<String>
    let onToggleFavorite: (Recipe) -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.orange.opacity(0.12), .accentColor.opacity(0.08), .white],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack(spacing: 18) {
                HStack(spacing: 14) {
                    Text(recipe.name)
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(LinearGradient(colors: [.accentColor, .orange], startPoint: .leading, endPoint: .trailing))
                        .shadow(radius: 3, x: 0, y: 2)
                    Button(action: { onToggleFavorite(recipe) }) {
                        Image(systemName: favoriteIDs.contains(recipe.id) ? "heart.fill" : "heart")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(10)
                            .background(Color.white.opacity(0.90))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                }
                .padding(.top, 18)
                Text(recipe.cuisine)
                    .font(.headline)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    AsyncImage(url: URL(string: recipe.photo_url_large)) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 290, height: 290)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.accentColor.opacity(0.13), lineWidth: 2))
                    } placeholder: {
                        ProgressView()
                            .frame(width: 290, height: 290)
                    }
                }
                .frame(width: 305, height: 305)
                Spacer().frame(height: 12)
                HStack(spacing: 20) {
                    if let source = recipe.source_url, let url = URL(string: source) {
                        Link(destination: url) {
                            Label("Source", systemImage: "book.fill")
                                .padding(10)
                                .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                    }
                    if let youtube = recipe.youtube_url, let url = URL(string: youtube) {
                        Link(destination: url) {
                            Label("YouTube", systemImage: "play.rectangle.fill")
                                .padding(10)
                                .background(Capsule().fill(Color.red.opacity(0.13)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 7)
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    RecipeDetail(recipe: .sample, favoriteIDs: [Recipe.sample.id], onToggleFavorite: { _ in })
}
