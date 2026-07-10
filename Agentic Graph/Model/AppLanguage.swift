import Foundation
import SwiftUI

/// User-selectable application language. Defaults to `.system` which uses the OS locale.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = ""
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portugueseBrazil = "pt-BR"
    case italian = "it"
    case greek = "el"
    case polish = "pl"
    case turkish = "tr"
    case czech = "cs"
    case arabic = "ar"
    case finnish = "fi"
    case japanese = "ja"
    case korean = "ko"

    var id: String { rawValue }

    /// Display name shown in the language picker (in the language itself).
    var nativeName: String {
        switch self {
        case .system: return String(localized: "System Default", comment: "Language picker — follow system locale")
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .portugueseBrazil: return "Português (Brasil)"
        case .italian: return "Italiano"
        case .greek: return "Ελληνικά"
        case .polish: return "Polski"
        case .turkish: return "Türkçe"
        case .czech: return "Čeština"
        case .arabic: return "العربية"
        case .finnish: return "Suomi"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        }
    }

    /// Resolved Locale. `.system` returns the user's current locale.
    var resolvedLocale: Locale {
        switch self {
        case .system: return Locale.autoupdatingCurrent
        default: return Locale(identifier: rawValue)
        }
    }

    /// UserDefaults key used by @AppStorage bindings throughout the app.
    static let storageKey = "appLanguage"
}
