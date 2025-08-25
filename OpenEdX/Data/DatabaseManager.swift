//
//  Persistence.swift
//  OpenEdX
//
//  Created by  Stepanok Ivan on 25.07.2023.
//

import Foundation
@preconcurrency import CoreData
import Core
import Discovery
import Dashboard
import Course
import Downloads
import Profile

final class DatabaseManager: CoreDataHandlerProtocol {
    
    private let baseDatabaseName: String
    private nonisolated(unsafe) var _tenantManager: TenantManagerProtocol?
    
    private var tenantManager: TenantManagerProtocol? {
        return _tenantManager
    }
        
    private let bundles: [Bundle] = [
        Bundle(for: CoreBundle.self),
        Bundle(for: DiscoveryBundle.self),
        Bundle(for: DashboardBundle.self),
        Bundle(for: CourseBundle.self),
        Bundle(for: ProfileBundle.self),
        Bundle(for: DownloadsBundle.self)
    ]
        
    private nonisolated(unsafe) var persistentContainers: [String: NSPersistentContainer] = [:]
    
    public func getPersistentContainer() -> NSPersistentContainer {
        let tenantKey = tenantManager?.getCurrentTenantKey() ?? "default"
        
        if persistentContainers[tenantKey] == nil {
            persistentContainers[tenantKey] = createContainer(for: tenantKey)
        }
        return persistentContainers[tenantKey]!
    }
    
    init(databaseName: String, tenantManager: TenantManagerProtocol? = nil) {
        self.baseDatabaseName = databaseName
        self._tenantManager = tenantManager
    }
    
    public func setTenantManager(_ tenantManager: TenantManagerProtocol) {
        self._tenantManager = tenantManager
    }
    
    private func createContainer(for tenantKey: String) -> NSPersistentContainer {
        let model = NSManagedObjectModel.mergedModel(from: bundles)!
        let databaseName = "\(baseDatabaseName)_\(tenantKey)"
        let container = NSPersistentContainer(name: databaseName, managedObjectModel: model)
        
        // Создаем уникальный путь для базы данных каждого тенанта
        let description = NSPersistentStoreDescription()
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let storeURL = documentsURL.appendingPathComponent("\(databaseName).sqlite")
            description.url = storeURL
        }
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Unresolved error \(error)")
                fatalError()
            }
        }
        
        return container
    }
    
    private func createContext() -> NSManagedObjectContext {
        let context = getPersistentContainer().newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        return context
    }
    
    public func clear() {
        let tenantKey = tenantManager?.getCurrentTenantKey() ?? "default"
        clearTenant(tenantKey: tenantKey)
    }
    
    public func clearTenant(tenantKey: String) {
        guard let container = persistentContainers[tenantKey] else { return }
        
        let storeContainer = container.persistentStoreCoordinator
        for store in storeContainer.persistentStores {
            do {
                try storeContainer.destroyPersistentStore(
                    at: store.url!,
                    ofType: store.type,
                    options: nil
                )
            } catch {
                print("⛔️⛔️⛔️⛔️⛔️", error)
            }
        }

        // Remove from cache
        persistentContainers.removeValue(forKey: tenantKey)
        
        // Re-create the persistent container if it's the current tenant
        if tenantKey == (tenantManager?.getCurrentTenantKey() ?? "default") {
            _ = getPersistentContainer()
        }
    }
    
    public func clearAllTenants() {
        for tenantKey in persistentContainers.keys {
            clearTenant(tenantKey: tenantKey)
        }
    }
}
