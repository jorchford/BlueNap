//
//  Localization.swift
//  Bluesnooze
//
//  Created on 2026-10-26.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case en
    case ja

    var id: String {
        rawValue
    }

    static var current: AppLanguage {
        get {
            cachedCurrentLanguage
        }
        set {
            cachedCurrentLanguage = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: "appLanguage")
            if newValue == .system {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.set([newValue.rawValue], forKey: "AppleLanguages")
            }
            refreshCachedBundle()
        }
    }

    private nonisolated(unsafe) static var cachedCurrentLanguage: AppLanguage = {
        if let str = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = AppLanguage(rawValue: str) {
            return lang
        }
        return .system
    }()

    private nonisolated(unsafe) static var cachedBundle: Bundle = resolveLanguageBundle(for: cachedCurrentLanguage)

    static func refreshCachedBundle() {
        cachedBundle = resolveLanguageBundle(for: cachedCurrentLanguage)
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
        Locale(identifier: AppLanguage.effectiveLanguageCode)
    }

    static var effectiveLanguageCode: String {
        resolveEffectiveLanguageCode(for: cachedCurrentLanguage)
    }

    private static func resolveEffectiveLanguageCode(for language: AppLanguage) -> String {
        if language != .system {
            return language.rawValue
        }
        for lang in Locale.preferredLanguages {
            if lang.hasPrefix("zh-Hans") || lang.hasPrefix("zh-CN") || lang.hasPrefix("zh-SG") {
                return "zh-Hans"
            }
            if lang.hasPrefix("zh-Hant") || lang.hasPrefix("zh-TW") || lang.hasPrefix("zh-HK") || lang.hasPrefix("zh-MO") {
                return "zh-Hant"
            }
            if lang.hasPrefix("zh") {
                return "zh-Hans"
            }
            if lang.hasPrefix("ja") {
                return "ja"
            }
            if lang.hasPrefix("en") {
                return "en"
            }
        }
        return "zh-Hans"
    }

    static var currentLanguageBundle: Bundle {
        cachedBundle
    }

    private static func resolveLanguageBundle(for language: AppLanguage) -> Bundle {
        let code = resolveEffectiveLanguageCode(for: language)
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }

    var bundle: Bundle {
        AppLanguage.currentLanguageBundle
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
            let targetBundle = AppLanguage.currentLanguageBundle
            if targetBundle != Bundle.main {
                return targetBundle.customLocalizedString(forKey: key, value: value, table: tableName)
            }
        }
        return customLocalizedString(forKey: key, value: value, table: tableName)
    }

    static func localized(_ key: String, table tableName: String? = nil) -> String {
        AppLanguage.currentLanguageBundle.localizedString(forKey: key, value: nil, table: tableName)
    }
}
