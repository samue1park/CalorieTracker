import SwiftUI
import SwiftData

struct GoalsCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Bindings to parent values to save directly
    @Binding var goalCalories: Int
    @Binding var goalProtein: Double
    @Binding var goalCarbs: Double
    @Binding var goalFat: Double
    
    var canCancel: Bool = true
    
    @State private var currentStep = 1
    
    // Step 1 State
    @State private var selectedGoal: GoalType = .maintain
    
    // Step 2 State
    @State private var gender: GenderType = .female
    @State private var ageInput: String = ""
    @State private var heightUnit: HeightUnit = .ft
    @State private var selectedFtHeight: String = "5'7\""
    @State private var selectedCmHeight: String = "170 cm"
    @State private var showHeightPicker: Bool = false
    @State private var weightInput: String = ""
    @State private var weightUnit: WeightUnit = .lb
    
    // Step 3 State
    @State private var activityLevel: ActivityType = .moderate
    
    // Step 4 State
    @State private var weeklyApproach: ApproachType = .steady
    
    // Step 5 State
    @State private var isCalculating = false
    @State private var calculatedResults: AICalculatedGoals? = nil
    
    // Animation States
    @State private var animateText = false
    @State private var animateContent = false
    
    // Programmatic heights list
    private let ftHeights: [String] = {
        var list: [String] = []
        for ft in 4...8 {
            for inch in 0...11 {
                list.append("\(ft)'\(inch)\"")
                if ft == 8 && inch == 0 { break }
            }
        }
        return list
    }()
    
    private let cmHeights: [String] = (120...240).map { "\($0) cm" }
    
    // Computed heights/weights
    private var parsedHeightCm: Double {
        if heightUnit == .cm {
            let numericPart = selectedCmHeight.replacingOccurrences(of: " cm", with: "")
            return Double(numericPart) ?? 170.0
        } else {
            let cleaned = selectedFtHeight.replacingOccurrences(of: "\"", with: "")
            let parts = cleaned.split(separator: "'")
            if parts.count == 2, let ft = Double(parts[0]), let inch = Double(parts[1]) {
                let totalInches = ft * 12.0 + inch
                return totalInches * 2.54
            }
            return 170.0
        }
    }
    
    private var parsedWeightKg: Double {
        guard let val = Double(weightInput) else { return 70.0 }
        return weightUnit == .kg ? val : val * 0.45359237
    }
    
    private var weeklyChangeLbs: Double {
        switch weeklyApproach {
        case .maintain: return 0.0
        case .slow: return 0.25
        case .steady: return 0.5
        case .moderate: return 1.0
        case .aggressive: return 2.0
        }
    }
    
    var body: some View {
        ZStack {
            AppTheme.goalsBackgroundGradient
                .ignoresSafeArea()
            
            VStack {
                // Header navigation toolbar
                HStack {
                    if currentStep > 1 {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if currentStep == 5 && selectedGoal == .maintain {
                                    currentStep = 3 // Skip approach step for maintenance
                                } else {
                                    currentStep -= 1
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Back")
                            }
                            .helvetica(size: 14, weight: .bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08))
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                        }
                    } else {
                        Spacer()
                            .frame(width: 1, height: 1)
                    }
                    
                    Spacer()
                    
                    if canCancel {
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Cancel")
                                .helvetica(size: 14, weight: .bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.08))
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Progress Bar
                progressIndicator
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // Step Content
                VStack(spacing: 24) {
                    switch currentStep {
                    case 1:
                        step1GoalSelection
                    case 2:
                        step2Demographics
                    case 3:
                        step3ActivityLevel
                    case 4:
                        step4WeeklyApproach
                    case 5:
                        step5SummaryResults
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                
                Spacer()
                
                // Next/Submit Button (For steps 1-4)
                if currentStep < 5 {
                    Button(action: advanceStep) {
                        HStack {
                            Text("Next Step")
                            Image(systemName: "arrow.right")
                        }
                        .helvetica(size: 16, weight: .bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(isStepValid ? Color.white.opacity(0.12) : Color.white.opacity(0.02))
                        .background {
                            if isStepValid {
                                Color.clear.background(.ultraThinMaterial)
                            }
                        }
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isStepValid ? Color.white.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1)
                        )
                    }
                    .disabled(!isStepValid)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            triggerFadeInAnimations()
        }
        .onChange(of: currentStep) { _, _ in
            if currentStep == 5 {
                runGoalCalculation()
            } else {
                triggerFadeInAnimations()
            }
        }
    }
    
    // MARK: - Step Validation
    private var isStepValid: Bool {
        switch currentStep {
        case 1:
            return true
        case 2:
            let ageValid = Int(ageInput) != nil && (Int(ageInput) ?? 0) > 0
            let weightValid = Double(weightInput) != nil && (Double(weightInput) ?? 0) > 0
            return ageValid && weightValid
        case 3:
            return true
        case 4:
            return true
        default:
            return false
        }
    }
    
    private func advanceStep() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if currentStep == 3 && selectedGoal == .maintain {
                currentStep = 5 // Skip approach rate screen for maintainers
            } else {
                currentStep += 1
            }
        }
    }
    
    // MARK: - Fade In Animations Helper
    private func triggerFadeInAnimations() {
        animateText = false
        animateContent = false
        withAnimation(.easeOut(duration: 0.5)) {
            animateText = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            animateContent = true
        }
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.1))
                .frame(height: 6)
            
            GeometryReader { geometry in
                Capsule()
                    .fill(AppTheme.purpleAccent)
                    .frame(width: geometry.size.width * CGFloat(Double(currentStep) / 5.0), height: 6)
            }
            .frame(height: 6)
        }
        .frame(height: 6)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
    }
    
    // MARK: - STEP 1: Goal Selection
    private var step1GoalSelection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What is your main goal?")
                    .helvetica(size: 26, weight: .bold)
                    .foregroundColor(.white)
                    .opacity(animateText ? 1.0 : 0.0)
                    .offset(y: animateText ? 0 : 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                ForEach(GoalType.allCases) { type in
                    Button(action: {
                        selectedGoal = type
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .stroke(selectedGoal == type ? AppTheme.purpleAccent : AppTheme.cardBorder, lineWidth: 2)
                                    .frame(width: 22, height: 22)
                                
                                if selectedGoal == type {
                                    Circle()
                                        .fill(AppTheme.purpleAccent)
                                        .frame(width: 12, height: 12)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.rawValue)
                                    .helvetica(size: 16, weight: .bold)
                                    .foregroundColor(.white)
                                
                                Text(type.description)
                                    .helvetica(size: 13)
                                    .foregroundColor(AppTheme.secondaryText)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.white.opacity(selectedGoal == type ? 0.06 : 0.02))
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selectedGoal == type ? AppTheme.purpleAccent.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .opacity(animateContent ? 1.0 : 0.0)
            .offset(y: animateContent ? 0 : 20)
        }
    }
    
    // MARK: - STEP 2: Demographics & Info
    private var step2Demographics: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tell us a bit about yourself")
                    .helvetica(size: 26, weight: .bold)
                    .foregroundColor(.white)
                    .opacity(animateText ? 1.0 : 0.0)
                    .offset(y: animateText ? 0 : 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                // Gender Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gender")
                        .helvetica(size: 14, weight: .bold)
                        .foregroundColor(AppTheme.primaryText)
                    
                    HStack(spacing: 12) {
                        ForEach(GenderType.allCases) { type in
                            Button(action: {
                                gender = type
                            }) {
                                Text(type.rawValue)
                                    .helvetica(size: 15, weight: .semibold)
                                    .foregroundColor(gender == type ? .white : AppTheme.secondaryText)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(gender == type ? AppTheme.purpleAccent.opacity(0.2) : Color.white.opacity(0.02))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(gender == type ? AppTheme.purpleAccent : Color.white.opacity(0.05), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                
                // Age Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Age")
                        .helvetica(size: 14, weight: .bold)
                        .foregroundColor(AppTheme.primaryText)
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(AppTheme.secondaryText)
                        TextField("e.g. 26", text: $ageInput)
                            .keyboardType(.numberPad)
                            .helvetica(size: 15)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .liquidGlassCard(cornerRadius: 10, borderOpacity: 0.1)
                }
                
                // Height Picker Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Height")
                        .helvetica(size: 14, weight: .bold)
                        .foregroundColor(AppTheme.primaryText)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            withAnimation {
                                showHeightPicker.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: "ruler")
                                    .foregroundColor(AppTheme.secondaryText)
                                Text(heightUnit == .ft ? selectedFtHeight : selectedCmHeight)
                                    .foregroundColor(.white)
                                    .helvetica(size: 15)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.secondaryText)
                                    .rotationEffect(.degrees(showHeightPicker ? 180 : 0))
                            }
                            .padding()
                            .liquidGlassCard(cornerRadius: 10, borderOpacity: 0.1)
                        }
                        
                        // Height unit toggle
                        Button(action: {
                            withAnimation {
                                heightUnit = heightUnit == .ft ? .cm : .ft
                            }
                        }) {
                            Text(heightUnit == .ft ? "ft" : "cm")
                                .helvetica(size: 14, weight: .bold)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 46)
                                .background(Color.white.opacity(0.08))
                                .background(.ultraThinMaterial)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                                )
                        }
                    }
                    
                    if showHeightPicker {
                        Picker("Height Selection", selection: heightUnit == .ft ? $selectedFtHeight : $selectedCmHeight) {
                            ForEach(heightUnit == .ft ? ftHeights : cmHeights, id: \.self) { val in
                                Text(val)
                                    .helvetica(size: 16)
                                    .foregroundColor(.white)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                        .liquidGlassCard(cornerRadius: 10, borderOpacity: 0.1)
                        .clipped()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                
                // Weight Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight")
                        .helvetica(size: 14, weight: .bold)
                        .foregroundColor(AppTheme.primaryText)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "scalemass")
                                .foregroundColor(AppTheme.secondaryText)
                            TextField("Weight", text: $weightInput)
                                .keyboardType(.decimalPad)
                                .helvetica(size: 15)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .liquidGlassCard(cornerRadius: 10, borderOpacity: 0.1)
                        
                        // Weight unit toggle
                        Button(action: {
                            withAnimation {
                                weightUnit = weightUnit == .lb ? .kg : .lb
                                if let val = Double(weightInput) {
                                    if weightUnit == .kg {
                                        weightInput = String(format: "%.1f", val * 0.45359237)
                                    } else {
                                        weightInput = String(format: "%.1f", val / 0.45359237)
                                    }
                                }
                            }
                        }) {
                            Text(weightUnit == .lb ? "lb" : "kg")
                                .helvetica(size: 14, weight: .bold)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 42)
                                .background(Color.white.opacity(0.08))
                                .background(.ultraThinMaterial)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .opacity(animateContent ? 1.0 : 0.0)
            .offset(y: animateContent ? 0 : 20)
        }
    }
    
    // MARK: - STEP 3: Activity Level
    private var step3ActivityLevel: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("How active are you?")
                    .helvetica(size: 26, weight: .bold)
                    .foregroundColor(.white)
                    .opacity(animateText ? 1.0 : 0.0)
                    .offset(y: animateText ? 0 : 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                ForEach(ActivityType.allCases) { type in
                    Button(action: {
                        activityLevel = type
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .stroke(activityLevel == type ? AppTheme.purpleAccent : AppTheme.cardBorder, lineWidth: 2)
                                    .frame(width: 22, height: 22)
                                
                                if activityLevel == type {
                                    Circle()
                                        .fill(AppTheme.purpleAccent)
                                        .frame(width: 12, height: 12)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.rawValue)
                                    .helvetica(size: 16, weight: .bold)
                                    .foregroundColor(.white)
                                
                                Text(type.description)
                                    .helvetica(size: 13)
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.white.opacity(activityLevel == type ? 0.06 : 0.02))
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(activityLevel == type ? AppTheme.purpleAccent.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .opacity(animateContent ? 1.0 : 0.0)
            .offset(y: animateContent ? 0 : 20)
        }
    }
    
    // MARK: - STEP 4: Weekly Approach
    private var step4WeeklyApproach: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose your weekly pace")
                    .helvetica(size: 26, weight: .bold)
                    .foregroundColor(.white)
                    .opacity(animateText ? 1.0 : 0.0)
                    .offset(y: animateText ? 0 : 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                ForEach(ApproachType.allCases) { type in
                    Button(action: {
                        weeklyApproach = type
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .stroke(weeklyApproach == type ? AppTheme.purpleAccent : AppTheme.cardBorder, lineWidth: 2)
                                    .frame(width: 22, height: 22)
                                
                                if weeklyApproach == type {
                                    Circle()
                                        .fill(AppTheme.purpleAccent)
                                        .frame(width: 12, height: 12)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.rawValue)
                                    .helvetica(size: 16, weight: .bold)
                                    .foregroundColor(.white)
                                
                                Text(getPaceDescription(for: type))
                                    .helvetica(size: 13)
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.white.opacity(weeklyApproach == type ? 0.06 : 0.02))
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(weeklyApproach == type ? AppTheme.purpleAccent.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .opacity(animateContent ? 1.0 : 0.0)
            .offset(y: animateContent ? 0 : 20)
        }
    }
    
    private func getPaceDescription(for approach: ApproachType) -> String {
        let isLb = weightUnit == .lb
        switch approach {
        case .maintain:
            return isLb ? "0 lb / week" : "0 kg / week"
        case .slow:
            return isLb ? "0.25 lb / week" : "0.1 kg / week"
        case .steady:
            return isLb ? "0.5 lb / week" : "0.2 kg / week"
        case .moderate:
            return isLb ? "1.0 lb / week" : "0.5 kg / week"
        case .aggressive:
            return isLb ? "2.0 lb / week" : "1.0 kg / week"
        }
    }
    
    // MARK: - STEP 5: Summary & suggested goals
    private var step5SummaryResults: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Calculated Goals")
                    .helvetica(size: 26, weight: .bold)
                    .foregroundColor(.white)
                    .opacity(animateText ? 1.0 : 0.0)
                    .offset(y: animateText ? 0 : 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if isCalculating {
                VStack(spacing: 20) {
                    Spacer().frame(height: 40)
                    ProgressView()
                        .tint(AppTheme.purpleAccent)
                        .scaleEffect(1.5)
                    Text("AI is structuring your macro profile...")
                        .helvetica(size: 15, weight: .semibold)
                        .foregroundColor(AppTheme.secondaryText)
                    Spacer().frame(height: 40)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.02))
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            } else if let results = calculatedResults {
                VStack(spacing: 20) {
                    // Maintenance and Surplus/Deficit
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Estimated Maintenance")
                                .helvetica(size: 11, weight: .bold)
                                .foregroundColor(AppTheme.secondaryText)
                                .textCase(.uppercase)
                            Text("\(results.maintenanceCalories) kcal")
                                .helvetica(size: 18, weight: .bold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 76)
                        .background(Color.white.opacity(0.02))
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        
                        let isPositive = results.surplusOrDeficit > 0
                        let labelText = selectedGoal == .maintain ? "Maintenance" : (isPositive ? "Surplus" : "Deficit")
                        let signStr = results.surplusOrDeficit == 0 ? "" : (isPositive ? "+" : "")
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(labelText)
                                .helvetica(size: 11, weight: .bold)
                                .foregroundColor(AppTheme.secondaryText)
                                .textCase(.uppercase)
                            Text("\(signStr)\(results.surplusOrDeficit) kcal")
                                .helvetica(size: 18, weight: .bold)
                                .foregroundColor(selectedGoal == .cut ? AppTheme.protein : (selectedGoal == .bulk ? AppTheme.carbs : .white))
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 76)
                        .background(Color.white.opacity(0.02))
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                    }
                    
                    // Suggested Plan Target Summary Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Suggested Daily Intake")
                                    .helvetica(size: 14, weight: .semibold)
                                    .foregroundColor(AppTheme.secondaryText)
                                Text("\(results.targetCalories) kcal")
                                    .helvetica(size: 32, weight: .bold)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        
                        Divider().background(AppTheme.cardBorder)
                        
                        // Macros Row
                        HStack(spacing: 8) {
                            MacroStatPill(title: "Protein", grams: Int(round(results.proteinGrams)), color: AppTheme.protein)
                            MacroStatPill(title: "Carbs", grams: Int(round(results.carbsGrams)), color: AppTheme.carbs)
                            MacroStatPill(title: "Fat", grams: Int(round(results.fatGrams)), color: AppTheme.fat)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.03))
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
                    
                    // Disclaimer Subtext
                    Text("These values are estimated based on demographics and metabolic formulas. You can manually tweak your goals later in the Goals tab.")
                        .helvetica(size: 12)
                        .foregroundColor(AppTheme.secondaryText.opacity(0.8))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    // Save Button
                    Button(action: applyCalculatedGoals) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Save Suggested Goals")
                        }
                        .helvetica(size: 16, weight: .bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.12))
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                    }
                    .padding(.top, 8)
                }
                .opacity(animateContent ? 1.0 : 0.0)
                .offset(y: animateContent ? 0 : 20)
            }
        }
    }
    
    private func applyCalculatedGoals() {
        guard let results = calculatedResults else { return }
        
        goalCalories = results.targetCalories
        goalProtein = round(results.proteinGrams)
        goalCarbs = round(results.carbsGrams)
        goalFat = round(results.fatGrams)
        
        // Save weight input from demographics screening as the sole WeightEntry
        if let weightVal = Double(weightInput), weightVal > 0 {
            let finalWeight = weightUnit == .kg ? weightVal / 0.45359237 : weightVal
            
            // Delete all existing weight entries to ensure only the user's initial weight exists
            let descriptor = FetchDescriptor<WeightEntry>()
            if let existing = try? modelContext.fetch(descriptor) {
                for entry in existing {
                    modelContext.delete(entry)
                }
            }
            
            let newEntry = WeightEntry(weight: finalWeight, timestamp: Date())
            modelContext.insert(newEntry)
            try? modelContext.save()
        }
        
        dismiss()
    }
    
    // MARK: - Run Calculation (API with local fallback)
    private func runGoalCalculation() {
        isCalculating = true
        calculatedResults = nil
        
        Task {
            do {
                if GeminiService.shared.hasApiKey {
                    let results = try await GeminiService.shared.calculateGoals(
                        goal: selectedGoal.rawValue,
                        gender: gender.rawValue,
                        age: Int(ageInput) ?? 30,
                        heightCm: parsedHeightCm,
                        weightKg: parsedWeightKg,
                        activityLevel: activityLevel.rawValue,
                        weeklyApproachLbs: weeklyChangeLbs
                    )
                    await MainActor.run {
                        self.calculatedResults = results
                        self.isCalculating = false
                        self.triggerFadeInAnimations()
                    }
                } else {
                    let localResults = runLocalCalculation()
                    await MainActor.run {
                        self.calculatedResults = localResults
                        self.isCalculating = false
                        self.triggerFadeInAnimations()
                    }
                }
            } catch {
                print("Gemini API error, running local fallback: \(error.localizedDescription)")
                let localResults = runLocalCalculation()
                await MainActor.run {
                    self.calculatedResults = localResults
                    self.isCalculating = false
                    self.triggerFadeInAnimations()
                }
            }
        }
    }
    
    private func runLocalCalculation() -> AICalculatedGoals {
        let weightKg = parsedWeightKg
        let heightCm = parsedHeightCm
        let age = Double(ageInput) ?? 30.0
        
        let genderConstant = (gender == .male) ? 5.0 : -161.0
        let bmr = 10.0 * weightKg + 6.25 * heightCm - 5.0 * age + genderConstant
        
        let multiplier: Double
        switch activityLevel {
        case .none: multiplier = 1.2
        case .light: multiplier = 1.375
        case .moderate: multiplier = 1.55
        case .high: multiplier = 1.725
        case .intense: multiplier = 1.9
        }
        
        let maintenance = Int(round(bmr * multiplier))
        let dailyCalAdjustment = Int(round(weeklyChangeLbs * 500.0))
        
        let target: Int
        let adjustmentStr: String
        
        switch selectedGoal {
        case .cut:
            target = max(1200, maintenance - dailyCalAdjustment)
            adjustmentStr = "deficit of \(dailyCalAdjustment) kcal"
        case .bulk:
            target = maintenance + dailyCalAdjustment
            adjustmentStr = "surplus of \(dailyCalAdjustment) kcal"
        case .maintain:
            target = maintenance
            adjustmentStr = "maintenance intake"
        }
        
        let weightInLbs = weightUnit == .lb ? (Double(weightInput) ?? 150.0) : (Double(weightInput) ?? 70.0) * 2.20462
        let protein = max(50.0, round(weightInLbs * 1.0))
        let fat = max(30.0, round((Double(target) * 0.25) / 9.0))
        let carbs = max(50.0, round((Double(target) - protein * 4.0 - fat * 9.0) / 4.0))
        
        let unitText = weightUnit == .lb ? "lb" : "kg"
        let rateText = weightUnit == .lb ? "\(weeklyChangeLbs)" : String(format: "%.1f", weeklyChangeLbs * 0.45359237)
        let rateSummary = (selectedGoal != .maintain && weeklyChangeLbs > 0) ? " at a pace of \(rateText) \(unitText)/week" : ""
        
        let summary = "Based on your active metabolism and selected profile, a daily targets schedule of \(target) kcal (\(adjustmentStr)) will support your body to \(selectedGoal.rawValue.lowercased())\(rateSummary)."
        
        return AICalculatedGoals(
            maintenanceCalories: maintenance,
            surplusOrDeficit: selectedGoal == .cut ? -dailyCalAdjustment : (selectedGoal == .bulk ? dailyCalAdjustment : 0),
            targetCalories: target,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            summaryExplanation: summary
        )
    }
}

