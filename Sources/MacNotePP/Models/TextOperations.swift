import CryptoKit
import Foundation

public enum LineOperationType: String, CaseIterable, Codable {
    case sortLexAscending = "Satırları Alfabetik Sırala (A → Z)"
    case sortLexDescending = "Satırları Alfabetik Ters Sırala (Z → A)"
    case sortCaseInsensitiveAsc = "Satırları Büyük/Küçük Harf Duyarsız Sırala (A → Z)"
    case sortCaseInsensitiveDesc = "Satırları Büyük/Küçük Harf Duyarsız Ters Sırala (Z → A)"
    case sortNumericAscending = "Satırları Sayısal Sırala (0 → 9)"
    case sortNumericDescending = "Satırları Sayısal Ters Sırala (9 → 0)"
    case sortByLengthAsc = "Satırları Uzunluğa Göre Sırala (Kısa → Uzun)"
    case sortByLengthDesc = "Satırları Uzunluğa Göre Sırala (Uzun → Kısa)"
    case reverseLineOrder = "Satır Sırasını Ters Çevir"
    case randomizeLineOrder = "Satırları Rastgele Karıştır"
    case removeDuplicateLines = "Tekrarlayan Satırları Kaldır (Tüm Belge)"
    case removeConsecutiveDuplicateLines = "Ardışık Tekrarlayan Satırları Kaldır"
    case removeEmptyLines = "Boş Satırları Kaldır"
    case removeBlankLines = "Boş ve Boşluk Karakterli Satırları Kaldır"
    case trimTrailingSpace = "Satır Sonu Boşluklarını Temizle (Trim Trailing)"
    case trimLeadingSpace = "Satır Başı Boşluklarını Temizle (Trim Leading)"
    case trimBoth = "Satır Başı ve Sonu Boşluklarını Temizle"
    case tabToSpace = "TAB → Boşluk (4 Space) Dönüştür"
    case spaceToTab = "Boşluk (4 Space) → TAB Dönüştür"
    case eolToSpace = "Satır Sonlarını Boşluğa Dönüştür (Tek Satır Yap)"
    case insertBlankLineAbove = "Satırların Arasına Boş Satır Ekle"

    public func title(for lang: AppLanguage) -> String {
        let isTr = lang.resolvedLanguage == .turkish
        switch self {
        case .sortLexAscending:
            return isTr ? "Sırala (A → Z)" : "Sort (A → Z)"
        case .sortLexDescending:
            return isTr ? "Sırala (Z → A)" : "Sort (Z → A)"
        case .sortCaseInsensitiveAsc:
            return isTr ? "Harf Duyarsız Sırala (A → Z)" : "Sort Case-Insensitive (A → Z)"
        case .sortCaseInsensitiveDesc:
            return isTr ? "Harf Duyarsız Sırala (Z → A)" : "Sort Case-Insensitive (Z → A)"
        case .sortNumericAscending:
            return isTr ? "Sayısal Sırala (0 → 9)" : "Sort Numerically (0 → 9)"
        case .sortNumericDescending:
            return isTr ? "Sayısal Sırala (9 → 0)" : "Sort Numerically (9 → 0)"
        case .sortByLengthAsc:
            return isTr ? "Uzunluğa Göre Sırala (Kısa → Uzun)" : "Sort by Length (Short → Long)"
        case .sortByLengthDesc:
            return isTr ? "Uzunluğa Göre Sırala (Uzun → Kısa)" : "Sort by Length (Long → Short)"
        case .reverseLineOrder:
            return isTr ? "Sırayı Ters Çevir" : "Reverse Order"
        case .randomizeLineOrder:
            return isTr ? "Karıştır" : "Shuffle"
        case .removeDuplicateLines:
            return isTr ? "Tekrarları Kaldır" : "Remove Duplicates"
        case .removeConsecutiveDuplicateLines:
            return isTr ? "Ardışık Tekrarları Kaldır" : "Remove Consecutive Duplicates"
        case .removeEmptyLines:
            return isTr ? "Boş Satırları Kaldır" : "Remove Empty Lines"
        case .removeBlankLines:
            return isTr ? "Boşluklu Satırları da Kaldır" : "Remove Blank Lines"
        case .trimTrailingSpace:
            return isTr ? "Satır Sonu Boşluklarını Temizle (Trim Trailing)" : "Trim Trailing Whitespace"
        case .trimLeadingSpace:
            return isTr ? "Satır Başı Boşluklarını Temizle (Trim Leading)" : "Trim Leading Whitespace"
        case .trimBoth:
            return isTr ? "Satır Başı ve Sonu Boşluklarını Temizle" : "Trim Leading & Trailing Whitespace"
        case .tabToSpace:
            return isTr ? "TAB → Boşluk (4 Space) Dönüştür" : "Convert TAB to Spaces (4 Spaces)"
        case .spaceToTab:
            return isTr ? "Boşluk (4 Space) → TAB Dönüştür" : "Convert Spaces (4 Spaces) to TAB"
        case .eolToSpace:
            return isTr ? "Satır Sonlarını Boşluğa Dönüştür (Tek Satır Yap)" : "Join Lines into Single Line (EOL to Space)"
        case .insertBlankLineAbove:
            return isTr ? "Satırların Arasına Boş Satır Ekle" : "Insert Blank Line Above Lines"
        }
    }
}

