import AppKit
import SwiftUI

/// Runs the update checks and shows the update window. The window is a panel rather than a sheet:
/// AppKit ignores terminate while a sheet is open, and SwiftUI shows only one sheet at a time.
@MainActor
final class UpdateController: NSObject, NSWindowDelegate {
    static let shared = UpdateController()

    private static let lastCheckKey = "MacNotePP.lastUpdateCheck"
    static let skippedVersionKey = "MacNotePP.skippedUpdateVersion"

    private var panel: NSPanel?
    private var didScheduleAutomaticCheck = false
    private var isCheckingFromMenu = false

    /// At launch: at most once a day, silent unless there is a version the user has not skipped.
    func checkAutomatically(appState: AppState) {
        guard !didScheduleAutomaticCheck else { return }
        didScheduleAutomaticCheck = true
        guard appState.checkUpdatesAutomatically else { return }
        if let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date,
           Date().timeIntervalSince(last) < 86_400 { return }
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if case .newer(let release) = await check(),
               UserDefaults.standard.string(forKey: Self.skippedVersionKey) != release.version {
                show(release, appState: appState)
            }
        }
    }

    /// A failed check is not recorded, so the next launch tries again.
    func check() async -> UpdateChecker.Outcome {
        let outcome = await UpdateChecker.check()
        if case .failed = outcome { return outcome }
        UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)
        return outcome
    }

    /// Help menu: the result is always reported.
    func checkFromMenu(appState: AppState) {
        guard !isCheckingFromMenu else { return }
        isCheckingFromMenu = true
        Task {
            let outcome = await check()
            isCheckingFromMenu = false
            let alert = NSAlert()
            switch outcome {
            case .newer(let release):
                show(release, appState: appState)
                return
            case .upToDate(let version):
                alert.messageText = appState.loc("MacNote++ güncel.", "MacNote++ is up to date.")
                alert.informativeText = appState.loc("Kullandığınız sürüm (\(version)) en son sürüm.", "Version \(version) is the latest version.")
            case .failed(let reason):
                alert.messageText = appState.loc("Güncellemeler denetlenemedi.", "Could not check for updates.")
                alert.informativeText = reason
            }
            alert.runModal()
            appState.restoreEditorFocus()
        }
    }

    func show(_ release: UpdateChecker.Release, appState: AppState) {
        panel?.close()
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 330),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newPanel.title = appState.loc("MacNote++ Güncellemesi", "MacNote++ Update")
        newPanel.isReleasedWhenClosed = false
        newPanel.hidesOnDeactivate = false
        newPanel.level = .floating
        newPanel.delegate = self
        newPanel.contentView = NSHostingView(rootView: UpdatePanelView(appState: appState, release: release) { [weak self] in
            self?.panel?.close()
        })
        newPanel.center()
        panel = newPanel
        NSApp.activate(ignoringOtherApps: true)
        newPanel.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Removing the view ends its onDisappear, which cancels a download in progress.
        panel?.contentView = nil
        panel = nil
    }
}

/// A new release: what changed, and update now, later or never.
struct UpdatePanelView: View {
    @ObservedObject var appState: AppState
    let release: UpdateChecker.Release
    let close: () -> Void

    private enum Phase { case ask, installing, installed, failed(String) }
    @State private var phase = Phase.ask
    @State private var work: Task<Void, Never>?

    private var canInstall: Bool {
        release.archive != nil && release.checksum != nil && UpdateChecker.canReplace(app: Bundle.main.bundleURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.loc("MacNote++ \(release.version) yayımlandı", "MacNote++ \(release.version) is available")).font(.headline)
                    Text(appState.loc("Kullandığınız sürüm: \(UpdateChecker.currentVersion)", "Your version: \(UpdateChecker.currentVersion)"))
                        .foregroundStyle(.secondary)
                }
            }
            switch phase {
            case .ask: ask
            case .installing: installing
            case .installed: installed
            case .failed(let reason): failed(reason)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 480, height: 330)
        .preferredColorScheme(appState.theme.isDark ? .dark : .light)
        .focusEffectDisabled()
        .onDisappear { work?.cancel() }
    }

    private var ask: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView {
                Text(UpdateChecker.whatsNew(in: release.notes))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(height: 170)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            HStack {
                Button(appState.loc("Bu Sürümü Atla", "Skip This Version")) {
                    UserDefaults.standard.set(release.version, forKey: UpdateController.skippedVersionKey)
                    close()
                }
                Spacer()
                Button(appState.loc("Sonra", "Later"), action: close).keyboardShortcut(.cancelAction)
                if canInstall {
                    Button(appState.loc("Şimdi Güncelle", "Update Now")) { install() }
                        .keyboardShortcut(.defaultAction)
                } else {
                    openPage.keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    private var installing: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(appState.loc("Sürüm \(release.version) indiriliyor ve doğrulanıyor. Bitince MacNote++ yeniden açılır; açık sekmeleriniz geri gelir.",
                              "Downloading and verifying version \(release.version). MacNote++ then reopens with your tabs."))
            ProgressView().progressViewStyle(.linear)
            HStack {
                Spacer()
                Button(appState.loc("İptal", "Cancel")) { work?.cancel() }.keyboardShortcut(.cancelAction)
            }
        }
    }

    private var installed: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(appState.loc("Güncelleme kuruldu. Yeni sürüm MacNote++ yeniden açıldığında başlar. Açık bir iletişim penceresi varsa önce onu kapatın.",
                              "The update is installed and starts when MacNote++ reopens. If a dialog is open, close it first."))
            HStack {
                Spacer()
                Button(appState.loc("Sonra", "Later"), action: close).keyboardShortcut(.cancelAction)
                Button(appState.loc("Yeniden Aç", "Reopen")) { restart() }.keyboardShortcut(.defaultAction)
            }
        }
    }

    private func failed(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(appState.loc("Güncelleme kurulamadı", "The update could not be installed")).font(.headline)
            Text(reason).textSelection(.enabled)
            Text(appState.loc("İsterseniz yeni sürümü indirme sayfasından elle kurabilirsiniz.", "You can install the new version by hand from the download page."))
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(appState.loc("Sonra", "Later"), action: close).keyboardShortcut(.cancelAction)
                openPage.keyboardShortcut(.defaultAction)
            }
        }
    }

    private var openPage: some View {
        Button(appState.loc("İndirme Sayfasını Aç", "Open Download Page")) {
            NSWorkspace.shared.open(release.url)
            close()
        }
    }

    private func install() {
        phase = .installing
        work = Task {
            do {
                try await Updater.install(release)
                restart()
            } catch {
                if Task.isCancelled { phase = .ask } else { phase = .failed(error.localizedDescription) }
            }
        }
    }

    private func restart() {
        if appState.prepareForUpdateRestart() {
            Updater.relaunch()
        } else {
            phase = .installed
        }
    }
}