// MARK: - Macro Stat Pill Helper
struct MacroStatPill: View {
    var title: String
    var grams: Int
    var color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .helvetica(size: 11, weight: .bold)
                .foregroundColor(AppTheme.secondaryText)
                .textCase(.uppercase)
            
            Text("\(grams)g")
                .helvetica(size: 15, weight: .bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.12))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Goals Calculator Enums
enum GoalType: String, CaseIterable, Identifiable {
    case cut = "Cut"
    case maintain = "Maintain"
    case bulk = "Bulk"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .cut:
            return "Lose body fat while preserving lean muscle mass."
        case .maintain:
            return "Keep your current weight and optimize body composition."
        case .bulk:
            return "Build muscle mass by consuming a caloric surplus."
        }
    }
}

enum GenderType: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    
    var id: String { self.rawValue }
}

enum HeightUnit: String {
    case ft, cm
}

enum WeightUnit: String {
    case lb, kg
}

enum ActivityType: String, CaseIterable, Identifiable {
    case none = "Little to no exercise"
    case light = "Light"
    case moderate = "Moderate"
    case high = "High"
    case intense = "Intense"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .none: return "<1 hr a week"
        case .light: return "1-3 hrs a week"
        case .moderate: return "3-7 hrs a week"
        case .high: return "7-12 hrs a week"
        case .intense: return "12+ hrs a week"
        }
    }
}

enum ApproachType: String, CaseIterable, Identifiable {
    case maintain = "Maintain"
    case slow = "Slow"
    case steady = "Steady"
    case moderate = "Moderate"
    case aggressive = "Aggressive"
    
    var id: String { self.rawValue }
}
