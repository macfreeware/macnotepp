import AppKit
import SwiftUI

public struct MainMenuCommands: Commands {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some Commands {
        AppAndFileCommands(appState: appState)
        EditCommands(appState: appState)
        ViewCommands(appState: appState)
        FindCommands(appState: appState)
        FormatCommands(appState: appState)
        ToolsCommands(appState: appState)
        HelpCommands(appState: appState)
    }
}

private struct AppAndFileCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(appState.loc("MacNote++ Hakkında", "About MacNote++")) {
                appState.showAboutWindow()
            }
            .keyboardShortcut("i", modifiers: [.command])

            Button(appState.loc("Güncellemeleri Denetle...", "Check for Updates...")) {
                UpdateController.shared.checkFromMenu(appState: appState)
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button(appState.loc("Ayarlar...", "Settings...")) {
                appState.showSettingsSheet = true
            }
            .keyboardShortcut(",", modifiers: [.command])
        }

        CommandGroup(replacing: .appTermination) {
            Button(appState.loc("MacNote++ Uygulamasından Çık", "Quit MacNote++")) {
                appState.quitApplicationSafely()
            }
            .keyboardShortcut("q", modifiers: [.command])
        }

        // The window-level Close items would compete with Close Tab for ⌘W.
        CommandGroup(replacing: .saveItem) {}

        CommandGroup(replacing: .newItem) {
            Button(appState.loc("Yeni Sekme", "New Tab")) {
                appState.newTab()
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button(appState.loc("Aç...", "Open...")) {
                appState.openFilesPanel()
            }
            .keyboardShortcut("o", modifiers: [.command])

            Button(appState.loc("Klasör Aç...", "Open Folder...")) {
                appState.openWorkspaceFolderPanel()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Divider()

            Button(appState.loc("Kaydet", "Save")) {
                appState.saveActiveTab()
            }
            .keyboardShortcut("s", modifiers: [.command])

            Button(appState.loc("Farklı Kaydet...", "Save As...")) {
                appState.saveActiveTabAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Button(appState.loc("Tümünü Kaydet", "Save All")) {
                appState.saveAllTabs()
            }
            .keyboardShortcut("s", modifiers: [.command, .option])

            Button(appState.loc("Diskten Yeniden Yükle", "Reload from Disk")) {
                appState.reloadActiveTabFromDisk()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button(appState.loc("Baskı Önizleme...", "Print Preview...")) {
                appState.showPrintPreviewSheet = true
            }
            .keyboardShortcut("p", modifiers: [.command, .option])

            Button(appState.loc("Yazdır...", "Print...")) {
                appState.printDocumentDirectly()
            }
            .keyboardShortcut("p", modifiers: [.command])

            Divider()

            Button(appState.loc("Sekmeyi Kapat", "Close Tab")) {
                if let id = appState.activeTabId {
                    appState.closeTab(id: id)
                }
            }
            .keyboardShortcut("w", modifiers: [.command])

            Button(appState.loc("Değişmemiş Sekmeleri Kapat", "Close Unmodified Tabs")) {
                appState.closeUnmodifiedTabs()
            }

            Divider()

            Button(appState.loc("Sekmeyi Sola Taşı", "Move Tab Left")) {
                if let id = appState.activeTabId { appState.moveTab(id: id, by: -1) }
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option, .shift])

            Button(appState.loc("Sekmeyi Sağa Taşı", "Move Tab Right")) {
                if let id = appState.activeTabId { appState.moveTab(id: id, by: 1) }
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option, .shift])
        }
    }
}

