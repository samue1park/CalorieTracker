import Foundation
import SwiftData

@Model
final class FoodEntry {
    @Attribute(.unique) var id: UUID
    var name: String
    var calories: Int
    var protein: Double // in grams
    var carbs: Double   // in grams
    var fat: Double     // in grams
    var timestamp: Date
    var servings: Double? = 1.0
    
    var servingsSafe: Double {
        get { servings ?? 1.0 }
        set { servings = newValue }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        calories: Int,
        protein: Double = 0.0,
        carbs: Double = 0.0,
        fat: Double = 0.0,
        timestamp: Date = Date(),
        servings: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.timestamp = timestamp
        self.servings = servings
    }
}

@Model
final class WeightEntry {
    @Attribute(.unique) var id: UUID
    var weight: Double // in lbs
    var timestamp: Date
    
    init(
        id: UUID = UUID(),
        weight: Double,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.weight = weight
        self.timestamp = timestamp
    }
}

extension Date {
    func combiningTime(from timeDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: self)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: timeDate)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        combinedComponents.second = timeComponents.second
        
        return calendar.date(from: combinedComponents) ?? self
    }
}
