//
//  TenantSelectionViewModel.swift
//  Core
//
//  Created by Kiro on 24/08/2025.
//

import Foundation
import Combine

public class TenantSelectionViewModel: ObservableObject {
    @Published public var tenants: [TenantConfig] = []
    
    private let tenantManager: TenantManagerProtocol
    private let onTenantSelected: (TenantConfig) -> Void
    
    public init(
        tenants: [TenantConfig],
        tenantManager: TenantManagerProtocol,
        onTenantSelected: @escaping (TenantConfig) -> Void
    ) {
        self.tenants = tenants
        self.tenantManager = tenantManager
        self.onTenantSelected = onTenantSelected
    }
    
    public func loadTenants() {
        tenants = tenantManager.availableTenants
    }
    
    public func selectTenant(_ tenant: TenantConfig) {
        print("🔧 TenantSelectionViewModel selectTenant called: \(tenant.environmentDisplayName)")
        tenantManager.setCurrentTenant(tenant)
        print("🔧 TenantSelectionViewModel calling onTenantSelected callback")
        onTenantSelected(tenant)
    }
    
    public func isLoggedIn(tenant: TenantConfig) -> Bool {
        return tenantManager.isLoggedIn(for: tenant)
    }
}