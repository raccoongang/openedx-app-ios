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
    func clearAllTenantData() // for debug purpose
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
        
        // We check if this is the first launch after installation
        checkAndClearDataIfFirstLaunch()
        
        // load the saved Tenant only if the user is authorized in it
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
        // check if there are tenants in which the user has already been authorized
        let loggedInTenants = availableTenants.filter { isLoggedIn(for: $0) }
        if let firstLoggedInTenant = loggedInTenants.first {
            print("  - Setting first logged in tenant: \(firstLoggedInTenant.environmentDisplayName)")
            setCurrentTenant(firstLoggedInTenant)
        } else {
            print("  - No tenant set - user not logged in anywhere")
            // Do not install the tenant if the user is not authorized anywhere
        }
    }
    
    public func setCurrentTenant(_ tenant: TenantConfig) {
        print("🔧 TenantManager: Setting current tenant to \(tenant.environmentDisplayName)")
        currentTenantSubject.send(tenant)
        
        // save the selected Tenant
        if let encoded = try? JSONEncoder().encode(tenant) {
            UserDefaults.standard.set(encoded, forKey: KEY_CURRENT_TENANT)
        }
        
        // update tokens in Corestorage for the new Tenant
        updateTokensForCurrentTenant(tenant)
        
        print("🔧 TenantManager: Current tenant set successfully")
    }
    
    private func updateTokensForCurrentTenant(_ tenant: TenantConfig) {
        let tenantKey = tenant.environmentDisplayName
        let keychain = KeychainSwift()
        
        // get tokens for the new Tenant from KeyChain
        let accessToken = keychain.get("accessToken_\(tenantKey)")
        let refreshToken = keychain.get("refreshToken_\(tenantKey)")
        
        // update CoreStorage
        if let storage = Container.shared.resolve(CoreStorage.self) {
            var mutableStorage = storage
            mutableStorage.accessToken = accessToken
            mutableStorage.refreshToken = refreshToken
            
            // load the user's data for this Tenant
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
        
        // Clean user data for this Tenant
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
    
    private func checkAndClearDataIfFirstLaunch() {
        let hasLaunchedKey = "HasLaunchedBefore"
        
        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            print("🔧 TenantManager: First launch detected, clearing all tenant data")
            clearAllTenantData()
            
            // We note that the application has already been launched
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            print("  - First launch cleanup completed")
        }
    }
    
    public func clearAllTenantData() {
        print("🔧 TenantManager: Clearing all tenant data")
        
        // Clean the current Tenant
        currentTenantSubject.send(nil)
        UserDefaults.standard.removeObject(forKey: KEY_CURRENT_TENANT)
        
        // Clean all KeyChain tokens for all tenants
        let keychain = KeychainSwift()
        for tenant in availableTenants {
            let tenantKey = tenant.environmentDisplayName
            keychain.delete("accessToken_\(tenantKey)")
            keychain.delete("refreshToken_\(tenantKey)")
            UserDefaults.standard.removeObject(forKey: "user_\(tenantKey)")
            UserDefaults.standard.removeObject(forKey: "userProfile_\(tenantKey)")
            print("  - Cleared data for tenant: \(tenantKey)")
        }
        
        print("  - All tenant data cleared")
    }
}