private struct EditCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(appState.loc("Geri Al", "Undo")) {
                appState.performUndo()
            }
            .keyboardShortcut("z", modifiers: [.command])
            .disabled(!appState.canUndo)

            Button(appState.loc("Yinele", "Redo")) {
                appState.performRedo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!appState.canRedo)
        }

        CommandGroup(after: .pasteboard) {
            Divider()

            Menu(appState.loc("Satır", "Line")) {
                Button(appState.loc("Çoğalt", "Duplicate")) {
                    appState.duplicateCurrentLine()
                }
                .keyboardShortcut("d", modifiers: [.command])

                Button(appState.loc("Sil", "Delete")) {
                    appState.deleteCurrentLine()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Button(appState.loc("Yukarı Taşı", "Move Up")) {
                    appState.moveCurrentLine(direction: -1)
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])

                Button(appState.loc("Aşağı Taşı", "Move Down")) {
                    appState.moveCurrentLine(direction: 1)
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])

                Divider()

                ForEach(LineOperationType.allCases, id: \.self) { op in
                    Button(op.title(for: appState.language)) {
                        appState.applyLineOperation(op)
                    }
                }
            }

            Menu(appState.loc("Harf Durumu", "Change Case")) {
                ForEach(CaseConversionType.allCases, id: \.self) { conv in
                    Button(conv.title(for: appState.language)) {
                        appState.applyCaseConversion(conv)
                    }
                }
            }

            Menu(appState.loc("Çoklu İmleç", "Multiple Cursors")) {
                Button(appState.loc("Üste İmleç Ekle", "Add Cursor Above")) {
                    appState.triggerMultiCaret(.addCursorAbove)
                }
                .keyboardShortcut(.upArrow, modifiers: [.option, .shift])

                Button(appState.loc("Alta İmleç Ekle", "Add Cursor Below")) {
                    appState.triggerMultiCaret(.addCursorBelow)
                }
                .keyboardShortcut(.downArrow, modifiers: [.option, .shift])

                Divider()

                Button(appState.loc("Satır Sonlarına İmleç Koy", "Add Cursors to Line Ends")) {
                    appState.triggerMultiCaret(.addCursorsToSelectedLinesEnd)
                }
                .keyboardShortcut("i", modifiers: [.option, .shift])

                Button(appState.loc("Satır Başlarına İmleç Koy", "Add Cursors to Line Starts")) {
                    appState.triggerMultiCaret(.addCursorsToSelectedLinesStart)
                }

                Divider()

                Button(appState.loc("Tek İmlece Dön", "Single Cursor")) {
                    appState.triggerMultiCaret(.clearExtraCursors)
                }
            }

            Button(appState.loc("Sütun Düzenleyici...", "Column Editor...")) {
                appState.showColumnEditorSheet = true
            }
            .keyboardShortcut("c", modifiers: [.option])

            Divider()

            Button(appState.loc("Yorum Yap / Kaldır", "Toggle Comment")) {
                appState.toggleCommentOnActiveDocument()
            }
            .keyboardShortcut("/", modifiers: [.command])

            Button(appState.loc("Tarih ve Saat Ekle", "Insert Date and Time")) {
                appState.insertDateTime()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])

            Toggle(appState.loc("Salt Okunur", "Read-Only"), isOn: Binding(
                get: { appState.activeDocument?.isReadOnly == true },
                set: { _ in appState.toggleReadOnly() }
            ))
        }
    }
}

private struct ViewCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        // Goes into the system View menu, so there is no second one next to it.
        CommandGroup(before: .toolbar) {
            Toggle(appState.loc("Sözcük Kaydırma", "Word Wrap"), isOn: $appState.wordWrap)
                .keyboardShortcut("w", modifiers: [.command, .option])
            Toggle(appState.loc("Görünmez Karakterler", "Invisible Characters"), isOn: $appState.showInvisibleCharacters)
                .keyboardShortcut("i", modifiers: [.command, .option])
            Toggle(appState.loc("Satır Numaraları", "Line Numbers"), isOn: $appState.showLineNumbers)

            Divider()

            Button(appState.loc("Yakınlaştır", "Zoom In")) {
                appState.fontSize = min(32, appState.fontSize + 1)
            }
            .keyboardShortcut("+", modifiers: [.command])

            Button(appState.loc("Uzaklaştır", "Zoom Out")) {
                appState.fontSize = max(9, appState.fontSize - 1)
            }
            .keyboardShortcut("-", modifiers: [.command])

            Button(appState.loc("Gerçek Boyut", "Actual Size")) {
                appState.fontSize = 13.0
            }
            .keyboardShortcut("0", modifiers: [.command])

            Divider()

            Toggle(appState.loc("Klasör Paneli", "Folder Panel"), isOn: $appState.showLeftWorkspaceSidebar)
            Toggle(appState.loc("Fonksiyon Listesi", "Function List"), isOn: $appState.showRightSidebar)
            Toggle(appState.loc("Kod Haritası", "Minimap"), isOn: $appState.showMinimap)
            Toggle(appState.loc("Arama Sonuçları", "Search Results"), isOn: $appState.showSearchResultsDock)

            Divider()

            Toggle(appState.loc("Hex Görünümü", "Hex View"), isOn: Binding(
                get: { appState.activeDocument?.viewMode == .hex },
                set: { _ in appState.toggleHexView() }
            ))
            .keyboardShortcut("h", modifiers: [.command, .shift])

            Toggle(appState.loc("Markdown Önizleme", "Markdown Preview"), isOn: $appState.showMarkdownPreview)
                .keyboardShortcut("m", modifiers: [.command, .option])

            Menu(appState.loc("Markdown Düzeni", "Markdown Layout")) {
                ForEach(MarkdownDisplayMode.allCases) { m in
                    Button(m.title(for: appState.language)) {
                        appState.markdownDisplayMode = m
                        appState.showMarkdownPreview = true
                    }
                }
            }

            Divider()

            Menu(appState.loc("Tema", "Theme")) {
                ForEach(EditorTheme.allCases) { t in
                    Toggle(t.title(for: appState.language), isOn: Binding(get: { appState.theme == t }, set: { _ in appState.theme = t }))
                }
            }

            Menu(appState.loc("Araç Çubuğu", "Toolbar")) {
                Toggle(appState.loc("Çok Satırlı", "Multiple Rows"), isOn: $appState.isMultiRowToolbar)
                Toggle(appState.loc("Özelleştir", "Customize"), isOn: $appState.isToolbarEditMode)
            }

            Toggle(appState.loc("Her Zaman Üstte", "Always on Top"), isOn: $appState.isAlwaysOnTop)

            Divider()
        }
    }
}

