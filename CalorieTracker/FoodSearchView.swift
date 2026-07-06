import SwiftUI
import SwiftData
import SQLite3

struct LocalLibraryFood: Identifiable {
    var id = UUID()
    let name: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let serving: String
}

class FoodDatabase {
    static let shared = FoodDatabase()
    private var db: OpaquePointer?
    
    private init() {
        openDatabase()
    }
    
    private func openDatabase() {
        guard let path = Bundle.main.path(forResource: "opennutrition_foods", ofType: "sqlite") else {
            print("opennutrition_foods.sqlite not found in bundle!")
            return
        }
        
        if sqlite3_open(path, &db) != SQLITE_OK {
            print("Error opening SQLite database")
            db = nil
        }
    }
    
    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
    
    func searchFoods(query: String) -> [LocalLibraryFood] {
        guard let db = db else { return [] }
        
        // Normalize query: convert hyphens to spaces and strip duplicate spaces
        let normalizedQuery = query
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        guard !normalizedQuery.isEmpty else { return [] }
        
        var foods: [LocalLibraryFood] = []
        var statement: OpaquePointer?
        
        // Query foods containing the normalized search term
        let sql = "SELECT name, calories, protein, carbs, fat, serving FROM foods WHERE normalized_name LIKE ? LIMIT 80"
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let likePattern = "%\(normalizedQuery)%"
            sqlite3_bind_text(statement, 1, (likePattern as NSString).utf8String, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(statement, 0))
                let calories = Int(sqlite3_column_int(statement, 1))
                let protein = sqlite3_column_double(statement, 2)
                let carbs = sqlite3_column_double(statement, 3)
                let fat = sqlite3_column_double(statement, 4)
                let serving = String(cString: sqlite3_column_text(statement, 5))
                
                foods.append(LocalLibraryFood(
                    name: name,
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    serving: serving
                ))
            }
        } else {
            print("Error preparing SELECT statement")
        }
        
        sqlite3_finalize(statement)
        
        // Sort matches: items starting with the query go first, followed by shorter names
        return foods.sorted { lhs, rhs in
            let lhsLower = lhs.name.lowercased()
            let rhsLower = rhs.name.lowercased()
            
            let lhsStarts = lhsLower.hasPrefix(normalizedQuery)
            let rhsStarts = rhsLower.hasPrefix(normalizedQuery)
            
            if lhsStarts && !rhsStarts {
                return true
            } else if !lhsStarts && rhsStarts {
                return false
            }
            
            return lhs.name.count < rhs.name.count
        }
    }
    
    func lookupBarcode(barcode: String) -> LocalLibraryFood? {
        guard let db = db else { return nil }
        
        let cleanedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedBarcode.isEmpty else { return nil }
        
        var food: LocalLibraryFood? = nil
        var statement: OpaquePointer?
        
        // Query foods matching ean_13 barcode column
        let sql = "SELECT name, calories, protein, carbs, fat, serving FROM foods WHERE ean_13 = ? LIMIT 1"
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (cleanedBarcode as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(statement, 0))
                let calories = Int(sqlite3_column_int(statement, 1))
                let protein = sqlite3_column_double(statement, 2)
                let carbs = sqlite3_column_double(statement, 3)
                let fat = sqlite3_column_double(statement, 4)
                let serving = String(cString: sqlite3_column_text(statement, 5))
                
                food = LocalLibraryFood(
                    name: name,
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    serving: serving
                )
            }
        } else {
            print("Error preparing SELECT barcode statement")
        }
        
        sqlite3_finalize(statement)
        return food
    }
}

