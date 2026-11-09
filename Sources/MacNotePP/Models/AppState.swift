import AppKit
import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

public enum ToolbarItemID: String, CaseIterable, Codable, Identifiable {
    case newTab = "newTab"
    case openFile = "openFile"
    case saveFile = "saveFile"
    case saveAll = "saveAll"
    case printDocument = "printDocument"
    case closeTab = "closeTab"
    case cutCopyPaste = "cutCopyPaste"
    case undoRedo = "undoRedo"
    case findReplace = "findReplace"
    case goToLine = "goToLine"
    case columnEditor = "columnEditor"
    case multiCaret = "multiCaret"
    case wordWrap = "wordWrap"
    case showInvisibles = "showInvisibles"
    case zoomControls = "zoomControls"
    case bookmarks = "bookmarks"
    case compareDiff = "compareDiff"
    case hexView = "hexView"
    case markdownPreview = "markdownPreview"
    case lineOperations = "lineOperations"
    case macros = "macros"
    case sidebarsAndPanels = "sidebarsAndPanels"
    case alwaysOnTop = "alwaysOnTop"
    case documentSummary = "documentSummary"
    case shortcutPicker = "shortcutPicker"
    case themePicker = "themePicker"
    case toolsMenu = "toolsMenu"

    public var id: String { rawValue }

    public var displayName: String {
        title(for: .turkish)
    }

    public func title(for lang: AppLanguage) -> String {
        let isTr = lang.resolvedLanguage == .turkish
        switch self {
        case .toolsMenu: return isTr ? "Hızlı Araçlar & İşlemler Menüsü (Gruplandırılmış)" : "Quick Tools & Operations Menu (Grouped)"
        case .newTab: return isTr ? "Yeni Sekme (⌘N)" : "New Tab (⌘N)"
        case .openFile: return isTr ? "Dosya Aç (⌘O)" : "Open File (⌘O)"
        case .saveFile: return isTr ? "Kaydet (⌘S)" : "Save (⌘S)"
        case .saveAll: return isTr ? "Tümünü Kaydet (⌥⌘S)" : "Save All (⌥⌘S)"
        case .printDocument: return isTr ? "Yazdır / Yazdırma Önizleme (⌘P)" : "Print / Print Preview (⌘P)"
        case .closeTab: return isTr ? "Aktif Sekmeyi Kapat (⌘W)" : "Close Active Tab (⌘W)"
        case .cutCopyPaste: return isTr ? "Kes / Kopyala / Yapıştır" : "Cut / Copy / Paste"
        case .undoRedo: return isTr ? "Geri Al / İleri Al (Undo / Redo)" : "Undo / Redo"
        case .findReplace: return isTr ? "Bul / Değiştir Penceresi (⌘F)" : "Find / Replace (⌘F)"
        case .goToLine: return isTr ? "Satıra / Ofsete Git (⌘G)" : "Go to Line / Offset (⌘G)"
        case .columnEditor: return isTr ? "Sütun Düzenleyici (Column Editor ⌥C)" : "Column Editor (⌥C)"
        case .multiCaret: return isTr ? "Çoklu İmleç (Multi-Cursor) Menüsü" : "Multi-Cursor Menu"
        case .wordWrap: return isTr ? "Sözcük Kaydırma (Word Wrap)" : "Word Wrap"
        case .showInvisibles: return isTr ? "Tüm Karakterleri Göster (¶)" : "Show All Characters (¶)"
        case .zoomControls: return isTr ? "Yakınlaştır / Uzaklaştır / %100" : "Zoom Controls (+ / - / 100%)"
        case .bookmarks: return isTr ? "Yer İmleri (Bookmark Ekle / Sonraki / Önceki)" : "Bookmarks (Toggle / Next / Prev)"
        case .compareDiff: return isTr ? "Karşılaştır (Diff) Butonu" : "Compare (Diff) Button"
        case .hexView: return isTr ? "Hex View Butonu" : "Hex View Button"
        case .markdownPreview: return isTr ? "MD Önizleme (Markdown) Butonu" : "Markdown Preview Button"
        case .lineOperations: return isTr ? "Satır İşlemleri Hızlı Menüsü" : "Line Operations Quick Menu"
        case .macros: return isTr ? "Makro Kayıt / Oynatma / Çoklu Çalıştırma" : "Macro Record / Playback / Run"
        case .sidebarsAndPanels: return isTr ? "Yan Paneller & Arama Sonuçları Alt Paneli" : "Sidebars & Search Results Dock"
        case .alwaysOnTop: return isTr ? "Pencereyi Her Zaman Üstte Tut (Pin)" : "Always on Top (Pin)"
        case .documentSummary: return isTr ? "Belge Özeti ve İstatistikler" : "Document Summary & Stats"
        case .shortcutPicker: return isTr ? "Klavye Kısayol Şeması Seçici (Win / Mac)" : "Keyboard Shortcut Scheme Picker"
        case .themePicker: return isTr ? "Editör Teması Seçici" : "Editor Theme Picker"
        }
    }

    public var iconName: String {
        switch self {
        case .newTab: return "doc.badge.plus"
        case .openFile: return "folder"
        case .saveFile: return "internaldrive"
        case .saveAll: return "externaldrive.badge.checkmark"
        case .printDocument: return "printer"
        case .closeTab: return "xmark.square"
        case .cutCopyPaste: return "scissors"
        case .undoRedo: return "arrow.uturn.backward"
        case .findReplace: return "magnifyingglass"
        case .goToLine: return "arrow.right.to.line"
        case .columnEditor: return "rectangle.split.3x1"
        case .multiCaret: return "cursorarrow.motionlines"
        case .wordWrap: return "text.word.spacing"
        case .showInvisibles: return "paragraphsign"
        case .zoomControls: return "plus.magnifyingglass"
        case .bookmarks: return "bookmark.fill"
        case .compareDiff: return "arrow.left.and.right.square.fill"
        case .hexView: return "00.square.fill"
        case .markdownPreview: return "doc.richtext.fill"
        case .lineOperations: return "arrow.up.arrow.down.square"
        case .macros: return "record.circle"
        case .sidebarsAndPanels: return "sidebar.left"
        case .alwaysOnTop: return "pin"
        case .documentSummary: return "chart.bar.doc.horizontal"
        case .shortcutPicker: return "keyboard"
        case .themePicker: return "paintpalette"
        case .toolsMenu: return "ellipsis.circle.fill"
        }
    }
}

@MainActor
public final class AppState: ObservableObject {
    // MARK: - Tabs & Active Document
    @Published public var tabs: [EditorDocument] = []
    @Published public var activeTabId: UUID? {
        didSet {
            // Automatically turn off Minimap on large files to prevent UI lag/freeze
            if let id = activeTabId, let doc = tabs.first(where: { $0.id == id }) {
                let isLarge = doc.byteLength >= 20 * 1024 * 1024 || (doc.totalFileSize ?? 0) >= 20 * 1024 * 1024 || doc.isPartialPreview
                if isLarge && showMinimap {
                    showMinimap = false
                }
            }
        }
    }
    @Published public var recentFiles: [URL] = []

    // MARK: - View & Editor Settings
    @Published public var theme: EditorTheme = .nppClassicLight {
        didSet { scheduleSaveSession() }
    }
    // MARK: - Language / Localization
    @Published public var languageRefreshTrigger: UUID = UUID()

