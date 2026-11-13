import Foundation

public enum DocumentViewMode: String, Codable, CaseIterable {
    case text = "Metin (Text)"
    case hex = "Hex Görünümü (Hex)"
}

public enum ShortcutScheme: String, Codable, CaseIterable, Identifiable {
    case hybrid = "Hibrit (Mac ⌘ + Win Ctrl)"
    case windowsNPP = "Windows (Ctrl)"
    case macStandard = "macOS Standart (⌘ Cmd)"

    public var id: String { rawValue }

    public func title(for lang: AppLanguage) -> String {
        let isTr = lang.resolvedLanguage == .turkish
        switch self {
        case .hybrid: return isTr ? "Hibrit (Mac ⌘ + Win Ctrl)" : "Hybrid (Mac ⌘ + Win Ctrl)"
        case .windowsNPP: return "Windows (Ctrl)"
        case .macStandard: return isTr ? "macOS Standart (⌘ Cmd)" : "macOS Standard (⌘ Cmd)"
        }
    }
}

public struct DocumentSnapshot: Equatable {
    public let content: String
    public let cursorOffset: Int
    public let timestamp: Date

    public init(content: String, cursorOffset: Int, timestamp: Date = Date()) {
        self.content = content
        self.cursorOffset = cursorOffset
        self.timestamp = timestamp
    }
}

