import AppKit
import Foundation
import SwiftUI

/// Desteklenen Arayüz Dilleri
public enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case system = "system"
    case turkish = "tr"
    case english = "en"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "Sistem Dili (System Language)"
        case .turkish: return "Türkçe"
        case .english: return "English"
        }
    }

    public var flag: String {
        switch self {
        case .system: return "🌐"
        case .turkish: return "🇹🇷"
        case .english: return "🇬🇧"
        }
    }

    /// Çözümlenen etkin dil: Sistem dili seçiliyse sistem Türkçe mi bakar, Türkçe değilse İngilizce seçer.
    public var resolvedLanguage: AppLanguage {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased()
                ?? Locale.current.language.languageCode?.identifier.lowercased()
                ?? ""
            if preferred.hasPrefix("tr") {
                return .turkish
            } else {
                return .english
            }
        case .turkish:
            return .turkish
        case .english:
            return .english
        }
    }
}

/// Yerelleştirme Yardımcıları
public struct L10n {
    public static func tr(_ trText: String, en enText: String, language: AppLanguage) -> String {
        language.resolvedLanguage == .turkish ? trText : enText
    }
}
