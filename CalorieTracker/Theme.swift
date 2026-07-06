import SwiftUI
import CoreText

struct AppTheme {
    // Colors
    static let background = Color(hex: "0D0F12") // Dark slate background
    static let cardBackground = Color(hex: "171A21") // Slightly lighter dark slate
    static let cardBorder = Color(hex: "242A35")
    
    // Brand Colors
    static let accent = Color(hex: "3B82F6") // Brand Blue
    static let primaryText = Color(hex: "F3F4F6")
    static let secondaryText = Color(hex: "9CA3AF")
    
    // Nutrient Colors
    static let calories = Color(hex: "3B82F6") // Blue
    static let protein = Color(hex: "EF4444")  // Red/Coral
    static let carbs = Color(hex: "10B981")    // Emerald Green
    static let fat = Color(hex: "F59E0B")      // Amber/Gold
    
    static let purpleAccent = Color(hex: "8B5CF6") // Brand Premium Purple
    static let purpleGradient = Gradient(colors: [Color(hex: "8B5CF6"), Color(hex: "A78BFA")])
    
    // Gradients
    static let calorieGradient = Gradient(colors: [Color(hex: "3B82F6"), Color(hex: "60A5FA")])
    static let proteinGradient = Gradient(colors: [Color(hex: "EF4444"), Color(hex: "F87171")])
    static let carbsGradient = Gradient(colors: [Color(hex: "10B981"), Color(hex: "34D399")])
    static let fatGradient = Gradient(colors: [Color(hex: "F59E0B"), Color(hex: "FBBF24")])
    static let logBackgroundGradient = RadialGradient(
        gradient: Gradient(colors: [Color(hex: "172B3E"), Color(hex: "0C0E12")]),
        center: .top,
        startRadius: 0,
        endRadius: 450
    )
    static let trackBackgroundGradient = RadialGradient(
        gradient: Gradient(colors: [Color(hex: "123328"), Color(hex: "0A0D0B")]),
        center: .top,
        startRadius: 0,
        endRadius: 450
    )
    static let goalsBackgroundGradient = RadialGradient(
        gradient: Gradient(colors: [Color(hex: "2B1B4E"), Color(hex: "0C0912")]),
        center: .top,
        startRadius: 0,
        endRadius: 450
    )
    static let accountBackgroundGradient = RadialGradient(
        gradient: Gradient(colors: [Color(hex: "32200E"), Color(hex: "0C0A08")]),
        center: .top,
        startRadius: 0,
        endRadius: 450
    )
    static let originalBackgroundGradient = LinearGradient(
        gradient: Gradient(colors: [background, Color(hex: "1E2330")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let backgroundGradient = logBackgroundGradient
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 1)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Custom Glassmorphic Card modifier
struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .liquidGlassCard(cornerRadius: 16, borderOpacity: 0.15)
    }
}

extension View {
    func glassCard() -> some View {
        self.modifier(GlassCardModifier())
    }
    
    func liquidGlassCard(cornerRadius: CGFloat = 16, borderOpacity: Double = 0.15) -> some View {
        self
            .background(Color.white.opacity(0.02))
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(borderOpacity), .white.opacity(0.05), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

// Custom Circular Progress Ring
struct ProgressRing: View {
    var progress: Double // value between 0.0 and 1.0
    var gradient: Gradient
    var ringWidth: CGFloat = 14
    var size: CGFloat = 120
    var centerText: String
    var centerSubtitle: String
    
    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(AppTheme.cardBorder, lineWidth: ringWidth)
                .frame(width: size, height: size)
            
            // Progress Fill
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    AngularGradient(
                        gradient: gradient,
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(Angle(degrees: -90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            
            // Text labels
            VStack(spacing: 2) {
                Text(centerText)
                    .font(.custom("Manrope-Light", size: size * 0.16))
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                Text(centerSubtitle)
                    .font(.custom("Manrope-Medium", size: size * 0.08))
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.secondaryText)
                    .textCase(.uppercase)
            }
        }
    }
}

// Custom linear progress for macros
struct MacroProgressLine: View {
    var label: String
    var current: Double
    var target: Double
    var color: Color
    var icon: String
    var showFraction: Bool
    
    var progress: Double {
        target > 0 ? current / target : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .instrumentSerif(size: 19, weight: .bold)
                    .foregroundStyle(AppTheme.secondaryText)
                
                Spacer()
                
                if showFraction {
                    Text(verbatim: "\(Int(current))g / \(Int(target))g")
                        .font(.custom("Manrope-Medium", size: 14))
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    if current > target {
                        Text(verbatim: "\(Int(current - target))g over")
                            .font(.custom("Manrope-SemiBold", size: 14))
                            .foregroundStyle(color)
                    } else {
                        Text(verbatim: "\(Int(max(target - current, 0)))g left")
                            .font(.custom("Manrope-Medium", size: 14))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.cardBorder)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .saturation(progress > 1.0 ? 1.8 : 1.0)
                        .shadow(color: color.opacity(progress > 1.0 ? 0.6 : 0.0), radius: 4, x: 0, y: 0)
                        .frame(width: geometry.size.width * CGFloat(min(progress, 1.0)), height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

// View extensions for global Manrope, Instrument Serif, and number formatting
extension View {
    func helvetica(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        let fontName: String
        switch weight {
        case .bold, .heavy, .black:
            fontName = "Manrope-SemiBold"
        case .semibold, .medium:
            fontName = "Manrope-Medium"
        default:
            fontName = "Manrope-Light"
        }
        return self.font(.custom(fontName, size: size))
    }
    
    func instrumentSerif(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        // Instrument Serif only has a regular weight style
        return self.font(.custom("InstrumentSerif-Regular", size: size))
    }
}

// Programmatic Custom Font Registry
public final class FontRegistry {
    public static func registerFonts() {
        let fontNames = [
            "Manrope-Light",
            "Manrope-Regular",
            "Manrope-Medium",
            "Manrope-SemiBold",
            "InstrumentSerif-Regular"
        ]
        
        for name in fontNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                print("Font not found in bundle: \(name)")
                continue
            }
            
            var error: Unmanaged<CFError>?
            guard let dataProvider = CGDataProvider(url: url as CFURL),
                  let font = CGFont(dataProvider) else {
                print("Failed to load graphics font for: \(name)")
                continue
            }
            
            if !CTFontManagerRegisterGraphicsFont(font, &error) {
                if let error = error {
                    let description = CFErrorCopyDescription(error.takeRetainedValue()) as String
                    print("Failed to register font \(name): \(description)")
                }
            }
        }
    }
}

