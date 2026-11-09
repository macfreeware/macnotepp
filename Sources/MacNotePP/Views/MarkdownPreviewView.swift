import AppKit
import SwiftUI

public enum MarkdownDisplayMode: String, Codable, CaseIterable, Identifiable {
    case split = "Bölünmüş"
    case previewOnly = "Önizleme"
    case sourceOnly = "Kaynak Kod"

    public var id: String { rawValue }

    public func title(for language: AppLanguage) -> String {
        guard language.resolvedLanguage != .turkish else { return rawValue }
        switch self {
        case .split: return "Split"
        case .previewOnly: return "Preview"
        case .sourceOnly: return "Source"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "Bölünmüş (Kod + Önizleme)", "Bölünmüş", "split":
            self = .split
        case "Tam Önizleme (Okuma Modu)", "Önizleme", "previewOnly":
            self = .previewOnly
        case "Sadece Kaynak Kod", "Kaynak Kod", "sourceOnly":
            self = .sourceOnly
        default:
            self = .split
        }
    }
}

public struct MarkdownHeaderBar: View {
    @ObservedObject var appState: AppState
    let document: EditorDocument

    public init(appState: AppState, document: EditorDocument) {
        self.appState = appState
        self.document = document
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext.fill")
                .foregroundStyle(.blue)
                .font(.system(size: 13))

            Text(appState.loc("MARKDOWN ÖNİZLEME — \(document.displayTitle)", "MARKDOWN PREVIEW — \(document.displayTitle)"))
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)

            Spacer()

