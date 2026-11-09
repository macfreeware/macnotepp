import AppKit
import SwiftUI

public struct LeftWorkspaceSidebarView: View {
    @ObservedObject var appState: AppState
    @State private var directoryFiles: [URL] = []
    @State private var filterText: String = ""

    public var body: some View {
        let _ = appState.languageRefreshTrigger
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "folder.fill.badge.gearshape")
                    .foregroundStyle(.orange)
                Text(appState.loc("ÇALIŞMA ALANI", "WORKSPACE"))
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Button {
                    appState.openWorkspaceFolderPanel()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .buttonStyle(.plain)
                .help(appState.loc("Klasör Seç (Folder as Workspace)", "Select Workspace Folder"))

                Button {
                    refreshFolderFiles()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help(appState.loc("Listeyi Yenile", "Refresh List"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Open Documents Section
            VStack(alignment: .leading, spacing: 2) {
                Text("\(appState.loc("AÇIK SEKMELER", "OPEN TABS")) (\(appState.tabs.count))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                ForEach(appState.tabs) { tab in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(tab.isModified ? Color.red : Color.blue)
                            .frame(width: 6, height: 6)
                        Text(tab.displayTitle)
                            .font(.system(size: 11, weight: tab.id == appState.activeTabId ? .bold : .regular))
                            .lineLimit(1)
                        Spacer()
                        Text(tab.language.defaultExtension.uppercased())
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(tab.id == appState.activeTabId ? Color.accentColor.opacity(0.18) : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.activeTabId = tab.id
                    }
                }
            }
            .padding(.bottom, 6)

            Divider()

            // Folder as Workspace Section
            if let folder = appState.workspaceFolderURL {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 10))
                        Text(folder.lastPathComponent)
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                    TextField(appState.loc("Dosya filtrele...", "Filter files..."), text: $filterText)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .padding(.horizontal, 8)

                    List {
                        ForEach(filteredDirectoryFiles, id: \.self) { url in
                            Button {
                                appState.openFile(url: url)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: iconForFile(url))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.blue)
                                    Text(url.lastPathComponent)
                                        .font(.system(size: 11))
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(appState.loc("Aç (Open)", "Open")) {
                                    appState.openFile(url: url)
                                }
                                Button(appState.loc("Finder'da Göster", "Show in Finder")) {
                                    NSWorkspace.shared.activateFileViewerSelecting([url])
                                }
                                Button(appState.loc("Tam Dosya Yolunu Kopyala", "Copy Full Path")) {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(url.path, forType: .string)
                                }
                                Button(appState.loc("Dosya Adını Kopyala", "Copy File Name")) {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(url.lastPathComponent, forType: .string)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                    Text(appState.loc("Klasör Çalışma Alanı", "Workspace Folder"))
                        .font(.system(size: 12, weight: .semibold))
                    Text(appState.loc("Bir proje klasörünü yan panelde gezmek için klasör açın.", "Open a folder to explore project files in this sidebar."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                    Button(appState.loc("Klasör Aç...", "Open Folder...")) {
                        appState.openWorkspaceFolderPanel()
                    }
                    .controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 215)
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            refreshFolderFiles()
        }
        .onChange(of: appState.workspaceFolderURL) { _, _ in
            refreshFolderFiles()
        }
    }

    private var filteredDirectoryFiles: [URL] {
        if filterText.isEmpty { return directoryFiles }
        return directoryFiles.filter { $0.lastPathComponent.localizedCaseInsensitiveContains(filterText) }
    }

    private func refreshFolderFiles() {
        guard let root = appState.workspaceFolderURL else {
            directoryFiles = []
            return
        }
        var found: [URL] = []
        if let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let fileURL as URL in enumerator {
                if let vals = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]), vals.isRegularFile == true {
                    found.append(fileURL)
                    if found.count >= 400 { break }
                }
            }
        }
        directoryFiles = found.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func iconForFile(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pas", "dpr", "c", "cpp", "h", "swift", "py", "js", "ts", "rs", "go", "java", "cs":
            return "chevron.left.forwardslash.chevron.right"
        case "sql":
            return "cylinder.split.1x2"
        case "json", "xml", "yaml", "yml", "ini":
            return "gearshape.2"
        default:
            return "doc.text"
        }
    }
}

public struct RightInspectorSidebarView: View {
    @ObservedObject var appState: AppState
    @State private var functionFilter: String = ""

