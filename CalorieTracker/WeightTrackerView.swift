import SwiftUI
import SwiftData
import Charts

struct WeightTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var allWeights: [WeightEntry]
    
    @State private var selectedRange: TimeRange = .oneMonth
    @State private var animateProgress: CGFloat = 1.0
    @State private var weightToEdit: WeightEntry? = nil
    @State private var editWeightInput: String = ""
    @State private var editWeightDate: Date = Date()
    
    @AppStorage("weightUnit") private var appWeightUnit: String = "lb"
    
    private func displayWeight(_ lbs: Double) -> Double {
        if appWeightUnit == "kg" {
            return lbs * 0.45359237
        } else {
            return lbs
        }
    }
    
    
    // Date formatter for display: Jun 18th, 2026
    private func formatWeightDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        let monthStr = formatter.string(from: date)
        formatter.dateFormat = "yyyy"
        let yearStr = formatter.string(from: date)
        
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        return "\(monthStr) \(day)\(suffix), \(yearStr)"
    }
    
    // Date formatter for lists: 06/18/26
    private func formatListDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter.string(from: date)
    }
    
    // Filter weights based on selectedTimeRange (with fallback to recent entries if insufficient data)
    var filteredWeights: [WeightEntry] {
        let calendar = Calendar.current
        let now = Date()
        
        // If range is 1W (7 days) and we have fewer than 2 entries in that timeframe,
        // fall back to showing the 5 most recent entries from allWeights.
        if selectedRange == .oneWeek {
            let inRange = allWeights.filter { entry in
                if let cutOff = calendar.date(byAdding: .day, value: -7, to: now) {
                    return entry.timestamp >= cutOff
                }
                return false
            }
            if inRange.count >= 2 {
                return inRange
            } else {
                return Array(allWeights.prefix(5))
            }
        }
        
        guard let days = selectedRange.days else {
            return allWeights
        }
        
        guard let cutOffDate = calendar.date(byAdding: .day, value: -days, to: now) else { return allWeights }
        
        let filtered = allWeights.filter { entry in
            entry.timestamp >= cutOffDate
        }
        
        // General fallback: if filtered has fewer than 2 entries, show up to 5 most recent entries.
        if filtered.count < 2 && !allWeights.isEmpty {
            return Array(allWeights.prefix(5))
        }
        
        return filtered
    }
    
    // Sort chronological for chart
    var chartEntries: [WeightEntry] {
        filteredWeights.sorted(by: { $0.timestamp < $1.timestamp })
    }
    
    var body: some View {
        ZStack {
            AppTheme.trackBackgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Pinned Header elements
                VStack(spacing: 16) {
                    // Header Card
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if let latest = allWeights.first {
                                Text(verbatim: String(format: "%.1f %@", displayWeight(latest.weight), appWeightUnit))
                                    .helvetica(size: 32, weight: .bold)
                                    .foregroundStyle(AppTheme.primaryText)
                                Text(formatWeightDate(latest.timestamp))
                                    .helvetica(size: 14)
                                    .foregroundStyle(AppTheme.secondaryText)
                            } else {
                                Text("-- \(appWeightUnit)")
                                    .helvetica(size: 32, weight: .bold)
                                    .foregroundStyle(AppTheme.primaryText)
                                Text(formatWeightDate(Date()))
                                    .helvetica(size: 14)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Time Range Selector
                    RangeSelectorView(selectedRange: $selectedRange)
                        .frame(height: 38)
                        .padding(.horizontal)
                        .padding(.bottom, 5)
                    
                    // Chart Area (Trend line across screen)
                    chartView
                        .frame(height: 180)
                        .padding(.vertical, 8)
                    
                    // Weight History Section Header
                    HStack {
                        Text("Weight History (\(selectedRange.rawValue))")
                            .helvetica(size: 18, weight: .bold)
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                
                // Scrollable Content
                if filteredWeights.isEmpty {
                    VStack(spacing: 8) {
                        Text("No weight entries recorded in this timeframe.")
                            .helvetica(size: 14)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .glassCard()
                    .padding(.horizontal)
                    
                    Spacer()
                } else {
                    List {
                        ForEach(filteredWeights) { entry in
                            HStack {
                                Text(formatListDate(entry.timestamp))
                                    .helvetica(size: 15)
                                    .foregroundColor(AppTheme.secondaryText)
                                
                                Spacer()
                                
                                Text(verbatim: String(format: "%.1f %@", displayWeight(entry.weight), appWeightUnit))
                                    .helvetica(size: 15, weight: .bold)
                                    .foregroundColor(AppTheme.primaryText)
                            }
                            .padding()
                            .liquidGlassCard(cornerRadius: 12, borderOpacity: 0.1)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    editWeightInput = String(format: "%.1f", displayWeight(entry.weight))
                                    editWeightDate = entry.timestamp
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        weightToEdit = entry
                                    }
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
                        
                        // Bottom spacing item to allow scrolling past the floating tab bar
                        Color.clear
                            .frame(height: 100)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                }
            }
            
            if weightToEdit != nil {
                // Dimmed background
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            weightToEdit = nil
                        }
                    }
                    .transition(.opacity)
                
                VStack {
                    Spacer()
                    
                    // Edit weight log popup
                    VStack(spacing: 16) {
                        Text("Edit Weight")
                            .helvetica(size: 18, weight: .bold)
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 14) {
                            HStack(spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.pencil")
                                        .foregroundColor(AppTheme.secondaryText)
                                    TextField("Weight (\(appWeightUnit))", text: $editWeightInput)
                                        .keyboardType(.decimalPad)
                                        .helvetica(size: 15)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .liquidGlassCard(cornerRadius: 10, borderOpacity: 0.1)
                                
                                Button(action: saveEditedWeight) {
                                    Text("Save")
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
                                .disabled(Double(editWeightInput) == nil || (Double(editWeightInput) ?? 0) <= 0)
                            }
                            
                            DatePicker("Date of Weight Log", selection: $editWeightDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .helvetica(size: 14, weight: .semibold)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 24)
                    .liquidGlassCard(cornerRadius: 24, borderOpacity: 0.15)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .onChange(of: selectedRange) { _, _ in
            animateProgress = 0.0
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.8)) {
                    animateProgress = 1.0
                }
            }
        }
    }
    
    private var chartView: some View {
        ZStack {
            if chartEntries.isEmpty {
                VStack {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.secondaryText.opacity(0.4))
                    Text("No weight records in this timeframe")
                        .helvetica(size: 13, weight: .semibold)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                let weights = chartEntries.map { displayWeight($0.weight) }
                let minWeight = weights.min() ?? 50
                let maxWeight = weights.max() ?? 100
                let padding = (maxWeight - minWeight) * 0.2
                let yMin = max(0, minWeight - (padding > 0 ? padding : 5))
                let yMax = maxWeight + (padding > 0 ? padding : 5)
                
                Chart {
                    ForEach(chartEntries) { entry in
                        LineMark(
                            x: .value("Date", entry.timestamp),
                            y: .value("Weight", displayWeight(entry.weight))
                        )
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .foregroundStyle(.white)
                        .interpolationMethod(.catmullRom)
                    }
                }
                .animation(nil, value: chartEntries)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: yMin...yMax)
                .shadow(color: .white.opacity(0.3), radius: 4, x: 0, y: 2)
                .clipped()
                .mask(
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: animateProgress * geo.size.width)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                )
            }
        }
    }
    
    

    

    
    private func deleteEntry(_ entry: WeightEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }
    
    private func saveEditedWeight() {
        guard let entry = weightToEdit,
              let weightVal = Double(editWeightInput),
              weightVal > 0 else { return }
        
        let finalWeight = appWeightUnit == "kg" ? weightVal / 0.45359237 : weightVal
        entry.weight = finalWeight
        entry.timestamp = editWeightDate
        try? modelContext.save()
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            weightToEdit = nil
        }
        
        // Dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

enum TimeRange: String, CaseIterable, Identifiable {
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "ALL"
    
    var id: String { self.rawValue }
    
    var days: Int? {
        switch self {
        case .oneWeek: return 7
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .oneYear: return 365
        case .all: return nil
        }
    }
}

struct RangeSelectorView: View {
    @Binding var selectedRange: TimeRange
    
    var body: some View {
        Picker("Time Range", selection: $selectedRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
}


