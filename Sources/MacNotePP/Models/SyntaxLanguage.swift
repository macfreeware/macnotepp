import AppKit
import Foundation

public enum EditorTheme: String, CaseIterable, Codable, Identifiable {
    case nppClassicLight = "Klasik (Açık)"
    case obsidianDark = "Obsidian (Koyu)"
    case monokaiPro = "Monokai Pro (Koyu)"
    case solarizedLight = "Solarized (Açık)"

    public var id: String { rawValue }

    public func title(for language: AppLanguage) -> String {
        guard language.resolvedLanguage != .turkish else { return rawValue }
        return rawValue
            .replacingOccurrences(of: "Klasik", with: "Classic")
            .replacingOccurrences(of: "(Açık)", with: "(Light)")
            .replacingOccurrences(of: "(Koyu)", with: "(Dark)")
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if raw == "Klasik Aydınlık" || raw == "Klasik Açık" || raw == "Klasik (Açık)" {
            self = .nppClassicLight
        } else if let theme = EditorTheme(rawValue: raw) {
            self = theme
        } else {
            self = .nppClassicLight
        }
    }

    public var isDark: Bool {
        switch self {
        case .nppClassicLight, .solarizedLight: return false
        case .obsidianDark, .monokaiPro: return true
        }
    }

    public var editorBackground: NSColor {
        switch self {
        case .nppClassicLight: return NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        case .obsidianDark: return NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.15, alpha: 1.0)
        case .monokaiPro: return NSColor(calibratedRed: 0.15, green: 0.16, blue: 0.13, alpha: 1.0)
        case .solarizedLight: return NSColor(calibratedRed: 0.99, green: 0.96, blue: 0.89, alpha: 1.0)
        }
    }

    public var editorText: NSColor {
        switch self {
        case .nppClassicLight: return NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        case .obsidianDark: return NSColor(calibratedRed: 0.88, green: 0.90, blue: 0.93, alpha: 1.0)
        case .monokaiPro: return NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.95, alpha: 1.0)
        case .solarizedLight: return NSColor(calibratedRed: 0.35, green: 0.43, blue: 0.46, alpha: 1.0)
        }
    }

    public var currentLineHighlight: NSColor {
        switch self {
        case .nppClassicLight: return NSColor(calibratedRed: 0.91, green: 0.95, blue: 1.0, alpha: 1.0)
        case .obsidianDark: return NSColor(calibratedRed: 0.18, green: 0.20, blue: 0.25, alpha: 1.0)
        case .monokaiPro: return NSColor(calibratedRed: 0.22, green: 0.23, blue: 0.19, alpha: 1.0)
        case .solarizedLight: return NSColor(calibratedRed: 0.93, green: 0.91, blue: 0.84, alpha: 1.0)
        }
    }

    public var gutterBackground: NSColor {
        switch self {
        case .nppClassicLight: return NSColor(calibratedRed: 0.94, green: 0.94, blue: 0.94, alpha: 1.0)
        case .obsidianDark: return NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.13, alpha: 1.0)
        case .monokaiPro: return NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.11, alpha: 1.0)
        case .solarizedLight: return NSColor(calibratedRed: 0.95, green: 0.92, blue: 0.84, alpha: 1.0)
        }
    }

    public var gutterText: NSColor {
        switch self {
        case .nppClassicLight: return NSColor(calibratedRed: 0.45, green: 0.48, blue: 0.52, alpha: 1.0)
        case .obsidianDark: return NSColor(calibratedRed: 0.50, green: 0.54, blue: 0.60, alpha: 1.0)
        case .monokaiPro: return NSColor(calibratedRed: 0.56, green: 0.56, blue: 0.52, alpha: 1.0)
        case .solarizedLight: return NSColor(calibratedRed: 0.55, green: 0.60, blue: 0.61, alpha: 1.0)
        }
    }

    public var keywordColor: NSColor {
        switch self {
        case .nppClassicLight: return NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.85, alpha: 1.0) // Classic Blue
        case .obsidianDark: return NSColor(calibratedRed: 0.58, green: 0.78, blue: 0.39, alpha: 1.0)
        case .monokaiPro: return NSColor(calibratedRed: 0.98, green: 0.15, blue: 0.45, alpha: 1.0)
        case .solarizedLight: return NSColor(calibratedRed: 0.52, green: 0.60, blue: 0.0, alpha: 1.0)
        }
    }

    public var typeColor: NSColor {
        switch self {
        case .nppClassicLight: return NSColor(calibratedRed: 0.50, green: 0.0, blue: 0.55, alpha: 1.0) // Purple
        case .obsidianDark: return NSColor(calibratedRed: 0.40, green: 0.75, blue: 0.95, alpha: 1.0)
        case .monokaiPro: return NSColor(calibratedRed: 0.40, green: 0.85, blue: 0.94, alpha: 1.0)
        case .solarizedLight: return NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.82, alpha: 1.0)
        }
    }

    public var stringColor: NSColor {
        switch self {
        case .nppClassicLight: return NSColor(calibratedRed: 0.55, green: 0.25, blue: 0.0, alpha: 1.0) // Brown/Grey-Red
        case .obsidianDark: return NSColor(calibratedRed: 0.93, green: 0.56, blue: 0.28, alpha: 1.0)
        case .monokaiPro: return NSColor(calibratedRed: 0.90, green: 0.86, blue: 0.45, alpha: 1.0)
        case .solarizedLight: return NSColor(calibratedRed: 0.16, green: 0.63, blue: 0.60, alpha: 1.0)
        }
    }

    public var commentColor: NSColor {
        switch self {
        case .nppClassicLight: return NSColor(calibratedRed: 0.0, green: 0.52, blue: 0.0, alpha: 1.0) // Classic Green
        case .obsidianDark: return NSColor(calibratedRed: 0.48, green: 0.53, blue: 0.58, alpha: 1.0)
        case .monokaiPro: return NSColor(calibratedRed: 0.46, green: 0.44, blue: 0.37, alpha: 1.0)
        case .solarizedLight: return NSColor(calibratedRed: 0.58, green: 0.63, blue: 0.63, alpha: 1.0)
        }
    }

    public var numberColor: NSColor {
        switch self {
        case .nppClassicLight: return NSColor(calibratedRed: 0.85, green: 0.28, blue: 0.0, alpha: 1.0) // Classic Orange
        case .obsidianDark: return NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.32, alpha: 1.0)
        case .monokaiPro: return NSColor(calibratedRed: 0.68, green: 0.51, blue: 1.0, alpha: 1.0)
        case .solarizedLight: return NSColor(calibratedRed: 0.83, green: 0.21, blue: 0.51, alpha: 1.0)
        }
    }

    public var preprocessorColor: NSColor {
        switch self {
        case .nppClassicLight: return NSColor(calibratedRed: 0.55, green: 0.28, blue: 0.05, alpha: 1.0)
        case .obsidianDark: return NSColor(calibratedRed: 0.78, green: 0.56, blue: 0.95, alpha: 1.0)
        case .monokaiPro: return NSColor(calibratedRed: 0.65, green: 0.89, blue: 0.18, alpha: 1.0)
        case .solarizedLight: return NSColor(calibratedRed: 0.80, green: 0.29, blue: 0.09, alpha: 1.0)
        }
    }

    public var functionColor: NSColor {
        switch self {
        case .nppClassicLight: return NSColor(calibratedRed: 0.0, green: 0.32, blue: 0.62, alpha: 1.0)
        case .obsidianDark: return NSColor(calibratedRed: 0.52, green: 0.76, blue: 0.98, alpha: 1.0)
        case .monokaiPro: return NSColor(calibratedRed: 0.65, green: 0.89, blue: 0.18, alpha: 1.0)
        case .solarizedLight: return NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.82, alpha: 1.0)
        }
    }
}

