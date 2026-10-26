//
//  Localization.swift
//  Bluesnooze
//
//  Created on 2026-10-26.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case en = "en"
    case ja = "ja"

    var id: String { rawValue }

    static var current: AppLanguage {
        get {
            if let str = UserDefaults.standard.string(forKey: "appLanguage"),
               let lang = AppLanguage(rawValue: str) {
                return lang
            }
            return .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "appLanguage")
            if newValue == .system {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.set([newValue.rawValue], forKey: "AppleLanguages")
            }
        }
    }

    var displayName: String {
        switch self {
        case .system:
            "跟随系统 / Follow System"
        case .zhHans:
            "简体中文"
        case .zhHant:
            "繁體中文"
        case .en:
            "English"
        case .ja:
            "日本語"
        }
    }

    var locale: Locale? {
        switch self {
        case .system:
            nil
        case .zhHans:
            Locale(identifier: "zh-Hans")
        case .zhHant:
            Locale(identifier: "zh-Hant")
        case .en:
            Locale(identifier: "en")
        case .ja:
            Locale(identifier: "ja")
        }
    }

    var bundle: Bundle {
        if self == .system {
            return .main
        }
        if let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }
}

@MainActor
extension Bundle {
    private static var isSwizzled = false

    static func setupLocalizationSwizzling() {
        guard !isSwizzled else { return }
        isSwizzled = true

        let originalSelector = #selector(Bundle.localizedString(forKey:value:table:))
        let swizzledSelector = #selector(Bundle.customLocalizedString(forKey:value:table:))

        guard let originalMethod = class_getInstanceMethod(Bundle.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(Bundle.self, swizzledSelector) else {
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func customLocalizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if self == Bundle.main {
            let lang = AppLanguage.current
            if lang != .system,
               let path = Bundle.main.path(forResource: lang.rawValue, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle.customLocalizedString(forKey: key, value: value, table: tableName)
            }
        }
        return customLocalizedString(forKey: key, value: value, table: tableName)
    }

    static func localized(_ key: String, table tableName: String? = nil) -> String {
        let lang = AppLanguage.current
        if lang != .system,
           let path = Bundle.main.path(forResource: lang.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: tableName)
        }
        return Bundle.main.localizedString(forKey: key, value: nil, table: tableName)
    }
}
