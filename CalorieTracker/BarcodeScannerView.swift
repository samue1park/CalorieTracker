import SwiftUI
import SwiftData
import AVFoundation
import Combine

struct BarcodeScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var selectedDate: Date = Date()
    
    @State private var barcode: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var foundProduct: ScannedProduct? = nil
    
    // Scanner State Machine
    enum ScannerState {
        case scanning
        case confirming(product: ScannedProduct)
        case editing(product: ScannedProduct)
    }
    @State private var scannerState: ScannerState = .scanning
    
    // Form State (Same as Manual Logger)
    @State private var name: String = ""
    @State private var caloriesString: String = ""
    @State private var proteinString: String = ""
    @State private var carbsString: String = ""
    @State private var fatString: String = ""
    @State private var servingSizeString: String = "1.0"
    
    // Permission and active session tracking
    @StateObject private var permissionManager = CameraPermissionManager()
    
    struct ScannedProduct: Identifiable {
        let id = UUID()
        let name: String
        let calories: Int
        let protein: Double
        let carbs: Double
        let fat: Double
    }
    
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    var isEditing: Bool {
        if case .editing = scannerState {
            return true
        }
        return false
    }
    
    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(caloriesString) != nil &&
        Double(servingSizeString) != nil && (Double(servingSizeString) ?? 0) > 0
    }
    
    var navigationTitleText: String {
        switch scannerState {
        case .scanning:
            return "Scan Barcode"
        case .confirming:
            return "Verify Food"
        case .editing:
            return "Manual Log"
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.originalBackgroundGradient
                    .ignoresSafeArea()
                
                switch scannerState {
                case .scanning:
                    scanningView
                case .confirming(let product):
                    confirmingView(for: product)
                case .editing:
                    ScrollView(showsIndicators: false) {
                        editingFormView
                    }
                }
            }
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        handleCancel()
                    }) {
                        Text(isEditing ? "Back" : "Close")
                            .helvetica(size: 15, weight: .semibold)
                            .foregroundColor(AppTheme.primaryText)
                    }
                }
            }
            .onAppear {
                permissionManager.checkPermission()
            }
        }
    }
}

// Extends BarcodeScannerView to helper scanner state matching
extension BarcodeScannerView.ScannerState: Equatable {
    static func == (lhs: BarcodeScannerView.ScannerState, rhs: BarcodeScannerView.ScannerState) -> Bool {
        switch (lhs, rhs) {
        case (.scanning, .scanning): return true
        case (.confirming, .confirming): return true
        case (.editing, .editing): return true
        default: return false
        }
    }
}

