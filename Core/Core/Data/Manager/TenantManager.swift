//
//  TenantManager.swift
//  Core
//
//  Created by Kiro on 24/08/2025.
//

import Foundation
import Combine
import KeychainSwift
import OEXFoundation
import Swinject

public protocol TenantManagerProtocol: Sendable {
    var currentTenant: TenantConfig? { get }
    var availableTenants: [TenantConfig] { get }
    var isMultiTenant: Bool { get }
    var currentTenantPublisher: AnyPublisher<TenantConfig?, Never> { get }
    
    func setCurrentTenant(_ tenant: TenantConfig)
    func getCurrentTenantKey() -> String
    func isLoggedIn(for tenant: TenantConfig) -> Bool
    func logout(from tenant: TenantConfig)
    func switchToNextAvailableTenant()
    func clearCurrentTenant()
}

public final class TenantManager: TenantManagerProtocol, @unchecked Sendable {
    private let storage: CoreStorage
    private let multiTenantConfig: MultiTenantConfig?
    private let currentTenantSubject = CurrentValueSubject<TenantConfig?, Never>(nil)
    
    private let KEY_CURRENT_TENANT = "currentTenant"
    
    public var currentTenant: TenantConfig? {
        return currentTenantSubject.value
    }
    
    public var availableTenants: [TenantConfig] {
        return multiTenantConfig?.tenants ?? []
    }
    
    public var isMultiTenant: Bool {
        return multiTenantConfig?.isMultiTenant ?? false
    }
    
    public var currentTenantPublisher: AnyPublisher<TenantConfig?, Never> {
        return currentTenantSubject.eraseToAnyPublisher()
    }
    
    public init(storage: CoreStorage, multiTenantConfig: MultiTenantConfig?) {
        self.storage = storage
        self.multiTenantConfig = multiTenantConfig
        
        print("🔧 TenantManager init:")
        print("  - isMultiTenant: \(isMultiTenant)")
        print("  - availableTenants count: \(availableTenants.count)")
        print("  - availableTenants: \(availableTenants.map { $0.environmentDisplayName })")
        
        // Загружаем сохраненный тенант только если пользователь авторизован в нем
        if let savedTenantData = UserDefaults.standard.data(forKey: KEY_CURRENT_TENANT),
           let savedTenant = try? JSONDecoder().decode(TenantConfig.self, from: savedTenantData),
           availableTenants.contains(savedTenant) {
            
            if isLoggedIn(for: savedTenant) {
                print("  - Loading saved tenant (user is logged in): \(savedTenant.environmentDisplayName)")
                currentTenantSubject.send(savedTenant)
            } else {
                print("  - Saved tenant found but user not logged in, clearing saved tenant")
                UserDefaults.standard.removeObject(forKey: KEY_CURRENT_TENANT)
                checkForLoggedInTenants()
            }
        } else {
            checkForLoggedInTenants()
        }
    }
    
    private func checkForLoggedInTenants() {
        // Проверяем, есть ли тенанты, в которых пользователь уже авторизован
        let loggedInTenants = availableTenants.filter { isLoggedIn(for: $0) }
        if let firstLoggedInTenant = loggedInTenants.first {
            print("  - Setting first logged in tenant: \(firstLoggedInTenant.environmentDisplayName)")
            setCurrentTenant(firstLoggedInTenant)
        } else {
            print("  - No tenant set - user not logged in anywhere")
            // Не устанавливаем тенант, если пользователь нигде не авторизован
        }
    }
    
    public func setCurrentTenant(_ tenant: TenantConfig) {
        print("🔧 TenantManager: Setting current tenant to \(tenant.environmentDisplayName)")
        currentTenantSubject.send(tenant)
        
        // Сохраняем выбранный тенант
        if let encoded = try? JSONEncoder().encode(tenant) {
            UserDefaults.standard.set(encoded, forKey: KEY_CURRENT_TENANT)
        }
        
        // Обновляем токены в CoreStorage для нового тенанта
        updateTokensForCurrentTenant(tenant)
        
        print("🔧 TenantManager: Current tenant set successfully")
    }
    
    private func updateTokensForCurrentTenant(_ tenant: TenantConfig) {
        let tenantKey = tenant.environmentDisplayName
        let keychain = KeychainSwift()
        
        // Получаем токены для нового тенанта из keychain
        let accessToken = keychain.get("accessToken_\(tenantKey)")
        let refreshToken = keychain.get("refreshToken_\(tenantKey)")
        
        // Обновляем CoreStorage
        if let storage = Container.shared.resolve(CoreStorage.self) {
            var mutableStorage = storage
            mutableStorage.accessToken = accessToken
            mutableStorage.refreshToken = refreshToken
            
            // Загружаем данные пользователя для этого тенанта
            if let userData = UserDefaults.standard.data(forKey: "user_\(tenantKey)"),
               let user = try? JSONDecoder().decode(DataLayer.User.self, from: userData) {
                mutableStorage.user = user
            } else {
                mutableStorage.user = nil
            }
            
            print("🔧 TenantManager: Updated tokens for tenant \(tenantKey)")
            print("🔧 TenantManager: accessToken exists: \(accessToken != nil)")
            print("🔧 TenantManager: refreshToken exists: \(refreshToken != nil)")
        }
    }
    
    public func getCurrentTenantKey() -> String {
        return currentTenant?.environmentDisplayName ?? "default"
    }
    
    public func isLoggedIn(for tenant: TenantConfig) -> Bool {
        let tenantKey = tenant.environmentDisplayName
        let keychain = KeychainSwift()
        let hasToken = keychain.get("accessToken_\(tenantKey)") != nil
        print("  - isLoggedIn(\(tenantKey)): \(hasToken)")
        return hasToken
    }
    
    public func logout(from tenant: TenantConfig) {
        let tenantKey = tenant.environmentDisplayName
        let keychain = KeychainSwift()
        keychain.delete("accessToken_\(tenantKey)")
        keychain.delete("refreshToken_\(tenantKey)")
        
        // Очищаем данные пользователя для этого тенанта
        UserDefaults.standard.removeObject(forKey: "user_\(tenantKey)")
        UserDefaults.standard.removeObject(forKey: "userProfile_\(tenantKey)")
    }
    
    public func switchToNextAvailableTenant() {
        let loggedInTenants = availableTenants.filter { isLoggedIn(for: $0) }
        
        if let nextTenant = loggedInTenants.first {
            setCurrentTenant(nextTenant)
        } else if let firstTenant = availableTenants.first {
            setCurrentTenant(firstTenant)
        }
    }
    
    public func clearCurrentTenant() {
        currentTenantSubject.send(nil)
        UserDefaults.standard.removeObject(forKey: KEY_CURRENT_TENANT)
        print("  - Current tenant cleared")
    }
}

import KeychainSwift
