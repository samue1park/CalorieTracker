import SwiftUI
import SwiftData

struct RecentlyAddedFoodsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var selectedDate: Date = Date()
    
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var allEntries: [FoodEntry]
    
    @State private var entryToEdit: FoodEntry? = nil
    @State private var showAddedNotification = false
    @State private var notificationWorkItem: DispatchWorkItem? = nil
    
    // Get unique food entries by name
    var uniqueRecentEntries: [FoodEntry] {
        var seenNames = Set<String>()
        var uniqueList: [FoodEntry] = []
        
        let limit = allEntries.prefix(100)
        for entry in limit {
            let nameLower = entry.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !seenNames.contains(nameLower) {
                seenNames.insert(nameLower)
                uniqueList.append(entry)
                if uniqueList.count >= 15 {
                    break
                }
            }
        }
        return uniqueList
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.originalBackgroundGradient
                    .ignoresSafeArea()
                
                if uniqueRecentEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.secondaryText.opacity(0.5))
                        Text("No recent entries found")
                            .helvetica(size: 16, weight: .bold)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(uniqueRecentEntries) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.name)
                                        .helvetica(size: 16, weight: .bold)
                                        .foregroundStyle(AppTheme.primaryText)
                                    
                                    HStack(spacing: 10) {
                                        Text("P: \(Int(entry.protein))g")
                                        Text("C: \(Int(entry.carbs))g")
                                        Text("F: \(Int(entry.fat))g")
                                    }
                                    .helvetica(size: 11)
                                    .foregroundStyle(AppTheme.secondaryText)
                                }
                                
                                Spacer()
                                
                                Text("\(entry.calories) kcal")
                                    .helvetica(size: 16, weight: .bold)
                                    .foregroundStyle(AppTheme.primaryText)
                                
                                Button(action: { addQuickCopy(entry) }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(AppTheme.accent)
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 8)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                entryToEdit = entry
                            }
                            .listRowBackground(AppTheme.cardBackground.opacity(0.8))
                            .listRowSeparatorTint(AppTheme.cardBorder)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
                
                // Top notification banner
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
            .navigationTitle("Recently Added Foods")
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
            .sheet(item: $entryToEdit) { entry in
                ManualLoggerView(entryToEdit: entry)
            }
        }
    }
    
    private func addQuickCopy(_ entry: FoodEntry) {
        let newEntry = FoodEntry(
            name: entry.name,
            calories: entry.calories,
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat,
            timestamp: selectedDate.combiningTime(from: Date())
        )
        modelContext.insert(newEntry)
        try? modelContext.save()
        
        // Cancel any pending notification dismissal
        notificationWorkItem?.cancel()
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showAddedNotification = true
        }
        
        let workItem = DispatchWorkItem {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showAddedNotification = false
            }
        }
        notificationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }
}

#Preview {
    RecentlyAddedFoodsView()
}