extension BarcodeScannerView {
    // MARK: - Scanning View (Integrated Viewport Guide)
    private var scanningView: some View {
        ZStack {
            if isSimulator {
                // simulated camera viewport block
                Color(hex: "0B0D11")
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "camera.badge.ellipsis")
                                .font(.system(size: 36))
                                .foregroundColor(AppTheme.secondaryText.opacity(0.4))
                            Text("Simulator Mode")
                                .helvetica(size: 14, weight: .semibold)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    )
            } else {
                if permissionManager.isAuthorized {
                    // Integrated Live AVCaptureSession Viewport
                    CameraScannerRepresentable { scannedBarcode in
                        triggerHapticFeedback()
                        barcode = scannedBarcode
                        fetchProductFromOpenFoodFacts()
                    }
                    .ignoresSafeArea()
                } else {
                    Color.black
                        .ignoresSafeArea()
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(AppTheme.secondaryText.opacity(0.4))
                                Text("Camera access required to scan barcodes")
                                    .helvetica(size: 14, weight: .semibold)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button("Grant Access") {
                                    permissionManager.requestAccess()
                                }
                                .helvetica(size: 14, weight: .bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(AppTheme.accent)
                                .cornerRadius(10)
                            }
                        )
                }
            }
            
            // Centered viewfinder brackets guide [    ]
            ViewfinderBrackets()
            
            // Mock buttons placed at the bottom of the screen (only for simulator)
            if isSimulator {
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Button("Mock Coca-Cola") {
                            simulateMockScanCocaCola()
                        }
                        .helvetica(size: 12, weight: .semibold)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(AppTheme.cardBackground.opacity(0.85))
                        .foregroundColor(AppTheme.primaryText)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.cardBorder, lineWidth: 1))
                        
                        Button("Mock Granola") {
                            simulateMockScanGranola()
                        }
                        .helvetica(size: 12, weight: .semibold)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(AppTheme.cardBackground.opacity(0.85))
                        .foregroundColor(AppTheme.primaryText)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.cardBorder, lineWidth: 1))
                    }
                    .padding(.bottom, 50)
                }
            }
            
            // Loading Dialog
            if isLoading {
                Color.black.opacity(0.5)
                
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(AppTheme.accent)
                    Text("Searching database...")
                        .helvetica(size: 14, weight: .semibold)
                        .foregroundColor(AppTheme.secondaryText)
                }
                .padding(24)
                .glassCard()
            }
            
            // Error Message Alert Display
            if let error = errorMessage {
                VStack {
                    Text(error)
                        .helvetica(size: 12, weight: .medium)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(10)
                        .shadow(radius: 4)
                        .padding(.top, 24)
                    Spacer()
                }
                .transition(.move(edge: .top))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation {
                            self.errorMessage = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Confirmation View (Condensed Detail Card Screen)
    private func confirmingView(for product: ScannedProduct) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Condensed Product Detail Card with integrated 1x2 side-by-side buttons
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Product Identified")
                        .helvetica(size: 12, weight: .bold)
                        .foregroundColor(AppTheme.secondaryText)
                        .textCase(.uppercase)
                        .tracking(1.5)
                    
                    Text(product.name)
                        .helvetica(size: 20, weight: .bold)
                        .foregroundColor(AppTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Divider()
                    .background(AppTheme.cardBorder)
                    .padding(.horizontal)
                
                Text("Is this the correct item?")
                    .helvetica(size: 15, weight: .semibold)
                    .foregroundColor(AppTheme.primaryText)
                
                // 1x2 Action buttons
                HStack(spacing: 12) {
                    // Yes Button
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            // Populate manual log form fields
                            self.name = product.name
                            self.caloriesString = String(product.calories)
                            self.proteinString = product.protein.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", product.protein) : String(format: "%.1f", product.protein)
                            self.carbsString = product.carbs.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", product.carbs) : String(format: "%.1f", product.carbs)
                            self.fatString = product.fat.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", product.fat) : String(format: "%.1f", product.fat)
                            self.servingSizeString = "1.0"
                            
                            scannerState = .editing(product: product)
                        }
                    }) {
                        Text("Yes")
                            .helvetica(size: 14, weight: .bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(AppTheme.accent)
                            .cornerRadius(10)
                            .shadow(color: AppTheme.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    
                    // No Button
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            scannerState = .scanning
                            barcode = ""
                        }
                    }) {
                        Text("No, Scan Again")
                            .helvetica(size: 14, weight: .bold)
                            .foregroundColor(AppTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(AppTheme.cardBackground.opacity(0.5))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                    }
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(AppTheme.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Editing Form View (Identical to Manual Logger View)
    private var editingFormView: some View {
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
            
            // Card 2: Macronutrients
            VStack(spacing: 0) {
                // Calories
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
                
                // Protein
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
                
                // Carbs
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
                
                // Fat
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
            
            // Card 3: Servings Multiplier
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
            Button(action: saveScannedProduct) {
                Text("Save Entry")
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
    
    // MARK: - Viewfinder Brackets Guide
    struct ViewfinderBrackets: View {
        var body: some View {
            HStack {
                // Left Bracket
                Path { path in
                    let w: CGFloat = 20
                    let h: CGFloat = 60
                    path.move(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: w, y: h))
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: 20, height: 60)
                
                Spacer()
                
                // Right Bracket
                Path { path in
                    let w: CGFloat = 20
                    let h: CGFloat = 60
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: 20, height: 60)
            }
            .frame(width: 180, height: 60)
        }
    }
    
    // MARK: - Actions
    private func handleCancel() {
        switch scannerState {
        case .scanning, .confirming:
            dismiss()
        case .editing:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                scannerState = .scanning
                barcode = ""
                foundProduct = nil
            }
        }
    }
    
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    private func simulateMockScanCocaCola() {
        triggerHapticFeedback()
        barcode = "5449000000996"
        fetchProductFromOpenFoodFacts()
    }
    
    private func simulateMockScanGranola() {
        triggerHapticFeedback()
        let product = ScannedProduct(
            name: "Premium Honey Almond Granola",
            calories: 210,
            protein: 6.0,
            carbs: 38.0,
            fat: 5.0
        )
        self.foundProduct = product
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            scannerState = .confirming(product: product)
        }
    }
    
    private func saveScannedProduct() {
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
        
        let entry = FoodEntry(
            name: finalName,
            calories: finalCalories,
            protein: finalProtein,
            carbs: finalCarbs,
            fat: finalFat,
            timestamp: selectedDate.combiningTime(from: Date()),
            servings: servings
        )
        modelContext.insert(entry)
        dismiss()
    }
    
    private func fetchProductFromOpenFoodFacts() {
        guard !barcode.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        foundProduct = nil
        
        let cleanedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try local SQLite lookup first
        if let localFood = FoodDatabase.shared.lookupBarcode(barcode: cleanedBarcode) {
            let product = ScannedProduct(
                name: localFood.name,
                calories: localFood.calories,
                protein: localFood.protein,
                carbs: localFood.carbs,
                fat: localFood.fat
            )
            
            self.foundProduct = product
            self.isLoading = false
            
            // Automatically transition scanner state to confirming
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                scannerState = .confirming(product: product)
            }
            return
        }
        
        // Open Food Facts API v2 URL (online fallback)
        let urlString = "https://world.openfoodfacts.org/api/v2/product/\(cleanedBarcode).json"
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            errorMessage = "Invalid barcode format."
            return
        }
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw NSError(domain: "Scanner", code: 404, userInfo: [NSLocalizedDescriptionKey: "Product database query failed."])
                }
                
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // Validate API v2 status codes (e.g. status "product_found" or status 1)
                let statusVal = json?["status"]
                let isFound: Bool
                if let statusStr = statusVal as? String {
                    isFound = (statusStr == "product_found" || statusStr == "success")
                } else if let statusInt = statusVal as? Int {
                    isFound = (statusInt == 1)
                } else {
                    isFound = false
                }
                
                guard isFound, let productDict = json?["product"] as? [String: Any] else {
                    throw NSError(domain: "Scanner", code: 404, userInfo: [NSLocalizedDescriptionKey: "Product not found in database."])
                }
                
                let productName = productDict["product_name"] as? String ?? "Unknown Product"
                let nutriments = productDict["nutriments"] as? [String: Any] ?? [:]
                
                let kcal = nutriments["energy-kcal_serving"] as? Double ?? nutriments["energy-kcal_100g"] as? Double ?? 0.0
                let protein = nutriments["proteins_serving"] as? Double ?? nutriments["proteins_100g"] as? Double ?? 0.0
                let carbs = nutriments["carbohydrates_serving"] as? Double ?? nutriments["carbohydrates_100g"] as? Double ?? 0.0
                let fat = nutriments["fat_serving"] as? Double ?? nutriments["fat_100g"] as? Double ?? 0.0
                
                await MainActor.run {
                    let product = ScannedProduct(
                        name: productName,
                        calories: Int(kcal),
                        protein: protein,
                        carbs: carbs,
                        fat: fat
                    )
                    self.foundProduct = product
                    self.isLoading = false
                    
                    // Automatically transition scanner state to confirming
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        scannerState = .confirming(product: product)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    self.barcode = "" // Reset barcode so they can try again
                }
            }
        }
    }
}

