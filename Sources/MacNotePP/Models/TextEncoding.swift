import Foundation

public enum LineEndingType: String, CaseIterable, Codable, Identifiable {
    case lf = "Unix (LF)"
    case crlf = "Windows (CR LF)"
    case cr = "Macintosh (CR)"

    public var id: String { rawValue }

    public var sequence: String {
        switch self {
        case .lf: return "\n"
        case .crlf: return "\r\n"
        case .cr: return "\r"
        }
    }

    public var shortBadge: String {
        switch self {
        case .lf: return "LF"
        case .crlf: return "CRLF"
        case .cr: return "CR"
        }
    }

    public static func detect(in text: String) -> LineEndingType {
        // Bytes, not Characters: to Swift "\r\n" is a single Character. A mixed file takes its most common ending.
        var crlf = 0, lf = 0, cr = 0
        var previousWasCR = false
        for byte in text.utf8 {
            if byte == 10 {
                if previousWasCR { crlf += 1; cr -= 1 } else { lf += 1 }
            } else if byte == 13 {
                cr += 1
            }
            previousWasCR = byte == 13
        }
        if crlf > 0 && crlf >= lf && crlf >= cr { return .crlf }
        return cr > lf ? .cr : .lf
    }

    public static func normalizeToLF(_ text: String) -> String {
        guard text.utf8.contains(13) else { return text }
        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    public func apply(to text: String) -> String {
        let normalized = Self.normalizeToLF(text)
        switch self {
        case .lf:
            return normalized
        case .crlf:
            return normalized.replacingOccurrences(of: "\n", with: "\r\n")
        case .cr:
            return normalized.replacingOccurrences(of: "\n", with: "\r")
        }
    }
}

public enum TextEncodingOption: String, CaseIterable, Codable, Identifiable {
    case utf8 = "UTF-8"
    case utf8BOM = "UTF-8-BOM"
    case utf16LE = "UTF-16 LE"
    case utf16BE = "UTF-16 BE"
    case windows1254 = "Windows-1254 (Türkçe)"
    case iso8859_9 = "ISO-8859-9 (Türkçe)"
    case windows1252 = "Windows-1252 (ANSI)"
    case ascii = "ASCII"

    public var id: String { rawValue }

    public func title(for language: AppLanguage) -> String {
        language.resolvedLanguage == .turkish ? rawValue : rawValue.replacingOccurrences(of: "(Türkçe)", with: "(Turkish)")
    }

    public var stringEncoding: String.Encoding {
        switch self {
        case .utf8, .utf8BOM:
            return .utf8
        case .utf16LE:
            return .utf16LittleEndian
        case .utf16BE:
            return .utf16BigEndian
        case .windows1254:
            return .windowsCP1254
        case .iso8859_9:
            let cfEnc = CFStringEncoding(CFStringEncodings.isoLatin5.rawValue)
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEnc))
        case .windows1252:
            return .windowsCP1252
        case .ascii:
            return .ascii
        }
    }

    public static func decode(data: Data) -> (text: String, encoding: TextEncodingOption, lineEnding: LineEndingType) {
        if data.isEmpty {
            return ("", .utf8, .lf)
        }

        // Check BOM headers first
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            let payload = data.dropFirst(3)
            if let str = String(data: payload, encoding: .utf8) {
                let eol = LineEndingType.detect(in: str)
                return (LineEndingType.normalizeToLF(str), .utf8BOM, eol)
            }
        }
        if data.starts(with: [0xFF, 0xFE]) {
            let payload = data.dropFirst(2)
            if let str = String(data: payload, encoding: .utf16LittleEndian) {
                let eol = LineEndingType.detect(in: str)
                return (LineEndingType.normalizeToLF(str), .utf16LE, eol)
            }
        }
        if data.starts(with: [0xFE, 0xFF]) {
            let payload = data.dropFirst(2)
            if let str = String(data: payload, encoding: .utf16BigEndian) {
                let eol = LineEndingType.detect(in: str)
                return (LineEndingType.normalizeToLF(str), .utf16BE, eol)
            }
        }

        // Standard UTF-8
        if let str = String(data: data, encoding: .utf8) {
            let eol = LineEndingType.detect(in: str)
            return (LineEndingType.normalizeToLF(str), .utf8, eol)
        }

        // Turkish Windows-1254 fallback
        if let str = String(data: data, encoding: .windowsCP1254) {
            let eol = LineEndingType.detect(in: str)
            return (LineEndingType.normalizeToLF(str), .windows1254, eol)
        }

        // ANSI Windows-1252 fallback
        if let str = String(data: data, encoding: .windowsCP1252) {
            let eol = LineEndingType.detect(in: str)
            return (LineEndingType.normalizeToLF(str), .windows1252, eol)
        }

        // ISO-8859-9 assigns every byte, so bytes Windows-1254 leaves undefined survive a save unchanged
        if let str = String(data: data, encoding: TextEncodingOption.iso8859_9.stringEncoding) {
            let eol = LineEndingType.detect(in: str)
            return (LineEndingType.normalizeToLF(str), .iso8859_9, eol)
        }

        // Lossy UTF-8 fallback for binary files opened in text view
        let lossy = String(decoding: data, as: UTF8.self)
        let eol = LineEndingType.detect(in: lossy)
        return (LineEndingType.normalizeToLF(lossy), .utf8, eol)
    }

    /// Whether saving in this encoding keeps every character.
    public func canRepresent(_ text: String) -> Bool {
        switch self {
        case .utf8, .utf8BOM, .utf16LE, .utf16BE:
            return true
        default:
            return text.data(using: stringEncoding, allowLossyConversion: false) != nil
        }
    }

    public func encode(text: String, lineEnding: LineEndingType) -> Data {
        let formatted = lineEnding.apply(to: text)
        switch self {
        case .utf8BOM:
            var out = Data([0xEF, 0xBB, 0xBF])
            if let d = formatted.data(using: .utf8) {
                out.append(d)
            }
            return out
        case .utf16LE:
            var out = Data([0xFF, 0xFE])
            if let d = formatted.data(using: .utf16LittleEndian) {
                out.append(d)
            }
            return out
        case .utf16BE:
            var out = Data([0xFE, 0xFF])
            if let d = formatted.data(using: .utf16BigEndian) {
                out.append(d)
            }
            return out
        default:
            return formatted.data(using: stringEncoding, allowLossyConversion: true)
                ?? formatted.data(using: .utf8)
                ?? Data()
        }
    }
}
