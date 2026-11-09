import SwiftUI

/// Settings tab: which file types open in MacNote++ by default.
struct FileAssociationsTab: View {
    @ObservedObject var appState: AppState
    @StateObject private var model = FileAssociationsModel()

    var body: some View {
        let _ = model.revision
        VStack(alignment: .leading, spacing: 12) {
            Text(appState.loc(
                "İşaretlediğiniz dosya türleri Finder'dan çift tıklayınca MacNote++ ile açılır. Bu ayar yalnızca siz işaretleyince değişir ve geri alınabilir.",
                "File types you check open in MacNote++ when double-clicked in Finder. This changes only when you check a box, and it can be undone."
            ))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Label(
                appState.loc(
                    "macOS her dosya türü için ayrı onay penceresi açar. Değişiklik için pencerede \"MacNote++ Kullan\" düğmesine basın.",
                    "macOS shows a separate confirmation for each file type. To apply the change, click \"Use MacNote++\" in that window."
                ),
                systemImage: "info.circle"
            )
            .font(.system(size: 12))
            .fixedSize(horizontal: false, vertical: true)

            if !model.isInstalledInApplications {
                Label(
                    appState.loc(
                        "MacNote++ Uygulamalar klasöründe değil. Önce oraya taşıyın; aksi halde dosya ilişkilendirmeleri sonradan bozulabilir.",
                        "MacNote++ is not in the Applications folder. Move it there first, or these file associations may break later."
                    ),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.system(size: 12))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button(appState.loc("Tümünü Seç", "Select All")) {
                    if confirmBatch(count: model.typesNotYetDefault) {
                        Task { await model.selectAll() }
                    }
                }
                .disabled(model.typesNotYetDefault == 0)
                Button(appState.loc("Önceki Uygulamalara Dön", "Restore Previous Apps")) {
                    if confirmBatch(count: model.typesAlreadyDefault) {
                        Task { await model.restoreAll() }
                    }
                }
                .disabled(!model.canRestore || model.typesAlreadyDefault == 0)
                if model.isWorking {
                    ProgressView().controlSize(.small)
                }
            }
            .disabled(model.isWorking)

            if let failure = model.failure {
                Text(failure)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            ForEach(FileAssociationGroup.all) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title(for: appState.language).uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                    ForEach(group.associations.filter { !$0.contentTypes.isEmpty }) { association in
                        row(association)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
    }

    private func confirmBatch(count: Int) -> Bool {
        let alert = NSAlert()
        alert.messageText = appState.loc("macOS \(count) kez onay soracak", "macOS will ask \(count) times")
        alert.informativeText = appState.loc(
            "Her dosya türü için ayrı bir pencere açılır. Pencerelerden birinde vazgeçerseniz kalan türler değiştirilmez.",
            "A separate window opens for each file type. If you decline one of them, the remaining types are left unchanged."
        )
        alert.addButton(withTitle: appState.loc("Devam Et", "Continue"))
        alert.addButton(withTitle: appState.loc("Vazgeç", "Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func row(_ association: FileAssociation) -> some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { model.isDefault(association) },
                set: { enabled in Task { await model.setDefault(association, enabled: enabled) } }
            )) {
                HStack(spacing: 8) {
                    Text(association.title(for: appState.language))
                        .font(.system(size: 12, weight: .medium))
                    Text(association.extensionList)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .toggleStyle(.checkbox)
            .disabled(model.isWorking)

            Spacer(minLength: 8)

            Text(model.currentHandlerName(association, language: appState.language))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
    }
}
