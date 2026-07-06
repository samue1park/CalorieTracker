import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var allEntries: [FoodEntry]
    
    @Binding var selectedDate: Date
    @State private var showFractionMode: Bool = false
    @State private var entryToEdit: FoodEntry? = nil
    @State private var showCalendar: Bool = false
    @State private var selectedIndex: Int? = nil
    @State private var entryToShowDetails: FoodEntry? = nil
    
    // Goals persisted via AppStorage
    @AppStorage("goalCalories") private var calorieGoal = 2000
    @AppStorage("goalProtein") private var proteinGoal = 130.0
    @AppStorage("goalCarbs") private var carbsGoal = 220.0
    @AppStorage("goalFat") private var fatGoal = 65.0
    @AppStorage("username") private var username: String = ""
    
    var greetingText: String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let greeting: String
        
        if hour >= 4 && hour < 12 {
            greeting = "Good Morning"
        } else if hour >= 12 && hour < 16 {
            greeting = "Good Afternoon"
        } else {
            greeting = "Good Evening"
        }
        
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name.count > 8 {
            return greeting
        } else {
            return "\(greeting), \(name)"
        }
    }
    
    // Filter entries for the selected day
    var filteredEntries: [FoodEntry] {
        allEntries.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: selectedDate) }
    }
    
    // Calculate daily totals
    var totalCalories: Int {
        filteredEntries.reduce(0) { $0 + $1.calories }
    }
    
    var totalProtein: Double {
        filteredEntries.reduce(0.0) { $0 + $1.protein }
    }
    
    var totalCarbs: Double {
        filteredEntries.reduce(0.0) { $0 + $1.carbs }
    }
    
    var totalFat: Double {
        filteredEntries.reduce(0.0) { $0 + $1.fat }
    }
    
    var caloriesRemaining: Int {
        max(calorieGoal - totalCalories, 0)
    }
    
    var calorieProgress: Double {
        Double(totalCalories) / Double(calorieGoal)
    }
    
    var formattedDateString: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }
    var body: some View {
        ZStack {
            AppTheme.logBackgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Pinned Header
                VStack(spacing: 12) {
                    // Greeting Header
                    HStack {
                        Text(greetingText)
                            .helvetica(size: 32, weight: .bold)
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 10)
                    
                    // Date Navigation
                    dateSelector
                }
                .padding(.horizontal)
                
                // Scrollable Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Core Calorie Circle & Macro Breakdown
                        summaryDashboardCard
                        
                        // Daily Food Log
                        foodLogList
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 80) // Ensure log items aren't covered by bottom tab bar
                }
            }
            
            if showCalendar {
                calendarOverlayDialog
            }
            
            if let entry = entryToShowDetails {
                foodEntryDetailOverlay(for: entry)
            }
        }
        .sheet(item: $entryToEdit) { entry in
            ManualLoggerView(entryToEdit: entry)
        }
    }
    
    // MARK: - Date Selector
    private var dateSelector: some View {
        let range = dates
        
        return GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let itemWidth = screenWidth / 3
            let center = screenWidth / 2
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(0..<range.count, id: \.self) { index in
                        dateItemView(for: range[index], index: index, itemWidth: itemWidth, timelineCenter: center)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, itemWidth, for: .scrollContent)
            .coordinateSpace(name: "dateTimeline")
            .scrollPosition(id: $selectedIndex)
            .scrollTargetBehavior(.viewAligned)
            .mask(
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [.clear, .white],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: itemWidth)
                    
                    Color.white
                    
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: itemWidth)
                }
            )
            .onAppear {
                let range = dates
                if let index = range.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) }) {
                    selectedIndex = index
                }
            }
            .onChange(of: selectedDate) { _, newValue in
                let range = dates
                if let index = range.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: newValue) }),
                   index != selectedIndex {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedIndex = index
                    }
                }
            }
            .onChange(of: selectedIndex) { _, newIndex in
                guard let index = newIndex else { return }
                let range = dates
                if index >= 0 && index < range.count {
                    let date = range[index]
                    if !Calendar.current.isDate(selectedDate, inSameDayAs: date) {
                        selectedDate = date
                    }
                }
            }
        }
        .frame(height: 40)
        .padding(.vertical, 4)
    }
    
    private func dateItemView(for date: Date, index: Int, itemWidth: CGFloat, timelineCenter: CGFloat) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        
        return GeometryReader { itemGeo in
            let itemCenter = itemGeo.frame(in: .named("dateTimeline")).midX
            let distance = abs(itemCenter - timelineCenter)
            let maxDistance = itemWidth * 1.5
            let opacity = max(1.0 - (distance / maxDistance), 0.3)
            
            VStack(spacing: 4) {
                Text(dateString(for: date))
                    .helvetica(size: isSelected ? 16 : 13, weight: isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
                    .opacity(opacity)
                    .lineLimit(1)
                
                // Indicator Underline
                Rectangle()
                    .fill(isSelected ? AppTheme.primaryText : Color.clear)
                    .frame(width: 50, height: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelected {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCalendar = true
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedIndex = index
                    }
                }
            }
        }
        .frame(width: itemWidth)
    }
    
    private func dateString(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: date)
        }
    }
    
    private var dates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        return (0...90).reversed().compactMap { i in
            calendar.date(byAdding: .day, value: -i, to: today)
        }
    }
    
    // MARK: - Summary Dashboard Card
    private var summaryDashboardCard: some View {
        VStack(spacing: 14) {
            ZStack {
                // Rotated progress track (layout is 140x280, rotated visually to 280x140)
                ZStack {
                    Capsule()
                        .stroke(AppTheme.cardBorder, lineWidth: 10)
                    
                    Capsule()
                        .trim(from: 0.0, to: CGFloat(min(calorieProgress, 1.0)))
                        .stroke(
                            LinearGradient(
                                gradient: AppTheme.calorieGradient,
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .saturation(calorieProgress > 1.0 ? 1.8 : 1.0)
                        .shadow(color: Color(hex: "3B82F6").opacity(calorieProgress > 1.0 ? 0.6 : 0.0), radius: 6, x: 0, y: 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: calorieProgress)
                }
                .frame(width: 140, height: 280)
                .rotationEffect(Angle(degrees: -90))
                
                // Centered content (unrotated, laid out relative to the outer ZStack)
                VStack(alignment: .center, spacing: 4) {
                    Text("Caloric Summary")
                        .instrumentSerif(size: 17)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    if showFractionMode {
                        VStack(alignment: .center, spacing: 1) {
                            Text(verbatim: "\(totalCalories) / \(calorieGoal)")
                                .helvetica(size: 28, weight: .bold)
                                .foregroundStyle(AppTheme.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            
                            Text("kcal")
                                .helvetica(size: 12, weight: .semibold)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    } else {
                        VStack(alignment: .center, spacing: 1) {
                            if totalCalories > calorieGoal {
                                let caloriesOver = totalCalories - calorieGoal
                                Text(verbatim: "\(caloriesOver)")
                                    .helvetica(size: 34, weight: .bold)
                                    .foregroundStyle(AppTheme.primaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                
                                Text("kcal over")
                                    .helvetica(size: 12, weight: .semibold)
                                    .foregroundStyle(AppTheme.secondaryText)
                            } else {
                                Text(verbatim: "\(caloriesRemaining)")
                                    .helvetica(size: 34, weight: .bold)
                                    .foregroundStyle(AppTheme.primaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                
                                Text("kcal left")
                                    .helvetica(size: 12, weight: .semibold)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                    }
                }
                .frame(width: 220, alignment: .center)
            }
            .frame(width: 280, height: 140)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
            
            // Macro bars grid
            VStack(spacing: 12) {
                MacroProgressLine(
                    label: "Protein",
                    current: totalProtein,
                    target: proteinGoal,
                    color: AppTheme.protein,
                    icon: "fish.fill", showFraction: showFractionMode
                )
                
                MacroProgressLine(
                    label: "Carbs",
                    current: totalCarbs,
                    target: carbsGoal,
                    color: AppTheme.carbs,
                    icon: "fork.knife", showFraction: showFractionMode
                )
                
                MacroProgressLine(
                    label: "Fat",
                    current: totalFat,
                    target: fatGoal,
                    color: AppTheme.fat,
                    icon: "drop.fill", showFraction: showFractionMode
                )
            }
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            showFractionMode.toggle()
        }
    }
    
    // MARK: - Food Log List
    private var foodLogList: some View {
        Group {
            if !filteredEntries.isEmpty {
                List {
                    ForEach(filteredEntries) { entry in
                        HStack {
                            Text(parseServingSize(from: entry.name).baseName)
                                .helvetica(size: 15, weight: .bold)
                                .foregroundStyle(AppTheme.primaryText)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .mask(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: .white, location: 0.85),
                                            .init(color: .clear, location: 1.0)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Spacer()
                            
                            Text(verbatim: "\(entry.calories) kcal")
                                .helvetica(size: 15, weight: .bold)
                                .foregroundStyle(AppTheme.primaryText)
                                .layoutPriority(1)
                        }
                        .frame(height: 34)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .liquidGlassCard(cornerRadius: 12, borderOpacity: 0.1)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                entryToShowDetails = entry
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                entryToEdit = entry
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteEntry(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(height: CGFloat(filteredEntries.count * 60 + 10))
            }
        }
    }
    
    // MARK: - Helpers
    private func changeDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            // Prevent going into the future
            if newDate <= Date() || Calendar.current.isDateInToday(newDate) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    selectedDate = newDate
                }
            }
        }
    }
    
    private func deleteEntry(_ entry: FoodEntry) {
        withAnimation {
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }
    
    // MARK: - Calendar Overlay Dialog (Center Popup)
    private var calendarOverlayDialog: some View {
        ZStack {
            // Dimmed background overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCalendar = false
                    }
                }
            
            // Central Card
            VStack(spacing: 0) {
                // Top Header Bar
                Text("Choose Date")
                    .helvetica(size: 17, weight: .bold)
                    .foregroundColor(AppTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                
                // Calendar DatePicker
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .tint(AppTheme.accent)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                
                // Bottom Done Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCalendar = false
                    }
                }) {
                    Text("Done")
                        .helvetica(size: 16, weight: .bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AppTheme.accent)
                        .cornerRadius(12)
                        .shadow(color: AppTheme.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .liquidGlassCard(cornerRadius: 20, borderOpacity: 0.15)
            .padding(.horizontal, 20)
            .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
        }
    }
    
    // MARK: - Food Entry Detail Overlay
    private func foodEntryDetailOverlay(for entry: FoodEntry) -> some View {
        ZStack {
            // Dimmed background overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        entryToShowDetails = nil
                    }
                }
            
            VStack {
                Spacer()
                
                // Bottom popup card
                VStack(spacing: 12) {
                    // Header (Edit on top-left, Delete on top-right)
                    HStack {
                        Button(action: {
                            let targetEntry = entry
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                entryToShowDetails = nil
                            }
                            entryToEdit = targetEntry
                        }) {
                            Text("Edit")
                        }
                        .buttonStyle(LiquidGlassButtonStyle(isDestructive: false))
                        
                        Spacer()
                        
                        Button(action: {
                            let targetEntry = entry
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                entryToShowDetails = nil
                            }
                            deleteEntry(targetEntry)
                        }) {
                            Text("Delete")
                        }
                        .buttonStyle(LiquidGlassButtonStyle(isDestructive: true))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // Full food name, calories, serving size, and side-by-side macros
                    let parsed = parseServingSize(from: entry.name)
                    let servingsVal = entry.servingsSafe != 1.0 ? entry.servingsSafe : parsed.servings
                    let servingsStr = servingsVal.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(servingsVal))" : String(format: "%.1f", servingsVal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(parsed.baseName)
                            .helvetica(size: 20, weight: .bold)
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack(spacing: 12) {
                            Text(verbatim: "\(entry.calories) kcal")
                                .helvetica(size: 15, weight: .semibold)
                                .foregroundStyle(AppTheme.primaryText)
                            
                            Text("•")
                                .helvetica(size: 14)
                                .foregroundStyle(AppTheme.secondaryText.opacity(0.5))
                            
                            Text("\(servingsStr) \(servingsVal == 1.0 ? "serving" : "servings")")
                                .helvetica(size: 14, weight: .medium)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        
                        Divider()
                            .background(AppTheme.cardBorder)
                            .padding(.top, 4)
                            .padding(.bottom, 4)
                        
                        // Side-by-side macros matching historical color code layout
                        HStack(spacing: 16) {
                            HStack(spacing: 3) {
                                Text("P")
                                    .helvetica(size: 14, weight: .bold)
                                    .foregroundStyle(AppTheme.protein)
                                Text("\(Int(round(entry.protein)))g")
                                    .helvetica(size: 14, weight: .semibold)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            
                            HStack(spacing: 3) {
                                Text("C")
                                    .helvetica(size: 14, weight: .bold)
                                    .foregroundStyle(AppTheme.carbs)
                                Text("\(Int(round(entry.carbs)))g")
                                    .helvetica(size: 14, weight: .semibold)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            
                            HStack(spacing: 3) {
                                Text("F")
                                    .helvetica(size: 14, weight: .bold)
                                    .foregroundStyle(AppTheme.fat)
                                Text("\(Int(round(entry.fat)))g")
                                    .helvetica(size: 14, weight: .semibold)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .liquidGlassCard(cornerRadius: 24, borderOpacity: 0.15)
                .padding(.horizontal, 16)
                .padding(.bottom, 96)
            }
            .ignoresSafeArea(.keyboard)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
}

struct LiquidGlassButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .helvetica(size: 14, weight: .bold)
            .foregroundColor(isDestructive ? .red : AppTheme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Color.white.opacity(configuration.isPressed ? 0.04 : 0.08)
                    .background(.ultraThinMaterial)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.4),
                                .white.opacity(0.15),
                                .black.opacity(0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    DashboardView(selectedDate: .constant(Date()))
}