            Picker("", selection: $appState.markdownDisplayMode) {
                ForEach(MarkdownDisplayMode.allCases) { m in
                    Text(m.title(for: appState.language)).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 250)

            Button {
                appState.showMarkdownPreview = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(appState.loc("Markdown Önizlemeyi Kapat", "Close Markdown Preview"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

public struct MarkdownRenderedContentView: View {
    @ObservedObject var appState: AppState
    let document: EditorDocument

    public init(appState: AppState, document: EditorDocument) {
        self.appState = appState
        self.document = document
    }

    private var blocks: [MarkdownBlock] {
        MarkdownParser.parse(document.content)
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(blocks) { block in
                        MarkdownBlockView(
                            block: block,
                            isDark: appState.theme.isDark,
                            onToggleCheckbox: { lineIndex in
                                toggleCheckboxAtLine(lineIndex)
                            },
                            onJumpToLine: { lineIndex in
                                appState.jumpToLine(lineIndex)
                            }
                        )
                        .id(block.id)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: appState.theme.editorBackground))
        }
    }

    private func toggleCheckboxAtLine(_ lineNumber: Int) {
        guard var doc = appState.activeDocument, doc.id == document.id else { return }
        var lines = LineEndingType.normalizeToLF(doc.content).components(separatedBy: "\n")
        let idx = lineNumber - 1
        guard idx >= 0 && idx < lines.count else { return }
        if let range = lines[idx].range(of: "[ ]") {
            lines[idx].replaceSubrange(range, with: "[x]")
        } else if let range = lines[idx].range(of: "[x]") {
            lines[idx].replaceSubrange(range, with: "[ ]")
        } else if let range = lines[idx].range(of: "[X]") {
            lines[idx].replaceSubrange(range, with: "[ ]")
        }
        doc.applyContentMutation(lines.joined(separator: "\n"))
        appState.activeDocument = doc
        appState.saveSession()
    }
}

public struct MarkdownPreviewView: View {
    @ObservedObject var appState: AppState
    let document: EditorDocument

    public init(appState: AppState, document: EditorDocument) {
        self.appState = appState
        self.document = document
    }

    public var body: some View {
        VStack(spacing: 0) {
            MarkdownHeaderBar(appState: appState, document: document)
            Divider()
            MarkdownRenderedContentView(appState: appState, document: document)
        }
    }
}

// MARK: - Structured Markdown AST & Parser
public struct MarkdownBlock: Identifiable {
    public let id = UUID()
    public let lineNumber: Int
    public let kind: Kind

    public enum Kind {
        case heading(level: Int, text: String)
        case paragraph(text: String)
        case codeBlock(language: String, code: String)
        case blockquote(alertType: String?, lines: [String])
        case unorderedList(items: [(line: Int, indent: Int, text: String)])
        case orderedList(items: [(line: Int, number: Int, text: String)])
        case taskList(items: [(line: Int, checked: Bool, text: String)])
        case table(headers: [String], rows: [[String]])
        case horizontalRule
    }
}

public enum MarkdownParser {
    public static func parse(_ rawText: String) -> [MarkdownBlock] {
        let lines = LineEndingType.normalizeToLF(rawText).components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var i = 0
        let count = lines.count

        while i < count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 1. Empty line
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // 2. Fenced Code Block ```
            if trimmed.hasPrefix("```") {
                let startLine = i + 1
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                i += 1
                var codeLines: [String] = []
                while i < count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                if i < count { i += 1 } // skip closing ```
                blocks.append(MarkdownBlock(lineNumber: startLine, kind: .codeBlock(language: lang, code: codeLines.joined(separator: "\n"))))
                continue
            }

            // 3. Horizontal Rule (---, ***, ___)
            if (trimmed == "---" || trimmed == "***" || trimmed == "___") ||
                (trimmed.count >= 3 && (trimmed.allSatisfy { $0 == "-" } || trimmed.allSatisfy { $0 == "*" })) {
                blocks.append(MarkdownBlock(lineNumber: i + 1, kind: .horizontalRule))
                i += 1
                continue
            }

            // 4. Heading (# .. ######)
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix(while: { $0 == "#" })
                let level = hashes.count
                if level >= 1 && level <= 6 {
                    let rest = trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces)
                    blocks.append(MarkdownBlock(lineNumber: i + 1, kind: .heading(level: level, text: rest)))
                    i += 1
                    continue
                }
            }

            // 5. GFM Table (| col1 | col2 |)
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && i + 1 < count {
                let nextTrimmed = lines[i + 1].trimmingCharacters(in: .whitespaces)
                if nextTrimmed.hasPrefix("|") && nextTrimmed.contains("-") {
                    let startLine = i + 1
                    let headers = parseTableRow(trimmed)
                    i += 2 // skip header and separator row
                    var rows: [[String]] = []
                    while i < count {
                        let rowStr = lines[i].trimmingCharacters(in: .whitespaces)
                        if rowStr.hasPrefix("|") {
                            rows.append(parseTableRow(rowStr))
                            i += 1
                        } else {
                            break
                        }
                    }
                    blocks.append(MarkdownBlock(lineNumber: startLine, kind: .table(headers: headers, rows: rows)))
                    continue
                }
            }

            // 6. Blockquote / GitHub Alert (> ...)
            if trimmed.hasPrefix(">") {
                let startLine = i + 1
                var quoteLines: [String] = []
                while i < count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix(">") {
                        let content = String(t.dropFirst()).trimmingCharacters(in: .whitespaces)
                        quoteLines.append(content)
                        i += 1
                    } else {
                        break
                    }
                }
                var alertType: String? = nil
                if let first = quoteLines.first, first.hasPrefix("[!") && first.contains("]") {
                    if let closeIdx = first.firstIndex(of: "]") {
                        alertType = String(first[first.index(first.startIndex, offsetBy: 2)..<closeIdx]).uppercased()
                        let remainder = String(first[first.index(after: closeIdx)...]).trimmingCharacters(in: .whitespaces)
                        if remainder.isEmpty {
                            quoteLines.removeFirst()
                        } else {
                            quoteLines[0] = remainder
                        }
                    }
                }
                blocks.append(MarkdownBlock(lineNumber: startLine, kind: .blockquote(alertType: alertType, lines: quoteLines)))
                continue
            }

            // 7. Task List (- [ ] or - [x])
            if isTaskListLine(trimmed) != nil {
                let startLine = i + 1
                var items: [(line: Int, checked: Bool, text: String)] = []
                while i < count, let parsed = isTaskListLine(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append((line: i + 1, checked: parsed.checked, text: parsed.text))
                    i += 1
                }
                blocks.append(MarkdownBlock(lineNumber: startLine, kind: .taskList(items: items)))
                continue
            }

            // 8. Unordered List (- , * , + )
            if isUnorderedListLine(line) != nil {
                let startLine = i + 1
                var items: [(line: Int, indent: Int, text: String)] = []
                while i < count, let parsed = isUnorderedListLine(lines[i]) {
                    items.append((line: i + 1, indent: parsed.indent, text: parsed.text))
                    i += 1
                }
                blocks.append(MarkdownBlock(lineNumber: startLine, kind: .unorderedList(items: items)))
                continue
            }

            // 9. Ordered List (1. , 2. )
            if isOrderedListLine(trimmed) != nil {
                let startLine = i + 1
                var items: [(line: Int, number: Int, text: String)] = []
                while i < count, let parsed = isOrderedListLine(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append((line: i + 1, number: parsed.number, text: parsed.text))
                    i += 1
                }
                blocks.append(MarkdownBlock(lineNumber: startLine, kind: .orderedList(items: items)))
                continue
            }

            // 10. Standard Paragraph
            let startLine = i + 1
            var paraLines: [String] = [trimmed]
            i += 1
            while i < count {
                let next = lines[i].trimmingCharacters(in: .whitespaces)
                if next.isEmpty || next.hasPrefix("#") || next.hasPrefix("```") || next.hasPrefix(">") || next.hasPrefix("|") || isUnorderedListLine(lines[i]) != nil || isOrderedListLine(next) != nil {
                    break
                }
                paraLines.append(next)
                i += 1
            }
            blocks.append(MarkdownBlock(lineNumber: startLine, kind: .paragraph(text: paraLines.joined(separator: " "))))
        }

