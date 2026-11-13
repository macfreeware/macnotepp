import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public final class MacNoteAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    public weak var appState: AppState? {
        didSet { openPendingFiles() }
    }

    private weak var editorWindow: NSWindow?

    /// SwiftUI opens another window for every file it is handed, but files become tabs in the one window.
    public func adopt(_ window: NSWindow) {
        if let editorWindow, editorWindow !== window, editorWindow.isVisible {
            window.close()
            editorWindow.makeKeyAndOrderFront(nil)
            return
        }
        editorWindow = window
        if window.delegate !== self {
            window.delegate = self
        }
    }

    /// Files handed over before the window, and with it the app state, exists.
    private var pendingFiles: [(url: URL, viewOnly: Bool)] = []

    private func openPendingFiles() {
        guard let appState else { return }
        let files = pendingFiles
        pendingFiles = []
        for file in files {
            if file.viewOnly {
                appState.openFileForViewing(url: file.url)
            } else {
                appState.openFile(url: file.url)
            }
        }
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = MacNoteIconFactory.makeAppIcon(size: 512)
        NSApp.activate(ignoringOtherApps: true)

        // Open any files passed via command-line arguments
        let args = CommandLine.arguments.dropFirst()
        for arg in args where !arg.hasPrefix("-") {
            let url = URL(fileURLWithPath: arg)
            if FileManager.default.fileExists(atPath: url.path) {
                pendingFiles.append((url, false))
            }
        }
        openPendingFiles()
    }

    // SwiftUI apps get files from Finder here; application(_:openFiles:) is never called.
    public func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.isFileURL {
                pendingFiles.append((url, false))
            } else {
                pendingFiles += Self.viewedFiles(in: url).map { ($0, true) }
            }
        }
        openPendingFiles()
    }

    /// `macnotepp://view?path=/a/b.txt&path=/c.txt` opens files locked, for viewers such as MacExplorer's F3.
    private static func viewedFiles(in url: URL) -> [URL] {
        guard url.scheme == "macnotepp", url.host == "view",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [] }
        return items.compactMap { item in
            guard item.name == "path", let path = item.value, path.hasPrefix("/") else { return nil }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else { return nil }
            return URL(fileURLWithPath: path)
        }
    }

    public func applicationDidBecomeActive(_ notification: Notification) {
        appState?.reloadExternallyChangedTabs()
        if appState?.showFindPanel == true {
            FindReplaceWindowController.shared.showWindow()
        }
    }

    // MARK: - Exit Confirmation
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let appState = appState else { return .terminateNow }

        // Update restart: already confirmed; unsaved tabs come back from the session.
        if appState.isRestartingForUpdate {
            appState.saveSession()
            return .terminateNow
        }

        let canTerminate = appState.confirmCloseAllModifiedDocuments()
        if canTerminate {
            appState.saveSession()
            return .terminateNow
        } else {
            appState.restoreEditorFocus()
            return .terminateCancel
        }
    }

    // MARK: - Window Close Red 'X' Button Interception
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let appState = appState else { return true }
        let canClose = appState.confirmCloseAllModifiedDocuments()
        if !canClose {
            appState.restoreEditorFocus()
        }
        return canClose
    }

    public func applicationWillTerminate(_ notification: Notification) {
        appState?.saveSession()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

public struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                callback(window)
            }
        }
    }
}

@main
public struct MacNotePPApp: App {
    @NSApplicationDelegateAdaptor(MacNoteAppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    public init() {
        #if DEBUG
        Updater.runSelfTestIfRequested()
        #endif
    }

    public var body: some Scene {
        WindowGroup("MacNote++") {
            MainWorkspaceView(appState: appState, appDelegate: appDelegate)
                .onAppear {
                    appDelegate.appState = appState
                    FindReplaceWindowController.shared.bind(to: appState)
                    MainMenuLocalizationManager.shared.syncMenu(to: appState.appLanguage)
                    UpdateController.shared.checkAutomatically(appState: appState)
                }
        }
        .defaultSize(width: 1260, height: 820)
        .commands {
            MainMenuCommands(appState: appState)
        }
    }
}

public struct MainWorkspaceView: View {
    @ObservedObject var appState: AppState
    let appDelegate: MacNoteAppDelegate?