private struct FindCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandMenu(appState.loc("Bul", "Find")) {
            Button(appState.loc("Bul...", "Find...")) {
                appState.findPanelTab = .find
                appState.showFindPanel = true
            }
            .keyboardShortcut("f", modifiers: [.command])

            Button(appState.loc("Değiştir...", "Replace...")) {
                appState.findPanelTab = .replace
                appState.showFindPanel = true
            }
            .keyboardShortcut("r", modifiers: [.command])

            Button(appState.loc("Dosyalarda Bul...", "Find in Files...")) {
                appState.findPanelTab = .findInFiles
                appState.showFindPanel = true
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Button(appState.loc("İşaretle...", "Mark...")) {
                appState.findPanelTab = .mark
                appState.showFindPanel = true
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            Divider()

            Button(appState.loc("Sonrakini Bul", "Find Next")) {
                appState.findNext(forward: true)
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])

            Button(appState.loc("Satıra Git...", "Go to Line...")) {
                appState.showGoToLineSheet = true
            }
            .keyboardShortcut("g", modifiers: [.command])

            Divider()

            Menu(appState.loc("Yer İmleri", "Bookmarks")) {
                Button(appState.loc("Yer İmi Koy / Kaldır", "Toggle Bookmark")) {
                    appState.toggleBookmark()
                }
                .keyboardShortcut("b", modifiers: [.command])

                Button(appState.loc("Sonraki Yer İmi", "Next Bookmark")) {
                    appState.navigateBookmark(forward: true)
                }
                .keyboardShortcut("]", modifiers: [.command])

                Button(appState.loc("Önceki Yer İmi", "Previous Bookmark")) {
                    appState.navigateBookmark(forward: false)
                }
                .keyboardShortcut("[", modifiers: [.command])

                Divider()

                Button(appState.loc("İmli Satırları Kopyala", "Copy Bookmarked Lines")) {
                    appState.copyBookmarkedLinesToClipboard()
                }
                Button(appState.loc("İmli Satırları Kes", "Cut Bookmarked Lines")) {
                    appState.cutBookmarkedLinesToClipboard()
                }
                Button(appState.loc("İmli Satırları Sil", "Delete Bookmarked Lines")) {
                    appState.removeBookmarkedLines()
                }
                Button(appState.loc("İmsiz Satırları Sil", "Delete Unbookmarked Lines")) {
                    appState.removeUnbookmarkedLines()
                }

                Divider()

                Button(appState.loc("Yer İmlerini Tersine Çevir", "Invert Bookmarks")) {
                    appState.invertBookmarks()
                }
                Button(appState.loc("Tüm Yer İmlerini Temizle", "Clear All Bookmarks")) {
                    appState.clearAllBookmarks()
                }
            }
        }
    }
}

