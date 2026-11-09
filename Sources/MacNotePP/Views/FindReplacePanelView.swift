import AppKit
import Combine
import SwiftUI

@MainActor
public final class FindReplaceWindowController: NSObject, NSWindowDelegate {
    public static let shared = FindReplaceWindowController()

    private var panel: NSPanel?
    private weak var appState: AppState?
    private var cancellables: Set<AnyCancellable> = []

    public func bind(to appState: AppState) {
        self.appState = appState
        cancellables.removeAll()

        appState.$showFindPanel
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldShow in
                guard let self = self else { return }
                if shouldShow {
                    self.showWindow()
                } else {
                    self.hideWindow()
                }
            }
            .store(in: &cancellables)

        appState.$theme
            .receive(on: RunLoop.main)
            .sink { [weak self] theme in
                let appAppearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
                NSApp.appearance = appAppearance
                self?.panel?.appearance = appAppearance
            }
            .store(in: &cancellables)
    }

    public func showWindow() {
        guard let appState = appState else { return }
        let targetAppearance = NSAppearance(named: appState.theme.isDark ? .darkAqua : .aqua)
        NSApp.appearance = targetAppearance

        if panel == nil {
            let contentView = NSHostingView(rootView: FindReplacePanelView(appState: appState))
            let newPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 650, height: 340),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            newPanel.title = "Find / Replace — MacNote++"
            // Floating panel with hidesOnDeactivate:
            // - Moves 100% smoothly at 120fps (no addChildWindow frame-lock stutter)
            // - Always stays above MacNote++ main window while MacNote++ is active
            // - Automatically hides when switching to other apps and reappears when MacNote++ comes to front
            newPanel.isFloatingPanel = true
            newPanel.level = .floating
            newPanel.hidesOnDeactivate = true
            newPanel.isReleasedWhenClosed = false
            newPanel.isMovableByWindowBackground = true
            newPanel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
            newPanel.delegate = self
            newPanel.contentView = contentView

            // Initial position near top-right of main editor window
            if let mainWin = NSApp.windows.first(where: { $0 !== newPanel && $0.isVisible && !$0.title.isEmpty }) ?? NSApp.mainWindow {
                let mainFrame = mainWin.frame
                let x = mainFrame.maxX - newPanel.frame.width - 50
                let y = mainFrame.maxY - newPanel.frame.height - 90
                newPanel.setFrameOrigin(NSPoint(x: max(40, x), y: max(40, y)))
            } else {
                newPanel.center()
            }

            self.panel = newPanel
        }

        guard let panel = self.panel else { return }
        panel.appearance = targetAppearance
        panel.makeKeyAndOrderFront(nil)
    }

    public func hideWindow() {
        guard let panel = panel, panel.isVisible else { return }
        panel.orderOut(nil)
    }

    public func setWindowAlpha(_ alpha: Double) {
        panel?.alphaValue = CGFloat(max(0.35, min(1.0, alpha)))
    }

    public func windowWillClose(_ notification: Notification) {
        if appState?.showFindPanel == true {
            appState?.showFindPanel = false
        }
    }
}

public struct FindReplacePanelView: View {
    @ObservedObject var appState: AppState
    @State private var useTransparency: Bool = false
    @State private var windowOpacity: Double = 0.88

