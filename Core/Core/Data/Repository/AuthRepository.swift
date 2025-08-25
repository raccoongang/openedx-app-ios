//
//  AuthRepository.swift
//  Core
//
//  Created by  Stepanok Ivan on 14.10.2022.
//

import Foundation
import OEXFoundation
import Swinject
import KeychainSwift

public protocol AuthRepositoryProtocol: Sendable {
    func login(username: String, password: String) async throws -> User
    func login(externalToken: String, backend: String) async throws -> User
    func login(ssoToken: String) async throws -> User
    func getCookies(force: Bool) async throws
    func getRegistrationFields() async throws -> [PickerFields]
    func registerUser(fields: [String: String], isSocial: Bool) async throws -> User
    func validateRegistrationFields(fields: [String: String]) async throws -> [String: String]
    func resetPassword(email: String) async throws -> ResetPassword
}

public actor AuthRepository: AuthRepositoryProtocol {
    
    private var appStorage: CoreStorage
    
    public init(appStorage: CoreStorage) {
        self.appStorage = appStorage
    }
    
    private var api: API {
        Container.shared.resolve(API.self)!
    }
    
    private var config: ConfigProtocol {
        Container.shared.resolve(ConfigProtocol.self)!
    }
    
    public func login(username: String, password: String) async throws -> User {
        appStorage.cookiesDate = nil
        print("🔧 AuthRepository config.baseURL: \(config.baseURL.absoluteString)")
        let endPoint = AuthEndpoint.getAccessToken(
            username: username,
            password: password,
            clientId: config.oAuthClientId,
            tokenType: config.tokenType.rawValue
        )
        let authResponse = try await api.requestData(endPoint).mapResponse(DataLayer.AuthResponse.self)
        guard let accessToken = authResponse.accessToken,
              let refreshToken = authResponse.refreshToken else {
            if let error = authResponse.error, error == DataLayer.AuthResponse.invalidGrant {
                throw APIError.invalidGrant
            } else {
                throw APIError.unknown
            }
        }
        
        appStorage.accessToken = accessToken
        appStorage.refreshToken = refreshToken
        
        // Сохраняем токены в keychain для текущего тенанта
        saveTokensForCurrentTenant(accessToken: accessToken, refreshToken: refreshToken)
        
        let user = try await api.requestData(AuthEndpoint.getUserInfo).mapResponse(DataLayer.User.self)
        appStorage.user = user
        
        // Сохраняем данные пользователя для текущего тенанта
        saveUserForCurrentTenant(user: user)
        
        return user.domain
    }

    public func login(externalToken: String, backend: String) async throws -> User {
        let endPoint = AuthEndpoint.exchangeAccessToken(
            externalToken: externalToken,
            backend: backend,
            clientId: config.oAuthClientId,
            tokenType: config.tokenType.rawValue
        )
        let authResponse = try await api.requestData(endPoint).mapResponse(DataLayer.AuthResponse.self)
        guard let accessToken = authResponse.accessToken,
              let refreshToken = authResponse.refreshToken else {
            if let error = authResponse.error, error == DataLayer.AuthResponse.invalidGrant {
                throw APIError.invalidGrant
            } else {
                throw APIError.unknown
            }
        }

        appStorage.accessToken = accessToken
        appStorage.refreshToken = refreshToken

        // Сохраняем токены в keychain для текущего тенанта
        saveTokensForCurrentTenant(accessToken: accessToken, refreshToken: refreshToken)

        let user = try await api.requestData(AuthEndpoint.getUserInfo).mapResponse(DataLayer.User.self)
        appStorage.user = user
        
        // Сохраняем данные пользователя для текущего тенанта
        saveUserForCurrentTenant(user: user)
        
        return user.domain
    }

    public func login(ssoToken: String) async throws -> User {
        if appStorage.accessToken == nil {
            appStorage.accessToken = ssoToken
        }
        
        let user = try await api.requestData(AuthEndpoint.getUserInfo).mapResponse(DataLayer.User.self)
        appStorage.user = user
        return user.domain
    }
    
    public func resetPassword(email: String) async throws -> ResetPassword {
       let response = try await api.requestData(AuthEndpoint.resetPassword(email: email))
            .mapResponse(DataLayer.ResetPassword.self)
        return response.domain
    }
    
    public func getCookies(force: Bool) async throws {
        if let cookiesCreatedDate = appStorage.cookiesDate, !force {
            let cookieLifetimeLimit = cookiesCreatedDate.addingTimeInterval(60 * 60)
            if Date() > cookieLifetimeLimit {
                _ = try await api.requestData(AuthEndpoint.getAuthCookies)
                appStorage.cookiesDate = Date()
            }
        } else {
            _ = try await api.requestData(AuthEndpoint.getAuthCookies)
            appStorage.cookiesDate = Date()
        }
    }
    
    public func getRegistrationFields() async throws -> [PickerFields] {
        let fields = try await api.requestData(AuthEndpoint.getRegisterFields)
            .mapResponse(DataLayer.RegistrationFields.self)
        return fields.fields.map { $0.domain }
    }
    
    @discardableResult
    public func registerUser(fields: [String: String], isSocial: Bool) async throws -> User {
        try await api.requestData(AuthEndpoint.registerUser(fields))
        if isSocial {
            return try await login(externalToken: fields["access_token"] ?? "", backend: fields["provider"] ?? "")
        }
        return try await login(username: fields["username"] ?? "", password: fields["password"] ?? "")
    }

    public func validateRegistrationFields(fields: [String: String]) async throws -> [String: String] {
        let result = try await api.requestData(AuthEndpoint.validateRegistrationFields(fields))
        if let fieldsResult = try JSONSerialization.jsonObject(with: result, options: []) as? [String: Any] {
            if let errorsFields = fieldsResult["validation_decisions"] as? [String: String] {
                return errorsFields
            }
        }
        throw APIError.parsingError
    }
    
    private func saveTokensForCurrentTenant(accessToken: String, refreshToken: String) {
        guard let tenantManager = Container.shared.resolve(TenantManagerProtocol.self),
              let currentTenant = tenantManager.currentTenant else {
            return
        }
        
        let tenantKey = currentTenant.environmentDisplayName
        let keychain = KeychainSwift()
        keychain.set(accessToken, forKey: "accessToken_\(tenantKey)")
        keychain.set(refreshToken, forKey: "refreshToken_\(tenantKey)")
        
        print("🔧 AuthRepository: Saved tokens for tenant \(tenantKey)")
    }
    
    private func saveUserForCurrentTenant(user: DataLayer.User) {
        guard let tenantManager = Container.shared.resolve(TenantManagerProtocol.self),
              let currentTenant = tenantManager.currentTenant else {
            return
        }
        
        let tenantKey = currentTenant.environmentDisplayName
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "user_\(tenantKey)")
            print("🔧 AuthRepository: Saved user data for tenant \(tenantKey)")
        }
    }
    
}

