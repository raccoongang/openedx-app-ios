//
//  Config.swift
//  Core
//
//  Created by Muhammad Umer on 11/11/2023.
//

import Foundation
import Combine

//sourcery: AutoMockable
public protocol ConfigProtocol: Sendable {
    var baseURL: URL { get }
    var baseSSOURL: URL { get }
    var ssoFinishedURL: URL { get }
    var ssoButtonTitle: [String: Any] { get }
    var oAuthClientId: String { get }
    var tokenType: TokenType { get }
    var feedbackEmail: String { get }
    var appStoreLink: String { get }
    var faq: URL? { get }
    var platformName: String { get }
    var agreement: AgreementConfig { get }
    var firebase: FirebaseConfig { get }
    var facebook: FacebookConfig { get }
    var microsoft: MicrosoftConfig { get }
    var google: GoogleConfig { get }
    var appleSignIn: AppleSignInConfig { get }
    var features: FeaturesConfig { get }
    var theme: ThemeConfig { get }
    var uiComponents: UIComponentsConfig { get }
    var discovery: DiscoveryConfig { get }
    var dashboard: DashboardConfig { get }
    var braze: BrazeConfig { get }
    var branch: BranchConfig { get }
    var program: DiscoveryConfig { get }
    var experimentalFeatures: ExperimentalFeaturesConfig { get }
    var URIScheme: String { get }
    var isMultiTenant: Bool { get }
    var multiTenant: MultiTenantConfig? { get }
    var currentTenant: TenantConfig? { get }
}

public enum TokenType: String, Sendable {
    case jwt = "JWT"
    case bearer = "BEARER"
}

private enum ConfigKeys: String, Sendable {
    case baseURL = "API_HOST_URL"
    case ssoBaseURL = "SSO_URL"
    case ssoFinishedURL = "SSO_FINISHED_URL"
    case ssoButtonTitle = "SSO_BUTTON_TITLE"
    case oAuthClientID = "OAUTH_CLIENT_ID"
    case tokenType = "TOKEN_TYPE"
    case feedbackEmailAddress = "FEEDBACK_EMAIL_ADDRESS"
    case environmentDisplayName = "ENVIRONMENT_DISPLAY_NAME"
    case platformName = "PLATFORM_NAME"
    case organizationCode = "ORGANIZATION_CODE"
    case appstoreID = "APP_STORE_ID"
    case faq = "FAQ_URL"
    case URIScheme = "URI_SCHEME"
}

public class Config: @unchecked Sendable {
    let configFileName = "config"
    
    internal var properties: [String: Any] = [:]
    private var tenantManager: TenantManagerProtocol?
    private var multiTenantConfig: MultiTenantConfig?
    private var cancellables = Set<AnyCancellable>()
    private var _currentTenant: TenantConfig?
    
    internal init(properties: [String: Any]) {
        self.properties = properties
    }
    
    public convenience init() {
        self.init(properties: [:])
        loadAndParseConfig()
    }
    
    public convenience init(tenantManager: TenantManagerProtocol) {
        self.init(properties: [:])
        self.tenantManager = tenantManager
        loadAndParseConfig()
    }
    
    public func setTenantManager(_ tenantManager: TenantManagerProtocol) {
        print("🔧 Config setTenantManager called")
        self.tenantManager = tenantManager
        // Устанавливаем текущий тенант сразу
        self._currentTenant = tenantManager.currentTenant
        print("🔧 Config: Initial current tenant set to: \(self._currentTenant?.environmentDisplayName ?? "nil")")
        subscribeToTenantChanges()
    }
    
    private func subscribeToTenantChanges() {
        guard let tenantManager = tenantManager else { 
            print("🔧 Config subscribeToTenantChanges: tenantManager is nil")
            return 
        }
        
        print("🔧 Config: Subscribing to tenant changes")
        tenantManager.currentTenantPublisher
            .sink { [weak self] tenant in
                print("🔧 Config: Current tenant changed to: \(tenant?.environmentDisplayName ?? "nil")")
                self?._currentTenant = tenant
            }
            .store(in: &cancellables)
    }
    
    private func loadAndParseConfig() {
        guard let path = Bundle.main.path(forResource: configFileName, ofType: "plist"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let dict = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil) as? [String: Any]
        else { return }
        
        properties = dict
        
        // Проверяем, есть ли конфигурация мультитенантности
        if let tenantsArray = dict["TENANTS"] as? [[String: Any]], !tenantsArray.isEmpty {
            parseMultiTenantConfig(from: dict, tenantsArray: tenantsArray)
        }
    }
    
