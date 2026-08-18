import Foundation
import Combine

final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "appLanguage")
            loadTranslations()
        }
    }

    private var translations: [String: String] = [:]

    private init() {
        let systemLanguage = Self.getSystemLanguage()
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? systemLanguage
        self.currentLanguage = savedLanguage
        loadTranslations()
    }

    private static func getSystemLanguage() -> String {
        let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        let supportedLanguages = ["en", "ru", "de", "pl", "es", "it", "fr", "ja", "zh-CN", "pt", "nl"]

        if supportedLanguages.contains(systemLanguage) {
            return systemLanguage
        }

        let languageCode = String(systemLanguage.prefix(2))
        if supportedLanguages.contains(languageCode) {
            return languageCode
        }

        if languageCode == "zh" {
            return "zh-CN"
        }

        return "en"
    }

    private func loadTranslations() {
        guard let url = Bundle.main.url(forResource: "localization", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: [String: String]],
              let languageTranslations = json[currentLanguage] else {
            translations = [:]
            return
        }

        translations = languageTranslations
    }

    func localizedString(_ key: String) -> String {
        return translations[key] ?? key
    }

    static func localized(_ key: String) -> String {
        return shared.localizedString(key)
    }

    static func localized(_ key: String, _ args: CVarArg...) -> String {
        let format = shared.localizedString(key)
        return String(format: format, arguments: args)
    }
}

@propertyWrapper
struct LocalizedString {
    let key: String

    var wrappedValue: String {
        LocalizationManager.localized(key)
    }
}