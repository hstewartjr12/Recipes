import SwiftUI
import SwiftData

struct PlanMealSheet: View {
    let recipe: Recipe
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var plans: [PlannedMeal]
    @State private var date = Date()
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(recipe.name).font(.system(.title2, design: .serif).bold())
                    Text("Make a little room for something delicious.").foregroundStyle(.secondary)
                    DatePicker("Cooking date", selection: $date, displayedComponents: .date)
                }
                Section { Button("Add to meal plan") { add() }.frame(maxWidth: .infinity) }
            }.navigationTitle("Plan a meal")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .alert("Couldn't plan meal", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("OK", role: .cancel) { error = nil }
                } message: { Text(error ?? "") }
        }.presentationDetents([.medium, .large])
    }
    private func add() {
        guard !plans.contains(where: { $0.recipe?.id == recipe.id && Calendar.current.isDate($0.plannedDate, inSameDayAs: date) }) else {
            error = "This dish is already planned for that day."; return
        }
        do { context.insert(try PlannedMeal(recipe: recipe, date: date)); try context.save(); dismiss() }
        catch { context.rollback(); self.error = error.localizedDescription }
    }
}

struct MealPlannerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlannedMeal.plannedDate) private var plans: [PlannedMeal]
    @Query private var notes: [KitchenNote]
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var weekOffset = 0
    @State private var reschedule: PlannedMeal?
    @State private var newDate = Date()
    @State private var error: String?
    private var weekStart: Date {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())!.start
        return Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: start)!
    }
    private var days: [Date] { (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) } }
    private var dayPlans: [PlannedMeal] { plans.filter { Calendar.current.isDate($0.plannedDate, inSameDayAs: selectedDay) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                KitchenHeader(eyebrow: "GOOD FOOD, LESS GUESSWORK", title: "A week well fed", subtitle: "Your saved plans, one day at a time.")
                HStack {
                    Button { changeWeek(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous week")
                    Spacer()
                    Text(weekStart.formatted(.dateTime.month(.abbreviated).day()) + " – " + days[6].formatted(.dateTime.month(.abbreviated).day())).font(.headline)
                    Spacer()
                    Button { changeWeek(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next week")
                }
                HStack(spacing: 6) {
                    ForEach(days, id: \.self) { day in
                        Button { selectedDay = day } label: {
                            VStack(spacing: 8) {
                                Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption)
                                Text(day.formatted(.dateTime.day())).font(.headline)
                                Circle().fill(plans.contains { Calendar.current.isDate($0.plannedDate, inSameDayAs: day) } ? KitchenStyle.accent : .clear).frame(width: 5, height: 5)
                            }.frame(maxWidth: .infinity).padding(.vertical, 12)
                                .foregroundStyle(Calendar.current.isDate(day, inSameDayAs: selectedDay) ? .white : .primary)
                                .background(Calendar.current.isDate(day, inSameDayAs: selectedDay) ? KitchenStyle.accentFill : KitchenStyle.surface, in: RoundedRectangle(cornerRadius: 14))
                        }.buttonStyle(.plain).accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                            .accessibilityAddTraits(Calendar.current.isDate(day, inSameDayAs: selectedDay) ? .isSelected : [])
                    }
                }
                HStack {
                    Text(selectedDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).font(.system(.title2, design: .serif).bold())
                    Spacer()
                    Button("Today") { weekOffset = 0; selectedDay = Calendar.current.startOfDay(for: Date()) }.font(.subheadline)
                }
                if dayPlans.isEmpty {
                    ContentUnavailableView("An open invitation", systemImage: "calendar", description: Text("Open a recipe in Discover or your cookbook and choose Plan a meal to add it here."))
                        .padding(.vertical, 24)
                }
                ForEach(dayPlans) { plan in
                    if let recipe = plan.recipe {
                        VStack(alignment: .leading, spacing: 14) {
                            NavigationLink { RecipeDetail(recipe: recipe, plannedMeal: plan) } label: {
                                HStack(spacing: 14) {
                                    RecipePhoto(recipe: recipe).frame(width: 74, height: 74).clipped().clipShape(RoundedRectangle(cornerRadius: 14))
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(recipe.name).font(.headline).foregroundStyle(.primary)
                                        Text(recipe.cuisine).font(.caption).foregroundStyle(.secondary)
                                        if plan.cookedAt != nil { Label("Made with love", systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(KitchenStyle.accent) }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                }
                            }.buttonStyle(.plain)
                            HStack {
                                Button { setCooked(plan) } label: { Label(plan.cookedAt == nil ? "Mark cooked" : "Undo cooked", systemImage: plan.cookedAt == nil ? "checkmark.circle" : "arrow.uturn.backward") }.font(.caption)
                                Spacer()
                                Menu {
                                    Button("Reschedule", systemImage: "calendar") { newDate = plan.plannedDate; reschedule = plan }
                                    Button("Remove from plan", systemImage: "trash", role: .destructive) { context.delete(plan); save() }
                                } label: { Image(systemName: "ellipsis") }.accessibilityLabel("Meal options for \(recipe.name)")
                            }
                        }.padding(16).background(KitchenStyle.surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                }
                let cooked = notes.reduce(0) { $0 + $1.cookedCount }
                if cooked > 0 {
                    Label("\(cooked) meals made in your kitchen", systemImage: "checkmark.seal.fill")
                        .font(.subheadline).foregroundStyle(KitchenStyle.accent).padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading).background(KitchenStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                }
            }.padding(20).frame(maxWidth: 780).frame(maxWidth: .infinity)
        }.background(KitchenStyle.background).navigationTitle("Meal plan").kitchenInlineTitle()
        .sheet(item: $reschedule) { plan in
            NavigationStack {
                Form {
                    DatePicker("New cooking date", selection: $newDate, displayedComponents: .date)
                    Button("Save date") {
                        guard !plans.contains(where: { $0.persistentModelID != plan.persistentModelID && $0.recipe?.id == plan.recipe?.id && Calendar.current.isDate($0.plannedDate, inSameDayAs: newDate) }) else {
                            error = "This dish is already planned for that day."; return
                        }
                        plan.plannedDate = Calendar.current.startOfDay(for: newDate); save(); reschedule = nil
                    }
                }.navigationTitle("Reschedule meal").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { reschedule = nil } } }
            }.presentationDetents([.medium])
        }
        .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) { error = nil } } message: { Text(error ?? "") }
    }
    private func changeWeek(_ amount: Int) {
        weekOffset += amount
        selectedDay = Calendar.current.date(byAdding: .day, value: amount * 7, to: selectedDay)!
    }
    private func save() {
        do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription }
    }
    private func setCooked(_ plan: PlannedMeal) {
        guard let recipe = plan.recipe else { return }
        do {
            if plan.cookedAt == nil { _ = try CookingHistory.log(recipeID: recipe.id, plan: plan, context: context) }
            else { try CookingHistory.undo(plan: plan, context: context) }
        } catch { self.error = error.localizedDescription }
    }
}
