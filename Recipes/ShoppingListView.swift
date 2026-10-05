import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ShoppingItem.createdAt) private var items: [ShoppingItem]
    @State private var newItem = ""
    @State private var error: String?
    @State private var confirmClear = false
    private var remaining: [ShoppingItem] { items.filter { !$0.checked } }
    private var checked: [ShoppingItem] { items.filter(\.checked) }
    private var shareText: String { remaining.map { "• " + $0.display }.joined(separator: "\n") }
    var body: some View {
        List {
            Section {
                KitchenHeader(eyebrow: "READY WHEN YOU ARE", title: "The shopping list", subtitle: remaining.isEmpty ? "A little prep goes a long way." : "\(remaining.count) things left to pick up.")
                    .listRowBackground(Color.clear).listRowSeparator(.hidden).padding(.vertical, 10)
            }
            Section {
                HStack {
                    TextField("Add an ingredient or grocery", text: $newItem).onSubmit(addManual)
                    Button(action: addManual) { Image(systemName: "plus.circle.fill").font(.title2) }
                        .disabled(newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel("Add grocery")
                }
            }
            if items.isEmpty {
                ContentUnavailableView("Nothing on the list yet", systemImage: "basket", description: Text("Add ingredients from any recipe, or jot down the groceries you need above."))
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            if !remaining.isEmpty {
                Section("TO PICK UP") { ForEach(remaining) { item in row(item) }.onDelete { index in delete(index, from: remaining) } }
            }
            if !checked.isEmpty {
                Section("IN THE BASKET · \(checked.count)") { ForEach(checked) { item in row(item) }.onDelete { index in delete(index, from: checked) } }
                Section { Button("Clear picked-up items", role: .destructive) { confirmClear = true } }
            }
            Section { Text("Ingredients are kept by recipe so the source quantities stay intact. Unchecked duplicates from the same recipe are added only once.").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("Shopping").kitchenInlineTitle()
            .toolbar { ToolbarItem { ShareLink(item: "Shopping list\n\n" + shareText) { Image(systemName: "square.and.arrow.up") }.disabled(remaining.isEmpty).accessibilityLabel("Share shopping list") } }
            .confirmationDialog("Clear \(checked.count) picked-up items?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear picked-up items", role: .destructive) { for item in checked { context.delete(item) }; save() }
            }
            .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) { error = nil } } message: { Text(error ?? "") }
    }
    private func row(_ item: ShoppingItem) -> some View {
        Button { item.checked.toggle(); save() } label: {
            HStack(spacing: 14) {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(item.checked ? KitchenStyle.accent : .secondary)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.display).foregroundStyle(item.checked ? .secondary : .primary).strikethrough(item.checked)
                    if !item.recipeName.isEmpty { Text(item.recipeName).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
            }.padding(.vertical, 4)
        }.buttonStyle(.plain).accessibilityLabel("\(item.checked ? "Uncheck" : "Check off") \(item.display)")
    }
    private func addManual() {
        let name = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        context.insert(ShoppingItem(name: name)); if save() { newItem = "" }
    }
    private func delete(_ indices: IndexSet, from source: [ShoppingItem]) { for index in indices { context.delete(source[index]) }; save() }
    @discardableResult private func save() -> Bool {
        do { try context.save(); return true } catch { context.rollback(); self.error = error.localizedDescription; return false }
    }
}
