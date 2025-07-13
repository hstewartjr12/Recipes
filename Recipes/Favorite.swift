import Foundation
import SwiftData

@Model
final class Favorite {
    @Attribute(.unique) var recipeID: String
    
    init(recipeID: String) {
        self.recipeID = recipeID
    }
}