// MARK: - Camera Permission Manager
class CameraPermissionManager: ObservableObject {
    @Published var isAuthorized: Bool = false
    
    func checkPermission() {
        #if targetEnvironment(simulator)
        isAuthorized = true
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            requestAccess()
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
        #endif
    }
    
    func requestAccess() {
        #if !targetEnvironment(simulator)
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
        }
        #endif
    }
}

// MARK: - Native AVCaptureSession Coordinator Wrapper
struct CameraScannerRepresentable: UIViewControllerRepresentable {
    var onBarcodeScanned: (String) -> Void
    
    func makeUIViewController(context: Context) -> CameraScannerViewController {
        let controller = CameraScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeScanned: onBarcodeScanned)
    }
    
    class Coordinator: NSObject, CameraScannerViewControllerDelegate {
        var onBarcodeScanned: (String) -> Void
        
        init(onBarcodeScanned: @escaping (String) -> Void) {
            self.onBarcodeScanned = onBarcodeScanned
        }
        
        func cameraScannerViewController(_ controller: CameraScannerViewController, didDetectBarcode barcode: String) {
            onBarcodeScanned(barcode)
        }
    }
}

protocol CameraScannerViewControllerDelegate: AnyObject {
    func cameraScannerViewController(_ controller: CameraScannerViewController, didDetectBarcode barcode: String)
}

class CameraScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: CameraScannerViewControllerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let session = captureSession, !session.isRunning {
            DispatchQueue.global(qos: .background).async {
                session.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let session = captureSession, session.isRunning {
            session.stopRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        captureSession = session
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("Failed to initialize capture device input: \(error)")
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39, .code93]
        } else {
            return
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview
        
        DispatchQueue.global(qos: .background).async {
            session.startRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  let stringValue = readableObject.stringValue else { return }
            
            delegate?.cameraScannerViewController(self, didDetectBarcode: stringValue)
        }
    }
}