    private func parseMultiTenantConfig(from dict: [String: Any], tenantsArray: [[String: Any]]) {
        var tenants: [TenantConfig] = []
        
        print("🔧 Config parseMultiTenantConfig:")
        print("  - Found \(tenantsArray.count) tenants in config")
        
        for tenantDict in tenantsArray {
            if let tenant = parseTenantConfig(from: tenantDict) {
                print("  - Parsed tenant: \(tenant.environmentDisplayName)")
                tenants.append(tenant)
            }
        }
        
        let firebaseConfig = FirebaseConfig(dictionary: dict as [String: AnyObject])
        multiTenantConfig = MultiTenantConfig(tenants: tenants, firebase: firebaseConfig)
        
        print("  - MultiTenantConfig created with \(tenants.count) tenants")
        print("  - isMultiTenant: \(multiTenantConfig?.isMultiTenant ?? false)")
    }
    
    private func parseTenantConfig(from dict: [String: Any]) -> TenantConfig? {
        guard let baseURL = dict["API_HOST_URL"] as? String,
              let ssoURL = dict["SSO_URL"] as? String,
              let ssoFinishedURL = dict["SSO_FINISHED_URL"] as? String,
              let environmentDisplayName = dict["ENVIRONMENT_DISPLAY_NAME"] as? String,
              let feedbackEmail = dict["FEEDBACK_EMAIL_ADDRESS"] as? String,
              let oAuthClientId = dict["OAUTH_CLIENT_ID"] as? String else {
            return nil
        }
        
        let ssoButtonTitle = dict["SSO_BUTTON_TITLE"] as? [String: String] ?? [:]
        let discoveryDict = dict["DISCOVERY"] as? [String: Any] ?? [:]
        let uiComponentsDict = dict["UI_COMPONENTS"] as? [String: Any] ?? [:]
        let accentColor = dict["ACCENT_COLOR"] as? String
        
        return TenantConfig(
            baseURL: baseURL,
            ssoURL: ssoURL,
            ssoFinishedURL: ssoFinishedURL,
            environmentDisplayName: environmentDisplayName,
            feedbackEmail: feedbackEmail,
            oAuthClientId: oAuthClientId,
            ssoButtonTitle: ssoButtonTitle,
            discovery: DiscoveryConfig(dictionary: discoveryDict as [String: AnyObject]),
            uiComponents: UIComponentsConfig(dictionary: uiComponentsDict),
            accentColor: accentColor
        )
    }
    
    public var isMultiTenant: Bool {
        return multiTenantConfig?.isMultiTenant ?? false
    }
    
    public var multiTenant: MultiTenantConfig? {
        return multiTenantConfig
    }
    
    public var currentTenant: TenantConfig? {
        let tenant = _currentTenant ?? tenantManager?.currentTenant ?? multiTenantConfig?.defaultTenant
        print("🔧 Config currentTenant: _currentTenant=\(_currentTenant?.environmentDisplayName ?? "nil"), tenantManager.currentTenant=\(tenantManager?.currentTenant?.environmentDisplayName ?? "nil"), result=\(tenant?.environmentDisplayName ?? "nil")")
        return tenant
    }
    
    internal subscript(key: String) -> Any? {
        return properties[key]
    }
    
    func dict(for key: String) -> [String: Any]? {
        return properties[key] as? [String: Any]
    }
    
    func value<T>(for key: String) -> T? {
        return properties[key] as? T
    }
    
    func value(for key: String) -> Any? {
        return properties[key]
    }
    
    func value(for key: String, dict: [String: Any]) -> String? {
        return dict[key] as? String ?? nil
    }
    
    func string(for key: String) -> String? {
        return value(for: key) as? String ?? nil
    }
    
    func string(for key: String, dict: [String: Any]) -> String? {
        return value(for: key, dict: dict)
    }
    
    func bool(for key: String) -> Bool {
        return value(for: key) as? Bool ?? false
    }
}

extension Config: ConfigProtocol {
    public var baseURL: URL {
        // Для мультитенантности используем текущий тенант
        if let tenant = currentTenant {
            guard let url = URL(string: tenant.baseURL) else {
                fatalError("Unable to find base url in tenant config.")
            }
            print("🔧 Config baseURL: Using tenant \(tenant.environmentDisplayName) - \(tenant.baseURL)")
            return url
        }
        
        // Fallback на старую логику
        guard let urlString = string(for: ConfigKeys.baseURL.rawValue),
              let url = URL(string: urlString) else {
            fatalError("Unable to find base url in config.")
        }
        print("🔧 Config baseURL: Using fallback - \(urlString)")
        return url
    }
    
    public var baseSSOURL: URL {
        // Для мультитенантности используем текущий тенант
        if let tenant = currentTenant {
            guard let url = URL(string: tenant.ssoURL) else {
                fatalError("Unable to find SSO base url in tenant config.")
            }
            return url
        }
        
        // Fallback на старую логику
        guard let urlString = string(for: ConfigKeys.ssoBaseURL.rawValue),
              let url = URL(string: urlString) else {
            fatalError("Unable to find SSO base url in config.")
        }
        return url
    }
    