public enum SyntaxLanguage: String, CaseIterable, Codable, Identifiable {
    case plainText = "Normal Text"
    case cCpp = "C / C++"
    case pascal = "Pascal / Delphi"
    case sql = "SQL"
    case python = "Python"
    case javascript = "JavaScript / TypeScript"
    case htmlXml = "HTML / XML"
    case css = "CSS / SCSS"
    case json = "JSON"
    case yaml = "YAML"
    case markdown = "Markdown"
    case shell = "Bash / Shell"
    case swift = "Swift"
    case rust = "Rust"
    case go = "Go"
    case java = "Java"
    case csharp = "C#"
    case php = "PHP"
    case ini = "INI / Config"
    case assembly = "Assembly (ASM)"
    case batchPowerShell = "Batch / PowerShell"
    case logFile = "Log File"

    public var id: String { rawValue }

    public var statusDescription: String {
        switch self {
        case .plainText: return "Normal text file"
        case .cCpp: return "C / C++ source file"
        case .pascal: return "Pascal / Delphi source file (.pas/.dpr)"
        case .sql: return "Structured Query Language file (.sql)"
        case .python: return "Python file (.py)"
        case .javascript: return "JavaScript / TypeScript file"
        case .htmlXml: return "HyperText Markup / XML file"
        case .css: return "Cascade Style Sheets file"
        case .json: return "JSON data file"
        case .yaml: return "YAML configuration file"
        case .markdown: return "Markdown documentation file"
        case .shell: return "Unix Shell script"
        case .swift: return "Swift source file"
        case .rust: return "Rust source file"
        case .go: return "Go source file"
        case .java: return "Java source file"
        case .csharp: return "C# source file"
        case .php: return "PHP Hypertext Preprocessor file"
        case .ini: return "MS INI / Configuration file"
        case .assembly: return "Assembly language source file"
        case .batchPowerShell: return "Batch / PowerShell script"
        case .logFile: return "Application Log file"
        }
    }

    public var defaultExtension: String {
        switch self {
        case .plainText: return "txt"
        case .cCpp: return "cpp"
        case .pascal: return "pas"
        case .sql: return "sql"
        case .python: return "py"
        case .javascript: return "js"
        case .htmlXml: return "html"
        case .css: return "css"
        case .json: return "json"
        case .yaml: return "yaml"
        case .markdown: return "md"
        case .shell: return "sh"
        case .swift: return "swift"
        case .rust: return "rs"
        case .go: return "go"
        case .java: return "java"
        case .csharp: return "cs"
        case .php: return "php"
        case .ini: return "ini"
        case .assembly: return "asm"
        case .batchPowerShell: return "ps1"
        case .logFile: return "log"
        }
    }