private struct FormatCommands: Commands {
    @ObservedObject var appState: AppState

    private func update(_ change: (inout EditorDocument) -> Void) {
        guard var doc = appState.activeDocument else { return }
        change(&doc)
        appState.activeDocument = doc
        appState.saveSession()
    }

    var body: some Commands {
        CommandMenu(appState.loc("Biçim", "Format")) {
            Menu(appState.loc("Dil", "Language")) {
                ForEach(SyntaxLanguage.allCases) { lang in
                    Toggle(lang.rawValue, isOn: Binding(
                        get: { appState.activeDocument?.language == lang },
                        set: { _ in
                            update {
                                $0.language = lang
                                $0.isLanguageManuallySet = true
                            }
                        }
                    ))
                }
            }

            Menu(appState.loc("Kodlama", "Encoding")) {
                ForEach(TextEncodingOption.allCases) { enc in
                    Toggle(enc.rawValue, isOn: Binding(
                        get: { appState.activeDocument?.encoding == enc },
                        set: { _ in
                            update {
                                $0.encoding = enc
                                $0.isModified = true
                            }
                        }
                    ))
                }
            }

            Menu(appState.loc("Satır Sonu", "Line Endings")) {
                ForEach(LineEndingType.allCases) { eol in
                    Toggle(eol.rawValue, isOn: Binding(
                        get: { appState.activeDocument?.lineEnding == eol },
                        set: { _ in
                            update {
                                $0.lineEnding = eol
                                $0.isModified = true
                            }
                        }
                    ))
                }
            }
        }
    }
}

private struct ToolsCommands: Commands {
    @ObservedObject var appState: AppState

    private func transform(_ change: (String) -> String) {
        guard var doc = appState.activeDocument else { return }
        doc.content = change(doc.content)
        doc.isModified = true
        appState.activeDocument = doc
    }

    private func copyHash(_ hash: (String) -> String) {
        guard let doc = appState.activeDocument else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hash(doc.content), forType: .string)
    }

    var body: some Commands {
        CommandMenu(appState.loc("Araçlar", "Tools")) {
            Toggle(appState.loc("Karşılaştır", "Compare"), isOn: Binding(
                get: { appState.isCompareMode },
                set: { _ in appState.toggleCompareMode() }
            ))
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Divider()

            Menu("JSON") {
                Button(appState.loc("Biçimlendir", "Pretty Print")) { transform(TextOperations.jsonPrettyPrint) }
                Button(appState.loc("Sıkıştır", "Minify")) { transform(TextOperations.jsonMinify) }
            }

            Button(appState.loc("SQL Biçimlendir", "Format SQL")) { transform(TextOperations.sqlFormat) }

            Menu("Base64") {
                Button(appState.loc("Kodla", "Encode")) { transform(TextOperations.base64Encode) }
                Button(appState.loc("Çöz", "Decode")) { transform(TextOperations.base64Decode) }
            }

            Menu("URL") {
                Button(appState.loc("Kodla", "Encode")) { transform(TextOperations.urlEncode) }
                Button(appState.loc("Çöz", "Decode")) { transform(TextOperations.urlDecode) }
            }

            Menu(appState.loc("Özeti Kopyala", "Copy Hash")) {
                Button("MD5") { copyHash(TextOperations.md5Hash) }
                Button("SHA-256") { copyHash(TextOperations.sha256Hash) }
            }

            Divider()

            Menu(appState.loc("Makro", "Macro")) {
                Toggle(appState.loc("Kayıt", "Record"), isOn: Binding(
                    get: { appState.isRecordingMacro },
                    set: { _ in appState.toggleMacroRecording() }
                ))
                Button(appState.loc("Oynat", "Play")) {
                    appState.playMacro()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                Button(appState.loc("Çok Kez Oynat...", "Play Multiple Times...")) {
                    appState.showRunMacroSheet = true
                }
            }

            Divider()

            Button(appState.loc("Belge Bilgisi...", "Document Info...")) {
                appState.showSummarySheet = true
            }
        }
    }
}

private struct HelpCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button(appState.loc("Klavye Kısayolları", "Keyboard Shortcuts")) {
                appState.showAboutWindow(tab: .usage)
            }

            Button(appState.loc("MacNote++ Web Sayfası", "MacNote++ Website")) {
                NSWorkspace.shared.open(UpdateChecker.repositoryURL)
            }
        }
    }
}