    public var body: some View {
        let _ = appState.languageRefreshTrigger
        VStack(spacing: 0) {
            // Custom Compact Tab Bar that fits cleanly inside the sidebar
            HStack(spacing: 4) {
                SidebarTabButton(
                    title: appState.loc("Fonksiyon", "Functions"),
                    icon: "function",
                    isSelected: appState.rightSidebarTab == .functionList
                ) {
                    appState.rightSidebarTab = .functionList
                }

                SidebarTabButton(
                    title: appState.loc("Yer İmleri", "Bookmarks"),
                    icon: "bookmark.fill",
                    isSelected: appState.rightSidebarTab == .bookmarks
                ) {
                    appState.rightSidebarTab = .bookmarks
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            switch appState.rightSidebarTab {
            case .functionList:
                functionListView
            case .bookmarks:
                bookmarksListView
            }
        }
        .frame(width: appState.rightSidebarWidth)
        .clipped()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var functionListView: some View {
        let doc = appState.activeDocument
        let functions = doc.map {
            SyntaxHighlighter.shared.extractFunctions(from: $0.content, language: $0.language)
        } ?? []
        let filtered = functionFilter.isEmpty
            ? functions
            : functions.filter { $0.name.localizedCaseInsensitiveContains(functionFilter) }

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "function")
                    .foregroundStyle(.blue)
                Text(appState.loc("FONKSİYON LİSTESİ (\(filtered.count))", "FUNCTION LIST (\(filtered.count))"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)

            TextField(appState.loc("Fonksiyon / Prosedür ara...", "Search functions..."), text: $functionFilter)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

            Divider()

            if filtered.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "curlybraces")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                    Text(appState.loc("Sembol bulunamadı", "No symbols found"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(appState.loc("C/C++, Pascal, SQL, Python, Swift, JS vb. dosyalardaki fonksiyonlar burada listelenir.", "Functions, procedures, and classes are listed here."))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(filtered) { item in
                    Button {
                        appState.jumpToLine(item.lineNumber)
                    } label: {
                        HStack(spacing: 6) {
                            Text(item.kind)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(RoundedRectangle(cornerRadius: 3).fill(Color.blue.opacity(0.16)))
                                .foregroundStyle(.blue)

                            Text(item.name)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .lineLimit(1)

                            Spacer()

                            Text(":\(item.lineNumber)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
    }

    private var bookmarksListView: some View {
        let doc = appState.activeDocument
        let sortedBookmarks = doc?.bookmarks.sorted() ?? []

        return VStack(alignment: .leading, spacing: 0) {
            // Bookmarks Header
            HStack {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.cyan)
                Text("\(appState.loc("YER İMLERİ", "BOOKMARKS")) (\(sortedBookmarks.count))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !sortedBookmarks.isEmpty {
                    Button(appState.loc("Tümünü Temizle", "Clear All")) {
                        appState.clearAllBookmarks()
                    }
                    .controlSize(.mini)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            if sortedBookmarks.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "bookmark")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(appState.loc("Henüz yer imi eklenmedi.", "No bookmarks added yet."))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(appState.loc("Satır numarası şeridine tıklayarak veya F2 ile yer imi koyabilirsiniz.", "Click line numbers gutter or press F2 to bookmark lines."))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(sortedBookmarks, id: \.self) { lineNum in
                            let preview = getBookmarkLinePreview(lineNum: lineNum, in: doc?.content ?? "")
                            Button {
                                appState.jumpToLine(lineNum)
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.cyan)
                                        .frame(width: 8, height: 8)

                                    Text("\(appState.loc("Satır", "Line")) \(lineNum):")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.primary)

                                    Text(preview.isEmpty ? (appState.loc("(Boş satır)", "(Empty line)")) : preview)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)

                                    Spacer()

                                    Image(systemName: "arrow.right.circle")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary.opacity(0.7))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(appState.loc("Bu Satıra Git", "Jump to this Line")) {
                                    appState.jumpToLine(lineNum)
                                }
                                Button(appState.loc("Yer İmini Kaldır", "Remove Bookmark")) {
                                    if var doc = appState.activeDocument {
                                        doc.bookmarks.remove(lineNum)
                                        appState.activeDocument = doc
                                    }
                                }
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    private func getBookmarkLinePreview(lineNum: Int, in content: String) -> String {
        guard !content.isEmpty && lineNum >= 1 else { return "" }
        let ns = content as NSString
        var current = 1
        var lineStart = 0
        let maxSearch = min(ns.length, 1_000_000)
        for i in 0..<maxSearch {
            if ns.character(at: i) == 10 {
                if current == lineNum {
                    let r = NSRange(location: lineStart, length: min(i - lineStart, 100))
                    return ns.substring(with: r).trimmingCharacters(in: .whitespaces)
                }
                current += 1
                lineStart = i + 1
                if current > lineNum { break }
            }
        }
        if current == lineNum && lineStart < ns.length {
            let r = NSRange(location: lineStart, length: min(ns.length - lineStart, 100))
            return ns.substring(with: r).trimmingCharacters(in: .whitespaces)
        }
        return ""
    }
}

private struct SidebarTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

/// AppKit tabanlı, titreşimsiz, 120Hz ekran hassasiyetinde dikey bölücü (Splitter Handle NSView)
public final class SplitterHandleNSView: NSView {
    public var onDelta: ((CGFloat) -> Void)?
    public var onDragEnd: (() -> Void)?
    private var initialMouseScreenX: CGFloat = 0.0
    private var isDragging = false
    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    public override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    public override func mouseExited(with event: NSEvent) {
        if !isDragging {
            isHovered = false
            needsDisplay = true
        }
    }

    public override func mouseDown(with event: NSEvent) {
        isDragging = true
        isHovered = true
        initialMouseScreenX = NSEvent.mouseLocation.x
        needsDisplay = true
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let currentMouseScreenX = NSEvent.mouseLocation.x
        let deltaX = currentMouseScreenX - initialMouseScreenX
        initialMouseScreenX = currentMouseScreenX
        onDelta?(deltaX)
    }

    public override func mouseUp(with event: NSEvent) {
        isDragging = false
        isHovered = false
        needsDisplay = true
        onDragEnd?()
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isHovered || isDragging {
            NSColor.controlAccentColor.setFill()
            let barRect = NSRect(x: (bounds.width - 2) / 2, y: 0, width: 2, height: bounds.height)
            barRect.fill()
        } else {
            NSColor.separatorColor.withAlphaComponent(0.6).setFill()
            let barRect = NSRect(x: (bounds.width - 1) / 2, y: 0, width: 1, height: bounds.height)
            barRect.fill()
        }
    }
}

/// SwiftUI Sarmalayıcısı: Titreşimsiz, kesintisiz ve akıcı panel genişletme/daraltma sürgüsü
public struct SidebarResizeHandle: View {
    @ObservedObject var appState: AppState
    let minWidth: CGFloat
    let maxWidth: CGFloat

    public init(appState: AppState, minWidth: CGFloat = 160, maxWidth: CGFloat = 600) {
        self.appState = appState
        self.minWidth = minWidth
        self.maxWidth = maxWidth
    }

    public var body: some View {
        SidebarResizeHandleRepresentable(appState: appState, minWidth: minWidth, maxWidth: maxWidth)
            .frame(width: 6)
            .frame(maxHeight: .infinity)
    }
}

private struct SidebarResizeHandleRepresentable: NSViewRepresentable {
    @ObservedObject var appState: AppState
    let minWidth: CGFloat
    let maxWidth: CGFloat

    func makeNSView(context: Context) -> SplitterHandleNSView {
        let view = SplitterHandleNSView()
        view.onDelta = { [weak appState] deltaX in
            guard let appState = appState else { return }
            let newWidth = appState.rightSidebarWidth - deltaX
            appState.rightSidebarWidth = max(minWidth, min(maxWidth, newWidth))
        }
        view.onDragEnd = { [weak appState] in
            appState?.saveRightSidebarWidth()
        }
        return view
    }

    func updateNSView(_ nsView: SplitterHandleNSView, context: Context) {
        nsView.onDelta = { [weak appState] deltaX in
            guard let appState = appState else { return }
            let newWidth = appState.rightSidebarWidth - deltaX
            appState.rightSidebarWidth = max(minWidth, min(maxWidth, newWidth))
        }
        nsView.onDragEnd = { [weak appState] in
            appState?.saveRightSidebarWidth()
        }
    }
}