    public var singleLineCommentPrefix: String? {
        switch self {
        case .plainText, .htmlXml, .css, .json, .markdown, .logFile: return nil
        case .cCpp, .javascript, .swift, .rust, .go, .java, .csharp, .php, .pascal: return "//"
        case .sql: return "--"
        case .python, .yaml, .shell: return "#"
        case .ini, .assembly: return ";"
        case .batchPowerShell: return "REM "
        }
    }

    public static func detect(url: URL?, filename: String? = nil, content: String = "") -> SyntaxLanguage {
        let effectiveExt: String
        let effectiveName: String

        if let url = url {
            effectiveExt = url.pathExtension.lowercased()
            effectiveName = url.lastPathComponent.lowercased()
        } else if let filename = filename, !filename.isEmpty {
            effectiveExt = (filename as NSString).pathExtension.lowercased()
            effectiveName = (filename as NSString).lastPathComponent.lowercased()
        } else {
            effectiveExt = ""
            effectiveName = ""
        }

        if !effectiveName.isEmpty {
            if effectiveName == "makefile" || effectiveName == "dockerfile" || effectiveName == ".zshrc" || effectiveName == ".bashrc" {
                return .shell
            }
            if effectiveName == "cmakelists.txt" {
                return .ini
            }
        }

        if !effectiveExt.isEmpty {
            switch effectiveExt {
            case "c", "h", "cpp", "hpp", "cc", "cxx", "hxx", "ino", "m", "mm":
                return .cCpp
            case "pas", "dpr", "dpk", "inc", "pp", "lpr", "dfm", "fmx":
                return .pascal
            case "sql", "ddl", "dml", "pgsql", "plsql", "tsql":
                return .sql
            case "py", "pyw", "pyi":
                return .python
            case "js", "jsx", "ts", "tsx", "mjs", "cjs":
                return .javascript
            case "html", "htm", "xhtml", "xml", "svg", "plist", "csproj", "vcxproj", "xaml":
                return .htmlXml
            case "css", "scss", "less", "sass":
                return .css
            case "json", "geojson", "jsonl":
                return .json
            case "yml", "yaml":
                return .yaml
            case "md", "markdown", "rst":
                return .markdown
            case "sh", "bash", "zsh", "fish", "command":
                return .shell
            case "swift":
                return .swift
            case "rs":
                return .rust
            case "go":
                return .go
            case "java", "kt", "kts", "groovy":
                return .java
            case "cs":
                return .csharp
            case "php", "phtml":
                return .php
            case "ini", "cfg", "conf", "toml", "properties", "env":
                return .ini
            case "asm", "s", "nasm":
                return .assembly
            case "bat", "cmd", "ps1", "psm1":
                return .batchPowerShell
            case "log", "err", "out":
                return .logFile
            default:
                break
            }
        }

        // Multi-line Content heuristics if untitled or unknown extension
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .plainText }

        let sampleLines = trimmed.prefix(4000).components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let firstLine = sampleLines.first?.lowercased() ?? ""
        if firstLine.hasPrefix("#!/bin/sh") || firstLine.hasPrefix("#!/bin/bash") || firstLine.hasPrefix("#!/bin/zsh") {
            return .shell
        }
        if firstLine.hasPrefix("#!/usr/bin/env python") || firstLine.hasPrefix("#!/usr/bin/python") {
            return .python
        }
        if firstLine.hasPrefix("<?xml") || firstLine.hasPrefix("<!doctype html") || firstLine.hasPrefix("<html") {
            return .htmlXml
        }
        if firstLine.hasPrefix("<?php") {
            return .php
        }

        let lowerSample = trimmed.prefix(4000).lowercased()

        // C / C++ detection
        if sampleLines.contains(where: { $0.hasPrefix("#include ") || $0.hasPrefix("#pragma ") || $0.hasPrefix("#ifndef ") })
            || lowerSample.contains("int main(") || lowerSample.contains("void main(") || lowerSample.contains("std::") {
            return .cCpp
        }

        // SQL detection: check across first lines for common SQL statements
        let sqlKeywords = ["select ", "create table", "insert into", "alter table", "update ", "delete from", "drop table", "truncate table"]
        let hasSqlLine = sampleLines.contains { line in
            let l = line.lowercased()
            return sqlKeywords.contains { l.hasPrefix($0) }
        }
        if hasSqlLine || (lowerSample.contains("select ") && lowerSample.contains(" from ")) {
            return .sql
        }

        // Pascal detection
        if sampleLines.contains(where: { $0.lowercased().hasPrefix("unit ") || $0.lowercased().hasPrefix("program ") })
            || (lowerSample.contains("procedure ") && lowerSample.contains("begin")) {
            return .pascal
        }

        // Swift / Rust / Go detection
        if sampleLines.contains(where: { $0.hasPrefix("import SwiftUI") || $0.hasPrefix("import Foundation") }) {
            return .swift
        }
        if lowerSample.contains("fn main()") || sampleLines.contains(where: { $0.hasPrefix("use std::") }) {
            return .rust
        }
        if sampleLines.contains(where: { $0.hasPrefix("package main") }) {
            return .go
        }

