import AppKit
import Darwin
import SwiftUI

// MARK: - Dedicated About Window Controller
@MainActor
public final class AboutWindowController: NSObject, NSWindowDelegate {
    public static let shared = AboutWindowController()

    private var window: NSWindow?
    private weak var appState: AppState?

    public func showWindow(appState: AppState) {
        self.appState = appState

        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 510, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.title = appState.loc("MacNote++ Hakkında", "About MacNote++")
        newWindow.titleVisibility = .hidden
        newWindow.titlebarAppearsTransparent = true
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.appearance = NSAppearance(named: .darkAqua)
        newWindow.center()
        newWindow.delegate = self

        let hostingView = NSHostingView(rootView: AboutWindowContent(appState: appState))
        newWindow.contentView = hostingView

        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func close() {
        window?.orderOut(nil)
    }

    public func windowWillClose(_ notification: Notification) {
        // Keep window reference alive for fast re-opening
    }
}

// MARK: - About Tabs
public enum AboutTab: Int, CaseIterable, Identifiable {
    case general = 0
    case usage = 1
    case system = 2

    public var id: Int { rawValue }

    public func title(for lang: AppLanguage) -> String {
        let isTr = lang.resolvedLanguage == .turkish
        switch self {
        case .general: return isTr ? "Genel" : "General"
        case .usage: return isTr ? "Kullanım" : "Usage"
        case .system: return isTr ? "Sistem" : "System"
        }
    }
}

// MARK: - Main About Window SwiftUI Content
public struct AboutWindowContent: View {
    @ObservedObject var appState: AppState
    private var selectedTab: AboutTab {
        get { appState.aboutTab }
        nonmutating set { appState.aboutTab = newValue }
    }
    @State private var updateNotice: String?
    @State private var isCheckingForUpdates: Bool = false

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        let _ = appState.languageRefreshTrigger
        VStack(spacing: 0) {
            headerView
            colorBarView
            tabSelectorView
            Divider().opacity(0.2)
            tabContentView
            Divider().opacity(0.2)
            footerView
        }
        .frame(width: 510, height: 750)
        .preferredColorScheme(.dark)
        .focusEffectDisabled()
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 28)