public struct EditorDocument: Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var fileURL: URL?
    public var content: String {
        didSet { lineCount = LineCountCache() }
    }
    /// Counting lines walks the whole text, and the status bar asks on every update.
    private var lineCount = LineCountCache()
    public var rawData: Data?
    public var isModified: Bool
    public var isPinned: Bool
    public var isReadOnly: Bool
    public var isPartialPreview: Bool
    public var totalFileSize: Int64?
    public var language: SyntaxLanguage
    public var isLanguageManuallySet: Bool
    public var encoding: TextEncodingOption
    public var lineEnding: LineEndingType
    public var viewMode: DocumentViewMode
    /// Markdown preview belongs to the tab, like hex view, so another file does not inherit it.
    public var showsMarkdownPreview = false
    public var markdownDisplayMode: MarkdownDisplayMode? = nil
    /// Where the text was scrolled to when the tab was last shown.
    public var scrollOffsetY: CGFloat = 0
    public var bookmarks: Set<Int> // 1-based line numbers
    public var markedRanges: [NSRange]
    public var cursorLine: Int
    public var cursorColumn: Int
    public var cursorOffset: Int
    public var selectionLength: Int
    public var selectedLineCount: Int
    public var visibleStartLine: Int = 1
    public var visibleEndLine: Int = 30
    public var lastSavedDate: Date?
    public var undoStack: [DocumentSnapshot] = []
    public var redoStack: [DocumentSnapshot] = []

    public init(
        id: UUID = UUID(),
        title: String = "new 1",
        fileURL: URL? = nil,
        content: String = "",
        rawData: Data? = nil,
        isModified: Bool = false,
        isPinned: Bool = false,
        isReadOnly: Bool = false,
        isPartialPreview: Bool = false,
        totalFileSize: Int64? = nil,
        language: SyntaxLanguage = .plainText,
        isLanguageManuallySet: Bool = false,
        encoding: TextEncodingOption = .utf8,
        lineEnding: LineEndingType = .lf,
        viewMode: DocumentViewMode = .text,
        bookmarks: Set<Int> = [],
        markedRanges: [NSRange] = [],
        cursorLine: Int = 1,
        cursorColumn: Int = 1,
        cursorOffset: Int = 0,
        selectionLength: Int = 0,
        selectedLineCount: Int = 0,
        lastSavedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.fileURL = fileURL
        self.content = content
        self.rawData = rawData
        self.isModified = isModified
        self.isPinned = isPinned
        self.isReadOnly = isReadOnly
        self.isPartialPreview = isPartialPreview
        self.totalFileSize = totalFileSize
        self.language = language
        self.isLanguageManuallySet = isLanguageManuallySet
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.viewMode = viewMode
        self.bookmarks = bookmarks
        self.markedRanges = markedRanges
        self.cursorLine = cursorLine
        self.cursorColumn = cursorColumn
        self.cursorOffset = cursorOffset
        self.selectionLength = selectionLength
        self.selectedLineCount = selectedLineCount
        self.lastSavedDate = lastSavedDate
    }

    public var displayTitle: String {
        if let url = fileURL {
            return url.lastPathComponent
        }
        return title
    }

    public var formattedTotalSize: String {
        guard let size = totalFileSize else { return "" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    public var totalLines: Int {
        if let known = lineCount.value { return known }
        var count = 1
        for byte in content.utf8 where byte == 10 { count += 1 }
        lineCount.value = count
        return count
    }

    public var byteLength: Int {
        if let raw = rawData, viewMode == .hex {
            return raw.count
        }
        return content.utf8.count
    }

    public mutating func recordUndoSnapshot(oldContent: String, oldCursorOffset: Int, coalesceTyping: Bool = false) {
        guard !isReadOnly else { return }
        // For massive files (> 20 MB), avoid duplicating 500 MB in memory undo stacks
        guard content.utf8.count <= 20 * 1024 * 1024 else { return }
        guard oldContent != content else { return }
        let now = Date()
        if coalesceTyping, let last = undoStack.last {
            // If user is typing characters rapidly within 0.45s and length diff is small, keep the start-of-burst snapshot
            let timeDelta = now.timeIntervalSince(last.timestamp)
            let lenDelta = abs(oldContent.utf16.count - last.content.utf16.count)
            if timeDelta < 0.45 && lenDelta < 15 && !oldContent.hasSuffix("\n") {
                redoStack.removeAll()
                return
            }
        }
        undoStack.append(DocumentSnapshot(content: oldContent, cursorOffset: oldCursorOffset, timestamp: now))
        if undoStack.count > 150 {
            undoStack.removeFirst(undoStack.count - 150)
        }
        redoStack.removeAll()
    }

    public mutating func applyContentMutation(_ newContent: String, newCursorOffset: Int? = nil, coalesceTyping: Bool = false) {
        guard !isReadOnly else { return }
        guard newContent != self.content else { return }
        let prevContent = self.content
        let prevCursor = self.cursorOffset
        self.content = newContent
        if let newCursor = newCursorOffset {
            self.cursorOffset = newCursor
        }
        recordUndoSnapshot(oldContent: prevContent, oldCursorOffset: prevCursor, coalesceTyping: coalesceTyping)
        syncBytesFromText()
        self.isModified = true
    }

    public mutating func undo() -> Int? {
        guard !isReadOnly else { return nil }
        guard let snapshot = undoStack.popLast() else { return nil }
        redoStack.append(DocumentSnapshot(content: self.content, cursorOffset: self.cursorOffset, timestamp: Date()))
        self.content = snapshot.content
        self.cursorOffset = snapshot.cursorOffset
        syncBytesFromText()
        self.isModified = true
        return snapshot.cursorOffset
    }

    public mutating func redo() -> Int? {
        guard !isReadOnly else { return nil }
        guard let snapshot = redoStack.popLast() else { return nil }
        undoStack.append(DocumentSnapshot(content: self.content, cursorOffset: self.cursorOffset, timestamp: Date()))
        self.content = snapshot.content
        self.cursorOffset = snapshot.cursorOffset
        syncBytesFromText()
        self.isModified = true
        return snapshot.cursorOffset
    }

    public mutating func syncBytesFromText() {
        // Protect RAM on massive files (> 20 MB)
        guard content.utf8.count <= 20 * 1024 * 1024 else {
            self.rawData = nil
            return
        }
        self.rawData = encoding.encode(text: content, lineEnding: lineEnding)
    }

    public mutating func updateByte(at index: Int, value: UInt8) {
        guard !isPartialPreview else { return }
        if rawData == nil {
            syncBytesFromText()
        }
        guard var data = rawData, index >= 0 && index < data.count else { return }
        let prevContent = self.content
        let prevCursor = self.cursorOffset
        data[index] = value
        self.rawData = data
        let decoded = TextEncodingOption.decode(data: data)
        self.content = decoded.text
        recordUndoSnapshot(oldContent: prevContent, oldCursorOffset: prevCursor, coalesceTyping: false)
        self.isModified = true
    }

    public mutating func insertByte(at index: Int, value: UInt8) {
        guard !isPartialPreview else { return }
        if rawData == nil {
            syncBytesFromText()
        }
        let prevContent = self.content
        let prevCursor = self.cursorOffset
        var data = rawData ?? Data()
        let clamped = max(0, min(index, data.count))
        data.insert(value, at: clamped)
        self.rawData = data
        let decoded = TextEncodingOption.decode(data: data)
        self.content = decoded.text
        recordUndoSnapshot(oldContent: prevContent, oldCursorOffset: prevCursor, coalesceTyping: false)
        self.isModified = true
    }

    public mutating func deleteBytes(in range: Range<Int>) {
        guard !isPartialPreview else { return }
        if rawData == nil {
            syncBytesFromText()
        }
        guard var data = rawData, range.lowerBound >= 0, range.upperBound <= data.count, !range.isEmpty else { return }
        let prevContent = self.content
        let prevCursor = self.cursorOffset
        data.removeSubrange(data.startIndex + range.lowerBound..<data.startIndex + range.upperBound)
        self.rawData = data
        self.content = TextEncodingOption.decode(data: data).text
        recordUndoSnapshot(oldContent: prevContent, oldCursorOffset: prevCursor, coalesceTyping: false)
        self.isModified = true
    }

    public mutating func deleteByte(at index: Int) {
        guard !isPartialPreview else { return }
        if rawData == nil {
            syncBytesFromText()
        }
        guard var data = rawData, index >= 0 && index < data.count else { return }
        let prevContent = self.content
        let prevCursor = self.cursorOffset
        data.remove(at: index)
        self.rawData = data
        let decoded = TextEncodingOption.decode(data: data)
        self.content = decoded.text
        recordUndoSnapshot(oldContent: prevContent, oldCursorOffset: prevCursor, coalesceTyping: false)
        self.isModified = true
    }
}

private final class LineCountCache: Equatable {
    var value: Int?

    /// Only a remembered answer, so it never makes two documents different.
    static func == (lhs: LineCountCache, rhs: LineCountCache) -> Bool { true }
}

public struct PersistedSessionTab: Codable {
    public let id: UUID
    public let title: String
    public let filePath: String?
    public let content: String
    public let isModified: Bool
    public let isPinned: Bool
    public let isReadOnly: Bool?
    public let isPartialPreview: Bool?
    public let totalFileSize: Int64?
    public let language: SyntaxLanguage
    public let isLanguageManuallySet: Bool
    public let encoding: TextEncodingOption
    public let lineEnding: LineEndingType
    public let viewMode: DocumentViewMode
    public let bookmarks: [Int]
    public let cursorLine: Int
    public let cursorColumn: Int
    public let cursorOffset: Int
    /// The file's date when the tab was last in step with it; only kept for unsaved tabs.
    public let lastSavedDate: Date?
    /// Exact bytes of an unsaved hex tab, which the text form cannot reproduce.
    public let unsavedBytes: Data?
    public let markdownPreview: Bool?
    public let markdownMode: MarkdownDisplayMode?
}

public struct PersistedSessionState: Codable {
    public let tabs: [PersistedSessionTab]
    public let activeTabId: UUID?
    public let theme: EditorTheme
    public let fontSize: Double
    public let wordWrap: Bool
    public let showInvisibleCharacters: Bool
    public let showLineNumbers: Bool
    public let workspaceFolderPath: String?
    public let showLeftWorkspaceSidebar: Bool?
    public let showRightSidebar: Bool?
    public let showMinimap: Bool?
    public let showSearchResultsDock: Bool?
}