        return blocks
    }

    private static func parseTableRow(_ row: String) -> [String] {
        var s = row
        if s.hasPrefix("|") { s.removeFirst() }
        if s.hasSuffix("|") { s.removeLast() }
        return s.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func isTaskListLine(_ trimmed: String) -> (checked: Bool, text: String)? {
        let prefixes = ["- [ ] ", "* [ ] ", "+ [ ] ", "- [x] ", "* [x] ", "+ [x] ", "- [X] ", "* [X] ", "+ [X] "]
        for p in prefixes {
            if trimmed.hasPrefix(p) {
                let checked = p.contains("x") || p.contains("X")
                let text = String(trimmed.dropFirst(p.count))
                return (checked, text)
            }
        }
        return nil
    }

    private static func isUnorderedListLine(_ rawLine: String) -> (indent: Int, text: String)? {
        let leadingSpaces = rawLine.prefix(while: { $0 == " " || $0 == "\t" }).count
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        for prefix in ["- ", "* ", "+ "] {
            if trimmed.hasPrefix(prefix) && isTaskListLine(trimmed) == nil {
                return (leadingSpaces / 2, String(trimmed.dropFirst(prefix.count)))
            }
        }
        return nil
    }

    private static func isOrderedListLine(_ trimmed: String) -> (number: Int, text: String)? {
        guard let dotIdx = trimmed.firstIndex(of: ".") else { return nil }
        let numStr = String(trimmed[..<dotIdx])
        guard let num = Int(numStr) else { return nil }
        let afterDot = trimmed.index(after: dotIdx)
        guard afterDot < trimmed.endIndex && trimmed[afterDot] == " " else { return nil }
        let text = String(trimmed[trimmed.index(after: afterDot)...]).trimmingCharacters(in: .whitespaces)
        return (num, text)
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock
    let isDark: Bool
    let onToggleCheckbox: (Int) -> Void
    let onJumpToLine: (Int) -> Void

    @State private var copiedCode = false

    var body: some View {
        switch block.kind {
        case .heading(let level, let text):
            VStack(alignment: .leading, spacing: 6) {
                inlineMarkdownText(text)
                    .font(.system(size: headingSize(level), weight: .bold))
                    .foregroundStyle(headingColor(level))
                    .onTapGesture(count: 2) {
                        onJumpToLine(block.lineNumber)
                    }
                if level <= 2 {
                    Divider()
                }
            }
            .padding(.top, level == 1 ? 8 : 4)

        case .paragraph(let text):
            inlineMarkdownText(text)
                .font(.system(size: 13.5))
                .lineSpacing(4)
                .textSelection(.enabled)

        case .codeBlock(let language, let code):
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "terminal")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(language.isEmpty ? "CODE" : language.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                        copiedCode = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copiedCode = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: copiedCode ? "checkmark" : "doc.on.doc")
                            Text(copiedCode ? UpdateChecker.loc("Kopyalandı", "Copied") : UpdateChecker.loc("Kopyala", "Copy"))
                        }
                        .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(copiedCode ? .green : .blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(isDark ? 0.22 : 0.14))

                Divider()

                ScrollView(.horizontal, showsIndicators: true) {
                    Text(code)
                        .font(.system(size: 12.5, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.secondary.opacity(isDark ? 0.12 : 0.06))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )

        case .blockquote(let alertType, let lines):
            let color = alertColor(alertType)
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 4) {
                    if let alert = alertType {
                        HStack(spacing: 5) {
                            Image(systemName: alertIcon(alert))
                            Text(alert)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(color)
                    }
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        inlineMarkdownText(line)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary.opacity(0.88))
                    }
                }
                .padding(.vertical, 6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.10)))

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(item.indent > 0 ? "◦" : "•")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.blue)
                            .padding(.leading, CGFloat(item.indent) * 16)
                        inlineMarkdownText(item.text)
                            .font(.system(size: 13.5))
                            .textSelection(.enabled)
                    }
                }
            }

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(item.number).")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                            .frame(width: 24, alignment: .trailing)
                        inlineMarkdownText(item.text)
                            .font(.system(size: 13.5))
                            .textSelection(.enabled)
                    }
                }
            }

        case .taskList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Button {
                        onToggleCheckbox(item.line)
                    } label: {
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: item.checked ? "checkmark.square.fill" : "square")
                                .font(.system(size: 14))
                                .foregroundStyle(item.checked ? .green : .secondary)
                            inlineMarkdownText(item.text)
                                .font(.system(size: 13.5))
                                .strikethrough(item.checked, color: .secondary)
                                .foregroundStyle(item.checked ? .secondary : .primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

        case .table(let headers, let rows):
            VStack(spacing: 0) {
                // Header Row
                HStack(spacing: 0) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, h in
                        inlineMarkdownText(h)
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                }
                .background(Color.secondary.opacity(isDark ? 0.25 : 0.15))

                Divider()

                ForEach(Array(rows.enumerated()), id: \.offset) { rIdx, row in
                    HStack(spacing: 0) {
                        ForEach(0..<headers.count, id: \.self) { cIdx in
                            let cellText = cIdx < row.count ? row[cIdx] : ""
                            inlineMarkdownText(cellText)
                                .font(.system(size: 12))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        }
                    }
                    .background(rIdx % 2 == 1 ? Color.secondary.opacity(0.06) : Color.clear)
                    if rIdx < rows.count - 1 {
                        Divider().opacity(0.4)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.secondary.opacity(0.28), lineWidth: 1)
            )

        case .horizontalRule:
            Divider()
                .padding(.vertical, 6)
        }
    }

    private func inlineMarkdownText(_ raw: String) -> Text {
        if let attr = try? AttributedString(
            markdown: raw,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attr)
        }
        return Text(raw)
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 23
        case 2: return 19
        case 3: return 16
        case 4: return 14.5
        default: return 13.5
        }
    }

    private func headingColor(_ level: Int) -> Color {
        switch level {
        case 1: return .primary
        case 2: return .blue
        case 3: return .orange
        default: return .primary
        }
    }

    private func alertColor(_ type: String?) -> Color {
        switch type {
        case "NOTE": return .blue
        case "TIP": return .green
        case "IMPORTANT": return .purple
        case "WARNING": return .orange
        case "CAUTION": return .red
        default: return .secondary
        }
    }

    private func alertIcon(_ type: String) -> String {
        switch type {
        case "NOTE": return "info.circle.fill"
        case "TIP": return "lightbulb.fill"
        case "IMPORTANT": return "exclamationmark.bubble.fill"
        case "WARNING": return "exclamationmark.triangle.fill"
        case "CAUTION": return "flame.fill"
        default: return "quote.opening"
        }
    }
}