            Image(nsImage: MacNoteIconFactory.makeAppIcon(size: 192))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 82, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.45), radius: 10, y: 5)

            Text("MacNote++")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)

            Text(appVersionString)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.82))

            Button {
                checkForUpdates()
            } label: {
                Text(isCheckingForUpdates
                     ? appState.loc("Denetleniyor...", "Checking...")
                     : appState.loc("Güncellemeleri Denetle...", "Check for Updates..."))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
            .focusable(false)
            .disabled(isCheckingForUpdates)

            if let updateNotice {
                Text(updateNotice)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(.horizontal, 20)
            }

            Text(appState.loc("macOS için yerel, gelişmiş ve hızlı metin ve kod editörü", "Native, advanced and fast text and code editor for macOS"))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.96, green: 0.68, blue: 0.28))
                Text(appState.loc("Geliştirici: Rafet SAPANCI", "Developer: Rafet SAPANCI"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.14)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8))
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.16, blue: 0.28),
                    Color(red: 0.07, green: 0.23, blue: 0.38),
                    Color(red: 0.05, green: 0.12, blue: 0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Color Bar
    private var colorBarView: some View {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.48, blue: 0.10),
                Color(red: 0.94, green: 0.20, blue: 0.50),
                Color(red: 0.60, green: 0.25, blue: 0.88),
                Color(red: 0.05, green: 0.75, blue: 0.95),
                Color(red: 0.15, green: 0.85, blue: 0.45)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 3)
    }

    // MARK: - Tab Selector
    private var tabSelectorView: some View {
        HStack(spacing: 0) {
            Spacer()
            HStack(spacing: 0) {
                aboutTabButton(for: .general)
                Divider().frame(height: 14).opacity(0.3)
                aboutTabButton(for: .usage)
                Divider().frame(height: 14).opacity(0.3)
                aboutTabButton(for: .system)
            }
            .padding(3)
            .background(Capsule().fill(Color.black.opacity(0.45)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
            Spacer()
        }
        .padding(.vertical, 10)
        .background(Color(red: 0.09, green: 0.10, blue: 0.12))
    }

    private func aboutTabButton(for tab: AboutTab) -> some View {
        let isSelected = (selectedTab == tab)
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = tab
            }
        } label: {
            Text(tab.title(for: appState.language))
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.72))
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
                .background(isSelected ? Color(red: 0.10, green: 0.48, blue: 0.98) : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    // MARK: - Tab Content
    private var tabContentView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                switch selectedTab {
                case .general:
                    generalTabView
                case .usage:
                    usageTabView
                case .system:
                    systemTabView
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(red: 0.09, green: 0.10, blue: 0.12))
    }

    // MARK: - Update Check
    private func checkForUpdates() {
        isCheckingForUpdates = true
        updateNotice = nil
        Task {
            let outcome = await UpdateController.shared.check()
            isCheckingForUpdates = false
            switch outcome {
            case .upToDate(let version):
                updateNotice = appState.loc("MacNote++ güncel (\(version)).", "MacNote++ is up to date (\(version)).")
            case .failed(let reason):
                updateNotice = reason
            case .newer(let release):
                AboutWindowController.shared.close()
                appState.showAboutSheet = false
                UpdateController.shared.show(release, appState: appState)
            }
        }
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack {
            Spacer()
            Text(appState.loc("MacNote++ bağımsız, açık kaynaklı bir projedir.", "MacNote++ is an independent open-source project."))
                .font(.system(size: 10))
                .foregroundStyle(Color.secondary.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(red: 0.07, green: 0.08, blue: 0.10))
    }

    // MARK: - Tab 1: Genel View
    private var generalTabView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main description paragraph
            Text(appState.loc("Dosyalarınızı ve kaynak kodlarınızı Mac'inizde yüksek performans, akıllı renklendirme ve zengin araç setiyle düzenleyin. Tamamen Swift ile yazılmış, yerel bir macOS uygulamasıdır; Electron ya da ek kütüphane gerektirmez.", "Edit your files and source code on your Mac with high performance, smart highlighting and a rich tool set. Written entirely in Swift as a native macOS app; no Electron or extra libraries."))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.90))
                .lineSpacing(3)

            VStack(alignment: .leading, spacing: 8) {
                featureBullet(
                    icon: "macwindow.on.rectangle",
                    text: appState.loc("Sekmeler: Renkli durum göstergeleri, tekerlek/orta tuşla hızlı kapatma", "Tabs: coloured status indicators, quick close with the middle button")
                )
                featureBullet(
                    icon: "shield.lefthalf.filled",
                    text: appState.loc("Büyük Dosya Güvenlik Kalkanı: GB'larca boyuttaki dosyalarda kilitlenmeyen güvenli önizleme", "Large File Guard: safe preview that does not freeze on multi-gigabyte files")
                )
                featureBullet(
                    icon: "paintpalette",
                    text: appState.loc("Sözdizimi Renklendirme: SQL, Swift, C/C++, Python, JS, HTML, JSON ve onlarca dil", "Syntax Highlighting: SQL, Swift, C/C++, Python, JS, HTML, JSON and many more")
                )
                featureBullet(
                    icon: "rectangle.split.3x1",
                    text: appState.loc("Dikdörtgen (Sütun) Seçimi: ⌥ Option + fare sürükleme ile çok satırlı blok seçme ve silme", "Rectangular (Column) Selection: select and delete multi-line blocks with ⌥ Option + drag")
                )
                featureBullet(
                    icon: "map",
                    text: appState.loc("Kod Haritası (Minimap): Dosya genelinde hızlı ve görsel kuşbakışı gezinme", "Minimap: fast visual overview of the whole file")
                )
                featureBullet(
                    icon: "magnifyingglass",
                    text: appState.loc("Gelişmiş Arama & Değiştir: Düzenli ifadeler (RegEx), yer imleri ve çoklu arama paneli", "Advanced Find & Replace: regular expressions, bookmarks and a multi-search panel")
                )
                featureBullet(
                    icon: "00.square",
                    text: appState.loc("Hex Görünüm & Karşılaştır: İkili dosya analizi ve iki dosyayı yan yana kıyaslama (Diff)", "Hex View & Compare: binary file analysis and side-by-side diff")
                )
                featureBullet(
                    icon: "printer",
                    text: appState.loc("Yazdırma Önizleme: A4 sayfa düzeni, satır numaraları, üst/alt bilgi ve PDF çıktısı", "Print Preview: A4 layout, line numbers, header/footer and PDF output")
                )
            }
            .padding(.vertical, 4)

            Divider().opacity(0.2)

            // Copyright and License Notice
            VStack(alignment: .leading, spacing: 5) {
                Text("© 2026 Rafet SAPANCI")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)

                Text(appState.loc("MacNote++ özgür yazılımdır: GNU Genel Kamu Lisansı sürüm 3 ya da (isteğinize bağlı olarak) daha sonraki bir sürümünün (GPL-3.0-or-later) koşullarına göre kullanılabilir, değiştirilebilir ve yeniden dağıtılabilir. Program hiçbir garanti olmaksızın sunulur.", "MacNote++ is free software: you can use, modify and redistribute it under the terms of the GNU General Public License version 3 or (at your option) any later version (GPL-3.0-or-later). It comes with no warranty."))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .lineSpacing(2)

                HStack(spacing: 16) {
                    Link(destination: UpdateChecker.repositoryURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                            Text("gitlab.com/freeware2/macnotepp")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentColor)
                    }

                    Link(destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                            Text(appState.loc("Lisans metni (GPL-3.0-or-later)", "License text (GPL-3.0-or-later)"))
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Tab 2: Kullanım View
    private var usageTabView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(appState.loc("Sık Kullanılan Klavye Kısayolları", "Common Keyboard Shortcuts"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            VStack(spacing: 6) {
                shortcutRow(keys: ["⌘", "N"], desc: appState.loc("Yeni Belge Aç", "New Document"))
                shortcutRow(keys: ["⌘", "O"], desc: appState.loc("Dosya Aç...", "Open File..."))
                shortcutRow(keys: ["⌘", "S"], desc: appState.loc("Kaydet (⇧⌘S : Farklı Kaydet)", "Save (⇧⌘S: Save As)"))
                shortcutRow(keys: ["⌘", "W"], desc: appState.loc("Sekmeyi Kapat (veya Fare Orta Tuşu)", "Close Tab (or Middle Mouse Button)"))
                shortcutRow(keys: ["⌥", "⌘", "P"], desc: appState.loc("Yazdırma Önizleme (⌘P : Doğrudan Yazdır)", "Print Preview (⌘P: Print Directly)"))
                shortcutRow(keys: ["⌥", "+", appState.loc("Fare", "Mouse")], desc: appState.loc("Dikdörtgen / Sütun (Kolon) Seçimi", "Rectangular / Column Selection"))
                shortcutRow(keys: ["⌘", "F"], desc: appState.loc("Bul / Değiştir / Dosyalarda Bul Paneli", "Find / Replace / Find in Files Panel"))
                shortcutRow(keys: ["⌘", "G"], desc: appState.loc("Satıra / Karakter Ofsetine Git", "Go to Line / Offset"))
                shortcutRow(keys: ["⌘", "F2"], desc: appState.loc("Satıra Yer İmi Koy / Kaldır (F2 : Sonraki Yer İmi)", "Toggle Bookmark (F2: Next Bookmark)"))
                shortcutRow(keys: ["⌥", "C"], desc: appState.loc("Sütun & Sayı Dizisi Düzenleyici", "Column & Number Sequence Editor"))
                shortcutRow(keys: ["⇧", "⌘", "H"], desc: appState.loc("Hex (Onaltılık) Görünümünü Aç / Kapat", "Toggle Hex View"))
                shortcutRow(keys: ["⌥", "⌘", "M"], desc: appState.loc("Kod Haritasını (Minimap) Aç / Kapat", "Toggle Minimap"))
                shortcutRow(keys: ["⌥", "⌘", "B"], desc: appState.loc("Yan Panelleri (Fonksiyon / Klasör) Aç / Kapat", "Toggle Side Panels (Functions / Folder)"))
            }

            Divider().opacity(0.2)

            Text(appState.loc("Kullanım İpuçları", "Usage Tips"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                tipRow(
                    icon: "computermouse.fill",
                    title: appState.loc("Fare Orta Tuşu ile Kapatma", "Close with the Middle Button"),
                    body: appState.loc("Sekme başlığına fare tekerleğiyle tıklayarak sekmeyi doğrudan kapatabilirsiniz. Kaydedilmemiş veri varsa kaydetme onayı sorulur.", "Click a tab title with the mouse wheel to close it. If it has unsaved changes you are asked first.")
                )
                tipRow(
                    icon: "rectangle.split.3x1.fill",
                    title: appState.loc("Dikdörtgen Seçim", "Rectangular Selection"),
                    body: appState.loc("Option (⌥) tuşunu basılı tutarak fare ile sürüklediğinizde metin içinde dikdörtgen bir alan seçebilir, kopyalayabilir veya silebilirsiniz.", "Hold Option (⌥) and drag to select, copy or delete a rectangular area of text.")
                )
                tipRow(
                    icon: "shield.checkered",
                    title: appState.loc("Büyük Dosya Güvenliği", "Large File Safety"),
                    body: appState.loc("80 MB üzerindeki büyük SQL veya log dosyalarında donmayı önlemek için parçalı güvenli önizleme devreye girer.", "Files over 80 MB open in a safe partial preview so the app does not freeze.")
                )
            }
        }
    }

    // MARK: - Tab 3: Sistem View
    private var systemTabView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(appState.loc("Sistem ve Çalışma Zamanı Tanıları", "System and Runtime Diagnostics"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                systemInfoRow(icon: "laptopcomputer", title: appState.loc("İşletim Sistemi", "Operating System"), val: "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
                systemInfoRow(icon: "cpu", title: appState.loc("İşlemci / Mimari", "Processor / Architecture"), val: architectureName)
                systemInfoRow(icon: "memorychip", title: appState.loc("Bellek (RAM) Kullanımı", "Memory (RAM) Usage"), val: String(format: appState.loc("%.1f MB (Yerleşik)", "%.1f MB (Resident)"), getResidentMemoryMB()))
                systemInfoRow(icon: "swift", title: appState.loc("Geliştirme Motoru", "Built With"), val: "Swift / AppKit + SwiftUI")
                systemInfoRow(icon: "doc.on.doc", title: appState.loc("Açık Belge Sayısı", "Open Documents"), val: appState.loc("\(appState.tabs.count) açık sekme", "\(appState.tabs.count) open tabs"))
                systemInfoRow(icon: "character.book.closed", title: appState.loc("Aktif Arayüz Dili", "Interface Language"), val: appState.appLanguage.displayName)
                systemInfoRow(icon: "keyboard", title: appState.loc("Kısayol Şeması", "Shortcut Scheme"), val: appState.shortcutScheme.title(for: appState.appLanguage))
                systemInfoRow(icon: "paintpalette", title: appState.loc("Aktif Tema", "Theme"), val: appState.theme.title(for: appState.appLanguage))
                systemInfoRow(icon: "calendar", title: appState.loc("Telif ve Sürüm Yılı", "Copyright Year"), val: "2026")
            }

            Spacer()
        }
    }

    // MARK: - Helper Views
    private func featureBullet(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(red: 0.35, green: 0.70, blue: 0.98))
                .frame(width: 16, alignment: .center)
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.white.opacity(0.88))
                .lineSpacing(2)
        }
    }

    private func shortcutRow(keys: [String], desc: String) -> some View {
        HStack {
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { k in
                    Text(k)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.8)
                        )
                }
            }

            Text(desc)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.85))

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func tipRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.orange)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Text(body)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .lineSpacing(2)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func systemInfoRow(icon: String, title: String, val: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.35, green: 0.70, blue: 0.98))
                .frame(width: 18)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.75))

            Spacer()

            Text(val)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - App Version & Arch Helpers
    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        #if arch(arm64)
        let arch = "arm64"
        #else
        let arch = "x86_64"
        #endif
        return appState.loc("Sürüm \(version) (derleme \(build) · \(arch))", "Version \(version) (build \(build) · \(arch))")
    }

    private var architectureName: String {
        #if arch(arm64)
        return "Apple Silicon (arm64)"
        #elseif arch(x86_64)
        return "Intel (x86_64)"
        #else
        return "arm64"
        #endif
    }

    private func getResidentMemoryMB() -> Double {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            return Double(taskInfo.resident_size) / (1024.0 * 1024.0)
        }
        return 0.0
    }
}

// MARK: - About Sheet View (Wraps AboutWindowContent for sheet presentation)
public struct AboutSheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            AboutWindowContent(appState: appState)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .padding(14)
        }
        .frame(width: 510, height: 750)
    }
}