public enum CaseConversionType: String, CaseIterable, Codable {
    case uppercase = "BÜYÜK HARF"
    case lowercase = "küçük harf"
    case properCase = "Baş Harfleri Büyük (Proper Case)"
    case sentenceCase = "Cümle düzeni"
    case invertCase = "tERS hARF"
    case randomCase = "rAsTgElE hArF"

    public func title(for lang: AppLanguage) -> String {
        let isTr = lang.resolvedLanguage == .turkish
        switch self {
        case .uppercase:
            return isTr ? "BÜYÜK HARF" : "UPPERCASE"
        case .lowercase:
            return isTr ? "küçük harf" : "lowercase"
        case .properCase:
            return isTr ? "Baş Harfleri Büyük" : "Capitalize Each Word"
        case .sentenceCase:
            return isTr ? "Cümle düzeni" : "Sentence case"
        case .invertCase:
            return isTr ? "tERS hARF" : "iNVERT cASE"
        case .randomCase:
            return isTr ? "rAsTgElE hArF" : "rAnDoM cAsE"
        }
    }
}

public enum NumberRadixFormat: String, CaseIterable, Identifiable {
    case decimal = "Decimal (10'luk)"
    case hexUpper = "Hexadecimal (16'lık BÜYÜK)"
    case hexLower = "Hexadecimal (16'lık küçük)"
    case octal = "Octal (8'lik)"
    case binary = "Binary (2'lik)"

    public var id: String { rawValue }

    public func title(for language: AppLanguage) -> String {
        guard language.resolvedLanguage != .turkish else { return rawValue }
        switch self {
        case .decimal: return "Decimal"
        case .hexUpper: return "Hexadecimal (uppercase)"
        case .hexLower: return "Hexadecimal (lowercase)"
        case .octal: return "Octal"
        case .binary: return "Binary"
        }
    }
}

public enum TextOperations {
    public static func performLineOperation(_ op: LineOperationType, on text: String) -> String {
        let normalized = LineEndingType.normalizeToLF(text)
        var lines = normalized.components(separatedBy: "\n")

        switch op {
        case .sortLexAscending:
            lines.sort()
        case .sortLexDescending:
            lines.sort(by: >)
        case .sortCaseInsensitiveAsc:
            lines.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        case .sortCaseInsensitiveDesc:
            lines.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedDescending }
        case .sortNumericAscending:
            lines.sort { extractLeadingNumber($0) < extractLeadingNumber($1) }
        case .sortNumericDescending:
            lines.sort { extractLeadingNumber($0) > extractLeadingNumber($1) }
        case .sortByLengthAsc:
            lines.sort { $0.count < $1.count }
        case .sortByLengthDesc:
            lines.sort { $0.count > $1.count }
        case .reverseLineOrder:
            lines.reverse()
        case .randomizeLineOrder:
            lines.shuffle()
        case .removeDuplicateLines:
            var seen = Set<String>()
            lines = lines.filter { line in
                if seen.contains(line) { return false }
                seen.insert(line)
                return true
            }
        case .removeConsecutiveDuplicateLines:
            var result: [String] = []
            for line in lines {
                if result.last != line {
                    result.append(line)
                }
            }
            lines = result
        case .removeEmptyLines:
            lines = lines.filter { !$0.isEmpty }
        case .removeBlankLines:
            lines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        case .trimTrailingSpace:
            lines = lines.map { line in
                var s = line
                while let last = s.last, last == " " || last == "\t" {
                    s.removeLast()
                }
                return s
            }
        case .trimLeadingSpace:
            lines = lines.map { line in
                var s = line
                while let first = s.first, first == " " || first == "\t" {
                    s.removeFirst()
                }
                return s
            }
        case .trimBoth:
            lines = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        case .tabToSpace:
            lines = lines.map { $0.replacingOccurrences(of: "\t", with: "    ") }
        case .spaceToTab:
            lines = lines.map { $0.replacingOccurrences(of: "    ", with: "\t") }
        case .eolToSpace:
            return lines.joined(separator: " ")
        case .insertBlankLineAbove:
            return lines.joined(separator: "\n\n")
        }

