import Foundation
import Observation

@MainActor @Observable final class RecipeCatalog {
    private(set) var recipes: [Recipe] = []
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var lastUpdated: Date?
    private var didLoad = false
    private let cacheURL: URL
    private let session: URLSession

    init(cacheURL: URL? = nil) {
        self.cacheURL = cacheURL ?? URL.applicationSupportDirectory.appending(path: "recipe-catalog-v2.json")
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 25
        session = URLSession(configuration: configuration)
        if let data = try? Data(contentsOf: self.cacheURL),
           let cached = try? JSONDecoder().decode(Cache.self, from: data) {
            recipes = cached.recipes; lastUpdated = cached.savedAt
        }
    }

    struct Cache: Codable { let recipes: [Recipe]; let savedAt: Date }
    enum CatalogError: LocalizedError {
        case badResponse, empty
        var errorDescription: String? {
            switch self {
            case .badResponse: "The recipe service returned an unexpected response."
            case .empty: "The recipe service returned an empty catalogue."
            }
        }
    }

    func load(force: Bool = false) async {
        guard !isLoading, force || !didLoad else { return }
        didLoad = true; isLoading = true
        defer { isLoading = false }
        do {
            let base = "https://www.themealdb.com/api/json/v1/1/"
            async let popular = fetchAvailable(URL(string: base + "search.php?s=")!)
            async let pasta = fetchAvailable(URL(string: base + "search.php?s=pasta")!)
            async let chicken = fetchAvailable(URL(string: base + "search.php?s=chicken")!)
            let chunks = await [popular, pasta, chicken]
            try Task.checkCancellation()
            let decoded = Self.unique(chunks.compactMap { $0 }.flatMap { $0 })
            guard !decoded.isEmpty else { throw CatalogError.empty }
            let now = Date()
            recipes = decoded; lastUpdated = now
            message = chunks.contains(where: { $0 == nil }) ? "Some recipes could not refresh. You can browse the recipes that loaded and try again later." : nil
            do {
                try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(Cache(recipes: decoded, savedAt: now)).write(to: cacheURL, options: .atomic)
            } catch { message = "Recipes loaded. Offline caching is temporarily unavailable." }
        } catch is CancellationError {
            didLoad = false
        } catch {
            message = recipes.isEmpty ? "Couldn't load recipes. Check your connection and try again. Your saved cookbook is still available."
                : "You're browsing your last saved catalogue. Refresh when you're back online."
        }
    }

    private func fetchAvailable(_ url: URL) async -> [Recipe]? { try? await fetch(url) }

    private func fetch(_ url: URL) async throws -> [Recipe] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw CatalogError.badResponse }
        return try JSONDecoder().decode(MealDBResponse.self, from: data).meals?.map(\.recipe) ?? []
    }

    static func unique(_ recipes: [Recipe]) -> [Recipe] {
        var ids = Set<String>()
        return recipes.filter { ids.insert($0.id).inserted }
    }
}
