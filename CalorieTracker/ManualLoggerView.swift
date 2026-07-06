import SwiftUI
import SwiftData

struct ManualLoggerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var entryToEdit: FoodEntry? = nil
    var selectedDate: Date = Date()
    
    // Prefilled values for Food Search library logging
    var prefilledName: String? = nil
    var prefilledCalories: Int? = nil
    var prefilledProtein: Double? = nil
    var prefilledCarbs: Double? = nil
    var prefilledFat: Double? = nil
    
    @State private var name: String = ""
    @State private var caloriesString: String = ""
    @State private var proteinString: String = ""
    @State private var carbsString: String = ""
    @State private var fatString: String = ""
    @State private var servingSizeString: String = "1.0"
    
    var calculatedCalories: Int {
        let calories = Int(caloriesString) ?? 0
        let servings = Double(servingSizeString) ?? 1.0
        return Int(Double(calories) * servings)
    }
    
    var calculatedProtein: Double {
        let protein = Double(proteinString) ?? 0.0
        let servings = Double(servingSizeString) ?? 1.0
        return protein * servings
    }
    
    var calculatedCarbs: Double {
        let carbs = Double(carbsString) ?? 0.0
        let servings = Double(servingSizeString) ?? 1.0
        return carbs * servings
    }
    
    var calculatedFat: Double {
        let fat = Double(fatString) ?? 0.0
        let servings = Double(servingSizeString) ?? 1.0
        return fat * servings
    }
    
    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(caloriesString) != nil &&
        Double(servingSizeString) != nil && (Double(servingSizeString) ?? 0) > 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.originalBackgroundGradient
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Card 1: Food Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Food Name")
                                .helvetica(size: 15, weight: .semibold)
                                .foregroundStyle(AppTheme.primaryText)
                            
                            TextField("Enter food name here...", text: $name)
                                .foregroundStyle(AppTheme.primaryText)
                                .helvetica(size: 15)
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                        
                        // Card 3: Macronutrients (Calories, Protein, Carbs, Fat)
                        VStack(spacing: 0) {
                            // Calories Row
                            HStack {
                                Text("Calories (kcal)")
                                    .helvetica(size: 15, weight: .medium)
                                    .foregroundStyle(AppTheme.primaryText)
                                Spacer()
                                TextField("Enter calories", text: $caloriesString)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(AppTheme.primaryText)
                                    .helvetica(size: 15)
                                    .frame(width: 120)
                            }
                            .padding(.vertical, 14)
                            
                            Divider()
                                .background(AppTheme.cardBorder)
                            
                            // Protein Row
                            HStack {
                                Text("Protein (g)")
                                    .helvetica(size: 15, weight: .medium)
                                    .foregroundStyle(AppTheme.primaryText)
                                Spacer()
                                TextField("Enter protein", text: $proteinString)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(AppTheme.primaryText)
                                    .helvetica(size: 15)
                                    .frame(width: 120)
                            }
                            .padding(.vertical, 14)
                            
                            Divider()
                                .background(AppTheme.cardBorder)
                            
                            // Carbs Row
                            HStack {
                                Text("Carbs (g)")
                                    .helvetica(size: 15, weight: .medium)
                                    .foregroundStyle(AppTheme.primaryText)
                                Spacer()
                                TextField("Enter carbs", text: $carbsString)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(AppTheme.primaryText)
                                    .helvetica(size: 15)
                                    .frame(width: 120)
                            }
                            .padding(.vertical, 14)
                            
                            Divider()
                                .background(AppTheme.cardBorder)
                            
                            // Fat Row
                            HStack {
                                Text("Fat (g)")
                                    .helvetica(size: 15, weight: .medium)
                                    .foregroundStyle(AppTheme.primaryText)
                                Spacer()
                                TextField("Enter fat", text: $fatString)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(AppTheme.primaryText)
                                    .helvetica(size: 15)
                                    .frame(width: 120)
                            }
                            .padding(.vertical, 14)
                        }
                        .padding(.horizontal)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                        
                        // Card 2: Servings Size & Servings Multiplier
                        VStack(spacing: 0) {
                            HStack {
                                Text("Serving Size")
                                    .helvetica(size: 15, weight: .medium)
                                    .foregroundStyle(AppTheme.primaryText)
                                Spacer()
                                Text("1 serving")
                                    .helvetica(size: 15)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            .padding(.vertical, 14)
                            
                            Divider()
                                .background(AppTheme.cardBorder)
                            
                            HStack {
                                Text("Servings")
                                    .helvetica(size: 15, weight: .medium)
                                    .foregroundStyle(AppTheme.primaryText)
                                Spacer()
                                TextField("1", text: $servingSizeString)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(AppTheme.primaryText)
                                    .helvetica(size: 15, weight: .semibold)
                                    .frame(width: 80)
                            }
                            .padding(.vertical, 14)
                        }
                        .padding(.horizontal)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                        
                        // Save Button
                        Button(action: saveEntry) {
                            Text(entryToEdit != nil ? "Save Changes" : "Save Entry")
                                .helvetica(size: 16, weight: .bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(isFormValid ? AppTheme.accent : AppTheme.secondaryText.opacity(0.3))
                                .cornerRadius(12)
                                .shadow(color: isFormValid ? AppTheme.accent.opacity(0.4) : Color.clear, radius: 8, x: 0, y: 4)
                        }
                        .disabled(!isFormValid)
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }
                    .padding()
                }
            }
            .navigationTitle(entryToEdit != nil ? "Edit Entry" : "Manual Log")
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
            .onAppear {
                if let entry = entryToEdit {
                    let parsed = parseServingSize(from: entry.name)
                    self.name = parsed.baseName
                    let servings = entry.servingsSafe != 1.0 ? entry.servingsSafe : parsed.servings
                    self.servingSizeString = servings.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", servings) : String(format: "%.1f", servings)
                    
                    let baseCal = Double(entry.calories) / servings
                    let baseProtein = entry.protein / servings
                    let baseCarbs = entry.carbs / servings
                    let baseFat = entry.fat / servings
                    
                    self.caloriesString = String(format: "%.0f", baseCal)
                    self.proteinString = baseProtein.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", baseProtein) : String(format: "%.1f", baseProtein)
                    self.carbsString = baseCarbs.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", baseCarbs) : String(format: "%.1f", baseCarbs)
                    self.fatString = baseFat.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", baseFat) : String(format: "%.1f", baseFat)
                } else if let prefilledName = prefilledName {
                    self.name = prefilledName
                    if let c = prefilledCalories { self.caloriesString = "\(c)" }
                    if let p = prefilledProtein { self.proteinString = p.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", p) : String(format: "%.1f", p) }
                    if let c = prefilledCarbs { self.carbsString = c.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", c) : String(format: "%.1f", c) }
                    if let f = prefilledFat { self.fatString = f.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", f) : String(format: "%.1f", f) }
                }
            }
        }
    }
    
    private func parseServingSize(from name: String) -> (baseName: String, servings: Double) {
        guard name.hasSuffix("x)") else {
            return (name, 1.0)
        }
        if let lastOpenParenIndex = name.lastIndex(of: "(") {
            let beforeParenIndex = name.index(before: lastOpenParenIndex)
            if beforeParenIndex >= name.startIndex && name[beforeParenIndex] == " " {
                let suffixStart = name.index(after: lastOpenParenIndex)
                let suffixEnd = name.index(name.endIndex, offsetBy: -2)
                if suffixStart < suffixEnd {
                    let servingsSubstring = name[suffixStart..<suffixEnd]
                    if let servingsVal = Double(servingsSubstring) {
                        let base = String(name[..<beforeParenIndex])
                        return (base, servingsVal)
                    }
                }
            }
        }
        return (name, 1.0)
    }
    
    private func saveEntry() {
        guard let baseCalories = Int(caloriesString) else { return }
        let baseProtein = Double(proteinString) ?? 0.0
        let baseCarbs = Double(carbsString) ?? 0.0
        let baseFat = Double(fatString) ?? 0.0
        let servings = Double(servingSizeString) ?? 1.0
        
        let finalCalories = Int(Double(baseCalories) * servings)
        let finalProtein = baseProtein * servings
        let finalCarbs = baseCarbs * servings
        let finalFat = baseFat * servings
        
        let finalName = name
        
        if let entry = entryToEdit {
            entry.name = finalName
            entry.calories = finalCalories
            entry.protein = finalProtein
            entry.carbs = finalCarbs
            entry.fat = finalFat
            entry.servingsSafe = servings
            try? modelContext.save()
        } else {
            let newEntry = FoodEntry(
                name: finalName,
                calories: finalCalories,
                protein: finalProtein,
                carbs: finalCarbs,
                fat: finalFat,
                timestamp: selectedDate.combiningTime(from: Date()),
                servings: servings
            )
            modelContext.insert(newEntry)
        }
        
        dismiss()
    }
}

// Custom Premium Text Field
struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.background.opacity(0.5))
            .cornerRadius(10)
            .foregroundStyle(AppTheme.primaryText)
            .helvetica(size: 15)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
    }
}
