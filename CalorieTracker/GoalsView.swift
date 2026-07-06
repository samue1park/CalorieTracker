import SwiftUI

struct GoalsView: View {
    @AppStorage("goalCalories") private var goalCalories = 2000
    @AppStorage("goalProtein") private var goalProtein = 130.0
    @AppStorage("goalCarbs") private var goalCarbs = 220.0
    @AppStorage("goalFat") private var goalFat = 65.0
    
    @State private var inputCalories: String = ""
    @State private var inputProtein: String = ""
    @State private var inputCarbs: String = ""
    @State private var inputFat: String = ""
    
    @State private var showSaveSuccess: Bool = false
    @State private var showCalculator = false
    
    var body: some View {
        ZStack {
            AppTheme.goalsBackgroundGradient.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header card
                HStack {
                    Text("Your Daily Goals")
                        .helvetica(size: 32, weight: .bold)
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                VStack(alignment: .leading, spacing: 20) {
                    // Calories Input
                    GoalInputRow(label: "Calories", value: $inputCalories, placeholder: "e.g. 2000", unit: "kcal")
                    
                    Divider().background(AppTheme.cardBorder)
                    
                    // Protein Input;
                    GoalInputRow(label: "Protein", value: $inputProtein, placeholder: "e.g. 130", unit: "g")
                    
                    Divider().background(AppTheme.cardBorder)
                    
                    // Carbs Input
                    GoalInputRow(label: "Carbohydrates", value: $inputCarbs, placeholder: "e.g. 220", unit: "g")
                    
                    Divider().background(AppTheme.cardBorder)
                    
                    // Fat Input
                    GoalInputRow(label: "Fat", value: $inputFat, placeholder: "e.g. 65", unit: "g")
                }
                .padding(.horizontal)
                
                // Action Buttons
                HStack(spacing: 12) {
                    // Save button
                    Button(action: saveGoals) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                            Text("Save Goals")
                        }
                        .helvetica(size: 15, weight: .bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.08))
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.2), .white.opacity(0.05), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                    }
                    
                    // Calculate Goals button
                    Button(action: {
                        showCalculator = true
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16))
                            Text("Calculate Goals")
                        }
                        .helvetica(size: 15, weight: .bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.08))
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.2), .white.opacity(0.05), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                if showSaveSuccess {
                    Text("Goals saved successfully!")
                        .helvetica(size: 14, weight: .semibold)
                        .foregroundColor(.white)
                        .padding(.top, 8)
                        .transition(.opacity)
                }
                
                Spacer()
            }
            .padding(.bottom, 100)
        }
        .onAppear(perform: loadCurrentGoals)
        .fullScreenCover(isPresented: $showCalculator) {
            GoalsCalculatorView(
                goalCalories: $goalCalories,
                goalProtein: $goalProtein,
                goalCarbs: $goalCarbs,
                goalFat: $goalFat
            )
        }
        .onChange(of: showCalculator) { _, isPresented in
            if !isPresented {
                loadCurrentGoals()
            }
        }
    }
    
    private func loadCurrentGoals() {
        inputCalories = "\(goalCalories)"
        inputProtein = String(format: "%.0f", goalProtein)
        inputCarbs = String(format: "%.0f", goalCarbs)
        inputFat = String(format: "%.0f", goalFat)
    }
    
    private func saveGoals() {
        if let cal = Int(inputCalories), cal > 0 {
            goalCalories = cal
        }
        if let prot = Double(inputProtein), prot > 0 {
            goalProtein = prot
        }
        if let carb = Double(inputCarbs), carb > 0 {
            goalCarbs = carb
        }
        if let f = Double(inputFat), f > 0 {
            goalFat = f
        }
        
        withAnimation {
            showSaveSuccess = true
        }
        
        // Hide success message after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showSaveSuccess = false
            }
        }
        
        // Dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct GoalInputRow: View {
    var label: String
    @Binding var value: String
    var placeholder: String
    var unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .helvetica(size: 14, weight: .bold)
                .foregroundColor(AppTheme.primaryText)
            
            HStack {
                TextField(placeholder, text: $value)
                    .keyboardType(.numberPad)
                    .helvetica(size: 16)
                    .foregroundColor(.white)
                
                Text(unit)
                    .helvetica(size: 14, weight: .semibold)
                    .foregroundColor(AppTheme.secondaryText)
            }
            .padding()
            .liquidGlassCard(cornerRadius: 10, borderOpacity: 0.1)
        }
    }
}
