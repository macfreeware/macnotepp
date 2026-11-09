import Foundation

public enum SearchMode: String, CaseIterable, Codable, Identifiable {
    case normal = "Normal"
    case extended = "Genişletilmiş (\\n, \\r, \\t, \\x..)"
    case regex = "Düzenli İfade (Regex)"

    public var id: String { rawValue }

    public func title(for lang: AppLanguage) -> String {
        let isTr = lang.resolvedLanguage == .turkish
        switch self {
        case .normal: return "Normal"
        case .extended: return isTr ? "Genişletilmiş (\\n, \\r, \\t, \\x..)" : "Extended (\\n, \\r, \\t, \\x..)"
        case .regex: return isTr ? "Düzenli İfade (Regex)" : "Regular Expression (Regex)"
        }
    }
}

public enum FindPanelTab: String, CaseIterable, Identifiable {
    case find = "Bul (Find)"
    case replace = "Değiştir (Replace)"
    case findInFiles = "Dosyalarda Bul"
    case mark = "İşaretle (Mark)"

    public var id: String { rawValue }

    public func title(for lang: AppLanguage) -> String {
        let isTr = lang.resolvedLanguage == .turkish
        switch self {
        case .find: return isTr ? "Bul (Find)" : "Find"
        case .replace: return isTr ? "Değiştir (Replace)" : "Replace"
        case .findInFiles: return isTr ? "Dosyalarda Bul" : "Find in Files"
        case .mark: return isTr ? "İşaretle (Mark)" : "Mark"
        }
    }
}

public struct FindResultHit: Identifiable, Hashable {
    public let id = UUID()
    public let tabId: UUID?
    public let fileURL: URL?
    public let fileName: String
    public let lineNumber: Int
    public let columnNumber: Int
    public let linePreview: String
    public let matchRangeInDocument: NSRange
}

public struct FindResultGroup: Identifiable, Hashable {
    public let id = UUID()
    public let title: String
    public let searchTerm: String
    public let timestamp: Date
    public let hits: [FindResultHit]
}

public enum MacroAction: Codable, Equatable {
    case lineOperation(LineOperationType)
    case caseConversion(CaseConversionType)
    case replaceAll(pattern: String, replacement: String, mode: SearchMode, matchCase: Bool, wholeWord: Bool)
    case appendText(String)
    case prependText(String)
    case trimTrailingAndEnsureNewline
}

public struct SavedMacro: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var actions: [MacroAction]

    public init(id: UUID = UUID(), name: String, actions: [MacroAction]) {
        self.id = id
        self.name = name
        self.actions = actions
    }
}