        // Python detection
        if sampleLines.contains(where: { $0.hasPrefix("def ") || $0.hasPrefix("import ") || $0.hasPrefix("from ") }) && lowerSample.contains(":") {
            return .python
        }

        // JSON detection
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            if trimmed.contains("\":") {
                return .json
            }
        }

        return .plainText
    }
}

public struct FunctionItem: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let kind: String
    public let lineNumber: Int
    public let characterOffset: Int
}

public final class SyntaxHighlighter {
    public static let shared = SyntaxHighlighter()

    private var regexCache: [String: NSRegularExpression] = [:]

    private func cachedRegex(_ pattern: String, options: NSRegularExpression.Options = []) -> NSRegularExpression? {
        let key = "\(pattern)_\(options.rawValue)"
        if let existing = regexCache[key] {
            return existing
        }
        if let compiled = try? NSRegularExpression(pattern: pattern, options: options) {
            regexCache[key] = compiled
            return compiled
        }
        return nil
    }

    public func highlight(
        textStorage: NSTextStorage,
        language: SyntaxLanguage,
        theme: EditorTheme,
        font: NSFont,
        markedRanges: [NSRange] = [],
        searchMatches: [NSRange] = [],
        activeMatch: NSRange? = nil
    ) {
        let fullString: NSString = textStorage.mutableString
        let fullRange = NSRange(location: 0, length: fullString.length)
        guard fullRange.length > 0 else { return }

        // Avoid freezing on massive files (> 400KB) by capping regex highlight range
        let highlightRange = NSRange(location: 0, length: min(fullRange.length, 400_000))
        let styleRange = NSRange(location: 0, length: min(fullRange.length, 1_000_000))

        textStorage.beginEditing()
        textStorage.setAttributes([
            .font: font,
            .foregroundColor: theme.editorText
        ], range: styleRange)

        if language != .plainText {
            let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)

            let rules = rulesForLanguage(language)
            for rule in rules {
                guard let regex = cachedRegex(rule.pattern, options: rule.options) else { continue }
                let color: NSColor
                var ruleFont: NSFont = font

                switch rule.tokenType {
                case .keyword:
                    color = theme.keywordColor
                    ruleFont = boldFont
                case .type:
                    color = theme.typeColor
                case .string:
                    color = theme.stringColor
                case .comment:
                    color = theme.commentColor
                    ruleFont = italicFont
                case .number:
                    color = theme.numberColor
                case .preprocessor:
                    color = theme.preprocessorColor
                case .function:
                    color = theme.functionColor
                }

                regex.enumerateMatches(in: textStorage.string, options: [], range: highlightRange) { match, _, _ in
                    guard let matchRange = match?.range, matchRange.location != NSNotFound else { return }
                    textStorage.addAttributes([
                        .foregroundColor: color,
                        .font: ruleFont
                    ], range: matchRange)
                }
            }
        }

        // Apply "Mark" highlights
        let markColor = NSColor.systemCyan.withAlphaComponent(theme.isDark ? 0.40 : 0.35)
        for range in markedRanges {
            if NSMaxRange(range) <= fullRange.length {
                textStorage.addAttribute(.backgroundColor, value: markColor, range: range)
            }
        }

        // Apply live Search Match highlights
        let matchBg = NSColor.systemYellow.withAlphaComponent(theme.isDark ? 0.38 : 0.45)
        for range in searchMatches {
            if NSMaxRange(range) <= fullRange.length {
                textStorage.addAttribute(.backgroundColor, value: matchBg, range: range)
            }
        }

        if let active = activeMatch, NSMaxRange(active) <= fullRange.length {
            textStorage.addAttributes([
                .backgroundColor: NSColor.systemOrange.withAlphaComponent(0.75),
                .foregroundColor: NSColor.black
            ], range: active)
        }