    @Published public var appLanguage: AppLanguage = {
        if let raw = UserDefaults.standard.string(forKey: "MacNotePP.appLanguage"),
           let lang = AppLanguage(rawValue: raw) {
            return lang
        }
        return .system
    }() {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: "MacNotePP.appLanguage")
            languageRefreshTrigger = UUID()
            MainMenuLocalizationManager.shared.syncMenu(to: appLanguage)
            objectWillChange.send()
        }
    }

    public var language: AppLanguage {
        get { appLanguage }
        set { appLanguage = newValue }
    }

    public var isTurkish: Bool {
        appLanguage.resolvedLanguage == .turkish
    }

    /// The built-in macros carry their Turkish names; macros the user names stay as named.
    public func macroTitle(_ name: String) -> String {
        let english = [
            "Boşlukları Temizle ve Alfabetik Sırala": "Trim and Sort Alphabetically",
            "Tekrarlayan Satırları Sil ve Trim Yap": "Remove Duplicates and Trim"
        ]
        return loc(name, english[name] ?? name)
    }

    public func loc(_ tr: String, _ en: String) -> String {
        isTurkish ? tr : en
    }

    @Published public var shortcutScheme: ShortcutScheme = {
        if let raw = UserDefaults.standard.string(forKey: "MacNotePP.shortcutScheme"),
           let val = ShortcutScheme(rawValue: raw) {
            return val
        }
        return .hybrid
    }() {
        didSet {
            UserDefaults.standard.set(shortcutScheme.rawValue, forKey: "MacNotePP.shortcutScheme")
        }
    }
    @Published public var fontSize: Double = 13.0 {
        didSet { scheduleSaveSession() }
    }
    @Published public var wordWrap: Bool = false {
        didSet { scheduleSaveSession() }
    }
    @Published public var showInvisibleCharacters: Bool = false {
        didSet { scheduleSaveSession() }
    }
    @Published public var showLineNumbers: Bool = true {
        didSet { scheduleSaveSession() }
    }
    @Published public var isAlwaysOnTop: Bool = false {
        didSet { applyAlwaysOnTop() }
    }
    @Published public var enableScrollWheelZoom: Bool = {
        if UserDefaults.standard.object(forKey: "MacNotePP.enableScrollWheelZoom") != nil {
            return UserDefaults.standard.bool(forKey: "MacNotePP.enableScrollWheelZoom")
        }
        return true
    }() {
        didSet {
            UserDefaults.standard.set(enableScrollWheelZoom, forKey: "MacNotePP.enableScrollWheelZoom")
        }
    }
    @Published public var enableTrackpadPinchZoom: Bool = {
        if UserDefaults.standard.object(forKey: "MacNotePP.enableTrackpadPinchZoom") != nil {
            return UserDefaults.standard.bool(forKey: "MacNotePP.enableTrackpadPinchZoom")
        }
        return true
    }() {
        didSet {
            UserDefaults.standard.set(enableTrackpadPinchZoom, forKey: "MacNotePP.enableTrackpadPinchZoom")
        }
    }

    // MARK: - Smart Highlighting (Akıllı Vurgulama - Aynı Metinleri / Kelimeleri Vurgula)
    @Published public var enableSmartHighlighting: Bool = {
        if UserDefaults.standard.object(forKey: "MacNotePP.enableSmartHighlighting") != nil {
            return UserDefaults.standard.bool(forKey: "MacNotePP.enableSmartHighlighting")
        }
        return true
    }() {
        didSet {
            UserDefaults.standard.set(enableSmartHighlighting, forKey: "MacNotePP.enableSmartHighlighting")
        }
    }
    @Published public var smartHighlightCaseSensitive: Bool = {
        if UserDefaults.standard.object(forKey: "MacNotePP.smartHighlightCaseSensitive") != nil {
            return UserDefaults.standard.bool(forKey: "MacNotePP.smartHighlightCaseSensitive")
        }
        return false
    }() {
        didSet {
            UserDefaults.standard.set(smartHighlightCaseSensitive, forKey: "MacNotePP.smartHighlightCaseSensitive")
        }
    }
    @Published public var smartHighlightWholeWordOnly: Bool = {
        if UserDefaults.standard.object(forKey: "MacNotePP.smartHighlightWholeWordOnly") != nil {
            return UserDefaults.standard.bool(forKey: "MacNotePP.smartHighlightWholeWordOnly")
        }
        return true
    }() {
        didSet {
            UserDefaults.standard.set(smartHighlightWholeWordOnly, forKey: "MacNotePP.smartHighlightWholeWordOnly")
        }
    }

    // MARK: - Startup Session Restore (Açık Dosyaları Başlangıçta Hatırla / Geri Yükle)
    @Published public var restoreSessionOnStartup: Bool = {
        if UserDefaults.standard.object(forKey: "MacNotePP.restoreSessionOnStartup") != nil {
            return UserDefaults.standard.bool(forKey: "MacNotePP.restoreSessionOnStartup")
        }
        return true
    }() {
        didSet {
            UserDefaults.standard.set(restoreSessionOnStartup, forKey: "MacNotePP.restoreSessionOnStartup")
        }
    }

    // MARK: - Updates
    @Published public var checkUpdatesAutomatically: Bool = {
        if UserDefaults.standard.object(forKey: "MacNotePP.checkUpdates") != nil {
            return UserDefaults.standard.bool(forKey: "MacNotePP.checkUpdates")
        }
        return true
    }() {
        didSet {
            UserDefaults.standard.set(checkUpdatesAutomatically, forKey: "MacNotePP.checkUpdates")
        }
    }

    /// Set once quitting for an update is settled; quitting then asks nothing more.
    public private(set) var isRestartingForUpdate = false

    /// Whether the app may quit now to start an installed update. Unsaved tabs survive in the
    /// session; if session restore is off, the usual save questions are asked instead.
    public func prepareForUpdateRestart() -> Bool {
        // AppKit ignores terminate while a sheet is open.
        guard !NSApp.windows.contains(where: { $0.attachedSheet != nil }) else { return false }
        if !restoreSessionOnStartup && !confirmCloseAllModifiedDocuments() { return false }
        isRestartingForUpdate = true
        return true
    }

    // MARK: - VS Code Style Minimap (Belge Haritası) Settings
    @Published public var showMinimap: Bool = {
        if UserDefaults.standard.object(forKey: "MacNotePP.showMinimap") != nil {
            return UserDefaults.standard.bool(forKey: "MacNotePP.showMinimap")
        }
        return false // Default false for clean, fast first launch
    }() {
        didSet {
            UserDefaults.standard.set(showMinimap, forKey: "MacNotePP.showMinimap")
        }
    }

    // MARK: - Panels & Sidebars
    @Published public var showLeftWorkspaceSidebar: Bool = {
        if UserDefaults.standard.object(forKey: "MacNotePP.showLeftWorkspaceSidebar") != nil {
            return UserDefaults.standard.bool(forKey: "MacNotePP.showLeftWorkspaceSidebar")
        }
        return false
    }() {
        didSet {
            UserDefaults.standard.set(showLeftWorkspaceSidebar, forKey: "MacNotePP.showLeftWorkspaceSidebar")
            scheduleSaveSession()
        }
    }
    @Published public var workspaceFolderURL: URL? {
        didSet { scheduleSaveSession() }
    }
    @Published public var showRightSidebar: Bool = {
        if UserDefaults.standard.object(forKey: "MacNotePP.showRightSidebar") != nil {
            return UserDefaults.standard.bool(forKey: "MacNotePP.showRightSidebar")
        }
        return false
    }() {
        didSet {
            UserDefaults.standard.set(showRightSidebar, forKey: "MacNotePP.showRightSidebar")
            scheduleSaveSession()
        }
    }
    @Published public var rightSidebarTab: RightSidebarTab = .functionList
    @Published public var rightSidebarWidth: CGFloat = {
        let saved = UserDefaults.standard.double(forKey: "MacNotePP.rightSidebarWidth")
        if saved >= 160.0 && saved <= 600.0 {
            return CGFloat(saved)
        }
        return 260.0
    }()

    public func saveRightSidebarWidth() {
        UserDefaults.standard.set(Double(rightSidebarWidth), forKey: "MacNotePP.rightSidebarWidth")
    }

    // Active Editor References for Real-time Minimap & Scroll Sync
    public weak var activeTextView: NSTextView?
    public weak var activeScrollView: NSScrollView?
    @Published public var showFindPanel: Bool = false
    @Published public var findPanelTab: FindPanelTab = .find
    @Published public var showSearchResultsDock: Bool = {
        if UserDefaults.standard.object(forKey: "MacNotePP.showSearchResultsDock") != nil {
            return UserDefaults.standard.bool(forKey: "MacNotePP.showSearchResultsDock")
        }
        return false
    }() {
        didSet {
            UserDefaults.standard.set(showSearchResultsDock, forKey: "MacNotePP.showSearchResultsDock")
            scheduleSaveSession()
        }
    }
    @Published public var showMarkdownPreview: Bool = false
    @Published public var markdownDisplayMode: MarkdownDisplayMode = .split

    // MARK: - Compare / Diff Mode
    @Published public var isCompareMode: Bool = false
    @Published public var compareLeftTabId: UUID?
    @Published public var compareRightTabId: UUID?
    @Published public var compareIgnoreWhitespace: Bool = false {
        didSet { recomputeDiff() }
    }
    @Published public var compareIgnoreCase: Bool = false {
        didSet { recomputeDiff() }
    }
    @Published public var diffResult: DiffResult?
    @Published public var currentDiffBlockIndex: Int = 0
    @Published public var scrollToDiffRowTrigger: Int?

    // MARK: - Find / Replace / Mark State
    @Published public var searchQuery: String = ""
    @Published public var replaceQuery: String = ""
    @Published public var searchMode: SearchMode = .normal
    @Published public var matchCase: Bool = false
    @Published public var wholeWord: Bool = false
    @Published public var wrapAround: Bool = true
    @Published public var bookmarkLineOnMark: Bool = true
    @Published public var findInFilesFilter: String = "*.pas;*.sql;*.c;*.cpp;*.h;*.txt;*.py;*.js;*.swift"
    @Published public var findInFilesDirectory: String = ""
    @Published public var searchStatusMessage: String = ""
    @Published public var liveSearchMatches: [NSRange] = []
    @Published public var activeSearchMatchIndex: Int = 0
    @Published public var searchResultGroups: [FindResultGroup] = []

    // MARK: - Dialog Sheets & Settings
    @Published public var showColumnEditorSheet: Bool = false
    @Published public var showGoToLineSheet: Bool = false
    @Published public var showSummarySheet: Bool = false
    @Published public var showRunMacroSheet: Bool = false
    @Published public var showSettingsSheet: Bool = false

    // MARK: - Toolbar Customization & Multi-Row Settings
    @Published public var isMultiRowToolbar: Bool = {
        if UserDefaults.standard.object(forKey: "MacNotePP.isMultiRowToolbar") != nil {
            return UserDefaults.standard.bool(forKey: "MacNotePP.isMultiRowToolbar")
        }
        return true // Default true so smaller screens wrap cleanly into multiple rows
    }() {
        didSet {
            UserDefaults.standard.set(isMultiRowToolbar, forKey: "MacNotePP.isMultiRowToolbar")
        }
    }

    public static let defaultToolbarOrder: [ToolbarItemID] = [
        .toolsMenu,
        .newTab,
        .openFile,
        .saveFile,
        .saveAll,
        .closeTab,
        .printDocument,
        .cutCopyPaste,
        .undoRedo,
        .findReplace,
        .goToLine,
        .columnEditor,
        .multiCaret,
        .wordWrap,
        .showInvisibles,
        .zoomControls,
        .bookmarks,
        .compareDiff,
        .hexView,
        .markdownPreview,
        .lineOperations,
        .macros,
        .sidebarsAndPanels,
        .alwaysOnTop,
        .documentSummary,
        .shortcutPicker,
        .themePicker
    ]

    public static let defaultHiddenToolbarItems: Set<ToolbarItemID> = [
        .documentSummary,
        .columnEditor,
        .macros,
        .lineOperations,
        .multiCaret,
        .shortcutPicker
    ]

    @Published public var isToolbarEditMode: Bool = false

    @Published public var hiddenToolbarItems: Set<ToolbarItemID> = {
        if UserDefaults.standard.object(forKey: "MacNotePP.groupedToolbarMigrationV2") == nil {
            UserDefaults.standard.set(true, forKey: "MacNotePP.groupedToolbarMigrationV2")
            let defaults = AppState.defaultHiddenToolbarItems
            UserDefaults.standard.set(defaults.map(\.rawValue), forKey: "MacNotePP.hiddenToolbarItems")
            return defaults
        }
        if let rawList = UserDefaults.standard.stringArray(forKey: "MacNotePP.hiddenToolbarItems") {
            return Set(rawList.compactMap { ToolbarItemID(rawValue: $0) })
        }
        return AppState.defaultHiddenToolbarItems
    }() {
        didSet {
            UserDefaults.standard.set(hiddenToolbarItems.map(\.rawValue), forKey: "MacNotePP.hiddenToolbarItems")
        }
    }

    @Published public var toolbarItemOrder: [ToolbarItemID] = {
        if let rawList = UserDefaults.standard.stringArray(forKey: "MacNotePP.toolbarItemOrder") {
            var ordered = rawList.compactMap { ToolbarItemID(rawValue: $0) }
            if !ordered.contains(.toolsMenu) {
                if let idx = ordered.firstIndex(of: .sidebarsAndPanels) {
                    ordered.insert(.toolsMenu, at: idx + 1)
                } else {
                    ordered.append(.toolsMenu)
                }
            }
            for item in ToolbarItemID.allCases where !ordered.contains(item) {
                ordered.append(item)
            }
            return ordered
        }
        return AppState.defaultToolbarOrder
    }() {
        didSet {
            UserDefaults.standard.set(toolbarItemOrder.map(\.rawValue), forKey: "MacNotePP.toolbarItemOrder")
        }
    }

    public func isToolbarItemVisible(_ item: ToolbarItemID) -> Bool {
        !hiddenToolbarItems.contains(item)
    }

    public func toggleToolbarItemVisibility(_ item: ToolbarItemID) {
        if hiddenToolbarItems.contains(item) {
            hiddenToolbarItems.remove(item)
        } else {
            hiddenToolbarItems.insert(item)
        }
    }

    public func moveToolbarItem(_ item: ToolbarItemID, direction: Int) {
        guard let idx = toolbarItemOrder.firstIndex(of: item) else { return }
        let targetIdx = idx + direction
        guard targetIdx >= 0 && targetIdx < toolbarItemOrder.count else { return }
        toolbarItemOrder.swapAt(idx, targetIdx)
    }

    public func moveToolbarItem(from sourceItem: ToolbarItemID, to destinationItem: ToolbarItemID) {
        guard sourceItem != destinationItem,
              let fromIndex = toolbarItemOrder.firstIndex(of: sourceItem),
              let toIndex = toolbarItemOrder.firstIndex(of: destinationItem) else { return }
        toolbarItemOrder.remove(at: fromIndex)
        toolbarItemOrder.insert(sourceItem, at: toIndex)
    }

    public func showAllToolbarItems() {
        hiddenToolbarItems.removeAll()
    }

    public func resetToolbarToDefaults() {
        hiddenToolbarItems = AppState.defaultHiddenToolbarItems
        toolbarItemOrder = AppState.defaultToolbarOrder
        isMultiRowToolbar = true
    }

    // MARK: - About Window & Sheet
    @Published public var showAboutSheet: Bool = false

    @Published public var aboutTab: AboutTab = .general

    public func showAboutWindow(tab: AboutTab = .general) {
        aboutTab = tab
        AboutWindowController.shared.showWindow(appState: self)
    }

    // MARK: - Macro State
    @Published public var isRecordingMacro: Bool = false
    @Published public var currentRecordedActions: [MacroAction] = []
    @Published public var savedMacros: [SavedMacro] = [
        SavedMacro(
            name: "Boşlukları Temizle ve Alfabetik Sırala",
            actions: [.lineOperation(.trimBoth), .lineOperation(.removeEmptyLines), .lineOperation(.sortCaseInsensitiveAsc)]
        ),
        SavedMacro(
            name: "Tekrarlayan Satırları Sil ve Trim Yap",
            actions: [.lineOperation(.trimTrailingSpace), .lineOperation(.removeDuplicateLines)]
        )
    ]

    // MARK: - Navigation Request to Active Editor
    @Published public var requestedJumpRange: NSRange?
    @Published public var requestedJumpTrigger: UUID = UUID()
    @Published public var requestedScrollToLine: Int?
    @Published public var requestedScrollTrigger: UUID = UUID()

    public func scrollEditorToLine(_ lineNumber: Int) {
        requestedScrollToLine = lineNumber
        requestedScrollTrigger = UUID()
    }

    // MARK: - Multi-Caret (Çoklu İmleç) State
    public enum MultiCaretCommand: Equatable {
        case addCursorAbove
        case addCursorBelow
        case addCursorsToSelectedLinesEnd
        case addCursorsToSelectedLinesStart
        case clearExtraCursors
    }
    @Published public var activeMultiCaretCount: Int = 1
    @Published public var requestedMultiCaretCommand: MultiCaretCommand?
    @Published public var requestedMultiCaretTrigger: UUID = UUID()

    public func triggerMultiCaret(_ command: MultiCaretCommand) {
        requestedMultiCaretCommand = command
        requestedMultiCaretTrigger = UUID()
    }

    public enum RightSidebarTab: String, CaseIterable, Identifiable {
        case functionList = "Fonksiyonlar"
        case bookmarks = "Yer İmleri"

        public var id: String { rawValue }
    }

    private var untitledCounter: Int = 1

    public init() {
        loadSessionOrDefault()
    }

    public var activeTabIndex: Int? {
        guard let id = activeTabId else { return nil }
        return tabs.firstIndex(where: { $0.id == id })
    }

    public var activeDocument: EditorDocument? {
        get {
            guard let idx = activeTabIndex else { return nil }
            return tabs[idx]
        }
        set {
            guard let idx = activeTabIndex, let newValue = newValue else { return }
            tabs[idx] = newValue
            if isCompareMode {
                recomputeDiff()
            }
        }
    }

    // MARK: - Tab Operations
    public func newTab(
        title: String? = nil,
        content: String = "",
        language: SyntaxLanguage = .plainText,
        isLanguageManuallySet: Bool = false
    ) {
        let tabTitle: String
        if let custom = title {
            tabTitle = custom
        } else {
            while tabs.contains(where: { $0.fileURL == nil && $0.title == "new \(untitledCounter)" }) {
                untitledCounter += 1
            }
            tabTitle = "new \(untitledCounter)"
            untitledCounter += 1
        }

        let detectedLang = isLanguageManuallySet ? language : SyntaxLanguage.detect(url: nil, content: content)
        let doc = EditorDocument(
            title: tabTitle,
            fileURL: nil,
            content: content,
            rawData: Data(content.utf8),
            isModified: !content.isEmpty,
            language: detectedLang,
            isLanguageManuallySet: isLanguageManuallySet
        )
        tabs.append(doc)
        activeTabId = doc.id
        saveSession()
    }

    public func openFilesPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.title = loc("Dosya Aç — MacNote++", "Open File — MacNote++")
        panel.prompt = loc("Aç", "Open")

        if panel.runModal() == .OK {
            for url in panel.urls {
                openFile(url: url)
            }
        }
    }

    public func openWorkspaceFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = loc("Çalışma Klasörü Aç (Folder as Workspace)", "Open Folder")
        panel.prompt = loc("Klasörü Seç", "Choose Folder")

        if panel.runModal() == .OK, let url = panel.url {
            workspaceFolderURL = url
            findInFilesDirectory = url.path
            showLeftWorkspaceSidebar = true
        }
    }

    public func openFile(
        url: URL,
        bypassLargeFileGuard: Bool = false,
        partialSizeMB: Int? = nil,
        forceHex: Bool = false
    ) {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            workspaceFolderURL = url
            findInFilesDirectory = url.path
            showLeftWorkspaceSidebar = true
            return
        }

        if let existingIdx = tabs.firstIndex(where: { $0.fileURL?.standardizedFileURL == url.standardizedFileURL }) {
            let existing = tabs[existingIdx]
            let fileSizeOnDisk = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
            let isReallyPartial = existing.isPartialPreview || (fileSizeOnDisk > 50 * 1024 * 1024 && existing.content.utf8.count <= 25 * 1024 * 1024)

            if isReallyPartial && (bypassLargeFileGuard || forceHex) {
                if forceHex {
                    openTabInHex(for: existing.id)
                } else {
                    loadFullFile(for: existing.id)
                }
                return
            } else if forceHex && existing.viewMode != .hex {
                openTabInHex(for: existing.id)
                return
            } else if isReallyPartial && !bypassLargeFileGuard {
                pendingLargeFile = PendingLargeFileInfo(url: url, sizeBytes: fileSizeOnDisk)
                showLargeFileDialog = true
                return
            } else {
                activeTabId = existing.id
                return
            }
        }

        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        let modDate = attrs?[.modificationDate] as? Date

        // 🛡️ Large File Guard Check (Files >= 80 MB)
        if !bypassLargeFileGuard && partialSizeMB == nil && !forceHex && fileSize >= largeFileThresholdBytes {
            pendingLargeFile = PendingLargeFileInfo(url: url, sizeBytes: fileSize)
            showLargeFileDialog = true
            return
        }

        // Force Hex Mode
        if forceHex {
            openFileAsHex(url: url, fileSize: fileSize, modDate: modDate)
            return
        }

        // Partial Safe Preview (e.g. 10 MB)
        if let limitMB = partialSizeMB {
            openFileAsPartialPreview(url: url, limitMB: limitMB, fileSize: fileSize, modDate: modDate)
            return
        }

        // Full Open
        openFileFull(url: url, fileSize: fileSize, modDate: modDate)
    }

    /// Opens a file locked against editing; very large files go straight to the safe preview.
    public func openFileForViewing(url: URL) {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        let alreadyOpen = tabs.contains { $0.fileURL?.standardizedFileURL == url.standardizedFileURL }
        if size >= largeFileThresholdBytes && !alreadyOpen {
            openFile(url: url, bypassLargeFileGuard: true, partialSizeMB: 10)
        } else {
            openFile(url: url, bypassLargeFileGuard: true)
        }
        if !alreadyOpen, let idx = tabs.firstIndex(where: { $0.fileURL?.standardizedFileURL == url.standardizedFileURL }) {
            tabs[idx].isReadOnly = true
            saveSession()
        }
    }

    private func openFileAsPartialPreview(url: URL, limitMB: Int, fileSize: Int64, modDate: Date?) {
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }

            let bytesToRead = limitMB * 1024 * 1024
            let data = fileHandle.readData(ofLength: bytesToRead)
            let decoded = TextEncodingOption.decode(data: data)
            let lang = SyntaxLanguage.detect(url: url, filename: url.lastPathComponent, content: decoded.text)

            let doc = EditorDocument(
                title: loc("\(url.lastPathComponent) [Önizleme \(limitMB)MB]", "\(url.lastPathComponent) [Preview \(limitMB) MB]"),
                fileURL: url,
                content: decoded.text,
                rawData: data,
                isModified: false,
                isReadOnly: true,
                isPartialPreview: true,
                totalFileSize: fileSize,
                language: lang,
                isLanguageManuallySet: false,
                encoding: decoded.encoding,
                lineEnding: decoded.lineEnding,
                viewMode: .text,
                lastSavedDate: modDate
            )
            if showMinimap {
                showMinimap = false
            }
            tabs.append(doc)
            activeTabId = doc.id
            addToRecentFiles(url)
            saveSession()
        } catch {
            let alert = NSAlert()
            alert.messageText = loc("Dosya Önizlemesi Açılamadı", "Could Not Open Preview")
            alert.informativeText = "\(url.lastPathComponent): \(error.localizedDescription)"
            alert.runModal()
        }
    }

    private func openFileAsHex(url: URL, fileSize: Int64, modDate: Date?) {
        do {
            let bytesToRead = min(Int(fileSize), 20 * 1024 * 1024)
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }
            let data = fileHandle.readData(ofLength: bytesToRead)

            let doc = EditorDocument(
                title: url.lastPathComponent,
                fileURL: url,
                content: "",
                rawData: data,
                isModified: false,
                isReadOnly: true,
                isPartialPreview: fileSize > Int64(bytesToRead),
                totalFileSize: fileSize,
                language: .plainText,
                isLanguageManuallySet: false,
                encoding: .utf8,
                lineEnding: .lf,
                viewMode: .hex,
                lastSavedDate: modDate
            )
            if showMinimap {
                showMinimap = false
            }
            tabs.append(doc)
            activeTabId = doc.id
            addToRecentFiles(url)
            saveSession()
        } catch {
            let alert = NSAlert()
            alert.messageText = loc("Hex Görünümü Açılamadı", "Could Not Open Hex View")
            alert.informativeText = "\(url.lastPathComponent): \(error.localizedDescription)"
            alert.runModal()
        }
    }

    /// The tab whose whole file is being read in the background.
    @Published public private(set) var fullLoadTabId: UUID?
    private var fullLoadTask: Task<Void, Never>?

    public func loadFullFile(for docId: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == docId }),
              let url = tabs[idx].fileURL else { return }

        let fileSize = tabs[idx].totalFileSize
        let fileName = url.lastPathComponent
        let modDate = diskModificationDate(of: url)

        fullLoadTask?.cancel()
        fullLoadTabId = docId
        fullLoadTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                try Task.checkCancellation()
                let decoded = TextEncodingOption.decode(data: data)
                try Task.checkCancellation()
                let lang = SyntaxLanguage.detect(url: url, filename: fileName, content: String(decoded.text.prefix(20000)))

                let isLikelyBinary: Bool = {
                    if decoded.encoding == .utf16LE || decoded.encoding == .utf16BE { return false }
                    return data.prefix(512).contains(0x00)
                }()

                let isLarge = (fileSize ?? 0) >= 20 * 1024 * 1024 || data.count >= 20 * 1024 * 1024
                let keptBytes = (data.count <= 20 * 1024 * 1024) ? Data(data) : nil

                try Task.checkCancellation()
                await MainActor.run { [weak self] in
                    guard let self = self, self.fullLoadTabId == docId, !Task.isCancelled,
                          let targetIdx = self.tabs.firstIndex(where: { $0.id == docId }) else { return }

                    self.fullLoadTabId = nil
                    if isLarge && self.showMinimap {
                        self.showMinimap = false
                    }
                    self.tabs[targetIdx].title = fileName
                    self.tabs[targetIdx].content = decoded.text
                    self.tabs[targetIdx].rawData = keptBytes
                    self.tabs[targetIdx].isModified = false
                    self.tabs[targetIdx].isReadOnly = isLarge || isLikelyBinary
                    self.tabs[targetIdx].isPartialPreview = false
                    self.tabs[targetIdx].totalFileSize = fileSize
                    self.tabs[targetIdx].language = lang
                    self.tabs[targetIdx].encoding = decoded.encoding
                    self.tabs[targetIdx].lineEnding = decoded.lineEnding
                    self.tabs[targetIdx].viewMode = isLikelyBinary ? .hex : .text
                    self.tabs[targetIdx].lastSavedDate = modDate
                    self.activeTabId = docId
                    self.saveSession()
                    self.objectWillChange.send()
                }
            } catch is CancellationError {
                await MainActor.run { [weak self] in
                    if self?.fullLoadTabId == docId { self?.fullLoadTabId = nil }
                }
            } catch {
                await MainActor.run { [weak self] in
                    if self?.fullLoadTabId == docId { self?.fullLoadTabId = nil }
                    let alert = NSAlert()
                    alert.messageText = UpdateChecker.loc("Dosyanın Tamamı Yüklenemedi", "Could Not Load the Whole File")
                    alert.informativeText = "\(fileName): \(error.localizedDescription)"
                    alert.runModal()
                }
            }
        }
    }

    /// Stops a full load; the tab stays as the preview it was.
    public func cancelFullLoad() {
        fullLoadTask?.cancel()
        fullLoadTask = nil
        fullLoadTabId = nil
    }

    public func openTabInHex(for docId: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == docId }) else { return }
        let doc = tabs[idx]
        if let url = doc.fileURL {
            // The size on disk: the tab's own figure can be missing or out of date.
            let total = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
            let bytesToRead = min(Int(total), 20 * 1024 * 1024)
            if let fileHandle = try? FileHandle(forReadingFrom: url) {
                defer { try? fileHandle.close() }
                tabs[idx].rawData = fileHandle.readData(ofLength: bytesToRead)
                tabs[idx].totalFileSize = total
                tabs[idx].isPartialPreview = total > Int64(bytesToRead)
            }
        }
        tabs[idx].title = doc.fileURL?.lastPathComponent ?? doc.title
        tabs[idx].viewMode = .hex
        tabs[idx].isReadOnly = true
        activeTabId = docId
        objectWillChange.send()
    }

    private func openFileFull(url: URL, fileSize: Int64, modDate: Date?) {
        let isLarge = fileSize >= 20 * 1024 * 1024
        if isLarge && showMinimap {
            showMinimap = false
        }
        if isLarge {
            // The tab appears at once as a preview and can be closed while the rest loads.
            openFileAsPartialPreview(url: url, limitMB: 10, fileSize: fileSize, modDate: modDate)
            if let id = tabs.first(where: { $0.fileURL?.standardizedFileURL == url.standardizedFileURL })?.id {
                loadFullFile(for: id)
            }
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = TextEncodingOption.decode(data: data)
            let lang = SyntaxLanguage.detect(url: url, filename: url.lastPathComponent, content: decoded.text)

            let isLikelyBinary: Bool = {
                if decoded.encoding == .utf16LE || decoded.encoding == .utf16BE { return false }
                let sample = data.prefix(512)
                return sample.contains(0x00)
            }()

            let doc = EditorDocument(
                title: url.lastPathComponent,
                fileURL: url,
                content: decoded.text,
                rawData: data,
                isModified: false,
                isReadOnly: isLikelyBinary,
                isPartialPreview: false,
                totalFileSize: fileSize,
                language: lang,
                isLanguageManuallySet: false,
                encoding: decoded.encoding,
                lineEnding: decoded.lineEnding,
                viewMode: isLikelyBinary ? .hex : .text,
                lastSavedDate: modDate
            )
            if let existingIdx = tabs.firstIndex(where: { $0.fileURL?.standardizedFileURL == url.standardizedFileURL }) {
                tabs[existingIdx] = doc
            } else {
                tabs.append(doc)
            }
            activeTabId = doc.id
            addToRecentFiles(url)
            saveSession()
        } catch {
            let alert = NSAlert()
            alert.messageText = loc("Dosya Açılamadı", "Could Not Open File")
            alert.informativeText = "\(url.lastPathComponent): \(error.localizedDescription)"
            alert.runModal()
        }
    }

    public func saveActiveTab() {
        guard let id = activeTabId else { return }
        saveTab(id: id, saveAs: false)
    }

    public func saveActiveTabAs() {
        guard let id = activeTabId else { return }
        saveTab(id: id, saveAs: true)
    }

    public func saveAllTabs() {
        for tab in tabs where tab.isModified || tab.fileURL == nil {
            saveTab(id: tab.id, saveAs: false)
        }
    }

    // MARK: - Print & Print Preview
    @Published public var showPrintPreviewSheet: Bool = false

    // MARK: - Large File Guard & Streaming
    public let largeFileThresholdBytes: Int64 = 80 * 1024 * 1024 // 80 MB
    @Published public var showLargeFileDialog: Bool = false
    @Published public var pendingLargeFile: PendingLargeFileInfo? = nil

    public func confirmLargeFileOpen(action: LargeFileOpenAction) {
        guard let info = pendingLargeFile else { return }
        showLargeFileDialog = false
        pendingLargeFile = nil

        switch action {
        case .partialPreview(let limitMB):
            openFile(url: info.url, bypassLargeFileGuard: true, partialSizeMB: limitMB)
        case .hexView:
            openFile(url: info.url, bypassLargeFileGuard: true, forceHex: true)
        case .fullOpen:
            openFile(url: info.url, bypassLargeFileGuard: true)
        case .cancel:
            break
        }
    }

    public func printDocumentDirectly() {
        guard let doc = activeDocument else { return }

        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.topMargin = 36.0
        printInfo.bottomMargin = 36.0
        printInfo.leftMargin = 36.0
        printInfo.rightMargin = 36.0

        let printTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: printInfo.paperSize.width - 72, height: printInfo.paperSize.height - 72))
        printTextView.isEditable = false
        printTextView.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        printTextView.string = doc.content

        let printOperation = NSPrintOperation(view: printTextView, printInfo: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.run()
    }

    @discardableResult
    public func saveTab(id: UUID, saveAs: Bool) -> Bool {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return false }
        var doc = tabs[idx]

        var targetURL = doc.fileURL
        if saveAs || targetURL == nil {
            let panel = NSSavePanel()
            panel.title = loc("Dosyayı Kaydet — MacNote++", "Save File — MacNote++")
            let defaultName: String
            if let existingURL = doc.fileURL {
                defaultName = existingURL.lastPathComponent
            } else if doc.title.contains(".") {
                defaultName = doc.title
            } else {
                defaultName = "\(doc.title).\(doc.language.defaultExtension)"
            }
            panel.nameFieldStringValue = defaultName
            panel.canCreateDirectories = true

            guard panel.runModal() == .OK, let chosenURL = panel.url else { return false }
            targetURL = chosenURL
        }

        guard let finalURL = targetURL else { return false }
        let isSameFile = doc.fileURL?.standardizedFileURL == finalURL.standardizedFileURL

        // A preview holds only the start of the file: writing it back would cut the file short.
        if doc.isPartialPreview && isSameFile {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = loc("Önizleme özgün dosyaya kaydedilemez", "A preview cannot be saved over the original file")
            alert.informativeText = loc(
                "Bu sekme \"\(finalURL.lastPathComponent)\" dosyasının yalnızca bir bölümünü gösteriyor; kaydetmek dosyanın geri kalanını silerdi. Dosyanın tamamını yükleyin ya da Farklı Kaydet ile yeni bir dosyaya kaydedin.",
                "This tab shows only part of \"\(finalURL.lastPathComponent)\"; saving would delete the rest of the file. Load the whole file, or use Save As for a new file."
            )
            alert.runModal()
            return false
        }

        // Locked and unchanged: there is nothing to write.
        if doc.isReadOnly && !doc.isModified && isSameFile && !saveAs { return true }

        if isSameFile, let known = doc.lastSavedDate, let onDisk = diskModificationDate(of: finalURL),
           abs(onDisk.timeIntervalSince(known)) > 0.01 {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = loc("\"\(finalURL.lastPathComponent)\" başka bir uygulama tarafından değiştirildi", "\"\(finalURL.lastPathComponent)\" was changed by another application")
            alert.informativeText = loc("Kaydederseniz diskteki değişikliklerin üzerine yazılır.", "Saving will overwrite the changes on disk.")
            alert.addButton(withTitle: loc("Üzerine Yaz", "Overwrite"))
            alert.addButton(withTitle: loc("İptal", "Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { return false }
        }

        if doc.viewMode != .hex && !doc.encoding.canRepresent(doc.content) {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = loc("Bazı karakterler \(doc.encoding.rawValue) kodlamasında yok", "Some characters do not exist in \(doc.encoding.rawValue)")
            alert.informativeText = loc("Bu kodlamayla kaydederseniz o karakterler \"?\" olur.", "If you save in this encoding they become \"?\".")
            alert.addButton(withTitle: loc("UTF-8 Olarak Kaydet", "Save as UTF-8"))
            alert.addButton(withTitle: loc("Yine de Kaydet", "Save Anyway"))
            alert.addButton(withTitle: loc("İptal", "Cancel"))
            switch alert.runModal() {
            case .alertFirstButtonReturn: doc.encoding = .utf8
            case .alertSecondButtonReturn: break
            default: return false
            }
        }

        do {
            let outputData: Data
            if doc.viewMode == .hex, let raw = doc.rawData {
                outputData = raw
            } else {
                outputData = doc.encoding.encode(text: doc.content, lineEnding: doc.lineEnding)
            }
            // Through a symbolic link, so the link stays a link.
            try outputData.write(to: finalURL.resolvingSymlinksInPath(), options: .atomic)
            doc.fileURL = finalURL
            doc.title = finalURL.lastPathComponent
            doc.rawData = outputData
            doc.isModified = false
            doc.lastSavedDate = diskModificationDate(of: finalURL) ?? Date()
            doc.totalFileSize = Int64(outputData.count)
            if doc.isPartialPreview {
                // Save As: the new file holds exactly what this tab shows.
                doc.isPartialPreview = false
                doc.isReadOnly = false
            }
            if !doc.isLanguageManuallySet {
                doc.language = SyntaxLanguage.detect(url: finalURL, content: doc.content)
            }
            tabs[idx] = doc
            addToRecentFiles(finalURL)
            saveSession()
            return true
        } catch {
            let alert = NSAlert()
            alert.messageText = loc("Dosya Kaydedilemedi", "Could Not Save File")
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return false
        }
    }

    private func diskModificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    /// When the app comes forward: tabs without unsaved changes follow their file on disk.
    /// Tabs with unsaved changes are left alone; saving them asks before overwriting.
    public func reloadExternallyChangedTabs() {
        var changed = false
        for idx in tabs.indices {
            guard !tabs[idx].isModified, !tabs[idx].isPartialPreview, tabs[idx].viewMode == .text,
                  let url = tabs[idx].fileURL, let known = tabs[idx].lastSavedDate,
                  let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let onDisk = attributes[.modificationDate] as? Date, abs(onDisk.timeIntervalSince(known)) > 0.01,
                  let size = (attributes[.size] as? NSNumber)?.int64Value, size <= 20 * 1024 * 1024,
                  let data = try? Data(contentsOf: url) else { continue }
            let decoded = TextEncodingOption.decode(data: data)
            tabs[idx].content = decoded.text
            tabs[idx].rawData = data
            tabs[idx].encoding = decoded.encoding
            tabs[idx].lineEnding = decoded.lineEnding
            tabs[idx].totalFileSize = size
            tabs[idx].lastSavedDate = onDisk
            changed = true
        }
        if changed { saveSession() }
    }

    public func reloadActiveTabFromDisk() {
        guard let idx = activeTabIndex, let url = tabs[idx].fileURL else { return }
        let diskSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        if diskSize > 20 * 1024 * 1024 {
            loadFullFile(for: tabs[idx].id)
            return
        }
        if let data = try? Data(contentsOf: url) {
            let decoded = TextEncodingOption.decode(data: data)
            tabs[idx].content = decoded.text
            tabs[idx].rawData = data
            tabs[idx].encoding = decoded.encoding
            tabs[idx].lineEnding = decoded.lineEnding
            tabs[idx].isModified = false
            tabs[idx].totalFileSize = diskSize
            tabs[idx].lastSavedDate = diskModificationDate(of: url)
            saveSession()
        }
    }

    public func toggleReadOnly(id: UUID? = nil) {
        let targetId = id ?? activeTabId
        guard let targetId = targetId,
              let idx = tabs.firstIndex(where: { $0.id == targetId }) else { return }

        if tabs[idx].isPartialPreview {
            let alert = NSAlert()
            alert.messageText = loc("Önizleme düzenlenemez", "A preview cannot be edited")
            alert.informativeText = loc("Bu sekme dosyanın yalnızca bir bölümünü gösteriyor. Düzenlemek için dosyanın tamamını yükleyin.", "This tab shows only part of the file. Load the whole file to edit it.")
            alert.runModal()
            return
        }

        // Warn if file is huge (> 50 MB) and user is unlocking
        if tabs[idx].isReadOnly && (tabs[idx].totalFileSize ?? 0) > 50 * 1024 * 1024 {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = loc("Büyük Dosyayı Düzenlemeye Açmak İstiyor musunuz?", "Unlock Large File for Editing?")
            alert.informativeText = loc(
                "Bu dosya çok büyük (\(tabs[idx].formattedTotalSize.isEmpty ? "50+ MB" : tabs[idx].formattedTotalSize)). Düzenleme moduna geçildiğinde klavyeden yazarken sistemin yavaşlamasına neden olabilir. Devam etmek istiyor musunuz?",
                "This file is very large. Enabling edit mode may cause system slowdowns during typing. Do you want to continue?"
            )
            alert.addButton(withTitle: loc("Kilidi Kaldır (Düzenlenebilir Yap)", "Unlock Editing"))
            alert.addButton(withTitle: loc("İptal", "Cancel"))
            if alert.runModal() != .alertFirstButtonReturn {
                return
            }
        }

        tabs[idx].isReadOnly.toggle()
        if let act = activeTextView, tabs[idx].id == activeTabId {
            act.isEditable = !tabs[idx].isReadOnly
        }
        objectWillChange.send()
        saveSession()
    }

    @discardableResult
    public func closeTab(id: UUID) -> Bool {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return true }
        let doc = tabs[idx]

        if doc.isModified {
            // Kullanıcının hangi dosyayı kapattığını net görmesi için sekmeyi öne getir
            activeTabId = id

            let alert = NSAlert()
            alert.messageText = loc("\"\(doc.title)\" belgesindeki değişiklikleri kaydetmek istiyor musunuz?", "Do you want to save the changes to \"\(doc.title)\"?")
            alert.informativeText = loc("Kaydetmezseniz yaptığınız tüm değişiklikler kalıcı olarak kaybolacaktır.", "If you don't save, all your changes will be permanently lost.")
            alert.alertStyle = .warning

            let saveBtn = alert.addButton(withTitle: loc("Kaydet", "Save"))
            saveBtn.keyEquivalent = "\r"

            let dontSaveBtn = alert.addButton(withTitle: loc("Kaydetme", "Don't Save"))
            dontSaveBtn.keyEquivalent = "d"
            dontSaveBtn.keyEquivalentModifierMask = [.command]

            let cancelBtn = alert.addButton(withTitle: loc("İptal", "Cancel"))
            cancelBtn.keyEquivalent = "\u{1b}"

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn: // Kaydet
                let success = saveTab(id: id, saveAs: false)
                if !success {
                    // Kullanıcı dosya kaydetme diyaloğunda iptal etti veya kayıt başarısız oldu
                    restoreEditorFocus()
                    return false
                }
                forceCloseTab(id: id)
                return true

            case .alertSecondButtonReturn: // Kaydetme (Değişiklikleri at)
                forceCloseTab(id: id)
                return true

            default: // İptal (Esc veya İptal butonu)
                restoreEditorFocus()
                return false
            }
        } else {
            forceCloseTab(id: id)
            return true
        }
    }

    public func forceCloseTab(id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        if fullLoadTabId == id { cancelFullLoad() }
        if tabs[idx].isPinned && tabs.count > 1 {
            // Unpin first if user explicitly closes
            tabs[idx].isPinned = false
        }
        tabs.remove(at: idx)
        if tabs.isEmpty {
            newTab(title: "new 1")
        } else if activeTabId == id {
            let newIdx = min(idx, tabs.count - 1)
            activeTabId = tabs[newIdx].id
        }
        saveSession()
    }

    public func closeOtherTabs(keeping id: UUID) {
        let otherTabs = tabs.filter { $0.id != id && !$0.isPinned }
        for tab in otherTabs {
            if !closeTab(id: tab.id) {
                break
            }
        }
        activeTabId = id
    }

    public func closeTabsToRight(of id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let rightTabs = tabs.enumerated().filter { offset, tab in
            offset > idx && !tab.isPinned
        }.map(\.element)
        for tab in rightTabs {
            if !closeTab(id: tab.id) {
                break
            }
        }
    }

    // MARK: - Restore Editor Focus on Cancel / Modal Dismissal
    public func restoreEditorFocus() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.canBecomeKey && window.isVisible {
                window.makeKeyAndOrderFront(nil)
                if let textView = self.activeTextView {
                    window.makeFirstResponder(textView)
                }
                break
            }
        }
    }

    public func quitApplicationSafely() {
        let canTerminate = confirmCloseAllModifiedDocuments()
        if canTerminate {
            saveSession()
            NSApp.terminate(nil)
        } else {
            restoreEditorFocus()
        }
    }

    // MARK: - Save Confirmation for All Modified Documents on Exit / Close Window
    @discardableResult
    public func confirmCloseAllModifiedDocuments() -> Bool {
        let modifiedTabs = tabs.filter { $0.isModified }
        guard !modifiedTabs.isEmpty else { return true }

        var saveAllRemaining = false
        // Applied only once every question is answered: a later Cancel must leave all tabs as they were.
        var discarded: [UUID] = []

        for tab in modifiedTabs {
            // Check if tab is still present and modified
            guard let current = tabs.first(where: { $0.id == tab.id }), current.isModified else {
                continue
            }

            if saveAllRemaining {
                let saved = saveTab(id: tab.id, saveAs: false)
                if !saved {
                    restoreEditorFocus()
                    return false
                }
                continue
            }

            // Bring tab into view so user knows which file is being asked about
            activeTabId = tab.id

            let alert = NSAlert()
            alert.messageText = loc("\"\(tab.title)\" belgesindeki değişiklikler kaydedilsin mi?", "Do you want to save the changes to \"\(tab.title)\"?")
            alert.informativeText = loc("Değişiklikleri kaydetmezseniz yaptığınız tüm son düzenlemeler kalıcı olarak kaybolacaktır.", "If you don't save, all your recent changes will be permanently lost.")
            alert.alertStyle = .warning

            let saveBtn = alert.addButton(withTitle: loc("Kaydet", "Save"))
            saveBtn.keyEquivalent = "\r"

            let hasMultiple = (modifiedTabs.count > 1)
            if hasMultiple {
                alert.addButton(withTitle: loc("Tümünü Kaydet", "Save All"))
            }

            let dontSaveBtn = alert.addButton(withTitle: loc("Kaydetme", "Don't Save"))
            dontSaveBtn.keyEquivalent = "d"
            dontSaveBtn.keyEquivalentModifierMask = [.command]

            if hasMultiple {
                alert.addButton(withTitle: loc("Tümünü Kaydetme", "Don't Save Any"))
            }

            let cancelBtn = alert.addButton(withTitle: loc("İptal", "Cancel"))
            cancelBtn.keyEquivalent = "\u{1b}"

            let response = alert.runModal()
            if hasMultiple {
                switch response {
                case .alertFirstButtonReturn: // Kaydet
                    let saved = saveTab(id: tab.id, saveAs: false)
                    if !saved {
                        restoreEditorFocus()
                        return false // Save cancelled -> abort exit
                    }
                case .alertSecondButtonReturn: // Tümünü Kaydet
                    let saved = saveTab(id: tab.id, saveAs: false)
                    if !saved {
                        restoreEditorFocus()
                        return false
                    }
                    saveAllRemaining = true
                case .alertThirdButtonReturn: // Kaydetme
                    discarded.append(tab.id)
                case NSApplication.ModalResponse(rawValue: 1003): // Tümünü Kaydetme
                    discarded += tabs.filter { $0.isModified }.map(\.id)
                    discardUnsavedChanges(of: discarded)
                    return true
                default: // İptal
                    restoreEditorFocus()
                    return false
                }
            } else {
                switch response {
                case .alertFirstButtonReturn: // Kaydet
                    let saved = saveTab(id: tab.id, saveAs: false)
                    if !saved {
                        restoreEditorFocus()
                        return false
                    }
                case .alertSecondButtonReturn: // Kaydetme
                    discarded.append(tab.id)
                default: // İptal
                    restoreEditorFocus()
                    return false
                }
            }
        }

        discardUnsavedChanges(of: discarded)
        return true
    }

    /// "Don't Save" must not come back at the next launch: a file tab goes back to its file, a new tab goes away.
    private func discardUnsavedChanges(of ids: [UUID]) {
        for id in ids {
            guard let idx = tabs.firstIndex(where: { $0.id == id }) else { continue }
            if let url = tabs[idx].fileURL, FileManager.default.fileExists(atPath: url.path) {
                tabs[idx].isModified = false
            } else {
                forceCloseTab(id: id)
            }
        }
    }

    public func closeUnmodifiedTabs() {
        tabs = tabs.filter { $0.isModified || $0.isPinned }
        if tabs.isEmpty {
            newTab(title: "new 1")
        } else if !tabs.contains(where: { $0.id == activeTabId }) {
            activeTabId = tabs.first?.id
        }
        saveSession()
    }

    /// Puts the tab at `index` of the tab bar.
    public func moveTab(id: UUID, to index: Int) {
        guard let current = tabs.firstIndex(where: { $0.id == id }) else { return }
        let target = max(0, min(index, tabs.count - 1))
        guard target != current else { return }
        let tab = tabs.remove(at: current)
        tabs.insert(tab, at: target)
        saveSession()
    }

    public func moveTab(id: UUID, by delta: Int) {
        guard let current = tabs.firstIndex(where: { $0.id == id }) else { return }
        moveTab(id: id, to: current + delta)
    }

    public func togglePinTab(id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[idx].isPinned.toggle()
        saveSession()
    }

    private func addToRecentFiles(_ url: URL) {
        recentFiles.removeAll(where: { $0 == url })
        recentFiles.insert(url, at: 0)
        if recentFiles.count > 15 {
            recentFiles = Array(recentFiles.prefix(15))
        }
    }

    // MARK: - View Mode (Text <-> Hex) & Compare Mode
    public func toggleHexView() {
        guard let idx = activeTabIndex else { return }
        if tabs[idx].viewMode == .text {
            tabs[idx].syncBytesFromText()
            tabs[idx].viewMode = .hex
        } else {
            tabs[idx].viewMode = .text
        }
        saveSession()
    }

    public func toggleCompareMode(withTabId secondTabId: UUID? = nil) {
        if isCompareMode && secondTabId == nil {
            isCompareMode = false
            return
        }

        if tabs.count < 2 {
            // Create a modified clone so the user can immediately compare if only 1 tab is open
            if let current = activeDocument {
                let cloneContent = current.content + loc("\n// Yeni eklenen karşılaştırma satırı\n", "\n// New line added for comparison\n")
                newTab(
                    title: loc("\(current.displayTitle) (Kopya)", "\(current.displayTitle) (Copy)"),
                    content: cloneContent,
                    language: current.language,
                    isLanguageManuallySet: true
                )
            }
        }

        let currentId = activeTabId ?? tabs.first?.id
        compareLeftTabId = currentId
        if let explicitRight = secondTabId {
            compareRightTabId = explicitRight
        } else {
            compareRightTabId = tabs.first(where: { $0.id != currentId })?.id ?? currentId
        }
        isCompareMode = true
        recomputeDiff()
    }

    public func swapCompareSides() {
        let tmp = compareLeftTabId
        compareLeftTabId = compareRightTabId
        compareRightTabId = tmp
        recomputeDiff()
    }

    public func recomputeDiff() {
        guard isCompareMode else { return }
        let leftDoc = tabs.first(where: { $0.id == compareLeftTabId }) ?? tabs.first
        let rightDoc = tabs.first(where: { $0.id == compareRightTabId }) ?? tabs.last
        guard let l = leftDoc, let r = rightDoc else { return }

        let res = DiffEngine.compare(
            leftText: l.content,
            rightText: r.content,
            ignoreWhitespace: compareIgnoreWhitespace,
            ignoreCase: compareIgnoreCase
        )
        diffResult = res
        currentDiffBlockIndex = 0
    }

    public func navigateDiff(delta: Int) {
        guard let res = diffResult, !res.diffBlockRowIndices.isEmpty else { return }
        let count = res.diffBlockRowIndices.count
        currentDiffBlockIndex = (currentDiffBlockIndex + delta + count) % count
        scrollToDiffRowTrigger = res.diffBlockRowIndices[currentDiffBlockIndex]
    }

    public func navigateFirstDiff() {
        guard let res = diffResult, let first = res.diffBlockRowIndices.first else { return }
        currentDiffBlockIndex = 0
        scrollToDiffRowTrigger = first
    }

    public func navigateLastDiff() {
        guard let res = diffResult, let last = res.diffBlockRowIndices.last else { return }
        currentDiffBlockIndex = res.diffBlockRowIndices.count - 1
        scrollToDiffRowTrigger = last
    }

    // MARK: - Undo / Redo Engine
    public var canUndo: Bool {
        activeDocument?.undoStack.isEmpty == false
    }

    public var canRedo: Bool {
        activeDocument?.redoStack.isEmpty == false
    }

    public func performUndo() {
        guard let idx = activeTabIndex else { return }
        if let restoredOffset = tabs[idx].undo() {
            jumpToRange(NSRange(location: restoredOffset, length: 0))
            saveSession()
        }
    }

    public func performRedo() {
        guard let idx = activeTabIndex else { return }
        if let restoredOffset = tabs[idx].redo() {
            jumpToRange(NSRange(location: restoredOffset, length: 0))
            saveSession()
        }
    }

    // MARK: - Line, Case, Bookmark & Format Actions on Active Tab
    public func applyLineOperation(_ op: LineOperationType) {
        guard let idx = activeTabIndex else { return }
        let updated = TextOperations.performLineOperation(op, on: tabs[idx].content)
        tabs[idx].applyContentMutation(updated)
        if isRecordingMacro {
            currentRecordedActions.append(.lineOperation(op))
        }
        saveSession()
    }

    public func applyCaseConversion(_ type: CaseConversionType) {
        guard let idx = activeTabIndex else { return }
        let updated = TextOperations.convertCase(type, on: tabs[idx].content)
        tabs[idx].applyContentMutation(updated)
        if isRecordingMacro {
            currentRecordedActions.append(.caseConversion(type))
        }
        saveSession()
    }

    public func duplicateCurrentLine() {
        guard let idx = activeTabIndex else { return }
        var lines = LineEndingType.normalizeToLF(tabs[idx].content).components(separatedBy: "\n")
        let lineIdx = max(0, min(tabs[idx].cursorLine - 1, lines.count - 1))
        lines.insert(lines[lineIdx], at: lineIdx + 1)
        tabs[idx].applyContentMutation(lines.joined(separator: "\n"))
        saveSession()
    }

    public func deleteCurrentLine() {
        guard let idx = activeTabIndex else { return }
        var lines = LineEndingType.normalizeToLF(tabs[idx].content).components(separatedBy: "\n")
        let lineIdx = max(0, min(tabs[idx].cursorLine - 1, lines.count - 1))
        if lines.count > 1 {
            lines.remove(at: lineIdx)
        } else {
            lines[0] = ""
        }
        tabs[idx].applyContentMutation(lines.joined(separator: "\n"))
        saveSession()
    }

    public func moveCurrentLine(direction: Int) {
        guard let idx = activeTabIndex else { return }
        var lines = LineEndingType.normalizeToLF(tabs[idx].content).components(separatedBy: "\n")
        let lineIdx = max(0, min(tabs[idx].cursorLine - 1, lines.count - 1))
        let targetIdx = lineIdx + direction
        guard targetIdx >= 0 && targetIdx < lines.count else { return }
        lines.swapAt(lineIdx, targetIdx)
        tabs[idx].applyContentMutation(lines.joined(separator: "\n"))
        tabs[idx].cursorLine = targetIdx + 1
        saveSession()
    }

    public func toggleCommentOnActiveDocument() {
        guard let idx = activeTabIndex else { return }
        let prefix = tabs[idx].language.singleLineCommentPrefix ?? "//"
        let updated = TextOperations.toggleSingleLineComment(on: tabs[idx].content, prefix: prefix)
        tabs[idx].applyContentMutation(updated)
        saveSession()
    }

    public func insertDateTime() {
        guard let idx = activeTabIndex else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let stamp = formatter.string(from: Date())
        let ns = tabs[idx].content as NSString
        let offset = max(0, min(tabs[idx].cursorOffset, ns.length))
        let updated = ns.replacingCharacters(in: NSRange(location: offset, length: 0), with: stamp)
        tabs[idx].applyContentMutation(updated, newCursorOffset: offset + stamp.count)
        saveSession()
    }

    // MARK: - Bookmarks (Yer İmleri)
    public func toggleBookmark(line: Int? = nil) {
        guard let idx = activeTabIndex else { return }
        let targetLine = line ?? tabs[idx].cursorLine
        if tabs[idx].bookmarks.contains(targetLine) {
            tabs[idx].bookmarks.remove(targetLine)
        } else {
            tabs[idx].bookmarks.insert(targetLine)
        }
        saveSession()
    }

    public func clearAllBookmarks() {
        guard let idx = activeTabIndex else { return }
        tabs[idx].bookmarks.removeAll()
        saveSession()
    }

    public func invertBookmarks() {
        guard let idx = activeTabIndex else { return }
        let total = tabs[idx].totalLines
        var inverted = Set<Int>()
        for line in 1...total where !tabs[idx].bookmarks.contains(line) {
            inverted.insert(line)
        }
        tabs[idx].bookmarks = inverted
        saveSession()
    }

    public func navigateBookmark(forward: Bool) {
        guard let doc = activeDocument, !doc.bookmarks.isEmpty else { return }
        let sorted = doc.bookmarks.sorted()
        let current = doc.cursorLine
        let targetLine: Int
        if forward {
            targetLine = sorted.first(where: { $0 > current }) ?? sorted.first!
        } else {
            targetLine = sorted.last(where: { $0 < current }) ?? sorted.last!
        }
        jumpToLine(targetLine)
    }

    public func copyBookmarkedLinesToClipboard() {
        guard let doc = activeDocument else { return }
        let text = TextOperations.copyBookmarkedLines(from: doc.content, bookmarks: doc.bookmarks)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    public func cutBookmarkedLinesToClipboard() {
        guard let idx = activeTabIndex else { return }
        let doc = tabs[idx]
        let copied = TextOperations.copyBookmarkedLines(from: doc.content, bookmarks: doc.bookmarks)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(copied, forType: .string)
        let updated = TextOperations.removeBookmarkedLines(from: doc.content, bookmarks: doc.bookmarks)
        tabs[idx].applyContentMutation(updated)
        tabs[idx].bookmarks.removeAll()
        saveSession()
    }

    public func removeBookmarkedLines() {
        guard let idx = activeTabIndex else { return }
        let updated = TextOperations.removeBookmarkedLines(from: tabs[idx].content, bookmarks: tabs[idx].bookmarks)
        tabs[idx].applyContentMutation(updated)
        tabs[idx].bookmarks.removeAll()
        saveSession()
    }

    public func removeUnbookmarkedLines() {
        guard let idx = activeTabIndex else { return }
        let updated = TextOperations.removeUnbookmarkedLines(from: tabs[idx].content, bookmarks: tabs[idx].bookmarks)
        tabs[idx].applyContentMutation(updated)
        tabs[idx].bookmarks.removeAll()
        saveSession()
    }

    public func jumpToLine(_ lineNumber: Int, column: Int = 1) {
        guard let idx = activeTabIndex else { return }
        let doc = tabs[idx]
        let lines = doc.content.components(separatedBy: "\n")
        let clampedLine = max(1, min(lineNumber, max(1, lines.count)))
        var offset = 0
        for i in 0..<(clampedLine - 1) {
            offset += (lines[i] as NSString).length + 1
        }
        let lineLen = clampedLine <= lines.count ? (lines[clampedLine - 1] as NSString).length : 0
        let colOffset = max(0, min(column - 1, lineLen))
        let finalOffset = offset + colOffset

        tabs[idx].cursorLine = clampedLine
        tabs[idx].cursorColumn = colOffset + 1
        tabs[idx].cursorOffset = finalOffset
        tabs[idx].selectionLength = 0
        tabs[idx].selectedLineCount = 0

        requestedJumpRange = NSRange(location: finalOffset, length: 0)
        requestedJumpTrigger = UUID()
    }

    public func jumpToRange(_ range: NSRange, inTabId tabId: UUID? = nil) {
        if let tabId = tabId, tabs.contains(where: { $0.id == tabId }) {
            activeTabId = tabId
        }
        if let idx = activeTabIndex {
            let (ln, col) = lineAndColumn(forOffset: range.location, in: tabs[idx].content)
            tabs[idx].cursorLine = ln
            tabs[idx].cursorColumn = col
            tabs[idx].cursorOffset = range.location
            tabs[idx].selectionLength = range.length
        }
        requestedJumpRange = range
        requestedJumpTrigger = UUID()
    }

    // MARK: - Find / Replace / Mark / Find in Files Engine
    private func buildRegex(for query: String, mode: SearchMode, matchCase: Bool, wholeWord: Bool) -> NSRegularExpression? {
        guard !query.isEmpty else { return nil }
        var pattern: String
        switch mode {
        case .normal:
            pattern = NSRegularExpression.escapedPattern(for: query)
        case .extended:
            let expanded = Self.expandExtendedEscapes(query)
            pattern = NSRegularExpression.escapedPattern(for: expanded)
        case .regex:
            pattern = query
        }

        if wholeWord {
            pattern = "\\b(?:\(pattern))\\b"
        }

        var options: NSRegularExpression.Options = [.anchorsMatchLines]
        if !matchCase {
            options.insert(.caseInsensitive)
        }
        return try? NSRegularExpression(pattern: pattern, options: options)
    }

    private static func expandExtendedEscapes(_ input: String) -> String {
        var result = input
        result = result.replacingOccurrences(of: "\\n", with: "\n")
        result = result.replacingOccurrences(of: "\\r", with: "\r")
        result = result.replacingOccurrences(of: "\\t", with: "\t")
        result = result.replacingOccurrences(of: "\\0", with: "\0")
        result = result.replacingOccurrences(of: "\\\\", with: "\\")
        return result
    }

    public func updateLiveSearchMatches() {
        guard let doc = activeDocument, !searchQuery.isEmpty,
              let regex = buildRegex(for: searchQuery, mode: searchMode, matchCase: matchCase, wholeWord: wholeWord) else {
            liveSearchMatches = []
            searchStatusMessage = ""
            return
        }
        let ns = doc.content as NSString
        let matches = regex.matches(in: doc.content, options: [], range: NSRange(location: 0, length: ns.length))
        liveSearchMatches = matches.map(\.range)
        searchStatusMessage = loc("\(liveSearchMatches.count) eşleşme bulundu", "\(liveSearchMatches.count) matches found")
        if activeSearchMatchIndex >= liveSearchMatches.count {
            activeSearchMatchIndex = 0
        }
    }

    public func findNext(forward: Bool = true) {
        updateLiveSearchMatches()
        guard !liveSearchMatches.isEmpty else {
            searchStatusMessage = loc("Eşleşme bulunamadı: \"\(searchQuery)\"", "No matches: \"\(searchQuery)\"")
            return
        }
        let count = liveSearchMatches.count
        if forward {
            activeSearchMatchIndex = (activeSearchMatchIndex + 1) % count
        } else {
            activeSearchMatchIndex = (activeSearchMatchIndex - 1 + count) % count
        }
        let targetRange = liveSearchMatches[activeSearchMatchIndex]
        jumpToRange(targetRange)
        searchStatusMessage = loc("Eşleşme \(activeSearchMatchIndex + 1) / \(count)", "Match \(activeSearchMatchIndex + 1) / \(count)")
    }

    public func countMatchesInActiveDocument() {
        updateLiveSearchMatches()
        searchStatusMessage = loc("Toplam \(liveSearchMatches.count) kez bulundu.", "Found \(liveSearchMatches.count) times.")
    }

    public func replaceNext() {
        guard let idx = activeTabIndex, !searchQuery.isEmpty else { return }
        updateLiveSearchMatches()
        guard !liveSearchMatches.isEmpty else { return }
        let matchIndex = min(activeSearchMatchIndex, liveSearchMatches.count - 1)
        let targetRange = liveSearchMatches[matchIndex]
        let ns = tabs[idx].content as NSString
        guard NSMaxRange(targetRange) <= ns.length else { return }

        let replacementText = searchMode == .extended ? Self.expandExtendedEscapes(replaceQuery) : replaceQuery
        let updated = ns.replacingCharacters(in: targetRange, with: replacementText)
        tabs[idx].applyContentMutation(updated)
        updateLiveSearchMatches()
        if !liveSearchMatches.isEmpty {
            let nextIdx = min(matchIndex, liveSearchMatches.count - 1)
            jumpToRange(liveSearchMatches[nextIdx])
        }
        saveSession()
    }

    public func replaceAllInActiveDocument() {
        guard let idx = activeTabIndex, !searchQuery.isEmpty,
              let regex = buildRegex(for: searchQuery, mode: searchMode, matchCase: matchCase, wholeWord: wholeWord) else { return }
        let content = tabs[idx].content
        let ns = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else {
            searchStatusMessage = loc("Değiştirilecek eşleşme bulunamadı.", "Nothing to replace.")
            return
        }
        let replacementText = searchMode == .extended ? Self.expandExtendedEscapes(replaceQuery) : replaceQuery
        let replaced = regex.stringByReplacingMatches(
            in: content,
            options: [],
            range: NSRange(location: 0, length: ns.length),
            withTemplate: replacementText
        )
        tabs[idx].applyContentMutation(replaced)
        if isRecordingMacro {
            currentRecordedActions.append(
                .replaceAll(
                    pattern: searchQuery,
                    replacement: replaceQuery,
                    mode: searchMode,
                    matchCase: matchCase,
                    wholeWord: wholeWord
                )
            )
        }
        updateLiveSearchMatches()
        searchStatusMessage = loc("\(matches.count) eşleşme değiştirildi.", "\(matches.count) matches replaced.")
        saveSession()
    }

    public func replaceAllInAllOpenedDocuments() {
        guard !searchQuery.isEmpty,
              let regex = buildRegex(for: searchQuery, mode: searchMode, matchCase: matchCase, wholeWord: wholeWord) else { return }
        var totalReplaced = 0
        let replacementText = searchMode == .extended ? Self.expandExtendedEscapes(replaceQuery) : replaceQuery

        for idx in tabs.indices {
            let content = tabs[idx].content
            let ns = content as NSString
            let count = regex.numberOfMatches(in: content, options: [], range: NSRange(location: 0, length: ns.length))
            if count > 0 {
                tabs[idx].content = regex.stringByReplacingMatches(
                    in: content,
                    options: [],
                    range: NSRange(location: 0, length: ns.length),
                    withTemplate: replacementText
                )
                tabs[idx].isModified = true
                totalReplaced += count
            }
        }
        updateLiveSearchMatches()
        searchStatusMessage = loc("Tüm açık belgelerde toplam \(totalReplaced) eşleşme değiştirildi.", "\(totalReplaced) matches replaced in all open documents.")
        saveSession()
    }

    public func markAllInActiveDocument() {
        guard let idx = activeTabIndex, !searchQuery.isEmpty,
              let regex = buildRegex(for: searchQuery, mode: searchMode, matchCase: matchCase, wholeWord: wholeWord) else { return }
        let content = tabs[idx].content
        let ns = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: ns.length))
        let ranges = matches.map(\.range)
        tabs[idx].markedRanges = ranges

        if bookmarkLineOnMark {
            for r in ranges {
                let (line, _) = lineAndColumn(forOffset: r.location, in: content)
                tabs[idx].bookmarks.insert(line)
            }
        }
        searchStatusMessage = loc("\(ranges.count) eşleşme işaretlendi\(bookmarkLineOnMark ? " ve yer imi eklendi" : "").", "\(ranges.count) matches marked\(bookmarkLineOnMark ? " and bookmarked" : "").")
    }

    public func clearMarksInActiveDocument() {
        guard let idx = activeTabIndex else { return }
        tabs[idx].markedRanges.removeAll()
        searchStatusMessage = loc("İşaretler temizlendi.", "Marks cleared.")
    }

    public func findAllInCurrentDocument() {
        guard let doc = activeDocument, !searchQuery.isEmpty,
              let regex = buildRegex(for: searchQuery, mode: searchMode, matchCase: matchCase, wholeWord: wholeWord) else { return }
        let hits = extractHits(in: doc.content, regex: regex, tabId: doc.id, fileURL: doc.fileURL, fileName: doc.displayTitle)
        let group = FindResultGroup(
            title: loc("\"\(searchQuery)\" — \(doc.displayTitle) (\(hits.count) eşleşme)", "\"\(searchQuery)\" — \(doc.displayTitle) (\(hits.count) matches)"),
            searchTerm: searchQuery,
            timestamp: Date(),
            hits: hits
        )
        searchResultGroups.insert(group, at: 0)
        showSearchResultsDock = true
        searchStatusMessage = loc("\(hits.count) sonuç alt panele listelendi.", "\(hits.count) results listed in the panel below.")
    }

    public func findAllInAllOpenedDocuments() {
        guard !searchQuery.isEmpty,
              let regex = buildRegex(for: searchQuery, mode: searchMode, matchCase: matchCase, wholeWord: wholeWord) else { return }
        var allHits: [FindResultHit] = []
        var fileCount = 0
        for doc in tabs {
            let hits = extractHits(in: doc.content, regex: regex, tabId: doc.id, fileURL: doc.fileURL, fileName: doc.displayTitle)
            if !hits.isEmpty {
                fileCount += 1
                allHits.append(contentsOf: hits)
            }
        }
        let group = FindResultGroup(
            title: loc("\"\(searchQuery)\" — \(fileCount) açık dosyada \(allHits.count) eşleşme", "\"\(searchQuery)\" — \(allHits.count) matches in \(fileCount) open files"),
            searchTerm: searchQuery,
            timestamp: Date(),
            hits: allHits
        )
        searchResultGroups.insert(group, at: 0)
        showSearchResultsDock = true
        searchStatusMessage = loc("\(fileCount) dosyada \(allHits.count) sonuç bulundu.", "\(allHits.count) results in \(fileCount) files.")
    }

    public func findInFiles() {
        guard !searchQuery.isEmpty,
              let regex = buildRegex(for: searchQuery, mode: searchMode, matchCase: matchCase, wholeWord: wholeWord) else { return }
        let dirPath = findInFilesDirectory.isEmpty ? (workspaceFolderURL?.path ?? "") : findInFilesDirectory
        guard !dirPath.isEmpty else {
            searchStatusMessage = loc("Lütfen aranacak klasörü seçin.", "Please choose a folder to search.")
            return
        }
        let rootURL = URL(fileURLWithPath: dirPath)
        let allowedExtensions: Set<String> = Set(
            findInFilesFilter
                .components(separatedBy: CharacterSet(charactersIn: ";, "))
                .map { $0.replacingOccurrences(of: "*.", with: "").lowercased().trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0 != "*" }
        )

        var allHits: [FindResultHit] = []
        var matchedFiles = 0
        if let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let fileURL as URL in enumerator {
                if !allowedExtensions.isEmpty && !allowedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    continue
                }
                guard let data = try? Data(contentsOf: fileURL),
                      data.count <= 2_000_000 else { continue }
                let decoded = TextEncodingOption.decode(data: data)
                let hits = extractHits(in: decoded.text, regex: regex, tabId: nil, fileURL: fileURL, fileName: fileURL.lastPathComponent)
                if !hits.isEmpty {
                    matchedFiles += 1
                    allHits.append(contentsOf: hits)
                }
            }
        }

        let group = FindResultGroup(
            title: loc("\"\(searchQuery)\" — Klasörde \(matchedFiles) dosyada \(allHits.count) eşleşme", "\"\(searchQuery)\" — \(allHits.count) matches in \(matchedFiles) files"),
            searchTerm: searchQuery,
            timestamp: Date(),
            hits: allHits
        )
        searchResultGroups.insert(group, at: 0)
        showSearchResultsDock = true
        searchStatusMessage = loc("Klasör taraması tamamlandı: \(matchedFiles) dosyada \(allHits.count) eşleşme.", "Folder search finished: \(allHits.count) matches in \(matchedFiles) files.")
    }

    private func extractHits(
        in content: String,
        regex: NSRegularExpression,
        tabId: UUID?,
        fileURL: URL?,
        fileName: String
    ) -> [FindResultHit] {
        let ns = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: ns.length))
        let lines = content.components(separatedBy: "\n")

        // Precompute line start offsets for fast lookup
        var lineStarts: [Int] = []
        lineStarts.reserveCapacity(lines.count)
        var acc = 0
        for line in lines {
            lineStarts.append(acc)
            acc += (line as NSString).length + 1
        }

        var hits: [FindResultHit] = []
        for m in matches {
            let loc = m.range.location
            // Binary search line index
            var low = 0
            var high = max(0, lineStarts.count - 1)
            while low <= high {
                let mid = (low + high) / 2
                if lineStarts[mid] <= loc {
                    low = mid + 1
                } else {
                    high = mid - 1
                }
            }
            let lineIdx = max(0, high)
            let col = loc - lineStarts[lineIdx] + 1
            let preview = lineIdx < lines.count ? lines[lineIdx].trimmingCharacters(in: .whitespaces) : ""
            hits.append(
                FindResultHit(
                    tabId: tabId,
                    fileURL: fileURL,
                    fileName: fileName,
                    lineNumber: lineIdx + 1,
                    columnNumber: col,
                    linePreview: preview,
                    matchRangeInDocument: m.range
                )
            )
        }
        return hits
    }

    private func lineAndColumn(forOffset offset: Int, in text: String) -> (Int, Int) {
        let ns = text as NSString
        let clamped = max(0, min(offset, ns.length))
        var line = 1
        var lastNewlineOffset = 0
        for i in 0..<clamped {
            if ns.character(at: i) == 10 { // '\n'
                line += 1
                lastNewlineOffset = i + 1
            }
        }
        return (line, clamped - lastNewlineOffset + 1)
    }

    // MARK: - Macro Recording & Playback
    public func toggleMacroRecording() {
        if isRecordingMacro {
            isRecordingMacro = false
        } else {
            currentRecordedActions.removeAll()
            isRecordingMacro = true
        }
    }

    public func playMacro(actions: [MacroAction]? = nil, repeatCount: Int = 1) {
        let actionsToRun = actions ?? currentRecordedActions
        guard !actionsToRun.isEmpty, let idx = activeTabIndex else { return }
        let count = max(1, repeatCount)

        for _ in 0..<count {
            for action in actionsToRun {
                switch action {
                case .lineOperation(let op):
                    tabs[idx].content = TextOperations.performLineOperation(op, on: tabs[idx].content)
                case .caseConversion(let c):
                    tabs[idx].content = TextOperations.convertCase(c, on: tabs[idx].content)
                case .replaceAll(let pattern, let replacement, let mode, let mc, let ww):
                    if let regex = buildRegex(for: pattern, mode: mode, matchCase: mc, wholeWord: ww) {
                        let ns = tabs[idx].content as NSString
                        tabs[idx].content = regex.stringByReplacingMatches(
                            in: tabs[idx].content,
                            options: [],
                            range: NSRange(location: 0, length: ns.length),
                            withTemplate: replacement
                        )
                    }
                case .appendText(let suffix):
                    tabs[idx].content += suffix
                case .prependText(let prefix):
                    tabs[idx].content = prefix + tabs[idx].content
                case .trimTrailingAndEnsureNewline:
                    tabs[idx].content = TextOperations.performLineOperation(.trimTrailingSpace, on: tabs[idx].content) + "\n"
                }
            }
        }
        tabs[idx].isModified = true
        saveSession()
    }

    // MARK: - Window Pinning (Always on Top)
    private func applyAlwaysOnTop() {
        for window in NSApplication.shared.windows {
            window.level = isAlwaysOnTop ? .floating : .normal
        }
    }

    // MARK: - Hot Exit Session Persistence
    private var saveSessionDebounceTask: Task<Void, Never>?

    private var sessionFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MacNotePP", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("session.json")
    }

    public func scheduleSaveSession() {
        saveSessionDebounceTask?.cancel()
        saveSessionDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            self?.saveSession()
        }
    }

    public func saveSession() {
        let persistedTabs = tabs.map { doc in
            // Protect session.json from ballooning to hundreds of megabytes
            let shouldOmitMassiveContent = (doc.fileURL != nil && !doc.isModified && doc.content.utf8.count > 500_000)
            return PersistedSessionTab(
                id: doc.id,
                title: doc.title,
                filePath: doc.fileURL?.path,
                content: shouldOmitMassiveContent ? "" : doc.content,
                isModified: doc.isModified,
                isPinned: doc.isPinned,
                isReadOnly: doc.isReadOnly,
                isPartialPreview: doc.isPartialPreview,
                totalFileSize: doc.totalFileSize,
                language: doc.language,
                isLanguageManuallySet: doc.isLanguageManuallySet,
                encoding: doc.encoding,
                lineEnding: doc.lineEnding,
                viewMode: doc.viewMode,
                bookmarks: Array(doc.bookmarks),
                cursorLine: doc.cursorLine,
                cursorColumn: doc.cursorColumn,
                cursorOffset: doc.cursorOffset,
                lastSavedDate: doc.isModified ? doc.lastSavedDate : nil,
                unsavedBytes: (doc.isModified && doc.viewMode == .hex) ? doc.rawData : nil
            )
        }
        let state = PersistedSessionState(
            tabs: persistedTabs,
            activeTabId: activeTabId,
            theme: theme,
            fontSize: fontSize,
            wordWrap: wordWrap,
            showInvisibleCharacters: showInvisibleCharacters,
            showLineNumbers: showLineNumbers,
            workspaceFolderPath: workspaceFolderURL?.path,
            showLeftWorkspaceSidebar: showLeftWorkspaceSidebar,
            showRightSidebar: showRightSidebar,
            showMinimap: showMinimap,
            showSearchResultsDock: showSearchResultsDock
        )
        if let encoded = try? JSONEncoder().encode(state) {
            try? encoded.write(to: sessionFileURL, options: .atomic)
        }
    }

    private func loadSessionOrDefault() {
        if let data = try? Data(contentsOf: sessionFileURL),
           let state = try? JSONDecoder().decode(PersistedSessionState.self, from: data) {
            self.theme = state.theme
            self.fontSize = state.fontSize
            self.wordWrap = state.wordWrap
            self.showInvisibleCharacters = state.showInvisibleCharacters
            self.showLineNumbers = state.showLineNumbers
            if let folderPath = state.workspaceFolderPath {
                self.workspaceFolderURL = URL(fileURLWithPath: folderPath)
            }
            if let left = state.showLeftWorkspaceSidebar {
                self.showLeftWorkspaceSidebar = left
            }
            if let right = state.showRightSidebar {
                self.showRightSidebar = right
            }
            if let minimap = state.showMinimap {
                self.showMinimap = minimap
            }
            if let dock = state.showSearchResultsDock {
                self.showSearchResultsDock = dock
            }

            if restoreSessionOnStartup && !state.tabs.isEmpty {
                let restored: [EditorDocument] = state.tabs.compactMap { pt in
                    let url = pt.filePath.map { URL(fileURLWithPath: $0) }
                    let diskAttributes = url.flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path) }
                    let diskSize = (diskAttributes?[.size] as? NSNumber)?.int64Value ?? 0
                    let diskDate = diskAttributes?[.modificationDate] as? Date

                    var isPartial = pt.isPartialPreview ?? false
                    var totalSize = pt.totalFileSize
                    if let total = totalSize {
                        if total == 0 && diskSize > 0 { totalSize = diskSize }
                    } else if diskSize > 0 {
                        totalSize = diskSize
                    }

                    // Auto-detect if this was a partial preview from earlier sessions
                    if diskSize >= 50 * 1024 * 1024 && pt.content.utf8.count <= 25 * 1024 * 1024 {
                        isPartial = true
                        totalSize = diskSize
                    }

                    let isReadOnly = isPartial || (pt.isReadOnly ?? (diskSize >= 20 * 1024 * 1024))

                    var content = pt.content
                    var encoding = pt.encoding
                    var lineEnding = pt.lineEnding
                    var isModified = pt.isModified
                    var diskData: Data?
                    // A tab without unsaved changes shows the file as it is now, not as it was last session.
                    if !pt.isModified, let fileURL = url {
                        if isPartial {
                            if let fh = try? FileHandle(forReadingFrom: fileURL) {
                                defer { try? fh.close() }
                                diskData = fh.readData(ofLength: 10 * 1024 * 1024)
                            }
                        } else if diskSize < 50 * 1024 * 1024 {
                            diskData = try? Data(contentsOf: fileURL)
                        }
                        if let diskData {
                            let decoded = TextEncodingOption.decode(data: diskData)
                            content = decoded.text
                            encoding = decoded.encoding
                            lineEnding = decoded.lineEnding
                        } else if content.isEmpty {
                            return nil // The file is gone and no copy of it was kept.
                        } else {
                            isModified = true // The file is gone: keep the text, as unsaved.
                        }
                    }

                    let raw: Data?
                    if let exact = pt.unsavedBytes ?? diskData, exact.count <= 20 * 1024 * 1024 {
                        raw = exact
                    } else {
                        raw = (content.utf16.count <= 20 * 1024 * 1024) ? encoding.encode(text: content, lineEnding: lineEnding) : nil
                    }
                    return EditorDocument(
                        id: pt.id,
                        title: pt.title,
                        fileURL: url,
                        content: content,
                        rawData: raw,
                        isModified: isModified,
                        isPinned: pt.isPinned,
                        isReadOnly: isReadOnly,
                        isPartialPreview: isPartial,
                        totalFileSize: totalSize,
                        language: pt.language,
                        isLanguageManuallySet: pt.isLanguageManuallySet,
                        encoding: encoding,
                        lineEnding: lineEnding,
                        viewMode: pt.viewMode,
                        bookmarks: Set(pt.bookmarks),
                        cursorLine: pt.cursorLine,
                        cursorColumn: pt.cursorColumn,
                        cursorOffset: pt.cursorOffset,
                        lastSavedDate: isModified ? pt.lastSavedDate : diskDate
                    )
                }
                if restored.isEmpty {
                    self.newTab(title: "new 1")
                    return
                }
                self.tabs = restored
                self.activeTabId = restored.contains(where: { $0.id == state.activeTabId }) ? state.activeTabId : restored.first?.id
                return
            } else if !restoreSessionOnStartup {
                // Kullanıcı ayarlarında başlangıçta önceki oturumu açma kapalı ise:
                // Temiz yeni bir metin belgesi ile başla
                self.tabs = []
                self.newTab(title: "new 1")
                return
            }
        }

        // First launch
        self.tabs = []
        self.newTab(title: "new 1")
    }

}

// MARK: - Large File Guard Models
public struct PendingLargeFileInfo: Identifiable {
    public let id = UUID()
    public let url: URL
    public let sizeBytes: Int64

    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }

    public var sizeInMB: Double {
        Double(sizeBytes) / (1024.0 * 1024.0)
    }
}

public enum LargeFileOpenAction {
    case partialPreview(limitMB: Int)
    case hexView
    case fullOpen
    case cancel
}
