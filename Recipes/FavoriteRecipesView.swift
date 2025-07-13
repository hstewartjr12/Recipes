import SwiftUI

struct FavoriteRecipesView: View {
    let recipes: [Recipe]
    let favoriteIDs: Set<String>
    let onToggleFavorite: (Recipe) -> Void

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            LinearGradient.backgroundGradient
                .ignoresSafeArea()
            VStack(alignment: .leading) {
                Text("Favorites")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(LinearGradient(
                        colors: [.accentColor, .orange],
                        startPoint: .leading, endPoint: .trailing))
                    .shadow(radius: 3)
                Text("Your favorite recipes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
                if recipes.isEmpty || favoriteIDs.isEmpty {
                    ContentUnavailableView("No Favorites Yet", systemImage: "star.fill")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical) {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(recipes.filter { favoriteIDs.contains($0.id) }) { recipe in
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
                    .padding(.horizontal)
                }
            }
            .padding()
        }
    }
}
