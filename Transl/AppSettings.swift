import Foundation
import Combine
import Carbon.HIToolbox

struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let defaultOptionT = KeyCombo(
        keyCode: UInt32(kVK_ANSI_T),
        modifiers: UInt32(optionKey)
    )

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(KeyCodeNames.name(for: keyCode))
        return parts.joined()
    }
}

enum KeyCodeNames {
    static func name(for code: UInt32) -> String {
        switch Int(code) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "Esc"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return "Key \(code)"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let hotKeyCombo = "hotKeyCombo"
        static let targetLanguageCode = "targetLanguageCode"
        static let fallbackLanguageCode = "fallbackLanguageCode"
        static let appLanguage = "appLanguage"
        static let autoCopyResult = "autoCopyResult"
        static let launchAtLogin = "launchAtLogin"
    }

    @Published var hotKeyCombo: KeyCombo {
        didSet { save(hotKeyCombo, for: Keys.hotKeyCombo) }
    }
    @Published var targetLanguageCode: String {
        didSet { UserDefaults.standard.set(targetLanguageCode, forKey: Keys.targetLanguageCode) }
    }
    @Published var fallbackLanguageCode: String {
        didSet { UserDefaults.standard.set(fallbackLanguageCode, forKey: Keys.fallbackLanguageCode) }
    }
    @Published var appLanguage: String {
        didSet { UserDefaults.standard.set(appLanguage, forKey: Keys.appLanguage) }
    }
    @Published var autoCopyResult: Bool {
        didSet { UserDefaults.standard.set(autoCopyResult, forKey: Keys.autoCopyResult) }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LaunchAtLoginManager.setEnabled(launchAtLogin)
        }
    }

    private init() {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: Keys.hotKeyCombo),
           let combo = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            self.hotKeyCombo = combo
        } else {
            self.hotKeyCombo = .defaultOptionT
        }

        self.targetLanguageCode = defaults.string(forKey: Keys.targetLanguageCode) ?? Self.getSystemLanguageCode()
        self.fallbackLanguageCode = defaults.string(forKey: Keys.fallbackLanguageCode) ?? "en"
        self.appLanguage = defaults.string(forKey: Keys.appLanguage) ?? Self.getSystemLanguageCode()
        self.autoCopyResult = defaults.object(forKey: Keys.autoCopyResult) as? Bool ?? false
        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false

        LaunchAtLoginManager.setEnabled(self.launchAtLogin)
    }

    private func save<T: Encodable>(_ value: T, for key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func getSystemLanguageCode() -> String {
        let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        let availableCodes = TranslationService.availableLanguages.map { $0.code }

        if availableCodes.contains(systemLanguage) {
            return systemLanguage
        }

        let languageCode = String(systemLanguage.prefix(2))
        if availableCodes.contains(languageCode) {
            return languageCode
        }
        return "en"
    }
}