    public var body: some View {
        let _ = appState.languageRefreshTrigger
        VStack(alignment: .leading, spacing: 14) {
            // Top Mode Tabs (Find / Replace / Find in Files / Mark)
            HStack(spacing: 6) {
                ForEach(FindPanelTab.allCases) { tab in
                    Button {
                        appState.findPanelTab = tab
                    } label: {
                        Text(tab.title(for: appState.language))
                            .font(.system(size: 12, weight: appState.findPanelTab == tab ? .bold : .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(appState.findPanelTab == tab ? Color.accentColor : Color.secondary.opacity(0.14))
                            )
                            .foregroundStyle(appState.findPanelTab == tab ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Classic Two-Column Dialog Layout (Left: Inputs & Options, Right: Action Buttons)
            HStack(alignment: .top, spacing: 18) {
                // Left Column: Inputs & Search Options
                VStack(alignment: .leading, spacing: 12) {
                    // Find What
                    HStack(spacing: 8) {
                        Text(appState.loc("Aranan:", "Find what:"))
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 82, alignment: .trailing)

                        TextField(appState.loc("Aranacak metin veya Regex...", "Text or Regex to find..."), text: $appState.searchQuery)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: appState.searchQuery) { _, _ in
                                appState.updateLiveSearchMatches()
                            }
                            .onSubmit {
                                appState.findNext(forward: true)
                            }
                    }

                    // Replace With (for Replace & Find in Files)
                    if appState.findPanelTab == .replace || appState.findPanelTab == .findInFiles {
                        HStack(spacing: 8) {
                            Text(appState.loc("Yeni Değer:", "Replace with:"))
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 82, alignment: .trailing)

                            TextField(appState.loc("Değiştirilecek metin...", "Replacement text..."), text: $appState.replaceQuery)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // Find in Files extra fields
                    if appState.findPanelTab == .findInFiles {
                        HStack(spacing: 8) {
                            Text(appState.loc("Filtreler:", "Filters:"))
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 82, alignment: .trailing)

                            TextField("*.pas;*.sql;*.cpp;*.txt", text: $appState.findInFilesFilter)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(spacing: 8) {
                            Text(appState.loc("Klasör:", "Folder:"))
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 82, alignment: .trailing)

                            TextField("/Users/...", text: $appState.findInFilesDirectory)
                                .textFieldStyle(.roundedBorder)

                            Button("...") {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                if panel.runModal() == .OK, let url = panel.url {
                                    appState.findInFilesDirectory = url.path
                                }
                            }
                            .help(appState.loc("Arama Klasörü Seç", "Select Search Folder"))
                        }
                    }

                    // Options & Search Mode Boxes
                    HStack(alignment: .top, spacing: 12) {
                        // Search Mode Group Box
                        VStack(alignment: .leading, spacing: 6) {
                            Text(appState.loc("Arama Modu", "Search Mode"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)

                            Picker("", selection: $appState.searchMode) {
                                ForEach(SearchMode.allCases) { mode in
                                    Text(mode.title(for: appState.language)).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.radioGroup)
                            .font(.system(size: 11))
                            .onChange(of: appState.searchMode) { _, _ in
                                appState.updateLiveSearchMatches()
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))

                        // Match Checkboxes Group Box
                        VStack(alignment: .leading, spacing: 7) {
                            Text(appState.loc("Seçenekler", "Options"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)

                            Toggle(appState.loc("Tam Sözcük Eşleştir", "Match Whole Word"), isOn: $appState.wholeWord)
                                .toggleStyle(.checkbox)
                                .font(.system(size: 11))
                                .onChange(of: appState.wholeWord) { _, _ in
                                    appState.updateLiveSearchMatches()
                                }

                            Toggle(appState.loc("Büyük/Küçük Harf Duyarlı", "Match Case"), isOn: $appState.matchCase)
                                .toggleStyle(.checkbox)
                                .font(.system(size: 11))
                                .onChange(of: appState.matchCase) { _, _ in
                                    appState.updateLiveSearchMatches()
                                }

                            Toggle(appState.loc("Belge Sonunda Başa Dön", "Wrap around"), isOn: $appState.wrapAround)
                                .toggleStyle(.checkbox)
                                .font(.system(size: 11))

                            if appState.findPanelTab == .mark {
                                Toggle(appState.loc("Satıra Yer İmi (Bookmark) Koy", "Bookmark Line on Mark"), isOn: $appState.bookmarkLineOnMark)
                                    .toggleStyle(.checkbox)
                                    .font(.system(size: 11))
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    }
                }
                .frame(maxWidth: .infinity)

                // Right Column: Stacked Action Buttons
                VStack(spacing: 7) {
                    Button {
                        appState.findNext(forward: true)
                    } label: {
                        Text(appState.loc("Sonrakini Bul (F3)", "Find Next (F3)"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)

                    Button {
                        appState.findNext(forward: false)
                    } label: {
                        Text(appState.loc("Öncekini Bul (⇧F3)", "Find Previous (⇧F3)"))
                            .frame(maxWidth: .infinity)
                    }

                    if appState.findPanelTab == .find {
                        Button {
                            appState.countMatchesInActiveDocument()
                        } label: {
                            Text(appState.loc("Eşleşmeleri Say", "Count Matches"))
                                .frame(maxWidth: .infinity)
                        }

                        Button {
                            appState.findAllInCurrentDocument()
                        } label: {
                            Text(appState.loc("Aktif Belgede Tümünü Bul", "Find All in Current Document"))
                                .frame(maxWidth: .infinity)
                        }

                        Button {
                            appState.findAllInAllOpenedDocuments()
                        } label: {
                            Text(appState.loc("Açık Belgelerde Tümünü Bul", "Find All in All Open Documents"))
                                .frame(maxWidth: .infinity)
                        }
                    } else if appState.findPanelTab == .replace {
                        Button {
                            appState.replaceNext()
                        } label: {
                            Text(appState.loc("Değiştir (Replace)", "Replace"))
                                .frame(maxWidth: .infinity)
                        }

                        Button {
                            appState.replaceAllInActiveDocument()
                        } label: {
                            Text(appState.loc("Tümünü Değiştir (Aktif)", "Replace All (Current)"))
                                .frame(maxWidth: .infinity)
                        }

                        Button {
                            appState.replaceAllInAllOpenedDocuments()
                        } label: {
                            Text(appState.loc("Açık Belgelerde Değiştir", "Replace All in All Open Docs"))
                                .frame(maxWidth: .infinity)
                        }
                    } else if appState.findPanelTab == .findInFiles {
                        Button {
                            appState.findInFiles()
                        } label: {
                            Text(appState.loc("Dosyalarda Bul", "Find in Files"))
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.orange)
                    } else if appState.findPanelTab == .mark {
                        Button {
                            appState.markAllInActiveDocument()
                        } label: {
                            Text(appState.loc("Tümünü İşaretle", "Mark All"))
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.cyan)

                        Button {
                            appState.clearMarksInActiveDocument()
                        } label: {
                            Text(appState.loc("İşaretleri Temizle", "Clear All Marks"))
                                .frame(maxWidth: .infinity)
                        }
                    }

                    Divider().padding(.vertical, 2)

                    Button {
                        appState.showFindPanel = false
                    } label: {
                        Text(appState.loc("Kapat (Esc)", "Close (Esc)"))
                            .frame(maxWidth: .infinity)
                    }
                    .keyboardShortcut(.cancelAction)
                }
                .frame(width: 185)
            }

            Divider()

            // Bottom Status Bar + Transparency Slider
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.orange)
                Text(appState.searchStatusMessage.isEmpty ? appState.loc("Hazır", "Ready") : appState.searchStatusMessage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(appState.searchStatusMessage.isEmpty ? Color.secondary : Color.orange)
                    .lineLimit(1)

                Spacer()

                Toggle(appState.loc("Şeffaflık:", "Transparency:"), isOn: $useTransparency)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .onChange(of: useTransparency) { _, enabled in
                        FindReplaceWindowController.shared.setWindowAlpha(enabled ? windowOpacity : 1.0)
                    }

                if useTransparency {
                    Slider(value: $windowOpacity, in: 0.45...1.0)
                        .frame(width: 90)
                        .controlSize(.small)
                        .onChange(of: windowOpacity) { _, val in
                            FindReplaceWindowController.shared.setWindowAlpha(val)
                        }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(width: 650)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(appState.theme.isDark ? .dark : .light)
    }
}

public struct SearchResultsDockView: View {
    @ObservedObject var appState: AppState

    public var body: some View {
        let _ = appState.languageRefreshTrigger
        VStack(spacing: 0) {
            Divider()

            // Dock Header
            HStack {
                Image(systemName: "text.magnifyingglass")
                    .foregroundStyle(.orange)
                Text(appState.loc("ARAMA SONUÇLARI (Find Result)", "SEARCH RESULTS (Find Result)"))
                    .font(.system(size: 11, weight: .bold))

                Spacer()

                Button(appState.loc("Sonuçları Temizle", "Clear Results")) {
                    appState.searchResultGroups.removeAll()
                }
                .controlSize(.mini)

                Button {
                    appState.showSearchResultsDock = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if appState.searchResultGroups.isEmpty {
                VStack(spacing: 4) {
                    Text(appState.loc("Henüz arama sonucu yok.", "No search results yet."))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(appState.loc("Bul penceresinden (⌘F / Ctrl+F) 'Aktif Belgede Tümünü Bul', 'Açık Belgelerde Tümünü Bul' veya 'Dosyalarda Bul' butonunu kullanın.", "Use 'Find All in Current Doc', 'Find All in Open Docs', or 'Find in Files' in Find panel (⌘F)."))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                List {
                    ForEach(appState.searchResultGroups) { group in
                        Section(header: Text(group.title).font(.system(size: 11, weight: .bold)).foregroundStyle(.orange)) {
                            ForEach(group.hits) { hit in
                                Button {
                                    if let tabId = hit.tabId {
                                        appState.jumpToRange(hit.matchRangeInDocument, inTabId: tabId)
                                    } else if let url = hit.fileURL {
                                        appState.openFile(url: url)
                                        appState.jumpToRange(hit.matchRangeInDocument)
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(hit.fileName)
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.blue)
                                            .frame(width: 140, alignment: .leading)
                                            .lineLimit(1)

                                        Text(appState.loc("Satır \(hit.lineNumber), Sütun \(hit.columnNumber):", "Line \(hit.lineNumber), Column \(hit.columnNumber):"))
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 135, alignment: .leading)

                                        Text(hit.linePreview)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(height: 175)
    }
}