    public init(appState: AppState, appDelegate: MacNoteAppDelegate? = nil) {
        self.appState = appState
        self.appDelegate = appDelegate
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Classic Dense Icon Toolbar
            NPPToolbarView(appState: appState)

            // 2. Multi-Tab Bar with Orange Active Stripe & Context Menu
            NPPTabBarView(appState: appState)

            // 3. Main Center Area (Left Workspace + Center Editor/Hex/Compare + Right Function List/Map)
            HStack(spacing: 0) {
                if appState.showLeftWorkspaceSidebar {
                    LeftWorkspaceSidebarView(appState: appState)
                    Divider()
                }

                // Center Content: Compare Mode vs Active Tab (Text or Hex)
                Group {
                    if appState.isCompareMode {
                        CompareView(appState: appState)
                    } else if let doc = appState.activeDocument {
                        if doc.viewMode == .hex && doc.content.utf8.count < 20 * 1024 * 1024 {
                            HexEditorView(appState: appState, document: doc)
                                .id(doc.id)
                        } else if appState.showMarkdownPreview && doc.viewMode != .hex {
                            VStack(spacing: 0) {
                                MarkdownHeaderBar(appState: appState, document: doc)
                                Divider()

                                switch appState.markdownDisplayMode {
                                case .split:
                                    HStack(spacing: 0) {
                                        CodeEditorView(appState: appState, document: doc)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .clipped()

                                        if appState.showMinimap && doc.byteLength < 20 * 1024 * 1024 && !doc.isPartialPreview {
                                            VSCodeMinimapView(appState: appState)
                                                .frame(width: 90)
                                                .frame(maxHeight: .infinity)
                                        }

                                        Divider()

                                        MarkdownRenderedContentView(appState: appState, document: doc)
                                            .id(doc.id)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .clipped()
                                    }
                                case .previewOnly:
                                    MarkdownRenderedContentView(appState: appState, document: doc)
                                            .id(doc.id)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .clipped()
                                case .sourceOnly:
                                    HStack(spacing: 0) {
                                        CodeEditorView(appState: appState, document: doc)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .clipped()

                                        if appState.showMinimap && doc.byteLength < 20 * 1024 * 1024 && !doc.isPartialPreview {
                                            VSCodeMinimapView(appState: appState)
                                                .frame(width: 90)
                                                .frame(maxHeight: .infinity)
                                        }
                                    }
                                }
                            }
                        } else {
                            // A huge document takes seconds to lay out, so its editor stays in place behind hex.
                            ZStack {
                            VStack(spacing: 0) {
                                if doc.isPartialPreview {
                                    LargeFilePartialPreviewBanner(appState: appState, doc: doc)
                                }
                                HStack(spacing: 0) {
                                    CodeEditorView(appState: appState, document: doc)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .clipped()

                                    if appState.showMinimap && doc.byteLength < 20 * 1024 * 1024 && !doc.isPartialPreview {
                                        VSCodeMinimapView(appState: appState)
                                            .frame(width: 95)
                                            .frame(maxHeight: .infinity)
                                    }
                                }
                            }
                            if doc.viewMode == .hex {
                                HexEditorView(appState: appState, document: doc)
                                .id(doc.id)
                                    .background(Color(nsColor: .windowBackgroundColor))
                            }
                            }
                        }
                    } else {
                        Text(appState.loc("Sekme bulunamadı", "No tab found"))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if appState.showRightSidebar && !appState.isCompareMode {
                    SidebarResizeHandle(appState: appState)
                    RightInspectorSidebarView(appState: appState)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 5. Bottom Collapsible Search Results Dock Panel ("Find result")
            if appState.showSearchResultsDock {
                SearchResultsDockView(appState: appState)
            }

            // 6. Classic Detailed Status Bar
            NPPStatusBarView(appState: appState)
        }
        .preferredColorScheme(appState.theme.isDark ? .dark : .light)
        .focusEffectDisabled()
        .navigationTitle(windowTitle)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        Task { @MainActor in
                            appState.openFile(url: url)
                        }
                    }
                }
            }
            return true
        }
        .sheet(isPresented: $appState.showColumnEditorSheet) {
            ColumnEditorSheetView(appState: appState)
                .focusEffectDisabled()
        }
        .sheet(isPresented: $appState.showGoToLineSheet) {
            GoToLineSheetView(appState: appState)
                .focusEffectDisabled()
        }
        .sheet(isPresented: $appState.showSummarySheet) {
            DocumentSummarySheetView(appState: appState)
                .focusEffectDisabled()
        }
        .sheet(isPresented: $appState.showRunMacroSheet) {
            RunMacroMultipleTimesSheetView(appState: appState)
                .focusEffectDisabled()
        }
        .sheet(isPresented: $appState.showSettingsSheet) {
            SettingsSheetView(appState: appState)
                .focusEffectDisabled()
        }
        .sheet(isPresented: $appState.showPrintPreviewSheet) {
            PrintPreviewSheetView(appState: appState)
                .focusEffectDisabled()
        }
        .sheet(isPresented: $appState.showLargeFileDialog) {
            LargeFileGuardSheetView(appState: appState)
                .focusEffectDisabled()
        }
        .sheet(isPresented: $appState.showAboutSheet) {
            AboutSheetView(appState: appState)
                .focusEffectDisabled()
        }
        .background(
            WindowAccessor { window in
                appDelegate?.adopt(window)
            }
        )
    }

