//
//  TenantSwitcherViewModel.swift
//  Core
//
//  Created by Kiro on 24/08/2025.
//

import Foundation
import Combine

public class TenantSwitcherViewModel: ObservableObject {
    @Published public var tenants: [TenantConfig] = []
    @Published public var currentTenant: TenantConfig?
    
    private let tenantManager: TenantManagerProtocol
    private let onTenantSwitched: (TenantConfig) -> Void
    private var cancellables = Set<AnyCancellable>()
    
    public init(
        tenants: [TenantConfig],
        tenantManager: TenantManagerProtocol,
        onTenantSwitched: @escaping (TenantConfig) -> Void
    ) {
        self.tenants = tenants
        self.tenantManager = tenantManager
        self.onTenantSwitched = onTenantSwitched
        
        // Подписываемся на изменения текущего тенанта
        tenantManager.currentTenantPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tenant in
                self?.currentTenant = tenant
            }
            .store(in: &cancellables)
    }
    
    public func loadTenants() {
        tenants = tenantManager.availableTenants
        currentTenant = tenantManager.currentTenant
    }
    
    public func switchToTenant(_ tenant: TenantConfig) {
        if tenantManager.isLoggedIn(for: tenant) {
            // Если пользователь уже залогинен в этот тенант, просто переключаемся
            tenantManager.setCurrentTenant(tenant)
            onTenantSwitched(tenant)
        } else {
            // Если не залогинен, устанавливаем тенант и переходим на экран логина
            tenantManager.setCurrentTenant(tenant)
            onTenantSwitched(tenant)
        }
    }
    
    public func isCurrentTenant(_ tenant: TenantConfig) -> Bool {
        return currentTenant?.id == tenant.id
    }
    
    public func isLoggedIn(tenant: TenantConfig) -> Bool {
        return tenantManager.isLoggedIn(for: tenant)
    }
}