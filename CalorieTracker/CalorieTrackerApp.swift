//
//  CalorieTrackerApp.swift
//  CalorieTracker
//
//  Created by Samuel Park on 6/18/26.
//

import SwiftUI
import SwiftData

@main
struct CalorieTrackerApp: App {
    init() {
        FontRegistry.registerFonts()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [FoodEntry.self, WeightEntry.self])
    }
}
