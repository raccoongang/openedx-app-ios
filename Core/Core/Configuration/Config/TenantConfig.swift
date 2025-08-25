//
//  TenantConfig.swift
//  Core
//
//  Created by Kiro on 24/08/2025.
//

import Foundation

public struct TenantConfig: Codable, @unchecked Sendable, Identifiable, Equatable {
    public let id = UUID()
    public let baseURL: String
    public let ssoURL: String
    public let ssoFinishedURL: String
    public let environmentDisplayName: String
    public let feedbackEmail: String
    public let oAuthClientId: String
    public let ssoButtonTitle: [String: String]
    public let discovery: DiscoveryConfig
    public let uiComponents: UIComponentsConfig
    public let accentColor: String?
    
    public init(
        baseURL: String,
        ssoURL: String,
        ssoFinishedURL: String,
        environmentDisplayName: String,
        feedbackEmail: String,
        oAuthClientId: String,
        ssoButtonTitle: [String: String],
        discovery: DiscoveryConfig,
        uiComponents: UIComponentsConfig,
        accentColor: String? = nil
    ) {
        self.baseURL = baseURL
        self.ssoURL = ssoURL
        self.ssoFinishedURL = ssoFinishedURL
        self.environmentDisplayName = environmentDisplayName
        self.feedbackEmail = feedbackEmail
        self.oAuthClientId = oAuthClientId
        self.ssoButtonTitle = ssoButtonTitle
        self.discovery = discovery
        self.uiComponents = uiComponents
        self.accentColor = accentColor
    }
    
    public static func == (lhs: TenantConfig, rhs: TenantConfig) -> Bool {
        return lhs.baseURL == rhs.baseURL && 
               lhs.environmentDisplayName == rhs.environmentDisplayName
    }
}

public struct MultiTenantConfig: @unchecked Sendable {
    public let tenants: [TenantConfig]
    public let firebase: FirebaseConfig
    
    public init(tenants: [TenantConfig], firebase: FirebaseConfig) {
        self.tenants = tenants
        self.firebase = firebase
    }
    
    public var isMultiTenant: Bool {
        return tenants.count > 1
    }
    
    public var defaultTenant: TenantConfig? {
        return tenants.first
    }
}