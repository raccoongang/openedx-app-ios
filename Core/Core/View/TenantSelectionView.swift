//
//  TenantSelectionView.swift
//  Core
//
//  Created by Kiro on 24/08/2025.
//

import SwiftUI
import Theme
import KeychainSwift

//extension Color {
//    init(hex: String) {
//        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
//        var int: UInt64 = 0
//        Scanner(string: hex).scanHexInt64(&int)
//        let a, r, g, b: UInt64
//        switch hex.count {
//        case 3: // RGB (12-bit)
//            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
//        case 6: // RGB (24-bit)
//            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
//        case 8: // ARGB (32-bit)
//            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
//        default:
//            (a, r, g, b) = (1, 1, 1, 0)
//        }
//
//        self.init(
//            .sRGB,
//            red: Double(r) / 255,
//            green: Double(g) / 255,
//            blue:  Double(b) / 255,
//            opacity: Double(a) / 255
//        )
//    }
//}

public struct TenantSelectionView: View {
    @ObservedObject private var viewModel: TenantSelectionViewModel
    
    public init(viewModel: TenantSelectionViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                // Background
                Theme.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "graduationcap.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 80)
                            .foregroundColor(Theme.Colors.accentColor)
                        
                        Text(CoreLocalization.TenantSelection.title)
                            .font(Theme.Fonts.titleLarge)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text(CoreLocalization.TenantSelection.subtitle)
                            .font(Theme.Fonts.bodyMedium)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                    
                    Spacer(minLength: 32)
                    
                    // Tenant List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.tenants) { tenant in
                                TenantCardView(
                                    tenant: tenant,
                                    isLoggedIn: viewModel.isLoggedIn(tenant: tenant)
                                ) {
                                    viewModel.selectTenant(tenant)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer(minLength: 32)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadTenants()
        }
    }
}

struct TenantCardView: View {
    let tenant: TenantConfig
    let isLoggedIn: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Tenant Icon/Color
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: tenant.accentColor ?? "#007AFF"))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(String(tenant.environmentDisplayName.prefix(2).uppercased()))
                            .font(Theme.Fonts.labelLarge)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(tenant.environmentDisplayName)
                        .font(Theme.Fonts.titleMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Text(tenant.baseURL)
                        .font(Theme.Fonts.bodySmall)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isLoggedIn {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .font(.caption)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.Colors.cardViewBackground)
                    .shadow(color: Theme.Colors.shadowColor, radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}



#if DEBUG
//struct TenantSelectionView_Previews: PreviewProvider {
//    static var previews: some View {
//        let mockTenants = [
//            TenantConfig(
//                baseURL: "https://axim-ccpv-dev.raccoongang.net",
//                ssoURL: "http://localhost:8000",
//                ssoFinishedURL: "http://localhost:8000",
//                environmentDisplayName: "axim-ccpv-dev",
//                feedbackEmail: "support@example.com",
//                oAuthClientId: "test",
//                ssoButtonTitle: [:],
//                discovery: DiscoveryConfig(dictionary: [:]),
//                uiComponents: UIComponentsConfig(dictionary: [:]),
//                accentColor: "#ED8794"
//            ),
//            TenantConfig(
//                baseURL: "https://axim-mobile-dev.raccoongang.net",
//                ssoURL: "http://localhost:8000",
//                ssoFinishedURL: "http://localhost:8000",
//                environmentDisplayName: "lms-axim-stage",
//                feedbackEmail: "support@example.com",
//                oAuthClientId: "test2",
//                ssoButtonTitle: [:],
//                discovery: DiscoveryConfig(dictionary: [:]),
//                uiComponents: UIComponentsConfig(dictionary: [:]),
//                accentColor: "#007AFF"
//            )
//        ]
//        
//        let viewModel = TenantSelectionViewModel(
//            tenants: mockTenants,
//            tenantManager: TenantManager(storage: AppStorage(keychain: KeychainSwift(), userDefaults: UserDefaults.standard), multiTenantConfig: nil),
//            onTenantSelected: { _ in }
//        )
//        
//        TenantSelectionView(viewModel: viewModel)
//    }
//}
#endif
