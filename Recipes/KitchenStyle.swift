import SwiftUI

#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum KitchenStyle {
    static let accent = Color("AccentColor")
    // Keep white labels readable while text and icon accents adapt to the appearance.
    static let accentFill = Color(red: 0.23, green: 0.40, blue: 0.28)
    static var background: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }
    static var surface: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }
}

struct KitchenHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow).font(.caption2.weight(.bold)).tracking(2).foregroundStyle(KitchenStyle.accent)
            Text(title).font(.system(.largeTitle, design: .serif).weight(.bold))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RecipePhoto: View {
    let recipe: Recipe
    var body: some View {
        AsyncImage(url: Recipe.webURL(recipe.photo_url_large)) { phase in
            if let image = phase.image { image.resizable().scaledToFill() }
            else {
                Rectangle().fill(KitchenStyle.accent.opacity(0.12))
                    .overlay { Image(systemName: "fork.knife").font(.largeTitle).foregroundStyle(KitchenStyle.accent.opacity(0.5)) }
            }
        }.accessibilityHidden(true)
    }
}

struct FeaturedRecipe: View {
    let recipe: Recipe
    var body: some View {
        RecipePhoto(recipe: recipe)
            .frame(height: 230).clipped()
            .overlay { LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .top, endPoint: .bottom) }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TODAY'S INSPIRATION").font(.caption2.weight(.bold)).tracking(2)
                    Text(recipe.name).font(.system(.title, design: .serif).weight(.semibold)).lineLimit(2)
                    Label([recipe.cuisine, recipe.category].filter { !$0.isEmpty }.joined(separator: " · "), systemImage: "arrow.up.right")
                        .font(.subheadline)
                }.foregroundStyle(.white).padding(22)
            }.clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct RecipeGrid: View {
    let recipes: [Recipe]
    let favoriteIDs: Set<String>
    let onToggleFavorite: (Recipe) -> Void
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 16)], alignment: .leading, spacing: 20) {
            ForEach(recipes) { recipe in
                VStack(alignment: .leading, spacing: 0) {
                    NavigationLink { RecipeDetail(recipe: recipe) } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            RecipePhoto(recipe: recipe).frame(height: 145).clipped()
                            VStack(alignment: .leading, spacing: 6) {
                                Text(recipe.cuisine.uppercased()).font(.caption2.weight(.bold)).tracking(1).foregroundStyle(KitchenStyle.accent)
                                Text(recipe.name).font(.system(.headline, design: .serif)).foregroundStyle(.primary).lineLimit(2).frame(height: 46, alignment: .topLeading)
                                Text(recipe.category.isEmpty ? "Recipe" : recipe.category).font(.caption).foregroundStyle(.secondary)
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.buttonStyle(.plain)
                }
                .background(KitchenStyle.surface)
                .overlay(alignment: .topTrailing) {
                    Button { onToggleFavorite(recipe) } label: {
                        Image(systemName: favoriteIDs.contains(recipe.id) ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(KitchenStyle.accent).frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                    }.buttonStyle(.plain).padding(8)
                        .accessibilityLabel(favoriteIDs.contains(recipe.id) ? "Remove \(recipe.name) from cookbook" : "Save \(recipe.name) to cookbook")
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }
}


extension View {
    @ViewBuilder func kitchenInlineTitle() -> some View {
        #if os(iOS) || os(visionOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