    private var windowTitle: String {
        guard let doc = appState.activeDocument else { return "MacNote++" }
        let dirtyPrefix = doc.isModified ? "● " : ""
        if let path = doc.fileURL?.path {
            return "\(dirtyPrefix)\(path) — MacNote++"
        }
        return "\(dirtyPrefix)\(doc.displayTitle) — MacNote++"
    }
}

public enum MacNoteIconFactory {
    public static func makeAppIcon(size: CGFloat = 512) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()

        let scale = size / 512.0
        let outerRect = NSRect(x: 28 * scale, y: 28 * scale, width: 456 * scale, height: 456 * scale)
        let squircle = NSBezierPath(roundedRect: outerRect, xRadius: 102 * scale, yRadius: 102 * scale)

        // Deep emerald to vibrant lime gradient background
        let bgGrad = NSGradient(colors: [
            NSColor(calibratedRed: 0.07, green: 0.22, blue: 0.14, alpha: 1.0),
            NSColor(calibratedRed: 0.11, green: 0.48, blue: 0.24, alpha: 1.0),
            NSColor(calibratedRed: 0.22, green: 0.72, blue: 0.34, alpha: 1.0)
        ])!
        bgGrad.draw(in: squircle, angle: 135)

        // Inner dark code editor sheet card
        let sheetRect = NSRect(x: 72 * scale, y: 80 * scale, width: 368 * scale, height: 352 * scale)
        let sheetPath = NSBezierPath(roundedRect: sheetRect, xRadius: 36 * scale, yRadius: 36 * scale)
        NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.16, alpha: 0.94).setFill()
        sheetPath.fill()

        // Top orange active tab bar stripe on the sheet
        let stripeRect = NSRect(x: 72 * scale, y: 404 * scale, width: 368 * scale, height: 28 * scale)
        let stripePath = NSBezierPath(roundedRect: stripeRect, xRadius: 14 * scale, yRadius: 14 * scale)
        NSColor(calibratedRed: 1.0, green: 0.56, blue: 0.12, alpha: 1.0).setFill()
        stripePath.fill()

        // Stylized colorful syntax lines inside the card
        let lineColors: [(CGFloat, CGFloat, NSColor)] = [
            (104, 150, NSColor(calibratedRed: 0.35, green: 0.75, blue: 1.0, alpha: 0.9)),
            (138, 220, NSColor(calibratedRed: 0.52, green: 0.90, blue: 0.45, alpha: 0.9)),
            (172, 180, NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.28, alpha: 0.9))
        ]
        for (idx, item) in lineColors.enumerated() {
            let yPos = (348 - CGFloat(idx) * 34) * scale
            let bar = NSBezierPath(
                roundedRect: NSRect(x: item.0 * scale, y: yPos, width: item.1 * scale, height: 14 * scale),
                xRadius: 7 * scale,
                yRadius: 7 * scale
            )
            item.2.setFill()
            bar.fill()
        }

        // Bold "N++" monogram at bottom-center of card
        let nppAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 122 * scale, weight: .black),
            .foregroundColor: NSColor.white
        ]
        let nppStr = "N++" as NSString
        let nppSize = nppStr.size(withAttributes: nppAttrs)
        nppStr.draw(
            at: NSPoint(x: (512 * scale - nppSize.width) / 2, y: 112 * scale),
            withAttributes: nppAttrs
        )

        // Subtle outer border highlight
        NSColor.white.withAlphaComponent(0.28).setStroke()
        squircle.lineWidth = 6 * scale
        squircle.stroke()

        img.unlockFocus()
        return img
    }
}
