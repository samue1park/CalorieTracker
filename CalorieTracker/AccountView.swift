import SwiftUI

struct AccountView: View {
    @AppStorage("username") private var username: String = ""
    @AppStorage("weightUnit") private var weightUnit: String = "lb"
    
    var body: some View {
        ZStack {
            AppTheme.accountBackgroundGradient.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header Card
                HStack {
                    Text("Account Settings")
                        .helvetica(size: 32, weight: .bold)
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Username Input Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("Profile Information")
                        .helvetica(size: 16, weight: .bold)
                        .foregroundStyle(AppTheme.primaryText)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Name")
                            .helvetica(size: 12, weight: .semibold)
                            .foregroundStyle(AppTheme.secondaryText)
                        
                        CustomTextField(placeholder: "Please enter your first name", text: $username)
                            .autocorrectionDisabled()
                    }
                }
                .glassCard()
                .padding(.horizontal)
                
                // App Settings Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("App Settings")
                        .helvetica(size: 16, weight: .bold)
                        .foregroundStyle(AppTheme.primaryText)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Weight Unit")
                                .helvetica(size: 14, weight: .semibold)
                                .foregroundColor(AppTheme.secondaryText)
                            
                            Spacer()
                            
                            Picker("Weight Unit", selection: $weightUnit) {
                                Text("lb").tag("lb")
                                Text("kg").tag("kg")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 100)
                        }
                    }
                }
                .glassCard()
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.bottom, 100)
        }
    }
}
