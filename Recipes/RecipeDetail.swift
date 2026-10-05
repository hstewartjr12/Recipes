import SwiftUI
import SwiftData

struct RecipeDetail: View {
    let recipe: Recipe
    var plannedMeal: PlannedMeal? = nil
    @Environment(\.modelContext) private var context
    @Query private var favorites: [Favorite]
    @Query private var shopping: [ShoppingItem]
    @Query private var notes: [KitchenNote]
    @State private var showPlan = false
    @State private var showCooking = false
    @State private var draft = ""
    @State private var feedback: String?
    @State private var error: String?
    private var isFavorite: Bool { favorites.contains { $0.recipeID == recipe.id } }
    private var note: KitchenNote? { notes.first { $0.recipeID == recipe.id } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RecipePhoto(recipe: recipe).frame(height: 260).clipped().clipShape(RoundedRectangle(cornerRadius: 24))
                KitchenHeader(eyebrow: recipe.cuisine.uppercased(), title: recipe.name, subtitle: recipe.category)
                HStack(spacing: 12) {
                    Button { showPlan = true } label: { Label("Plan a meal", systemImage: "calendar.badge.plus") }.buttonStyle(.borderedProminent).tint(KitchenStyle.accentFill)
                    Button { toggleSave() } label: { Label(isFavorite ? "Saved" : "Save", systemImage: isFavorite ? "bookmark.fill" : "bookmark") }.buttonStyle(.bordered)
                }
                if let feedback { Label(feedback, systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(KitchenStyle.accent) }
                if !recipe.ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("What you'll need").font(.system(.title2, design: .serif).bold())
                            Spacer()
                            Button { addIngredients() } label: { Image(systemName: "basket.badge.plus") }.accessibilityLabel("Add ingredients to shopping list")
                        }
                        ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, ingredient in
                            HStack(alignment: .top) {
                                Image(systemName: "circle").font(.caption).foregroundStyle(KitchenStyle.accent).padding(.top, 4)
                                Text(ingredient.name).frame(maxWidth: .infinity, alignment: .leading)
                                Text(ingredient.measure).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                            }
                        }
                        Button { addIngredients() } label: { Label("Add to shopping list", systemImage: "basket") }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                    }.padding(20).background(KitchenStyle.surface, in: RoundedRectangle(cornerRadius: 20))
                }
                if !recipe.instructions.isEmpty {
                    HStack {
                        Text("Let's make it").font(.system(.title2, design: .serif).bold())
                        Spacer()
                        Button("Cook mode") { showCooking = true }.font(.subheadline.weight(.semibold))
                    }
                    ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(index + 1)").font(.subheadline.bold()).foregroundStyle(KitchenStyle.accent)
                                .frame(width: 32, height: 32).background(KitchenStyle.accent.opacity(0.12), in: Circle())
                            Text(step).font(.body).lineSpacing(4).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your kitchen notes").font(.system(.title2, design: .serif).bold())
                    TextField("Substitutions, tips, things to try next time…", text: $draft, axis: .vertical).lineLimit(3...8)
                        .padding(14).background(KitchenStyle.surface, in: RoundedRectangle(cornerRadius: 14))
                    HStack {
                        Button("Save notes") { saveNotes() }.buttonStyle(.bordered)
                        Spacer()
                        Button { logCook() } label: { Label("I made this", systemImage: "checkmark.seal") }.buttonStyle(.bordered)
                    }
                    if let note, note.cookedCount > 0 {
                        Text("Made \(note.cookedCount) \(note.cookedCount == 1 ? "time" : "times")\(note.lastCooked.map { " · Last cooked " + $0.formatted(date: .abbreviated, time: .omitted) } ?? "")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    if let url = recipe.sourceURL { Link(destination: url) { Label("Read the original recipe", systemImage: "arrow.up.right.square") } }
                    if let url = recipe.videoURL { Link(destination: url) { Label("Watch the recipe video", systemImage: "play.rectangle") } }
                    ShareLink(item: shareText) { Label("Share recipe", systemImage: "square.and.arrow.up") }
                    Text("Recipe and photo provided by TheMealDB. Ingredient amounts are shown as supplied by the source.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(20).frame(maxWidth: 780).frame(maxWidth: .infinity)
        }.background(KitchenStyle.background)
        .navigationTitle("Recipe").kitchenInlineTitle()
        .onAppear { draft = note?.notes ?? "" }
        .sheet(isPresented: $showPlan) { PlanMealSheet(recipe: recipe) }
        .sheet(isPresented: $showCooking) { CookingView(recipe: recipe, onFinished: logCook) }
        .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) { error = nil } } message: { Text(error ?? "") }
    }
    private var shareText: String { recipe.name + "\n" + (recipe.sourceURL?.absoluteString ?? "https://www.themealdb.com/meal/" + recipe.id.replacingOccurrences(of: "mealdb-", with: "")) }
    private func persist(_ success: String) {
        do { try context.save(); feedback = success } catch { context.rollback(); self.error = error.localizedDescription }
    }
    private func toggleSave() {
        if let saved = favorites.first(where: { $0.recipeID == recipe.id }) { context.delete(saved) }
        else { context.insert(Favorite(recipe: recipe)) }
        persist(isFavorite ? "Cookbook updated" : "Saved to your cookbook")
    }
    private func addIngredients() {
        var added = 0
        for ingredient in recipe.ingredients where !shopping.contains(where: { !$0.checked && $0.recipeID == recipe.id && $0.name == ingredient.name && $0.measure == ingredient.measure }) {
            context.insert(ShoppingItem(name: ingredient.name, measure: ingredient.measure, recipeName: recipe.name, recipeID: recipe.id)); added += 1
        }
        persist(added == 0 ? "These ingredients are already on your list" : "Added \(added) ingredients to your list")
    }
    private func makeNote() -> KitchenNote {
        if let note { return note }
        let new = KitchenNote(recipeID: recipe.id); context.insert(new); return new
    }
    private func saveNotes() { makeNote().notes = draft; persist("Notes saved") }
    private func logCook() {
        do {
            let added = try CookingHistory.log(recipeID: recipe.id, plan: plannedMeal, context: context)
            feedback = added ? "Added to your cooking history" : "This planned meal is already marked cooked"
        } catch { self.error = error.localizedDescription }
    }
}

struct CookingView: View {
    let recipe: Recipe
    let onFinished: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                KitchenHeader(eyebrow: "COOK MODE", title: recipe.name, subtitle: "One step at a time.")
                ProgressView(value: Double(step + 1), total: Double(max(1, recipe.instructions.count))).tint(KitchenStyle.accent)
                Text("STEP \(step + 1) OF \(recipe.instructions.count)").font(.caption.weight(.bold)).tracking(2).foregroundStyle(KitchenStyle.accent)
                ScrollView { Text(recipe.instructions[step]).font(.title3).lineSpacing(8).frame(maxWidth: .infinity, alignment: .leading) }
                HStack {
                    Button("Back") { step -= 1 }.buttonStyle(.bordered).disabled(step == 0)
                    Spacer()
                    Button(step == recipe.instructions.count - 1 ? "Finish & log cook" : "Next step") {
                        if step == recipe.instructions.count - 1 { onFinished(); dismiss() } else { step += 1 }
                    }.buttonStyle(.borderedProminent).tint(KitchenStyle.accentFill)
                }
            }.padding(24).background(KitchenStyle.background)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        #if os(iOS)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        #endif
    }
}
