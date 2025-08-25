//
//  TenantThemeManager.swift
//  Core
//
//  Created by Kiro on 24/08/2025.
//

import Foundation
import SwiftUI
import Theme
import Combine
import OEXFoundation

// Класс для уведомления об изменениях темы
public class ThemeNotifier: ObservableObject {
    @MainActor public static let shared = ThemeNotifier()
    
    @Published public var themeChanged = false
    
    private init() {}
    
    public func notifyThemeChanged() {
        themeChanged.toggle()
    }
}

public protocol TenantThemeManagerProtocol: Sendable {
    func applyTheme(for tenant: TenantConfig?)
    func resetToDefaultTheme()
}

public final class TenantThemeManager: TenantThemeManagerProtocol, @unchecked Sendable {
    private let tenantManager: TenantManagerProtocol
    private var cancellables = Set<AnyCancellable>()
    
    public init(tenantManager: TenantManagerProtocol) {
        self.tenantManager = tenantManager
        
        print("🎨 TenantThemeManager: Initializing and subscribing to tenant changes")
        
        // Подписываемся на изменения текущего тенанта
        tenantManager.currentTenantPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tenant in
                print("🎨 TenantThemeManager: Received tenant change: \(tenant?.environmentDisplayName ?? "nil")")
                self?.applyTheme(for: tenant)
            }
            .store(in: &cancellables)
        
        // Применяем тему для текущего тенанта при инициализации
        applyTheme(for: tenantManager.currentTenant)
    }
    
    public func applyTheme(for tenant: TenantConfig?) {
        DispatchQueue.main.async {
            guard let tenant = tenant,
                  let accentColorHex = tenant.accentColor else {
                print("🎨 TenantThemeManager: No tenant or accent color, resetting to default theme")
                self.resetToDefaultTheme()
                return
            }
            
            print("🎨 TenantThemeManager: Applying theme for tenant \(tenant.environmentDisplayName) with color \(accentColorHex)")
            
            let accentColor = Color(hex: accentColorHex)
            
            // Обновляем цвета темы
            Theme.Colors.update(
                accentColor: accentColor,
                accentXColor: accentColor
            )
            
            // Обновляем UIColors для UIKit компонентов
            Theme.UIColors.update(
                accentColor: accentColor.uiColor(),
                accentXColor: accentColor.uiColor(),
                
            )
            
            // Уведомляем об изменении темы
            ThemeNotifier.shared.notifyThemeChanged()
            
            // Принудительно обновляем tintColor окна
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.tintColor = accentColor.uiColor()
            }
            
            // Отправляем уведомление об изменении темы
            NotificationCenter.default.post(name: .themeChanged, object: nil)
            
            print("🎨 TenantThemeManager: Theme applied successfully")
        }
    }
    
    public func resetToDefaultTheme() {
        DispatchQueue.main.async {
            print("🎨 TenantThemeManager: Resetting to default theme")
            // Сбрасываем на дефолтные цвета
            Theme.Colors.update()
            Theme.UIColors.update()
            
            // Уведомляем об изменении темы
            ThemeNotifier.shared.notifyThemeChanged()
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func uiColor() -> UIColor {
        return UIColor(self)
    }
}

public extension Notification.Name {
    static let themeChanged = Notification.Name("themeChanged")
}