// Mark - For testing and SwiftUI preview
#if DEBUG
final class AuthRepositoryMock: AuthRepositoryProtocol {
    func login(username: String, password: String) async throws -> User {
        User(id: 1, username: "User", email: "email@gmail.com", name: "User Name", userAvatar: "")
    }

    public func login(externalToken: String, backend: String) async throws -> User {
        User(id: 1, username: "User", email: "email@gmail.com", name: "User Name", userAvatar: "")
    }

    func login(ssoToken: String) async throws -> User {
        return User(id: 1, username: "User", email: "email@gmail.com", name: "User Name", userAvatar: "")
    }
    
    func resetPassword(email: String) async throws -> ResetPassword {
        ResetPassword(success: true, responseText: "Success reset")
    }
    
    func getCookies(force: Bool) async throws {}
    
    func getRegistrationFields() async throws -> [PickerFields] {
        let fields = [
            PickerFields(type: .text,
                               label: "User Name",
                               required: true,
                               name: "UserName",
                               instructions: "Enter username or nickname",
                               options: []),
            PickerFields(type: .text,
                               label: "Email",
                               required: true,
                               name: "email",
                               instructions: "Enter registration email",
                               options: []),
            PickerFields(type: .select,
                               label: "Choose your gender",
                               required: false,
                               name: "email",
                               instructions: "Who are you, stranger?",
                               options: [
                                PickerFields.Option(value: "Male",
                                                          name: "Male",
                                                          optionDefault: true)]),
            PickerFields(type: .text,
                               label: "Email",
                               required: true,
                               name: "email",
                               instructions: "Enter registration email",
                               options: [])
        ]
        return fields
    }
    
    func registerUser(fields: [String: String], isSocial: Bool) async throws -> User {
        User(id: 1, username: "User", email: "email@gmail.com", name: "User Name", userAvatar: "")
    }
    
    func validateRegistrationFields(fields: [String: String]) async throws -> [String: String] {
        [:]
    }
}
#endif
