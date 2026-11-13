import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct NPPToolbarView: View {
    @ObservedObject var appState: AppState
    @State private var draggedItem: ToolbarItemID? = nil
    @State private var dropTargetItem: ToolbarItemID? = nil

    public init(appState: AppState) {
        self.appState = appState
    }

    private var visibleOrderedItems: [ToolbarItemID] {
        if appState.isToolbarEditMode {
            return appState.toolbarItemOrder
        }
        return appState.toolbarItemOrder.filter { appState.isToolbarItemVisible($0) }
    }

    public var body: some View {
        let _ = appState.languageRefreshTrigger
        VStack(spacing: 0) {
            // Optional Edit Mode Banner Bar
            if appState.isToolbarEditMode {
                HStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.orange)
                    Text(appState.loc("Araç Çubuğu Düzenleme Modu:", "Toolbar Edit Mode:"))
                        .font(.system(size: 11, weight: .bold))
                    Text(appState.loc("Özellikleri fare ile sürükleyip bırakarak sıralayın, gizlemek/açmak için göz ikonuna tıklayın.", "Drag and drop items to reorder, click eye icon to hide or show."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Toggle(appState.loc("Çok Satırlı (Küçük Ekran)", "Multi-Row (Small Screen)"), isOn: $appState.isMultiRowToolbar)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                        .font(.system(size: 11, weight: .medium))

                    if !appState.hiddenToolbarItems.isEmpty {
                        Button("\(appState.loc("Tümünü Göster", "Show All")) (\(appState.hiddenToolbarItems.count) \(appState.loc("Gizli", "Hidden")))") {
                            appState.showAllToolbarItems()
                        }
                        .controlSize(.small)
                    }

                    Button(appState.loc("Varsayılana Sıfırla", "Reset to Defaults")) {
                        appState.resetToolbarToDefaults()
                    }
                    .controlSize(.small)

                    Button(appState.loc("Ayarlar...", "Settings...")) {
                        appState.showSettingsSheet = true
                    }
                    .controlSize(.small)

                    Button(appState.loc("Düzenlemeyi Bitir", "Done Editing")) {
                        appState.isToolbarEditMode = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.14))

                Divider()
            }

            // Main Toolbar Content: Multi-Row Flow Layout vs Single-Row Horizontal Scroll
            if appState.isMultiRowToolbar || appState.isToolbarEditMode {
                ToolbarWrapLayout(horizontalSpacing: 4, verticalSpacing: 5) {
                    brandBadge
                    ForEach(visibleOrderedItems) { item in
                        toolbarItemWrapper(for: item)
                    }
                    systemTrailingControls
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        brandBadge
                        ForEach(visibleOrderedItems) { item in
                            toolbarItemWrapper(for: item)
                        }
                        Spacer(minLength: 8)
                        systemTrailingControls
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
        .contextMenu {
            Button {
                appState.isToolbarEditMode.toggle()
            } label: {
                Label(
                    appState.isToolbarEditMode
                        ? appState.loc("Toolbar Düzenleme Modunu Kapat", "Close Toolbar Edit Mode")
                        : appState.loc("Toolbar'ı Düzenle (Gizle / Göster / Sırala)", "Customize Toolbar (Hide / Show / Reorder)"),
                    systemImage: "slider.horizontal.3"
                )
            }

            Toggle(appState.loc("Çok Satırlı Araç Çubuğu (Küçük Ekranlar İçin Kaydır)", "Multi-Row Toolbar (Wrap for Narrow Screens)"), isOn: $appState.isMultiRowToolbar)

            if !appState.hiddenToolbarItems.isEmpty {
                Button("\(appState.loc("Gizlenen Tüm Araçları Geri Aç", "Show All Hidden Tools")) (\(appState.hiddenToolbarItems.count))") {
                    appState.showAllToolbarItems()
                }
            }

            Divider()

            Button {
                appState.showSettingsSheet = true
            } label: {
                Label(appState.loc("Ayarlar Penceresini Aç... (⌘,)", "Open Settings & Preferences... (⌘,)"), systemImage: "gearshape")
            }
        }
    }

    // MARK: - Brand Emblem
    private var brandBadge: some View {
        HStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.16, green: 0.68, blue: 0.28), Color(red: 0.06, green: 0.42, blue: 0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                Text("N+")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
        .padding(.trailing, 2)
        .help("MacNote++ — Native macOS Text & Hex Editor")
    }

    // MARK: - Always-Visible Toolbar Customization & Settings Controls
    private var systemTrailingControls: some View {
        HStack(spacing: 3) {
            ToolbarDivider()

            ToolIconButton(
                icon: appState.isMultiRowToolbar ? "rectangle.split.1x2.fill" : "rectangle.split.1x2",
                tooltip: appState.isMultiRowToolbar
                    ? appState.loc("Tek satırlı araç çubuğuna geç", "Switch to a single-row toolbar")
                    : appState.loc("Çok satırlı araç çubuğuna geç", "Switch to a multi-row toolbar"),
                isActive: appState.isMultiRowToolbar
            ) {
                appState.isMultiRowToolbar.toggle()
            }

            ToolIconButton(
                icon: "slider.horizontal.3",
                tooltip: appState.isToolbarEditMode
                    ? appState.loc("Özelleştirmeyi bitir", "Finish customizing")
                    : appState.loc("Araç çubuğunu özelleştir", "Customize toolbar"),
                isActive: appState.isToolbarEditMode,
                tint: appState.isToolbarEditMode ? .orange : nil
            ) {
                appState.isToolbarEditMode.toggle()
            }

            ToolIconButton(
                icon: "gearshape.fill",
                tooltip: appState.loc("Ayarlar (⌘,)", "Settings (⌘,)")
            ) {
                appState.showSettingsSheet = true
            }
        }
    }

    // MARK: - Item Wrapper (Normal vs Edit Mode Overlay with Drag & Drop)
    @ViewBuilder
    private func toolbarItemWrapper(for item: ToolbarItemID) -> some View {
        if appState.isToolbarEditMode {
            let isVisible = appState.isToolbarItemVisible(item)
            let isBeingDragged = (draggedItem == item)
            let isDropTarget = (dropTargetItem == item)

            HStack(spacing: 3) {
                // Drag handle grip
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.85))
                    .frame(width: 10, height: 22)
                    .help(appState.loc("Sürükleyerek sıralayın: \(item.title(for: appState.language))", "Drag to reorder: \(item.title(for: appState.language))"))

                Button {
                    appState.moveToolbarItem(item, direction: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 10, height: 22)
                }
                .buttonStyle(.plain)
                .help(appState.loc("Sola taşı: \(item.title(for: appState.language))", "Move left: \(item.title(for: appState.language))"))

                toolbarItemContent(for: item)
                    .opacity(isVisible ? 1.0 : 0.35)
                    .allowsHitTesting(false)

                Button {
                    appState.toggleToolbarItemVisibility(item)
                } label: {
                    Image(systemName: isVisible ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isVisible ? Color.green : Color.red)
                        .frame(width: 18, height: 22)
                }
                .buttonStyle(.plain)
                .help(isVisible ? appState.loc("Gizle: \(item.title(for: appState.language))", "Hide: \(item.title(for: appState.language))") : appState.loc("Göster: \(item.title(for: appState.language))", "Show: \(item.title(for: appState.language))"))

                Button {
                    appState.moveToolbarItem(item, direction: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 10, height: 22)
                }
                .buttonStyle(.plain)
                .help(appState.loc("Sağa taşı: \(item.title(for: appState.language))", "Move right: \(item.title(for: appState.language))"))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isBeingDragged
                            ? Color.orange.opacity(0.20)
                            : (isDropTarget
                                ? Color.accentColor.opacity(0.25)
                                : (isVisible ? Color.accentColor.opacity(0.08) : Color.red.opacity(0.08)))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isDropTarget
                            ? Color.orange
                            : (isVisible ? Color.accentColor.opacity(0.45) : Color.red.opacity(0.45)),
                        style: StrokeStyle(lineWidth: isDropTarget ? 2 : 1, dash: isVisible ? [] : [3, 2])
                    )
            )
            .scaleEffect(isDropTarget ? 1.04 : (isBeingDragged ? 0.96 : 1.0))
            .animation(.easeInOut(duration: 0.15), value: isDropTarget)
            .onDrag {
                self.draggedItem = item
                return NSItemProvider(object: item.rawValue as NSString)
            }
            .onDrop(
                of: [UTType.text.identifier, UTType.plainText.identifier],
                delegate: ToolbarItemDropDelegate(
                    targetItem: item,
                    draggedItem: $draggedItem,
                    dropTargetItem: $dropTargetItem,
                    appState: appState
                )
            )
        } else {
            toolbarItemContent(for: item)
        }
    }

    // MARK: - Individual Customizable Toolbar Items
    @ViewBuilder
    private func toolbarItemContent(for item: ToolbarItemID) -> some View {
        switch item {
        case .newTab:
            ToolIconButton(icon: "doc.badge.plus", tooltip: appState.loc("Yeni Sekme (⌘N)", "New Tab (⌘N)")) {
                appState.newTab()
            }

        case .openFile:
            ToolIconButton(icon: "folder", tooltip: appState.loc("Dosya Aç... (⌘O)", "Open File... (⌘O)")) {
                appState.openFilesPanel()
            }

        case .saveFile:
            ToolIconButton(
                icon: "internaldrive",
                tooltip: appState.loc("Kaydet (⌘S)", "Save (⌘S)"),
                tint: (appState.activeDocument?.isModified == true) ? .red : .blue
            ) {
                appState.saveActiveTab()
            }

        case .saveAll:
            ToolIconButton(icon: "externaldrive.badge.checkmark", tooltip: appState.loc("Tümünü Kaydet (⌥⌘S)", "Save All (⌥⌘S)")) {
                appState.saveAllTabs()
            }

        case .printDocument:
            ToolIconButton(
                icon: "printer",
                tooltip: appState.loc("Yazdır / Yazdırma Önizleme (⌘P)", "Print / Preview (⌘P)")
            ) {
                appState.showPrintPreviewSheet = true
            }

        case .closeTab:
            HStack(spacing: 2) {
                ToolIconButton(icon: "xmark.square", tooltip: appState.loc("Aktif Sekmeyi Kapat (⌘W)", "Close Active Tab (⌘W)")) {
                    if let id = appState.activeTabId {
                        appState.closeTab(id: id)
                    }
                }
                ToolbarDivider()
            }

        case .cutCopyPaste:
            HStack(spacing: 2) {
                ToolIconButton(icon: "scissors", tooltip: appState.loc("Kes (⌘X)", "Cut (⌘X)")) {
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                }
                ToolIconButton(icon: "doc.on.doc", tooltip: appState.loc("Kopyala (⌘C)", "Copy (⌘C)")) {
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                }
                ToolIconButton(icon: "doc.on.clipboard", tooltip: appState.loc("Yapıştır (⌘V)", "Paste (⌘V)")) {
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                }
            }

        case .undoRedo:
            HStack(spacing: 2) {
                ToolIconButton(
                    icon: "arrow.uturn.backward",
                    tooltip: appState.loc("Geri Al (⌘Z / Ctrl+Z)", "Undo (⌘Z)"),
                    tint: appState.canUndo ? .blue : .secondary
                ) {
                    appState.performUndo()
                }
                ToolIconButton(
                    icon: "arrow.uturn.forward",
                    tooltip: appState.loc("İleri Al / Yinele (⇧⌘Z / Ctrl+Y)", "Redo (⇧⌘Z)"),
                    tint: appState.canRedo ? .blue : .secondary
                ) {
                    appState.performRedo()
                }
                ToolbarDivider()
            }

        case .findReplace:
            ToolIconButton(
                icon: "magnifyingglass",
                tooltip: appState.loc("Bul / Değiştir / Dosyalarda Bul (⌘F)", "Find / Replace / In Files (⌘F)"),
                isActive: appState.showFindPanel
            ) {
                appState.showFindPanel.toggle()
            }

        case .goToLine:
            ToolIconButton(icon: "arrow.right.to.line", tooltip: appState.loc("Satıra Git... (⌘G)", "Go to Line... (⌘G)")) {
                appState.showGoToLineSheet = true
            }

        case .columnEditor:
            ToolIconButton(
                icon: "rectangle.split.3x1",
                tooltip: appState.loc("Sütun / Çoklu Satır Düzenleyici (⌥C)", "Column Editor (⌥C)")
            ) {
                appState.showColumnEditorSheet = true
            }

        case .multiCaret:
            HStack(spacing: 2) {
                Menu {
                    Button(appState.loc("Sütun Düzenleyici (⌥C)...", "Column Editor (⌥C)...")) {
                        appState.showColumnEditorSheet = true
                    }
                    Divider()
                    Button(appState.loc("Üst Satıra İmleç Ekle (⌥⇧↑)", "Add Cursor Above (⌥⇧↑)")) {
                        appState.triggerMultiCaret(.addCursorAbove)
                    }
                    Button(appState.loc("Alt Satıra İmleç Ekle (⌥⇧↓)", "Add Cursor Below (⌥⇧↓)")) {
                        appState.triggerMultiCaret(.addCursorBelow)
                    }
                    Button(appState.loc("Seçili Satırların Sonuna Çoklu İmleç Koy (⌥⇧I)", "Add Cursors to Ends of Lines (⌥⇧I)")) {
                        appState.triggerMultiCaret(.addCursorsToSelectedLinesEnd)
                    }
                    Button(appState.loc("Seçili Satırların Başına Çoklu İmleç Koy", "Add Cursors to Starts of Lines")) {
                        appState.triggerMultiCaret(.addCursorsToSelectedLinesStart)
                    }
                    if appState.activeMultiCaretCount > 1 {
                        Divider()
                        Button(appState.loc("Çoklu İmleçten Çık / Tek İmlece Dön (Esc)", "Clear Extra Cursors (Esc)")) {
                            appState.triggerMultiCaret(.clearExtraCursors)
                        }
                    }
                } label: {
                    Image(systemName: "cursorarrow.motionlines")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(appState.activeMultiCaretCount > 1 ? Color.orange : Color.primary)
                        .frame(width: 26, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(appState.activeMultiCaretCount > 1 ? Color.orange.opacity(0.20) : Color.clear)
                        )
                }
                .menuStyle(.borderlessButton)
                .focusable(false)
                .fixedSize()
                .help(appState.loc("Çoklu İmleç (Multi-Cursor): ⌥+Tık, ⌥+Sürükle veya ⌥⇧↑/↓ ile birden fazla satıra aynı anda yazın", "Multi-Cursor: Option+Click or Option+Shift+Up/Down"))

                ToolbarDivider()
            }

        case .wordWrap:
            ToolIconButton(
                icon: "text.word.spacing",
                tooltip: appState.loc("Sözcük Kaydırma (Word Wrap - ⌥⌘W)", "Word Wrap (⌥⌘W)"),
                isActive: appState.wordWrap
            ) {
                appState.wordWrap.toggle()
            }

        case .showInvisibles:
            ToolIconButton(
                icon: "paragraphsign",
                tooltip: appState.loc("Tüm Karakterleri Göster (Boşluk, TAB, CRLF/LF)", "Show Invisibles (Space, TAB, EOL)"),
                isActive: appState.showInvisibleCharacters
            ) {
                appState.showInvisibleCharacters.toggle()
            }

        case .zoomControls:
            HStack(spacing: 2) {
                ToolIconButton(icon: "plus.magnifyingglass", tooltip: appState.loc("Yakınlaştır (⌘+)", "Zoom In (⌘+)")) {
                    appState.fontSize = min(32, appState.fontSize + 1)
                }
                ToolIconButton(icon: "minus.magnifyingglass", tooltip: appState.loc("Uzaklaştır (⌘-)", "Zoom Out (⌘-)")) {
                    appState.fontSize = max(9, appState.fontSize - 1)
                }
                ToolIconButton(icon: "1.magnifyingglass", tooltip: appState.loc("Varsayılan Boyut (⌘0)", "Default Zoom (⌘0)")) {
                    appState.fontSize = 13.0
                }
                ToolbarDivider()
            }

        case .bookmarks:
            HStack(spacing: 2) {
                ToolIconButton(
                    icon: "bookmark.fill",
                    tooltip: appState.loc("Satıra Yer İmi Ekle / Kaldır (⌘F2)", "Toggle Bookmark (⌘F2 / F2)"),
                    tint: .cyan
                ) {
                    appState.toggleBookmark()
                }
                ToolIconButton(icon: "chevron.down.circle", tooltip: appState.loc("Sonraki Yer İmi (F2)", "Next Bookmark (F2)")) {
                    appState.navigateBookmark(forward: true)
                }
                ToolIconButton(icon: "chevron.up.circle", tooltip: appState.loc("Önceki Yer İmi (⇧F2)", "Previous Bookmark (⇧F2)")) {
                    appState.navigateBookmark(forward: false)
                }
                ToolbarDivider()
            }

        case .compareDiff:
            ToolIconButton(
                icon: "arrow.left.and.right.square.fill",
                tooltip: appState.loc("Dosya Karşılaştır / Diff", "Compare Files / Diff"),
                isActive: appState.isCompareMode,
                tint: .orange
            ) {
                appState.toggleCompareMode()
            }

        case .hexView:
            ToolIconButton(
                icon: "00.square.fill",
                tooltip: appState.loc("Hex Görünümü (⇧⌘H)", "Hex Editor View (⇧⌘H)"),
                isActive: appState.activeDocument?.viewMode == .hex,
                tint: .purple
            ) {
                appState.toggleHexView()
            }

        case .markdownPreview:
            HStack(spacing: 2) {
                ToolIconButton(
                    icon: "doc.richtext.fill",
                    tooltip: appState.loc("Markdown Canlı Önizleme (⌥⌘M)", "Markdown Live Preview (⌥⌘M)"),
                    isActive: appState.showMarkdownPreview,
                    tint: .blue
                ) {
                    appState.showMarkdownPreview.toggle()
                }
                ToolbarDivider()
            }

        case .lineOperations:
            Menu {
                ForEach(LineOperationType.allCases, id: \.self) { op in
                    Button(op.title(for: appState.language)) {
                        appState.applyLineOperation(op)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down.square")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 26, height: 24)
            }
            .menuStyle(.borderlessButton)
            .focusable(false)
            .fixedSize()
            .help(appState.loc("Satır sıralama, tekrarlayan/boş satır silme işlemleri", "Line operations: sort, delete duplicates/empty"))

        case .macros:
            HStack(spacing: 2) {
                ToolIconButton(
                    icon: appState.isRecordingMacro ? "stop.circle.fill" : "record.circle",
                    tooltip: appState.isRecordingMacro
                        ? appState.loc("Makro Kaydını Durdur", "Stop Macro Recording")
                        : appState.loc("Makro Kaydını Başlat", "Start Macro Recording"),
                    isActive: appState.isRecordingMacro,
                    tint: .red
                ) {
                    appState.toggleMacroRecording()
                }
                ToolIconButton(
                    icon: "play.fill",
                    tooltip: appState.loc("Kaydedilen Makroyu Oynat", "Playback Macro"),
                    tint: .green
                ) {
                    appState.playMacro()
                }
                ToolIconButton(
                    icon: "forward.end.alt.fill",
                    tooltip: appState.loc("Makroyu Çoklu Çalıştır...", "Run Macro Multiple Times...")
                ) {
                    appState.showRunMacroSheet = true
                }
                ToolbarDivider()
            }

        case .sidebarsAndPanels:
            HStack(spacing: 2) {
                ToolIconButton(
                    icon: "sidebar.left",
                    tooltip: appState.loc("Çalışma Klasörü Paneli", "Workspace Folder Sidebar"),
                    isActive: appState.showLeftWorkspaceSidebar
                ) {
                    appState.showLeftWorkspaceSidebar.toggle()
                }
                ToolIconButton(
                    icon: "list.bullet.indent",
                    tooltip: appState.loc("Fonksiyon Listesi & Yer İmleri Paneli", "Function List & Bookmarks Sidebar"),
                    isActive: appState.showRightSidebar
                ) {
                    appState.showRightSidebar.toggle()
                }
                ToolIconButton(
                    icon: "dock.rectangle",
                    tooltip: appState.loc("Arama Sonuçları Alt Paneli", "Search Results Dock"),
                    isActive: appState.showSearchResultsDock
                ) {
                    appState.showSearchResultsDock.toggle()
                }
            }

        case .toolsMenu:
            toolsUnifiedMenu

        case .alwaysOnTop:
            ToolIconButton(
                icon: appState.isAlwaysOnTop ? "pin.fill" : "pin",
                tooltip: appState.loc("Her Zaman Üstte Tut (Always on Top)", "Always on Top"),
                isActive: appState.isAlwaysOnTop
            ) {
                appState.isAlwaysOnTop.toggle()
            }

        case .documentSummary:
            ToolIconButton(icon: "chart.bar.doc.horizontal", tooltip: appState.loc("Belge Özeti ve İstatistikler", "Document Summary & Stats")) {
                appState.showSummarySheet = true
            }

        case .shortcutPicker:
            Menu {
                ForEach(ShortcutScheme.allCases) { scheme in
                    Button {
                        appState.shortcutScheme = scheme
                    } label: {
                        Text(appState.shortcutScheme == scheme ? "✓ \(scheme.title(for: appState.language))" : scheme.title(for: appState.language))
                    }
                }
            } label: {
                Image(systemName: "keyboard")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 26, height: 24)
            }
            .menuStyle(.borderlessButton)
            .focusable(false)
            .fixedSize()
            .help("\(appState.loc("Kısayollar", "Shortcuts")): \(appState.shortcutScheme.title(for: appState.language))")

        case .themePicker:
            Menu {
                ForEach(EditorTheme.allCases) { t in
                    Button {
                        appState.theme = t
                    } label: {
                        Text(appState.theme == t ? "✓ \(t.title(for: appState.language))" : t.title(for: appState.language))
                    }
                }
            } label: {
                Image(systemName: "paintpalette")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 26, height: 24)
            }
            .menuStyle(.borderlessButton)
            .focusable(false)
            .fixedSize()
            .help("\(appState.loc("Tema", "Theme")): \(appState.theme.title(for: appState.language))")
        }
    }

    // MARK: - Unified Compact Grouped Menu
    private var toolsUnifiedMenu: some View {
        HStack(spacing: 2) {
            Menu {
                Menu(appState.loc("Görünüm", "View")) {
                    Toggle(appState.loc("Hex Görünümü", "Hex View"), isOn: Binding(
                        get: { appState.activeDocument?.viewMode == .hex },
                        set: { _ in appState.toggleHexView() }
                    ))
                    Toggle(appState.loc("Markdown Önizleme", "Markdown Preview"), isOn: $appState.showMarkdownPreview)
                    Toggle(appState.loc("Karşılaştır", "Compare"), isOn: Binding(
                        get: { appState.isCompareMode },
                        set: { _ in appState.toggleCompareMode() }
                    ))

                    Divider()

                    Toggle(appState.loc("Sözcük Kaydırma", "Word Wrap"), isOn: $appState.wordWrap)
                    Toggle(appState.loc("Görünmez Karakterler", "Invisible Characters"), isOn: $appState.showInvisibleCharacters)
                    Toggle(appState.loc("Kod Haritası", "Minimap"), isOn: $appState.showMinimap)

                    Divider()

                    Button(appState.loc("Yakınlaştır", "Zoom In")) {
                        appState.fontSize = min(32, appState.fontSize + 1)
                    }
                    Button(appState.loc("Uzaklaştır", "Zoom Out")) {
                        appState.fontSize = max(9, appState.fontSize - 1)
                    }
                    Button(appState.loc("Gerçek Boyut", "Actual Size")) {
                        appState.fontSize = 13.0
                    }
                }

                Menu(appState.loc("Satır", "Line")) {
                    ForEach(LineOperationType.allCases, id: \.self) { op in
                        Button(op.title(for: appState.language)) {
                            appState.applyLineOperation(op)
                        }
                    }
                }

                Menu(appState.activeMultiCaretCount > 1
                    ? "\(appState.loc("Çoklu İmleç", "Multiple Cursors")) (\(appState.activeMultiCaretCount))"
                    : appState.loc("Çoklu İmleç", "Multiple Cursors")) {
                    Button(appState.loc("Üste İmleç Ekle", "Add Cursor Above")) {
                        appState.triggerMultiCaret(.addCursorAbove)
                    }
                    Button(appState.loc("Alta İmleç Ekle", "Add Cursor Below")) {
                        appState.triggerMultiCaret(.addCursorBelow)
                    }
                    Button(appState.loc("Satır Sonlarına İmleç Koy", "Add Cursors to Line Ends")) {
                        appState.triggerMultiCaret(.addCursorsToSelectedLinesEnd)
                    }
                    Button(appState.loc("Satır Başlarına İmleç Koy", "Add Cursors to Line Starts")) {
                        appState.triggerMultiCaret(.addCursorsToSelectedLinesStart)
                    }
                    Divider()
                    Button(appState.loc("Sütun Düzenleyici...", "Column Editor...")) {
                        appState.showColumnEditorSheet = true
                    }
                    if appState.activeMultiCaretCount > 1 {
                        Button(appState.loc("Tek İmlece Dön", "Single Cursor")) {
                            appState.triggerMultiCaret(.clearExtraCursors)
                        }
                    }
                }

                Menu(appState.isRecordingMacro
                    ? appState.loc("Makro (Kaydediliyor)", "Macro (Recording)")
                    : appState.loc("Makro", "Macro")) {
                    Toggle(appState.loc("Kayıt", "Record"), isOn: Binding(
                        get: { appState.isRecordingMacro },
                        set: { _ in appState.toggleMacroRecording() }
                    ))
                    Button(appState.loc("Oynat", "Play")) {
                        appState.playMacro()
                    }
                    Button(appState.loc("Çok Kez Oynat...", "Play Multiple Times...")) {
                        appState.showRunMacroSheet = true
                    }
                }

                Divider()

                Menu(appState.loc("Tema", "Theme")) {
                    ForEach(EditorTheme.allCases) { t in
                        Toggle(t.title(for: appState.language), isOn: Binding(get: { appState.theme == t }, set: { _ in appState.theme = t }))
                    }
                }

                Menu(appState.loc("Kısayollar", "Shortcuts")) {
                    ForEach(ShortcutScheme.allCases) { scheme in
                        Toggle(scheme.title(for: appState.language), isOn: Binding(
                            get: { appState.shortcutScheme == scheme },
                            set: { _ in appState.shortcutScheme = scheme }
                        ))
                    }
                }

                Menu(appState.loc("Dil", "Language")) {
                    ForEach(AppLanguage.allCases) { lang in
                        Toggle("\(lang.flag) \(lang.displayName)", isOn: Binding(
                            get: { appState.appLanguage == lang },
                            set: { _ in appState.appLanguage = lang }
                        ))
                    }
                }

                Divider()

                Button(appState.loc("Belge Bilgisi...", "Document Info...")) {
                    appState.showSummarySheet = true
                }

                Button(appState.loc("MacNote++ Hakkında", "About MacNote++")) {
                    appState.showAboutWindow()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(appState.loc("Menü", "Menu"))
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.secondary.opacity(0.12))
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .focusable(false)
            .fixedSize()
            .help(appState.loc("Görünüm, satır işlemleri, makro ve tema", "View, line tools, macros and theme"))

            ToolbarDivider()
        }
    }
}

// MARK: - Responsive Multi-Row Flow Layout for Smaller / Narrower Screens
public struct ToolbarWrapLayout: Layout {
    public var horizontalSpacing: CGFloat
    public var verticalSpacing: CGFloat

    public init(horizontalSpacing: CGFloat = 4, verticalSpacing: CGFloat = 5) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = max(240, proposal.width ?? 1000)
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > 0 && currentX + size.width > maxWidth {
                maxRowWidth = max(maxRowWidth, currentX - horizontalSpacing)
                currentX = 0
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }
            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
        maxRowWidth = max(maxRowWidth, max(0, currentX - horizontalSpacing))
        let totalHeight = currentY + rowHeight
        return CGSize(width: proposal.width ?? maxRowWidth, height: max(26, totalHeight))
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = max(240, bounds.width)
        var rows: [[(subview: LayoutSubview, size: CGSize)]] = [[]]
        var currentRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if !rows[rows.count - 1].isEmpty && currentRowWidth + size.width > maxWidth {
                rows.append([])
                currentRowWidth = 0
            }
            rows[rows.count - 1].append((subview, size))
            currentRowWidth += size.width + horizontalSpacing
        }

        var yOffset = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.size.height }.max() ?? 24
            var xOffset = bounds.minX
            for item in row {
                let yCentered = yOffset + (rowHeight - item.size.height) / 2.0
                item.subview.place(
                    at: CGPoint(x: xOffset, y: yCentered),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                xOffset += item.size.width + horizontalSpacing
            }
            yOffset += rowHeight + verticalSpacing
        }
    }
}