        return lines.joined(separator: "\n")
    }

    private static func extractLeadingNumber(_ s: String) -> Double {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        let scanner = Scanner(string: trimmed)
        if let val = scanner.scanDouble() {
            return val
        }
        return Double.infinity
    }

    public static func convertCase(_ type: CaseConversionType, on text: String) -> String {
        let trLocale = Locale(identifier: "tr_TR")
        switch type {
        case .uppercase:
            return text.uppercased(with: trLocale)
        case .lowercase:
            return text.lowercased(with: trLocale)
        case .properCase:
            return text.capitalized(with: trLocale)
        case .sentenceCase:
            var result = ""
            var capitalizeNext = true
            for ch in text {
                if capitalizeNext && ch.isLetter {
                    result.append(String(ch).uppercased(with: trLocale))
                    capitalizeNext = false
                } else {
                    result.append(String(ch).lowercased(with: trLocale))
                }
                if ch == "." || ch == "!" || ch == "?" || ch == "\n" {
                    capitalizeNext = true
                }
            }
            return result
        case .invertCase:
            return String(text.map { ch in
                if ch.isUppercase {
                    return Character(String(ch).lowercased(with: trLocale))
                } else if ch.isLowercase {
                    return Character(String(ch).uppercased(with: trLocale))
                }
                return ch
            })
        case .randomCase:
            return String(text.map { ch in
                Bool.random()
                    ? Character(String(ch).uppercased(with: trLocale))
                    : Character(String(ch).lowercased(with: trLocale))
            })
        }
    }

    // MARK: - Bookmark Line Operations
    public static func copyBookmarkedLines(from text: String, bookmarks: Set<Int>) -> String {
        let lines = LineEndingType.normalizeToLF(text).components(separatedBy: "\n")
        var collected: [String] = []
        for (idx, line) in lines.enumerated() where bookmarks.contains(idx + 1) {
            collected.append(line)
        }
        return collected.joined(separator: "\n")
    }

    public static func removeBookmarkedLines(from text: String, bookmarks: Set<Int>) -> String {
        let lines = LineEndingType.normalizeToLF(text).components(separatedBy: "\n")
        var remaining: [String] = []
        for (idx, line) in lines.enumerated() where !bookmarks.contains(idx + 1) {
            remaining.append(line)
        }
        return remaining.joined(separator: "\n")
    }

    public static func removeUnbookmarkedLines(from text: String, bookmarks: Set<Int>) -> String {
        let lines = LineEndingType.normalizeToLF(text).components(separatedBy: "\n")
        var remaining: [String] = []
        for (idx, line) in lines.enumerated() where bookmarks.contains(idx + 1) {
            remaining.append(line)
        }
        return remaining.joined(separator: "\n")
    }

    // MARK: - Column Editor (Alt+C)
    public static func applyColumnInsertText(
        to text: String,
        columnIndex: Int, // 1-based column
        insertText: String,
        lineRange: ClosedRange<Int>? = nil
    ) -> String {
        var lines = LineEndingType.normalizeToLF(text).components(separatedBy: "\n")
        let targetCol = max(0, columnIndex - 1)
        let range = lineRange ?? (1...max(1, lines.count))

        for lineNum in range {
            let idx = lineNum - 1
            guard idx >= 0 && idx < lines.count else { continue }
            var chars = Array(lines[idx])
            if chars.count < targetCol {
                chars.append(contentsOf: Array(repeating: Character(" "), count: targetCol - chars.count))
            }
            chars.insert(contentsOf: insertText, at: targetCol)
            lines[idx] = String(chars)
        }
        return lines.joined(separator: "\n")
    }

    public static func applyColumnInsertNumbers(
        to text: String,
        columnIndex: Int,
        initialNumber: Int,
        increaseBy: Int,
        repeatCount: Int,
        leadingZeros: Bool,
        minDigits: Int,
        format: NumberRadixFormat,
        prefix: String = "",
        suffix: String = "",
        lineRange: ClosedRange<Int>? = nil
    ) -> String {
        var lines = LineEndingType.normalizeToLF(text).components(separatedBy: "\n")
        let targetCol = max(0, columnIndex - 1)
        let range = lineRange ?? (1...max(1, lines.count))

        var currentValue = initialNumber
        var currentRepeat = 0
        let safeRepeat = max(1, repeatCount)

        for lineNum in range {
            let idx = lineNum - 1
            guard idx >= 0 && idx < lines.count else { continue }

            var formattedNum: String
            switch format {
            case .decimal:
                formattedNum = String(currentValue)
            case .hexUpper:
                formattedNum = String(currentValue, radix: 16, uppercase: true)
            case .hexLower:
                formattedNum = String(currentValue, radix: 16, uppercase: false)
            case .octal:
                formattedNum = String(currentValue, radix: 8)
            case .binary:
                formattedNum = String(currentValue, radix: 2)
            }

            if leadingZeros && formattedNum.count < minDigits {
                formattedNum = String(repeating: "0", count: minDigits - formattedNum.count) + formattedNum
            }

            let fullToken = "\(prefix)\(formattedNum)\(suffix)"
            var chars = Array(lines[idx])
            if chars.count < targetCol {
                chars.append(contentsOf: Array(repeating: Character(" "), count: targetCol - chars.count))
            }
            chars.insert(contentsOf: fullToken, at: targetCol)
            lines[idx] = String(chars)

            currentRepeat += 1
            if currentRepeat >= safeRepeat {
                currentRepeat = 0
                currentValue += increaseBy
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Formatting, Encoding & Crypto Tools
    public static func base64Encode(_ text: String) -> String {
        return Data(text.utf8).base64EncodedString()
    }

    public static func base64Decode(_ text: String) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: cleaned, options: .ignoreUnknownCharacters),
              let str = String(data: data, encoding: .utf8) else {
            return text
        }
        return str
    }

    public static func urlEncode(_ text: String) -> String {
        return text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
    }

    public static func urlDecode(_ text: String) -> String {
        return text.removingPercentEncoding ?? text
    }

    public static func md5Hash(_ text: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256Hash(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func jsonPrettyPrint(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else {
            return text
        }
        return str
    }

    public static func jsonMinify(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let mini = try? JSONSerialization.data(withJSONObject: obj, options: []),
              let str = String(data: mini, encoding: .utf8) else {
            return text
        }
        return str
    }

    public static func sqlFormat(_ text: String) -> String {
        var out = text
        let majorClauses = [
            "SELECT", "FROM", "WHERE", "LEFT JOIN", "RIGHT JOIN", "INNER JOIN",
            "FULL JOIN", "JOIN", "GROUP BY", "HAVING", "ORDER BY", "LIMIT",
            "INSERT INTO", "VALUES", "UPDATE", "SET", "DELETE FROM", "UNION ALL", "UNION"
        ]
        for clause in majorClauses {
            if let regex = try? NSRegularExpression(pattern: "\\b\(clause)\\b", options: [.caseInsensitive]) {
                out = regex.stringByReplacingMatches(
                    in: out,
                    options: [],
                    range: NSRange(location: 0, length: (out as NSString).length),
                    withTemplate: "\n\(clause)"
                )
            }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func toggleSingleLineComment(on text: String, prefix: String) -> String {
        let lines = LineEndingType.normalizeToLF(text).components(separatedBy: "\n")
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let allCommented = !nonEmpty.isEmpty && nonEmpty.allSatisfy {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix.trimmingCharacters(in: .whitespaces))
        }

        if allCommented {
            return lines.map { line in
                if let range = line.range(of: prefix) {
                    var copy = line
                    copy.removeSubrange(range)
                    return copy
                } else if let range = line.range(of: prefix.trimmingCharacters(in: .whitespaces)) {
                    var copy = line
                    copy.removeSubrange(range)
                    return copy
                }
                return line
            }.joined(separator: "\n")
        } else {
            return lines.map { line in
                line.isEmpty ? line : "\(prefix) \(line)"
            }.joined(separator: "\n")
        }
    }
}