    public var ssoFinishedURL: URL {
        // Для мультитенантности используем текущий тенант
        if let tenant = currentTenant {
            guard let url = URL(string: tenant.ssoFinishedURL) else {
                fatalError("Unable to find SSO finished url in tenant config.")
            }
            return url
        }
        
        // Fallback на старую логику
        guard let urlString = string(for: ConfigKeys.ssoFinishedURL.rawValue),
              let url = URL(string: urlString) else {
            fatalError("Unable to find SSO successful login url in config.")
        }
        return url
    }
    
    public var ssoButtonTitle: [String: Any] {
        // Для мультитенантности используем текущий тенант
        if let tenant = currentTenant {
            return tenant.ssoButtonTitle.isEmpty ? 
                ["en": CoreLocalization.SignIn.logInWithSsoBtn] : 
                tenant.ssoButtonTitle
        }
        
        // Fallback на старую логику
        guard let ssoButtonTitle = dict(for: ConfigKeys.ssoButtonTitle.rawValue) else {
            return ["en": CoreLocalization.SignIn.logInWithSsoBtn]
        }
        return ssoButtonTitle
    }
    
    public var oAuthClientId: String {
        // Для мультитенантности используем текущий тенант
        if let tenant = currentTenant {
            print("🔧 Config oAuthClientId: Using tenant \(tenant.environmentDisplayName) - \(tenant.oAuthClientId)")
            return tenant.oAuthClientId
        }
        
        // Fallback на старую логику
        guard let clientID = string(for: ConfigKeys.oAuthClientID.rawValue) else {
            fatalError("Unable to find OAuth ClientID in config.")
        }
        print("🔧 Config oAuthClientId: Using fallback - \(clientID)")
        return clientID
    }
    
    public var tokenType: TokenType {
        guard let tokenTypeValue = string(for: ConfigKeys.tokenType.rawValue),
              let tokenType = TokenType(rawValue: tokenTypeValue)
        else { return .jwt }
        return tokenType
    }
    
    public var feedbackEmail: String {
        // Для мультитенантности используем текущий тенант
        if let tenant = currentTenant {
            return tenant.feedbackEmail
        }
        
        // Fallback на старую логику
        return string(for: ConfigKeys.feedbackEmailAddress.rawValue) ?? ""
    }

    public var platformName: String {
        return string(for: ConfigKeys.platformName.rawValue) ?? ""
    }

    private var appStoreId: String {
        return string(for: ConfigKeys.appstoreID.rawValue) ?? "0000000000"
    }
    
    public var appStoreLink: String {
        "itms-apps://itunes.apple.com/app/id\(appStoreId)?mt=8"
    }

    public var faq: URL? {
        guard let urlString = string(for: ConfigKeys.faq.rawValue),
              let url = URL(string: urlString) else {
            return nil
        }
        return url
    }
    
    public var URIScheme: String {
        return string(for: ConfigKeys.URIScheme.rawValue) ?? ""
    }
}

// Mark - For testing and SwiftUI preview
#if DEBUG
public class ConfigMock: Config, @unchecked Sendable {
    private let config: [String: Any] = [
        "API_HOST_URL": "https://www.example.com",
        "SSO_URL": "https://www.example.com",
        "OAUTH_CLIENT_ID": "oauth_client_id",
        "FEEDBACK_EMAIL_ADDRESS": "example@mail.com",
        "PLATFORM_NAME": "OpenEdx",
        "TOKEN_TYPE": "JWT",
        "WHATS_NEW_ENABLED": false,
        "AGREEMENT_URLS": [
            "PRIVACY_POLICY_URL": "https://www.example.com/privacy",
            "TOS_URL": "https://www.example.com/tos",
            "DATA_SELL_CONSENT_URL": "https://www.example.com/sell",
            "COOKIE_POLICY_URL": "https://www.example.com/cookie",
            "SUPPORTED_LANGUAGES": ["es"]
        ],
        "GOOGLE": [
            "ENABLED": true,
            "CLIENT_ID": "clientId"
        ],
        "FACEBOOK": [
            "ENABLED": true,
            "FACEBOOK_APP_ID": "facebookAppId",
            "CLIENT_TOKEN": "client_token"
        ],
        "MICROSOFT": [
            "ENABLED": true,
            "APP_ID": "appId"
        ],
        "APPLE_SIGNIN": [
            "ENABLED": true
        ],
        "EXPERIMENTAL_FEATURES": [
            "APP_LEVEL_DOWNLOADS": [
                "ENABLED": false
            ]
        ]
    ]
    
    public init() {
        super.init(properties: config)
    }
}
#endif