private struct ToolIconButton: View {
    let icon: String
    let tooltip: String
    var isActive: Bool = false
    var tint: Color? = nil
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? Color.accentColor : (tint ?? Color.primary))
                .frame(width: 26, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            isActive
                                ? Color.accentColor.opacity(0.20)
                                : (isHovering ? Color.secondary.opacity(0.15) : Color.clear)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isActive ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
                )
                // A plain button only reacts on drawn pixels; this makes the whole box clickable.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(tooltip)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct ToolbarDivider: View {
    var body: some View {
        Divider()
            .frame(height: 18)
            .padding(.horizontal, 2)
    }
}

public struct ToolbarItemDropDelegate: DropDelegate {
    let targetItem: ToolbarItemID
    @Binding var draggedItem: ToolbarItemID?
    @Binding var dropTargetItem: ToolbarItemID?
    let appState: AppState

    public func dropEntered(info: DropInfo) {
        guard let source = draggedItem, source != targetItem else { return }
        dropTargetItem = targetItem
        withAnimation(.easeInOut(duration: 0.2)) {
            appState.moveToolbarItem(from: source, to: targetItem)
        }
    }

    public func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    public func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        dropTargetItem = nil
        return true
    }

    public func dropExited(info: DropInfo) {
        if dropTargetItem == targetItem {
            dropTargetItem = nil
        }
    }
}
