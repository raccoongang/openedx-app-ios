//
//  TenantSwitcherView.swift
//  Core
//
//  Created by Kiro on 24/08/2025.
//

import SwiftUI
import Theme
import KeychainSwift

public struct TenantSwitcherView: View {
    @ObservedObject private var viewModel: TenantSwitcherViewModel
    
    public init(viewModel: TenantSwitcherViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(CoreLocalization.TenantSelection.switchTenant)
                .font(Theme.Fonts.titleMedium)
                .foregroundColor(Theme.Colors.textPrimary)
            
            ForEach(viewModel.tenants) { tenant in
                TenantRowView(
                    tenant: tenant,
                    isSelected: viewModel.isCurrentTenant(tenant),
                    isLoggedIn: viewModel.isLoggedIn(tenant: tenant)
                ) {
                    viewModel.switchToTenant(tenant)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Colors.cardViewBackground)
        )
        .onAppear {
            viewModel.loadTenants()
        }
    }
}

struct TenantRowView: View {
    let tenant: TenantConfig
    let isSelected: Bool
    let isLoggedIn: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Tenant Color Indicator
                Circle()
                    .fill(Color(hex: tenant.accentColor ?? "#007AFF"))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tenant.environmentDisplayName)
                        .font(Theme.Fonts.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    if !isLoggedIn {
                        Text(CoreLocalization.TenantSelection.notLoggedIn)
                            .font(Theme.Fonts.bodySmall)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(Color(hex: tenant.accentColor ?? "#007AFF"))
                        .font(.caption)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#if DEBUG
//struct TenantSwitcherView_Previews: PreviewProvider {
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
//        let viewModel = TenantSwitcherViewModel(
//            tenants: mockTenants,
//            tenantManager: TenantManager(storage: AppStorage(keychain: KeychainSwift(), userDefaults: UserDefaults.standard), multiTenantConfig: nil),
//            onTenantSwitched: { _ in }
//        )
//        
//        TenantSwitcherView(viewModel: viewModel)
//            .padding()
//    }
//}
#endif
