import Foundation

struct Recipe: Codable, Identifiable, Hashable {
    let cuisine: String
    let name: String
    let photo_url_large: String
    let photo_url_small: String
    let source_url: String?
    let id: String
    let youtube_url: String?
    var category: String = ""
    var ingredients: [Ingredient] = []
    var instructions: [String] = []

    struct Ingredient: Codable, Hashable, Identifiable {
        let name: String
        let measure: String
        var id: String { name + "|" + measure }
        var display: String { [measure, name].filter { !$0.isEmpty }.joined(separator: " ") }
    }
    
    private enum CodingKeys: String, CodingKey {
        case cuisine
        case name
        case photo_url_large
        case photo_url_small
        case source_url
        case id = "uuid"
        case youtube_url
        case category, ingredients, instructions
    }

    init(cuisine: String, name: String, photo_url_large: String, photo_url_small: String,
         source_url: String?, id: String, youtube_url: String?, category: String = "",
         ingredients: [Ingredient] = [], instructions: [String] = []) {
        self.cuisine = cuisine; self.name = name
        self.photo_url_large = photo_url_large; self.photo_url_small = photo_url_small
        self.source_url = source_url; self.id = id; self.youtube_url = youtube_url
        self.category = category; self.ingredients = ingredients
        self.instructions = Self.normalizedInstructionSteps(instructions)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cuisine = try c.decode(String.self, forKey: .cuisine)
        name = try c.decode(String.self, forKey: .name)
        photo_url_large = try c.decode(String.self, forKey: .photo_url_large)
        photo_url_small = try c.decode(String.self, forKey: .photo_url_small)
        source_url = try c.decodeIfPresent(String.self, forKey: .source_url)
        id = try c.decode(String.self, forKey: .id)
        youtube_url = try c.decodeIfPresent(String.self, forKey: .youtube_url)
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        ingredients = try c.decodeIfPresent([Ingredient].self, forKey: .ingredients) ?? []
        instructions = Self.normalizedInstructionSteps(try c.decodeIfPresent([String].self, forKey: .instructions) ?? [])
    }

    private static let instructionMarker = #"(?i)^(?:step\s*)?\(?\d+\)?\s*[.):–—-]?\s*$"#
    private static let instructionPrefix = #"(?i)^(?:step\s*\d+\s*[:.)–—-]\s*|step\s+\d+\s+|(?:\d+[.)]|\(\d+\))\s+)(?=\S)"#

    private static func hasInstructionNumbering(_ line: String) -> Bool {
        line.range(of: instructionMarker, options: .regularExpression) != nil ||
        line.range(of: instructionPrefix, options: .regularExpression) != nil
    }

    private static func normalizedNewlines(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    /// Arrays already describe step boundaries. Keep wrapped lines inside their
    /// existing step, unless a legacy snapshot still contains source numbering.
    static func normalizedInstructionSteps(_ instructions: [String]) -> [String] {
        let steps = instructions.map { normalizedNewlines($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let numbered = steps.contains { step in
            step.components(separatedBy: .newlines).contains {
                hasInstructionNumbering($0.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        return numbered ? instructionSteps(from: steps.joined(separator: "\n")) : steps
    }

    /// Source numbering belongs to the structure, not to the instruction text.
    /// Preserve quantities and group continuation lines under explicit step markers.
    static func instructionSteps(from source: String) -> [String] {
        let lines = normalizedNewlines(source).components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let numbered = lines.contains { hasInstructionNumbering($0) }
        guard numbered else { return lines.filter { !$0.isEmpty } }
        var steps: [String] = [], current: [String] = []
        func finishStep() {
            let text = current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { steps.append(text) }
            current.removeAll()
        }
        for line in lines {
            if line.range(of: instructionMarker, options: .regularExpression) != nil {
                finishStep()
            } else if let numbering = line.range(of: instructionPrefix, options: .regularExpression) {
                finishStep()
                current.append(String(line[numbering.upperBound...]))
            } else if !line.isEmpty || (!current.isEmpty && current.last != "") {
                current.append(line)
            }
        }
        finishStep()
        return steps
    }

    var sourceURL: URL? { Self.webURL(source_url) }
    var videoURL: URL? { Self.webURL(youtube_url) }
    static func webURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        return url
    }
}


extension Recipe {
    /// Convenience sample data used for SwiftUI previews.
    static let sample = Recipe(
        cuisine: "Italian",
        name: "Chicken Parmesan",
        photo_url_large: "https://example.com/large.jpg",
        photo_url_small: "https://example.com/small.jpg",
        source_url: "https://example.com",
        id: UUID().uuidString,
        youtube_url: "https://youtube.com/watch?v=1234"
    )
}

struct RecipesJSONResponse: Codable {
    let recipes: [Recipe]
}

struct MealDBResponse: Decodable {
    let meals: [Meal]?
    struct Meal: Decodable {
        let recipe: Recipe
        struct Key: CodingKey {
            var stringValue: String; var intValue: Int? { nil }
            init(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { return nil }
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Key.self)
            func text(_ key: String) -> String {
                ((try? c.decodeIfPresent(String.self, forKey: Key(stringValue: key))) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let id = text("idMeal"), name = text("strMeal")
            guard !id.isEmpty, !name.isEmpty else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Meal is missing its identity."))
            }
            let ingredients = (1...20).compactMap { index -> Recipe.Ingredient? in
                let name = text("strIngredient\(index)")
                return name.isEmpty ? nil : .init(name: name, measure: text("strMeasure\(index)"))
            }
            let steps = Recipe.instructionSteps(from: text("strInstructions"))
            recipe = Recipe(cuisine: text("strArea"), name: name,
                photo_url_large: text("strMealThumb"), photo_url_small: text("strMealThumb") + "/small",
                source_url: text("strSource"), id: "mealdb-" + id, youtube_url: text("strYoutube"),
                category: text("strCategory"), ingredients: ingredients, instructions: steps)
        }
    }
}
