import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showMenu = false
    
    @Environment(\.modelContext) private var modelContext
    @State private var weightInput: String = ""
    @State private var weightDate: Date = Date()
    
    // AppStorage for username greeting and goals
    @AppStorage("username") private var username: String = ""
    @AppStorage("weightUnit") private var appWeightUnit: String = "lb"
    
    @AppStorage("goalCalories") private var goalCalories = 2000
    @AppStorage("goalProtein") private var goalProtein = 130.0
    @AppStorage("goalCarbs") private var goalCarbs = 220.0
    @AppStorage("goalFat") private var goalFat = 65.0
    
    @AppStorage("hasCompletedFirstLaunchSetup") private var hasCompletedFirstLaunchSetup: Bool = false
    @State private var showFirstLaunchCalculator = false
    
    @Namespace private var tabNamespace
    
    @State private var selectedDate: Date = Date()
    
    // Sheet presentation triggers
    @State private var showFoodSearch = false
    @State private var showManualLogger = false
    @State private var showBarcodeScanner = false
    @State private var showRecentFoods = false
    
    var body: some View {
        ZStack {
            // Main App Views
            NavigationStack {
                ZStack {
                    switch selectedTab {
                    case 0:
                        DashboardView(selectedDate: $selectedDate)
                    case 1:
                        WeightTrackerView()
                    case 2:
                        GoalsView()
                    case 3:
                        AccountView()
                    default:
                        DashboardView(selectedDate: $selectedDate)
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .preferredColorScheme(.dark)
            }
            .blur(radius: showMenu ? 15 : 0) // Blur screen when menu is active
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showMenu)
            
            // Dimmed overlay when menu is active
            if showMenu {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showMenu = false
                        }
                    }
                    .transition(.opacity)
            }
            
            // Floating Tab Bar & Menu
            VStack {
                Spacer()
                
                if showMenu {
                    // Slide up popup menu
                    popupMenuSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                customTabBar
            }
            .ignoresSafeArea(.keyboard) // Prevent tab bar from shifting when keyboard is up
            .ignoresSafeArea(.container, edges: .bottom) // Move down to match the screen's bottom curve
        }
        // Sheet configurations
        .sheet(isPresented: $showFoodSearch) { FoodSearchView(selectedDate: selectedDate) }
        .sheet(isPresented: $showManualLogger) { ManualLoggerView(selectedDate: selectedDate) }
        .sheet(isPresented: $showBarcodeScanner) { BarcodeScannerView(selectedDate: selectedDate) }
        .sheet(isPresented: $showRecentFoods) { RecentlyAddedFoodsView(selectedDate: selectedDate) }
        .fullScreenCover(isPresented: $showFirstLaunchCalculator) {
            GoalsCalculatorView(
                goalCalories: $goalCalories,
                goalProtein: $goalProtein,
                goalCarbs: $goalCarbs,
                goalFat: $goalFat,
                canCancel: false
            )
        }
        .onChange(of: showFirstLaunchCalculator) { _, isPresented in
            if !isPresented {
                hasCompletedFirstLaunchSetup = true
            }
        }
        .onAppear {
            if !hasCompletedFirstLaunchSetup {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showFirstLaunchCalculator = true
                }
            }
        }
    }
    
    // MARK: - Custom Bottom Tab Bar
    private var customTabBar: some View {
        HStack(spacing: 8) {
            // Main Dock Capsule (contains the 4 tabs)
            HStack(spacing: 0) {
                // Log Tab button
                TabBarItem(
                    iconName: "house.fill",
                    label: "Log",
                    isSelected: selectedTab == 0 && !showMenu,
                    namespace: tabNamespace,
                    action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            selectedTab = 0
                        }
                    }
                )
                
                // Track Tab button
                TabBarItem(
                    iconName: "chart.line.uptrend.xyaxis",
                    label: "Track",
                    isSelected: selectedTab == 1 && !showMenu,
                    namespace: tabNamespace,
                    action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            selectedTab = 1
                        }
                    }
                )
                
                // Goals Tab button
                TabBarItem(
                    iconName: "target",
                    label: "Goals",
                    isSelected: selectedTab == 2 && !showMenu,
                    namespace: tabNamespace,
                    action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            selectedTab = 2
                        }
                    }
                )
                
                // Account Tab button
                TabBarItem(
                    iconName: "person.fill",
                    label: "Account",
                    isSelected: selectedTab == 3 && !showMenu,
                    namespace: tabNamespace,
                    action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            selectedTab = 3
                        }
                    }
                )
            }
            .padding(.horizontal, 8)
            .frame(height: 70)
            .background(
                Color.white.opacity(0.05)
                    .background(.ultraThinMaterial)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.1), .black.opacity(0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            
            // Separate Plus Circle Button
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    showMenu.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(showMenu ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.35), .white.opacity(0.1), .black.opacity(0.15)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    Image(systemName: showMenu ? "xmark" : "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(showMenu ? .white : AppTheme.primaryText)
                        .rotationEffect(.degrees(showMenu ? 90 : 0))
                }
                .frame(width: 70, height: 70)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 22)
        .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 10)
    }
    
    // MARK: - Popup Action Menu
    @ViewBuilder
    private var popupMenuSection: some View {
        if selectedTab == 1 {
            // Weight Log Menu
            VStack(spacing: 16) {
                Text("Log Weight")
                    .helvetica(size: 18, weight: .bold)
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(AppTheme.secondaryText)
                            TextField("Weight (\(appWeightUnit))", text: $weightInput)
                                .keyboardType(.decimalPad)
                                .helvetica(size: 15)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .liquidGlassCard(cornerRadius: 10, borderOpacity: 0.1)
                        
                        Button(action: saveWeightEntry) {
                            Text("Log")
                                .helvetica(size: 14, weight: .bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 11)
                                .background(Color.white.opacity(0.08))
                                .background(.ultraThinMaterial)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                    
                    DatePicker("Date of Weight Log", selection: $weightDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .helvetica(size: 14, weight: .semibold)
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 24)
            .liquidGlassCard(cornerRadius: 24, borderOpacity: 0.15)
            .padding(.horizontal)
            .padding(.bottom, 20) // Positioned above custom button
        } else {
            // Food Log Menu
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    MenuGridItem(title: "Manual Log", icon: "pencil.line", iconColor: Color(hex: "F59E0B"), action: { showManualLogger = true; showMenu = false })
                    MenuGridItem(title: "Food Search", icon: "magnifyingglass", iconColor: Color(hex: "3B82F6"), action: { showFoodSearch = true; showMenu = false })
                }
                
                HStack(spacing: 12) {
                    MenuGridItem(title: "Scan Barcode", icon: "barcode.viewfinder", iconColor: Color(hex: "EF4444"), action: { showBarcodeScanner = true; showMenu = false })
                    MenuGridItem(title: "Recently Added", icon: "plus.circle.fill", iconColor: Color(hex: "10B981"), action: { showRecentFoods = true; showMenu = false })
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 24)
            .liquidGlassCard(cornerRadius: 24, borderOpacity: 0.15)
            .padding(.horizontal)
            .padding(.bottom, 20) // Positioned above custom button
        }
    }
    
    private func saveWeightEntry() {
        guard let weightVal = Double(weightInput), weightVal > 0 else { return }
        
        let finalWeight = appWeightUnit == "kg" ? weightVal / 0.45359237 : weightVal
        let newEntry = WeightEntry(weight: finalWeight, timestamp: weightDate)
        modelContext.insert(newEntry)
        try? modelContext.save()
        
        weightInput = ""
        weightDate = Date()
        showMenu = false
        
        // Dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Tab Bar Item Helper
struct TabBarItem: View {
    var iconName: String
    var label: String
    var isSelected: Bool
    var namespace: Namespace.ID
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 16))
                Text(label)
                    .helvetica(size: 9.5, weight: .semibold)
            }
            .foregroundColor(isSelected ? .white : AppTheme.secondaryText)
            .frame(width: 66, height: 48)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .matchedGeometryEffect(id: "activeTabBackground", in: namespace)
                    }
                }
            )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Menu Grid Item Button
struct MenuGridItem: View {
    var title: String
    var icon: String
    var iconColor: Color
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .helvetica(size: 14, weight: .semibold)
                    .foregroundColor(AppTheme.primaryText)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(12)
            .liquidGlassCard(cornerRadius: 12, borderOpacity: 0.1)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