struct FoodSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var selectedDate: Date = Date()
    
    @State private var searchQuery: String = ""
    @State private var searchResults: [LocalLibraryFood] = []
    @State private var hasSearched = false
    @State private var isLoading = false
    
    @State private var prefillFood: LocalLibraryFood? = nil
    @State private var showAddedNotification = false
    @State private var notificationWorkItem: DispatchWorkItem? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.originalBackgroundGradient
                    .ignoresSafeArea()
                
                ZStack(alignment: .bottom) {
                    // Main Scrollable Results Content
                    Group {
                        if isLoading {
                            VStack {
                                Spacer()
                                ProgressView()
                                    .tint(AppTheme.accent)
                                Text("Searching database...")
                                    .helvetica(size: 14)
                                    .foregroundColor(AppTheme.secondaryText)
                                Spacer()
                            }
                            .frame(maxHeight: .infinity)
                        } else if !hasSearched {
                            // Clean blank initial state
                            VStack(spacing: 12) {
                                Spacer()
                                Image(systemName: "text.magnifyingglass")
                                    .font(.system(size: 44))
                                    .foregroundStyle(AppTheme.secondaryText.opacity(0.3))
                                Text("Look up food items and references")
                                    .helvetica(size: 15, weight: .medium)
                                    .foregroundStyle(AppTheme.secondaryText.opacity(0.7))
                                Spacer()
                            }
                            .frame(maxHeight: .infinity)
                        } else if searchResults.isEmpty {
                            VStack(spacing: 12) {
                                Spacer()
                                Image(systemName: "magnifyingglass.circle")
                                    .font(.system(size: 40))
                                    .foregroundStyle(AppTheme.secondaryText.opacity(0.5))
                                Text("No matching food items found")
                                    .helvetica(size: 15, weight: .semibold)
                                    .foregroundStyle(AppTheme.secondaryText)
                                Spacer()
                            }
                            .frame(maxHeight: .infinity)
                        } else {
                            List {
                                ForEach(searchResults) { food in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(food.name)
                                                .helvetica(size: 15, weight: .bold)
                                                .foregroundStyle(AppTheme.primaryText)
                                                .lineLimit(2)
                                            
                                            HStack(spacing: 10) {
                                                Text("P: \(Int(round(food.protein)))g")
                                                Text("C: \(Int(round(food.carbs)))g")
                                                Text("F: \(Int(round(food.fat)))g")
                                            }
                                            .helvetica(size: 11)
                                            .foregroundStyle(AppTheme.secondaryText)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(food.calories) kcal")
                                            .helvetica(size: 15, weight: .bold)
                                            .foregroundStyle(AppTheme.primaryText)
                                        
                                        Button(action: { addQuickCopy(food) }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title3)
                                                .foregroundColor(AppTheme.accent)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.leading, 8)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        prefillFood = food
                                    }
                                    .listRowBackground(AppTheme.cardBackground.opacity(0.8))
                                    .listRowSeparatorTint(AppTheme.cardBorder)
                                }
                                
                                // Extra spacer so last elements scroll fully past the fade zone
                                Color.clear
                                    .frame(height: 90)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                            .scrollContentBackground(.hidden)
                            .mask(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .white, location: 0.0),
                                        .init(color: .white, location: 0.78),
                                        .init(color: .clear, location: 0.94),
                                        .init(color: .clear, location: 1.0)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                    .frame(maxHeight: .infinity)
                    
                    // Search Bar floating at the bottom (no solid backdrop)
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(AppTheme.secondaryText)
                            
                            TextField("Search groceries, branded foods...", text: $searchQuery, onCommit: {
                                performSearch()
                            })
                            .foregroundStyle(AppTheme.primaryText)
                            .helvetica(size: 15)
                            .submitLabel(.search)
                            
                            if !searchQuery.isEmpty {
                                Button(action: {
                                    searchQuery = ""
                                    searchResults = []
                                    hasSearched = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(AppTheme.secondaryText)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(AppTheme.cardBackground.opacity(0.85))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 34) // Bottom safe area spacer
                    }
                }
                
                // Top notification toast banner
                if showAddedNotification {
                    VStack {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Food Added to Log")
                                .helvetica(size: 14, weight: .bold)
                                .foregroundColor(AppTheme.primaryText)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.cardBackground.opacity(0.95))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .padding(.top, 12)
                        
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
                }
            }
            .navigationTitle("Food Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.secondaryText)
                    .helvetica(size: 16)
                }
            }
            .sheet(item: $prefillFood) { food in
                ManualLoggerView(
                    selectedDate: selectedDate,
                    prefilledName: food.name,
                    prefilledCalories: food.calories,
                    prefilledProtein: food.protein,
                    prefilledCarbs: food.carbs,
                    prefilledFat: food.fat
                )
            }
        }
    }
    
    // Perform search on local OpenNutrition SQLite database in a background thread
    private func performSearch() {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        isLoading = true
        hasSearched = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let results = FoodDatabase.shared.searchFoods(query: trimmedQuery)
            DispatchQueue.main.async {
                self.searchResults = results
                self.isLoading = false
            }
        }
    }
    
    // Quick add food direct copy method
    private func addQuickCopy(_ food: LocalLibraryFood) {
        let name = food.name
        let calories = food.calories
        let protein = food.protein
        let carbs = food.carbs
        let fat = food.fat
        
        let newEntry = FoodEntry(
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            timestamp: selectedDate.combiningTime(from: Date())
        )
        
        modelContext.insert(newEntry)
        try? modelContext.save()
        
        // Show checkmark toast notification banner
        notificationWorkItem?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showAddedNotification = true
        }
        
        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.25)) {
                showAddedNotification = false
            }
        }
        notificationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }
}

// Extends LocalLibraryFood to be Identifiable inside sheet binder
extension LocalLibraryFood: Equatable {
    static func == (lhs: LocalLibraryFood, rhs: LocalLibraryFood) -> Bool {
        lhs.id == rhs.id
    }
}