        textStorage.endEditing()
    }

    private enum TokenType {
        case keyword
        case type
        case string
        case comment
        case number
        case preprocessor
        case function
    }

    private struct HighlightRule {
        let pattern: String
        let tokenType: TokenType
        let options: NSRegularExpression.Options
    }

    private func rulesForLanguage(_ language: SyntaxLanguage) -> [HighlightRule] {
        // Order matters: numbers & functions & types & keywords first, then strings, then comments override all
        switch language {
        case .cCpp:
            return [
                HighlightRule(pattern: "\\b(0x[0-9A-Fa-f]+|0b[01]+|\\d+(\\.\\d+)?([eE][+-]?\\d+)?[fFlLuU]*)\\b", tokenType: .number, options: []),
                HighlightRule(pattern: "\\b([A-Za-z_][A-Za-z0-9_]*)\\s*(?=\\()", tokenType: .function, options: []),
                HighlightRule(pattern: "\\b(int|long|short|char|void|float|double|bool|unsigned|signed|size_t|uint8_t|uint16_t|uint32_t|uint64_t|int8_t|int16_t|int32_t|int64_t|string|vector|map|set|auto|wchar_t|FILE|NULL|nullptr)\\b", tokenType: .type, options: []),
                HighlightRule(pattern: "\\b(if|else|for|while|do|switch|case|default|break|continue|return|goto|struct|class|union|enum|typedef|typename|template|namespace|using|public|private|protected|virtual|override|final|static|const|constexpr|volatile|inline|extern|sizeof|new|delete|try|catch|throw|operator|friend|this|true|false)\\b", tokenType: .keyword, options: []),
                HighlightRule(pattern: "^\\s*#[a-zA-Z_]+.*", tokenType: .preprocessor, options: [.anchorsMatchLines]),
                HighlightRule(pattern: "\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'", tokenType: .string, options: []),
                HighlightRule(pattern: "//.*", tokenType: .comment, options: []),
                HighlightRule(pattern: "/\\*[\\s\\S]*?\\*/", tokenType: .comment, options: [])
            ]

        case .pascal:
            return [
                HighlightRule(pattern: "(\\$[0-9A-Fa-f]+|\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b)", tokenType: .number, options: []),
                HighlightRule(pattern: "\\b([A-Za-z_][A-Za-z0-9_]*)\\s*(?=\\()", tokenType: .function, options: []),
                HighlightRule(pattern: "\\b(Integer|LongInt|ShortInt|SmallInt|Byte|Word|Cardinal|Int64|UInt64|Single|Double|Extended|Real|Currency|Boolean|Char|WideChar|AnsiChar|String|AnsiString|WideString|UnicodeString|ShortString|Pointer|Variant|TObject|TComponent|TForm|TStringList|TStream|TFileStream|TextFile|File|Array|Record|Set)\\b", tokenType: .type, options: [.caseInsensitive]),
                HighlightRule(pattern: "\\b(and|array|as|asm|begin|case|class|const|constructor|destructor|dispinterface|div|do|downto|else|end|except|exports|file|finalization|finally|for|function|goto|if|implementation|in|inherited|initialization|inline|interface|is|label|library|mod|nil|not|object|of|or|out|packed|procedure|program|property|raise|record|repeat|resourcestring|set|shl|shr|string|then|threadvar|to|try|type|unit|until|uses|var|while|with|xor|private|protected|public|published|virtual|override|overload|reintroduce|abstract|cdecl|stdcall|register|safecall|True|False|Self|Result|Exit|Break|Continue)\\b", tokenType: .keyword, options: [.caseInsensitive]),
                HighlightRule(pattern: "\\{\\$[^\\}]*\\}|\\(\\*\\$[\\s\\S]*?\\*\\)", tokenType: .preprocessor, options: []),
                HighlightRule(pattern: "'(?:''|[^'])*'|#\\d+", tokenType: .string, options: []),
                HighlightRule(pattern: "//.*", tokenType: .comment, options: []),
                HighlightRule(pattern: "\\{[^\\$][^\\}]*\\}|\\{\\}|\\(\\*[\\s\\S]*?\\*\\)", tokenType: .comment, options: [])
            ]

        case .sql:
            return [
                HighlightRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number, options: []),
                HighlightRule(pattern: "\\b(COUNT|SUM|AVG|MIN|MAX|COALESCE|ISNULL|NVL|CAST|CONVERT|SUBSTRING|TRIM|LTRIM|RTRIM|UPPER|LOWER|LEN|LENGTH|ROUND|NOW|GETDATE|DATEADD|DATEDIFF|YEAR|MONTH|DAY|ROW_NUMBER|RANK|DENSE_RANK|LEAD|LAG|CONCAT|REPLACE)\\b", tokenType: .function, options: [.caseInsensitive]),
                HighlightRule(pattern: "\\b(INT|INTEGER|BIGINT|SMALLINT|TINYINT|DECIMAL|NUMERIC|FLOAT|REAL|DOUBLE|MONEY|BIT|BOOLEAN|BOOL|DATE|DATETIME|DATETIME2|TIMESTAMP|TIME|CHAR|VARCHAR|VARCHAR2|NVARCHAR|TEXT|NTEXT|CLOB|BLOB|BINARY|VARBINARY|UUID|UNIQUEIDENTIFIER|JSON|JSONB|SERIAL|BIGSERIAL|XML)\\b", tokenType: .type, options: [.caseInsensitive]),
                HighlightRule(pattern: "\\b(SELECT|FROM|WHERE|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|ALTER|DROP|TRUNCATE|TABLE|VIEW|INDEX|PROCEDURE|FUNCTION|TRIGGER|DATABASE|SCHEMA|PRIMARY|FOREIGN|KEY|REFERENCES|CONSTRAINT|UNIQUE|CHECK|DEFAULT|NULL|NOT|AND|OR|IN|EXISTS|BETWEEN|LIKE|ILIKE|IS|AS|JOIN|INNER|LEFT|RIGHT|FULL|OUTER|CROSS|ON|USING|GROUP|BY|HAVING|ORDER|ASC|DESC|LIMIT|OFFSET|TOP|DISTINCT|UNION|ALL|CASE|WHEN|THEN|ELSE|END|BEGIN|COMMIT|ROLLBACK|TRANSACTION|DECLARE|EXEC|EXECUTE|RETURN|RETURNS|CURSOR|FETCH|OPEN|CLOSE|WITH|OVER|PARTITION|GRANT|REVOKE|IF|WHILE|LOOP)\\b", tokenType: .keyword, options: [.caseInsensitive]),
                HighlightRule(pattern: "@@[A-Za-z0-9_]+|@[A-Za-z0-9_]+|:[A-Za-z0-9_]+", tokenType: .preprocessor, options: []),
                HighlightRule(pattern: "'(?:''|[^'])*'|\"(?:\\\\.|[^\"\\\\])*\"", tokenType: .string, options: []),
                HighlightRule(pattern: "--.*", tokenType: .comment, options: []),
                HighlightRule(pattern: "/\\*[\\s\\S]*?\\*/", tokenType: .comment, options: [])
            ]

        case .python:
            return [
                HighlightRule(pattern: "\\b(0x[0-9A-Fa-f]+|\\d+(\\.\\d+)?([eE][+-]?\\d+)?)\\b", tokenType: .number, options: []),
                HighlightRule(pattern: "\\b([A-Za-z_][A-Za-z0-9_]*)\\s*(?=\\()", tokenType: .function, options: []),
                HighlightRule(pattern: "\\b(int|float|str|bool|list|dict|set|tuple|bytes|object|type|Exception|None|True|False|self|cls)\\b", tokenType: .type, options: []),
                HighlightRule(pattern: "\\b(and|as|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|from|global|if|import|in|is|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield|match|case)\\b", tokenType: .keyword, options: []),
                HighlightRule(pattern: "@[A-Za-z_][A-Za-z0-9_.]*", tokenType: .preprocessor, options: []),
                HighlightRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"|'''[\\s\\S]*?'''|\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'", tokenType: .string, options: []),
                HighlightRule(pattern: "#.*", tokenType: .comment, options: [])
            ]

        case .javascript, .swift, .rust, .go, .java, .csharp, .php:
            return [
                HighlightRule(pattern: "\\b(0x[0-9A-Fa-f]+|\\d+(\\.\\d+)?([eE][+-]?\\d+)?)\\b", tokenType: .number, options: []),
                HighlightRule(pattern: "\\b([A-Za-z_][A-Za-z0-9_]*)\\s*(?=\\()", tokenType: .function, options: []),
                HighlightRule(pattern: "\\b([A-Z][A-Za-z0-9_]*|string|number|boolean|any|void|int|float|double|bool|char|byte|usize|isize|i32|i64|u32|u64|f32|f64)\\b", tokenType: .type, options: []),
                HighlightRule(pattern: "\\b(if|else|for|while|do|switch|case|default|break|continue|return|function|func|fn|def|let|var|const|val|mut|struct|class|enum|interface|protocol|trait|impl|type|typealias|import|export|from|package|module|namespace|using|pub|public|private|protected|internal|static|final|override|async|await|try|catch|finally|throw|throws|new|this|self|super|true|false|null|nil|undefined|guard|defer|where|in|is|as|match)\\b", tokenType: .keyword, options: []),
                HighlightRule(pattern: "@[A-Za-z_][A-Za-z0-9_]*|\\$[A-Za-z_][A-Za-z0-9_]*", tokenType: .preprocessor, options: []),
                HighlightRule(pattern: "\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'|`(?:\\\\.|[^`\\\\])*`", tokenType: .string, options: []),
                HighlightRule(pattern: "//.*|#.*", tokenType: .comment, options: []),
                HighlightRule(pattern: "/\\*[\\s\\S]*?\\*/", tokenType: .comment, options: [])
            ]

        case .htmlXml:
            return [
                HighlightRule(pattern: "</?[A-Za-z0-9:_-]+|/?>", tokenType: .keyword, options: []),
                HighlightRule(pattern: "\\b[A-Za-z0-9:_-]+(?=\\s*=)", tokenType: .type, options: []),
                HighlightRule(pattern: "&[A-Za-z0-9#]+;", tokenType: .number, options: []),
                HighlightRule(pattern: "\"[^\"]*\"|'[^']*'", tokenType: .string, options: []),
                HighlightRule(pattern: "<!--[\\s\\S]*?-->", tokenType: .comment, options: [])
            ]

        case .css:
            return [
                HighlightRule(pattern: "(#[0-9A-Fa-f]{3,8}|\\b\\d+(\\.\\d+)?(px|em|rem|vh|vw|%|s|ms|deg)?\\b)", tokenType: .number, options: []),
                HighlightRule(pattern: "([.#][A-Za-z0-9_-]+|\\b(div|span|body|html|a|p|h[1-6]|ul|li|table|tr|td|button|input|header|footer|main|section|nav)\\b)", tokenType: .keyword, options: []),
                HighlightRule(pattern: "[A-Za-z-]+(?=\\s*:)", tokenType: .type, options: []),
                HighlightRule(pattern: "@[A-Za-z_-]+", tokenType: .preprocessor, options: []),
                HighlightRule(pattern: "\"[^\"]*\"|'[^']*'", tokenType: .string, options: []),
                HighlightRule(pattern: "/\\*[\\s\\S]*?\\*/", tokenType: .comment, options: [])
            ]

        case .json:
            return [
                HighlightRule(pattern: "\\b(true|false|null)\\b", tokenType: .keyword, options: []),
                HighlightRule(pattern: "-?\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b", tokenType: .number, options: []),
                HighlightRule(pattern: "\"(?:\\\\.|[^\"\\\\])*\"", tokenType: .string, options: []),
                HighlightRule(pattern: "\"(?:\\\\.|[^\"\\\\])*\"(?=\\s*:)", tokenType: .type, options: [])
            ]

        case .yaml, .ini:
            return [
                HighlightRule(pattern: "^\\s*\\[[^\\]]+\\]", tokenType: .keyword, options: [.anchorsMatchLines]),
                HighlightRule(pattern: "^\\s*[A-Za-z0-9_.-]+(?=\\s*[:=])", tokenType: .type, options: [.anchorsMatchLines]),
                HighlightRule(pattern: "\\b(true|false|yes|no|on|off|null)\\b", tokenType: .keyword, options: [.caseInsensitive]),
                HighlightRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number, options: []),
                HighlightRule(pattern: "\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'", tokenType: .string, options: []),
                HighlightRule(pattern: "[#;].*", tokenType: .comment, options: [])
            ]

        case .markdown:
            return [
                HighlightRule(pattern: "^#{1,6}\\s+.*$", tokenType: .keyword, options: [.anchorsMatchLines]),
                HighlightRule(pattern: "\\*\\*[^*]+\\*\\*|__[^_]+__", tokenType: .type, options: []),
                HighlightRule(pattern: "`[^`]+`|```[\\s\\S]*?```", tokenType: .string, options: []),
                HighlightRule(pattern: "\\[[^\\]]+\\]\\([^\\)]+\\)", tokenType: .function, options: []),
                HighlightRule(pattern: "^\\s*[-*+]\\s+|^\\s*\\d+\\.\\s+|^>\\s+.*", tokenType: .preprocessor, options: [.anchorsMatchLines])
            ]

        case .shell, .batchPowerShell:
            return [
                HighlightRule(pattern: "\\b\\d+\\b", tokenType: .number, options: []),
                HighlightRule(pattern: "\\b(if|then|else|elif|fi|for|while|do|done|case|esac|in|function|return|exit|export|local|readonly|set|unset|echo|cd|pwd|ls|grep|awk|sed|find|xargs|sudo|apt|brew|git|docker|npm|swift|goto|call|rem|pause|foreach|param)\\b", tokenType: .keyword, options: [.caseInsensitive]),
                HighlightRule(pattern: "\\$[A-Za-z0-9_@#?*!]+|\\$\\{[^}]+\\}|%[A-Za-z0-9_]+%", tokenType: .preprocessor, options: []),
                HighlightRule(pattern: "\"(?:\\\\.|[^\"\\\\])*\"|'[^']*'", tokenType: .string, options: []),
                HighlightRule(pattern: "(#|^\\s*REM\\b|^\\s*::).*", tokenType: .comment, options: [.caseInsensitive, .anchorsMatchLines])
            ]

        case .assembly:
            return [
                HighlightRule(pattern: "\\b(0x[0-9A-Fa-f]+|[0-9][0-9A-Fa-f]*h|\\d+)\\b", tokenType: .number, options: [.caseInsensitive]),
                HighlightRule(pattern: "^\\s*[A-Za-z_.$][A-Za-z0-9_.$]*:", tokenType: .function, options: [.anchorsMatchLines]),
                HighlightRule(pattern: "\\b(mov|lea|add|sub|mul|imul|div|idiv|inc|dec|and|or|xor|not|shl|shr|cmp|test|jmp|je|jne|jz|jnz|jg|jge|jl|jle|call|ret|push|pop|nop|syscall|int|ldr|str|b|bl|cbz|cbnz|svc)\\b", tokenType: .keyword, options: [.caseInsensitive]),
                HighlightRule(pattern: "\\b(rax|rbx|rcx|rdx|rsi|rdi|rbp|rsp|r8|r9|r10|r11|r12|r13|r14|r15|eax|ebx|ecx|edx|esi|edi|ebp|esp|ax|bx|cx|dx|al|bl|cl|dl|x[0-9]{1,2}|w[0-9]{1,2}|sp|lr|pc)\\b", tokenType: .type, options: [.caseInsensitive]),
                HighlightRule(pattern: "\"[^\"]*\"|'[^']*'", tokenType: .string, options: []),
                HighlightRule(pattern: ";.*", tokenType: .comment, options: [])
            ]

        case .logFile:
            return [
                HighlightRule(pattern: "\\b\\d{4}-\\d{2}-\\d{2}[T\\s]\\d{2}:\\d{2}:\\d{2}([.,]\\d+)?(Z|[+-]\\d{2}:?\\d{2})?\\b|\\b\\d{2}:\\d{2}:\\d{2}\\b", tokenType: .number, options: []),
                HighlightRule(pattern: "\\b(ERROR|FATAL|CRITICAL|SEVERE|FAIL|FAILED|EXCEPTION|PANIC)\\b", tokenType: .string, options: [.caseInsensitive]),
                HighlightRule(pattern: "\\b(WARN|WARNING|DEPRECATED|CAUTION)\\b", tokenType: .preprocessor, options: [.caseInsensitive]),
                HighlightRule(pattern: "\\b(INFO|NOTICE|SUCCESS|OK|PASS|READY)\\b", tokenType: .keyword, options: [.caseInsensitive]),
                HighlightRule(pattern: "\\b(DEBUG|TRACE|VERBOSE)\\b", tokenType: .comment, options: [.caseInsensitive])
            ]

        case .plainText:
            return []
        }
    }

    public func extractFunctions(from content: String, language: SyntaxLanguage) -> [FunctionItem] {
        var items: [FunctionItem] = []
        guard !content.isEmpty else { return [] }

        // Performance guard: for large files (> 200KB), sample first 1,500 lines to keep UI instant
        let sampleContent: Substring = (content.utf8.count > 200_000) ? content.prefix(200_000) : content[...]
        let lines = sampleContent.components(separatedBy: .newlines)
        var currentOffset = 0

        for (index, line) in lines.enumerated() {
            if items.count >= 500 { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            defer { currentOffset += line.utf16.count + 1 }
            guard !trimmed.isEmpty else { continue }

            switch language {
            case .pascal:
                if let match = firstMatch(in: trimmed, pattern: "^(procedure|function|constructor|destructor)\\s+([A-Za-z0-9_.]+)", options: [.caseInsensitive]) {
                    items.append(FunctionItem(name: match.1, kind: match.0.capitalized, lineNumber: index + 1, characterOffset: currentOffset))
                } else if let match = firstMatch(in: trimmed, pattern: "^([A-Za-z0-9_]+)\\s*=\\s*(class|record|interface)\\b", options: [.caseInsensitive]) {
                    items.append(FunctionItem(name: match.0, kind: match.1.capitalized, lineNumber: index + 1, characterOffset: currentOffset))
                }

            case .cCpp, .java, .csharp:
                if !trimmed.hasPrefix("//") && !trimmed.hasPrefix("#") && !trimmed.hasPrefix("if") && !trimmed.hasPrefix("for") && !trimmed.hasPrefix("while") && !trimmed.hasPrefix("switch") {
                    if let match = firstMatch(in: trimmed, pattern: "^(class|struct|enum|namespace)\\s+([A-Za-z_][A-Za-z0-9_]*)") {
                        items.append(FunctionItem(name: match.1, kind: match.0, lineNumber: index + 1, characterOffset: currentOffset))
                    } else if let match = firstMatch(in: trimmed, pattern: "([A-Za-z_][A-Za-z0-9_:]*)\\s*\\([^;]*\\)\\s*(const)?\\s*\\{?$") {
                        let name = match.0
                        if !["if", "for", "while", "switch", "catch", "return", "sizeof"].contains(name) {
                            items.append(FunctionItem(name: "\(name)()", kind: "fn", lineNumber: index + 1, characterOffset: currentOffset))
                        }
                    }
                }

            case .sql:
                if let match = firstMatch(in: trimmed, pattern: "^CREATE\\s+(?:OR\\s+REPLACE\\s+)?(TABLE|VIEW|PROCEDURE|FUNCTION|TRIGGER|INDEX)\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?([A-Za-z0-9_.\\[\\]\"]+)", options: [.caseInsensitive]) {
                    items.append(FunctionItem(name: match.1, kind: match.0.uppercased(), lineNumber: index + 1, characterOffset: currentOffset))
                }

            case .python:
                if let match = firstMatch(in: trimmed, pattern: "^(def|class)\\s+([A-Za-z_][A-Za-z0-9_]*)") {
                    items.append(FunctionItem(name: match.1, kind: match.0, lineNumber: index + 1, characterOffset: currentOffset))
                }

            case .swift, .javascript, .rust, .go, .php:
                if let match = firstMatch(in: trimmed, pattern: "\\b(func|function|fn|class|struct|enum|protocol|interface|trait)\\s+([A-Za-z_][A-Za-z0-9_]*)") {
                    items.append(FunctionItem(name: match.1, kind: match.0, lineNumber: index + 1, characterOffset: currentOffset))
                }

            case .markdown:
                if trimmed.hasPrefix("#") {
                    let level = trimmed.prefix(while: { $0 == "#" }).count
                    let title = trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        items.append(FunctionItem(name: title, kind: "H\(level)", lineNumber: index + 1, characterOffset: currentOffset))
                    }
                }

            case .ini, .yaml:
                if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                    items.append(FunctionItem(name: trimmed, kind: "Section", lineNumber: index + 1, characterOffset: currentOffset))
                }

            default:
                break
            }
        }
        return items
    }

    private func firstMatch(in text: String, pattern: String, options: NSRegularExpression.Options = []) -> (String, String)? {
        guard let regex = cachedRegex(pattern, options: options) else { return nil }
        let ns = text as NSString
        guard let res = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
              res.numberOfRanges >= 2 else { return nil }
        let r1 = res.range(at: 1)
        guard r1.location != NSNotFound, NSMaxRange(r1) <= ns.length else { return nil }
        let g1 = ns.substring(with: r1)

        var g2 = ""
        if res.numberOfRanges >= 3 {
            let r2 = res.range(at: 2)
            if r2.location != NSNotFound && NSMaxRange(r2) <= ns.length {
                g2 = ns.substring(with: r2)
            }
        }
        return (g1, g2)
    }
}
