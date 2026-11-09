import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct ColumnEditorSheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Int = 0 // 0 = Text, 1 = Numbers
    @State private var columnIndex: Int = 1
    @State private var useCustomLineRange: Bool = false
    @State private var startLine: Int = 1
    @State private var endLine: Int = 10

    // Mode 0: Text
    @State private var textToInsert: String = ""

    // Mode 1: Numbers
    @State private var initialNumber: Int = 1
    @State private var increaseBy: Int = 1
    @State private var repeatCount: Int = 1
    @State private var leadingZeros: Bool = true
    @State private var minDigits: Int = 3
    @State private var numberFormat: NumberRadixFormat = .decimal
    @State private var numberPrefix: String = ""
    @State private var numberSuffix: String = ". "

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "rectangle.split.3x1.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.orange)
                Text(appState.loc("Sütun / Çoklu Satır Düzenleyici (Column Editor)", "Column Editor"))
                    .font(.system(size: 15, weight: .bold))
                Spacer()
            }

            // Custom Mode Selector Buttons
            HStack(spacing: 8) {
                Button {
                    mode = 0
                } label: {
                    HStack {
                        Image(systemName: "character.cursor.ibeam")
                        Text(appState.loc("Metin Ekle (Text to Insert)", "Insert Text"))
                            .fontWeight(mode == 0 ? .bold : .medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(mode == 0 ? Color.accentColor : Color.secondary.opacity(0.14))
                    )
                    .foregroundStyle(mode == 0 ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)

                Button {
                    mode = 1
                } label: {
                    HStack {
                        Image(systemName: "list.number")
                        Text(appState.loc("Artan Sayı Dizisi Ekle (Number)", "Insert Number Sequence"))
                            .fontWeight(mode == 1 ? .bold : .medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(mode == 1 ? Color.accentColor : Color.secondary.opacity(0.14))
                    )
                    .foregroundStyle(mode == 1 ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }

            // Target Column & Line Range Box
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Text(appState.loc("Hedef Sütun (Column):", "Target Column:"))
                            .font(.system(size: 12, weight: .medium))
                        TextField("1", value: $columnIndex, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                    }

                    Toggle(appState.loc("Belirli Satır Aralığı:", "Line Range:"), isOn: $useCustomLineRange)
                        .font(.system(size: 12, weight: .medium))

                    if useCustomLineRange {
                        HStack(spacing: 6) {
                            TextField(appState.loc("Başlangıç", "Start"), value: $startLine, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("—")
                            TextField(appState.loc("Bitiş", "End"), value: $endLine, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                        }
                    }
                    Spacer()
                }

                Divider()

                if mode == 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appState.loc("Her satırda belirtilen sütuna eklenecek metin:", "Text to insert at this column on each line:"))
                            .font(.system(size: 12, weight: .semibold))
                        TextField(appState.loc("Örn: // veya SQL_PREFIX_", "e.g. // or SQL_PREFIX_"), text: $textToInsert)
                            .textFieldStyle(.roundedBorder)
                    }
                } else {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                        GridRow {
                            Text(appState.loc("Başlangıç Sayısı:", "Start Number:"))
                            TextField("1", value: $initialNumber, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)

                            Text(appState.loc("Artış Miktarı:", "Increment:"))
                            TextField("1", value: $increaseBy, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        GridRow {
                            Text(appState.loc("Tekrar Sayısı:", "Repeat Count:"))
                            TextField("1", value: $repeatCount, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)

                            Text(appState.loc("Sayı Biçimi:", "Number Format:"))
                            Picker("", selection: $numberFormat) {
                                ForEach(NumberRadixFormat.allCases) { fmt in
                                    Text(fmt.title(for: appState.language)).tag(fmt)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 175)
                        }
                        GridRow {
                            Toggle(appState.loc("Başına Sıfır Ekle (001):", "Leading Zeros (001):"), isOn: $leadingZeros)
                            TextField(appState.loc("Basamak", "Digits"), value: $minDigits, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .disabled(!leadingZeros)

                            Text(appState.loc("Ön Ek / Son Ek:", "Prefix / Suffix:"))
                            HStack(spacing: 6) {
                                TextField("Ön", text: $numberPrefix)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 55)
                                TextField(appState.loc("Son", "Suffix"), text: $numberSuffix)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 55)
                            }
                        }
                    }
                    .font(.system(size: 12))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

            // Footer
            HStack(spacing: 12) {
                Text(appState.loc("İpucu: Editörde ⌥ (Option) + Tık veya ⌥⇧↑/↓ ile çoklu imleç (Multi-Cursor) oluşturup tüm satırlara aynı anda yazabilirsiniz.", "Tip: Use ⌥ (Option) + click or ⌥⇧↑/↓ to create multiple cursors and type on all lines at once."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 12)

                Button(appState.loc("İptal", "Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(appState.loc("Uygula", "Apply")) {
                    applyColumnEdit()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(width: 580)
        .onAppear {
            if let doc = appState.activeDocument {
                columnIndex = doc.cursorColumn
                startLine = 1
                endLine = doc.totalLines
            }
        }
    }

    private func applyColumnEdit() {
        guard var doc = appState.activeDocument else { return }
        let range: ClosedRange<Int>? = useCustomLineRange
            ? (min(startLine, endLine)...max(startLine, endLine))
            : nil

        let updated: String
        if mode == 0 {
            updated = TextOperations.applyColumnInsertText(
                to: doc.content,
                columnIndex: columnIndex,
                insertText: textToInsert,
                lineRange: range
            )
        } else {
            updated = TextOperations.applyColumnInsertNumbers(
                to: doc.content,
                columnIndex: columnIndex,
                initialNumber: initialNumber,
                increaseBy: increaseBy,
                repeatCount: repeatCount,
                leadingZeros: leadingZeros,
                minDigits: minDigits,
                format: numberFormat,
                prefix: numberPrefix,
                suffix: numberSuffix,
                lineRange: range
            )
        }
        doc.applyContentMutation(updated)
        appState.activeDocument = doc
        appState.saveSession()
    }
}

public struct GoToLineSheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var targetMode: Int = 0 // 0 = Line, 1 = Character Offset
    @State private var targetValue: Int = 1

    public var body: some View {
        let doc = appState.activeDocument
        let maxLines = doc?.totalLines ?? 1
        let maxOffset = (doc?.content as NSString?)?.length ?? 0

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.right.to.line")
                    .foregroundStyle(.blue)
                Text(appState.loc("Satıra / Ofsete Git (Go To...)", "Go To"))
                    .font(.system(size: 15, weight: .bold))
                Spacer()
            }

            Picker("", selection: $targetMode) {
                Text(appState.loc("Satır Numarası (Line)", "Line Number")).tag(0)
                Text(appState.loc("Karakter Ofseti (Offset)", "Character Offset")).tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(targetMode == 0 ? appState.loc("Mevcut Satır:", "Current Line:") : appState.loc("Mevcut Ofset:", "Current Offset:"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(targetMode == 0 ? "\(doc?.cursorLine ?? 1) / \(maxLines)" : "\(doc?.cursorOffset ?? 0) / \(maxOffset)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }

                HStack {
                    Text(targetMode == 0 ? appState.loc("Gidilecek Satır:", "Go to Line:") : appState.loc("Gidilecek Ofset:", "Go to Offset:"))
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    TextField("1", value: $targetValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 130)
                        .onSubmit {
                            performJump()
                            dismiss()
                        }
                }
            }
            .font(.system(size: 12))
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            HStack {
                Spacer()
                Button(appState.loc("Vazgeç", "Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(appState.loc("Git", "Go")) {
                    performJump()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(width: 380)
        .onAppear {
            targetValue = doc?.cursorLine ?? 1
        }
    }

    private func performJump() {
        if targetMode == 0 {
            appState.jumpToLine(targetValue)
        } else {
            appState.jumpToRange(NSRange(location: max(0, targetValue), length: 0))
        }
    }
}

public struct DocumentSummarySheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        let doc = appState.activeDocument
        let text = doc?.content ?? ""
        let charCount = text.count
        let charNoSpaces = text.filter { !$0.isWhitespace && !$0.isNewline }.count
        let wordCount = text.split { $0.isWhitespace || $0.isNewline }.count
        let lineCount = doc?.totalLines ?? 1
        let byteCount = doc?.byteLength ?? 0
        let bookmarkCount = doc?.bookmarks.count ?? 0

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .foregroundStyle(.blue)
                Text(appState.loc("Belge Özeti (Summary) — \(doc?.displayTitle ?? "")", "Document Info — \(doc?.displayTitle ?? "")"))
                    .font(.system(size: 15, weight: .bold))
                Spacer()
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text(appState.loc("Tam Dosya Yolu:", "Full Path:")).foregroundStyle(.secondary)
                    Text(doc?.fileURL?.path ?? appState.loc("(Henüz diske kaydedilmedi — Hot Exit ile korunuyor)", "(Not saved yet)"))
                        .textSelection(.enabled)
                }
                GridRow {
                    Text(appState.loc("Algılanan Dil:", "Language:")).foregroundStyle(.secondary)
                    Text("\(doc?.language.rawValue ?? "") — \(doc?.language.statusDescription ?? "")")
                }
                GridRow {
                    Text(appState.loc("Karakter Kodlaması:", "Encoding:")).foregroundStyle(.secondary)
                    Text(doc?.encoding.title(for: appState.language) ?? "UTF-8")
                }
                GridRow {
                    Text(appState.loc("Satır Sonu (EOL):", "Line Ending:")).foregroundStyle(.secondary)
                    Text(doc?.lineEnding.rawValue ?? "Unix (LF)")
                }
                GridRow {
                    Text(appState.loc("Toplam Byte Uzunluğu:", "Size in Bytes:")).foregroundStyle(.secondary)
                    Text("\(byteCount) byte").fontWeight(.bold)
                }
                GridRow {
                    Text(appState.loc("Toplam Karakter (Boşluk dahil):", "Characters (with spaces):")).foregroundStyle(.secondary)
                    Text("\(charCount)").fontWeight(.bold)
                }
                GridRow {
                    Text(appState.loc("Karakter (Boşluk hariç):", "Characters (no spaces):")).foregroundStyle(.secondary)
                    Text("\(charNoSpaces)")
                }
                GridRow {
                    Text(appState.loc("Kelime Sayısı:", "Words:")).foregroundStyle(.secondary)
                    Text("\(wordCount)").fontWeight(.bold)
                }
                GridRow {
                    Text(appState.loc("Satır Sayısı:", "Lines:")).foregroundStyle(.secondary)
                    Text("\(lineCount)").fontWeight(.bold)
                }
                GridRow {
                    Text(appState.loc("Yer İmi (Bookmark) Sayısı:", "Bookmarks:")).foregroundStyle(.secondary)
                    Text("\(bookmarkCount)")
                }
            }
            .font(.system(size: 12))
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            HStack {
                Spacer()
                Button(appState.loc("Tamam", "OK")) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(width: 520)
    }
}

public struct RunMacroMultipleTimesSheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMacroIndex: Int = -1
    @State private var repeatCount: Int = 5
    @State private var newMacroName: String = ""

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "play.square.stack.fill")
                    .foregroundStyle(.green)
                Text(appState.loc("Makro Yöneticisi ve Çoklu Çalıştırma", "Macros"))
                    .font(.system(size: 15, weight: .bold))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                Picker(appState.loc("Çalıştırılacak Makro:", "Macro:"), selection: $selectedMacroIndex) {
                    Text(appState.loc("Son Kaydedilen Geçici Makro (\(appState.currentRecordedActions.count) adım)", "Last Recorded Macro (\(appState.currentRecordedActions.count) steps)")).tag(-1)
                    ForEach(Array(appState.savedMacros.enumerated()), id: \.offset) { idx, macro in
                        Text("\(appState.macroTitle(macro.name)) (\(macro.actions.count) \(appState.loc("adım", "steps")))").tag(idx)
                    }
                }

                HStack {
                    Text(appState.loc("Tekrar Sayısı:", "Repeat Count:"))
                    TextField("5", value: $repeatCount, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text(appState.loc("kez çalıştır", "times"))
                }
                .font(.system(size: 12))

                if !appState.currentRecordedActions.isEmpty {
                    Divider()
                    HStack {
                        TextField(appState.loc("Geçici makroyu isimlendir...", "Name the recorded macro..."), text: $newMacroName)
                            .textFieldStyle(.roundedBorder)
                        Button(appState.loc("Kaydet", "Save")) {
                            let name = newMacroName.trimmingCharacters(in: .whitespaces).isEmpty
                                ? appState.loc("Özel Makro \(appState.savedMacros.count + 1)", "Custom Macro \(appState.savedMacros.count + 1)")
                                : newMacroName
                            appState.savedMacros.append(SavedMacro(name: name, actions: appState.currentRecordedActions))
                            newMacroName = ""
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            HStack {
                Spacer()
                Button(appState.loc("Kapat", "Close")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(appState.loc("Çalıştır", "Run")) {
                    if selectedMacroIndex == -1 {
                        appState.playMacro(actions: appState.currentRecordedActions, repeatCount: repeatCount)
                    } else if selectedMacroIndex >= 0 && selectedMacroIndex < appState.savedMacros.count {
                        appState.playMacro(actions: appState.savedMacros[selectedMacroIndex].actions, repeatCount: repeatCount)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(width: 500)
    }
}

public struct SettingsSheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: Int = 0 // 0 = Toolbar, 1 = Editor & View, 2 = Shortcuts
    @State private var draggedToolbarItem: ToolbarItemID? = nil
    @State private var dropTargetToolbarItem: ToolbarItemID? = nil

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        let _ = appState.languageRefreshTrigger
        VStack(alignment: .leading, spacing: 14) {
            // Header with Close ('X') button on top-right
            HStack(spacing: 10) {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.loc("MacNote++ Ayarlar ve Özelleştirme", "MacNote++ Settings & Preferences"))
                        .font(.system(size: 15, weight: .bold))
                    Text(appState.loc("Araç çubuğu butonlarını düzenleyin, editör tercihlerini ve kısayolları yönetin", "Customize toolbar buttons, editor preferences and shortcuts"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help(appState.loc("Kapat (Esc)", "Close (Esc)"))
            }

            // Tab Selector Buttons
            HStack(spacing: 8) {
                settingsTabButton(title: appState.loc("Araç Çubuğu (Toolbar)", "Toolbar"), icon: "slider.horizontal.3", tag: 0)
                settingsTabButton(title: appState.loc("Editör & Görünüm", "Editor & View"), icon: "doc.text.magnifyingglass", tag: 1)
                settingsTabButton(title: appState.loc("Kısayollar & Kodlama", "Shortcuts & Encoding"), icon: "keyboard", tag: 2)
                settingsTabButton(title: appState.loc("Dosya Türleri", "File Types"), icon: "doc.badge.gearshape", tag: 3)
            }

            Divider()

            // Tab Body inside ScrollView so it NEVER clips or overflows
            ScrollView(.vertical, showsIndicators: true) {
                Group {
                    if selectedTab == 0 {
                        toolbarCustomizationTab
                    } else if selectedTab == 1 {
                        editorAndViewTab
                    } else if selectedTab == 2 {
                        shortcutsAndEncodingTab
                    } else {
                        FileAssociationsTab(appState: appState)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Footer with Clear "Kapat" Button
            HStack {
                Text(appState.loc("Tüm tercihler otomatik olarak anında kaydedilir.", "All preferences are saved automatically."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(appState.loc("Kapat", "Close")) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(width: 700, height: 580)
    }

    private func settingsTabButton(title: String, icon: String, tag: Int) -> some View {
        let active = (selectedTab == tag)
        return Button {
            selectedTab = tag
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .fontWeight(active ? .bold : .medium)
            }
            .font(.system(size: 12))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(active ? Color.accentColor : Color.secondary.opacity(0.14))
            )
            .foregroundStyle(active ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 0: Toolbar Customization
    private var toolbarCustomizationTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolbarTopOptionsBox
            toolbarItemsHeader
            toolbarItemsScrollView
        }
    }

    private var toolbarTopOptionsBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(appState.loc("Küçük / Dar Ekranlar İçin Çok Satırlı Araç Çubuğu (Multi-Row Toolbar)", "Multi-Row Toolbar for Small Screens"), isOn: $appState.isMultiRowToolbar)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            Text(appState.loc("Aktif olduğunda pencere genişliğine sığmayan araç çubuğu butonları otomatik olarak alt satıra kayar.", "Wraps toolbar buttons to multiple rows when window width is narrow."))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Toggle(appState.loc("Araç Çubuğu Üzerinde Canlı Düzenleme Modu", "Live Toolbar Edit Mode"), isOn: $appState.isToolbarEditMode)
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                Button(appState.loc("Tüm Özellikleri Göster", "Show All Items")) {
                    appState.showAllToolbarItems()
                }
                .controlSize(.small)
                .disabled(appState.hiddenToolbarItems.isEmpty)

                Button(appState.loc("Varsayılan Sıralamaya Sıfırla", "Reset to Defaults")) {
                    appState.resetToolbarToDefaults()
                }
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var toolbarItemsHeader: some View {
        HStack {
            Text("\(appState.loc("ARAÇ ÇUBUĞU ÖZELLİKLERİ", "TOOLBAR BUTTONS")) (\(ToolbarItemID.allCases.count - appState.hiddenToolbarItems.count) / \(ToolbarItemID.allCases.count) \(appState.loc("Görünür", "Visible")))")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(appState.loc("İşaretini kaldırarak gizleyin veya sürükleyerek sıralayın", "Uncheck to hide, drag to reorder"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var toolbarItemsScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(Array(appState.toolbarItemOrder.enumerated()), id: \.element.id) { index, item in
                    toolbarItemRow(item: item, index: index)
                }
            }
            .padding(6)
        }
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func toolbarItemRow(item: ToolbarItemID, index: Int) -> some View {
        let isVisible = appState.isToolbarItemVisible(item)
        let isBeingDragged = (draggedToolbarItem == item)
        let isDropTarget = (dropTargetToolbarItem == item)

        return HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary.opacity(0.8))
                .frame(width: 14)
                .help(appState.loc("Fare ile sürükleyip bırakarak sıralayın", "Drag and drop to reorder"))

            Toggle("", isOn: Binding(
                get: { appState.isToolbarItemVisible(item) },
                set: { _ in appState.toggleToolbarItemVisibility(item) }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)

            Image(systemName: item.iconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isVisible ? Color.accentColor : Color.secondary)
                .frame(width: 22)

            Text(item.title(for: appState.language))
                .font(.system(size: 12, weight: isVisible ? .medium : .regular))
                .foregroundStyle(isVisible ? Color.primary : Color.secondary)

            Spacer()

            Text(isVisible ? appState.loc("Görünür", "Visible") : appState.loc("Gizli", "Hidden"))
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(isVisible ? Color.green.opacity(0.16) : Color.red.opacity(0.16))
                )
                .foregroundStyle(isVisible ? Color.green : Color.red)

            HStack(spacing: 2) {
                Button {
                    appState.moveToolbarItem(item, direction: -1)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 22, height: 20)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(index == 0)
                .help(appState.loc("Yukarı / Sola Taşı", "Move Up / Left"))

                Button {
                    appState.moveToolbarItem(item, direction: 1)
                } label: {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 22, height: 20)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(index == appState.toolbarItemOrder.count - 1)
                .help(appState.loc("Aşağı / Sağa Taşı", "Move Down / Right"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isBeingDragged
                        ? Color.orange.opacity(0.2)
                        : (isDropTarget ? Color.accentColor.opacity(0.2) : Color(nsColor: .controlBackgroundColor))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isDropTarget ? Color.orange : Color.clear, lineWidth: 1.5)
        )
        .onDrag {
            self.draggedToolbarItem = item
            return NSItemProvider(object: item.rawValue as NSString)
        }
        .onDrop(
            of: [UTType.text.identifier, UTType.plainText.identifier],
            delegate: ToolbarItemDropDelegate(
                targetItem: item,
                draggedItem: $draggedToolbarItem,
                dropTargetItem: $dropTargetToolbarItem,
                appState: appState
            )
        )
    }

    // MARK: - Tab 1: Editor & View Settings
    private var editorAndViewTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(appState.loc("Uygulama Dili (Language):", "Application Language:"))
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 170, alignment: .leading)
                    Picker("", selection: $appState.appLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text("\(lang.flag) \(lang.displayName)").tag(lang)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 240)
                    Spacer()
                }

                Divider()

                HStack {
                    Text(appState.loc("Editör Teması:", "Editor Theme:"))
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 170, alignment: .leading)
                    Picker("", selection: $appState.theme) {
                        ForEach(EditorTheme.allCases) { t in
                            Text(t.title(for: appState.language)).tag(t)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 240)
                    Spacer()
                }

                HStack {
                    Text(appState.loc("Yazı Tipi Boyutu (Font Size):", "Font Size:"))
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 170, alignment: .leading)
                    Slider(value: $appState.fontSize, in: 8...48, step: 1)
                        .frame(width: 180)
                    Text("\(Int(appState.fontSize)) pt")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .frame(width: 45)
                    Button(appState.loc("Varsayılan (13 pt)", "Default (13 pt)")) {
                        appState.fontSize = 13.0
                    }
                    .controlSize(.small)
                    Spacer()
                }

                Toggle(appState.loc("Ctrl / ⌘ Cmd + Fare Tekerleği ile Yakınlaştırma (Mouse Wheel Zoom)", "Mouse Wheel Zoom with Ctrl / ⌘ Cmd"), isOn: $appState.enableScrollWheelZoom)
                    .font(.system(size: 12, weight: .medium))

                Toggle(appState.loc("MacBook Dokunmatik Yüzey (Trackpad) İki Parmak Kıstırma ile Zoom (Pinch to Zoom)", "Trackpad Pinch to Zoom"), isOn: $appState.enableTrackpadPinchZoom)
                    .font(.system(size: 12, weight: .medium))

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Toggle(appState.loc("Akıllı Vurgulama (Smart Highlighting — Çift tıklanan kelimeyi ve eşleşenleri vurgula)", "Smart Highlighting (Highlight matching occurrences on double-click)"), isOn: $appState.enableSmartHighlighting)
                        .font(.system(size: 12, weight: .semibold))

                    if appState.enableSmartHighlighting {
                        HStack(spacing: 20) {
                            Toggle(appState.loc("Yalnızca Tam Sözcükleri Eşleştir", "Match Whole Words Only"), isOn: $appState.smartHighlightWholeWordOnly)
                                .font(.system(size: 11, weight: .regular))
                            Toggle(appState.loc("Büyük/Küçük Harf Duyarlı", "Case Sensitive"), isOn: $appState.smartHighlightCaseSensitive)
                                .font(.system(size: 11, weight: .regular))
                        }
                        .padding(.leading, 20)
                    }
                }

                Divider()

                Toggle(appState.loc("Sözcük Kaydırma (Word Wrap — Pencereye sığdır)", "Word Wrap (Fit lines to window width)"), isOn: $appState.wordWrap)
                    .font(.system(size: 12, weight: .medium))

                Toggle(appState.loc("Satır Numaralarını ve Yer İmi (Bookmark) Şeridini Göster", "Show Line Numbers and Bookmark Gutter"), isOn: $appState.showLineNumbers)
                    .font(.system(size: 12, weight: .medium))

                Toggle(appState.loc("Görünmez Karakterleri Göster (Boşluk ·, Sekme → ve Satır Sonu CRLF/LF)", "Show Invisible Characters (Space, Tab, EOL badges)"), isOn: $appState.showInvisibleCharacters)
                    .font(.system(size: 12, weight: .medium))

                Toggle(appState.loc("MacNote++ Penceresini Her Zaman Üstte Tut (Always on Top)", "Always on Top"), isOn: $appState.isAlwaysOnTop)
                    .font(.system(size: 12, weight: .medium))

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Toggle(appState.loc("Önceki Oturumu ve Açık Dosyaları Başlangıçta Geri Yükle", "Restore Previous Session on Startup"), isOn: $appState.restoreSessionOnStartup)
                        .font(.system(size: 12, weight: .semibold))
                    Text(appState.loc("İşaret kaldırıldığında MacNote++ sonraki açılışında önceki dosyaları açmaz, yeni bir metin belgesi ile başlar.", "When unchecked, MacNote++ starts fresh with a new tab."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 20)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Toggle(appState.loc("Güncellemeleri Her Gün Otomatik Denetle", "Check for Updates Automatically Every Day"), isOn: $appState.checkUpdatesAutomatically)
                        .font(.system(size: 12, weight: .semibold))
                    Text(appState.loc("Yalnızca gitlab.com'daki son sürüm bilgisine bakılır; yeni sürüm kurulmadan önce sorulur.", "Only the latest release information on gitlab.com is read; you are asked before anything is installed."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 20)
                }

                Divider()

                Text(appState.loc("PANELLER & YARDIMCI GÖRÜNÜMLER", "PANELS & VIEWS"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)

                Toggle(appState.loc("Belge Haritasını Göster (Minimap — Editörün sağında önizleme)", "Show Document Minimap"), isOn: $appState.showMinimap)
                    .font(.system(size: 12, weight: .medium))

                Toggle(appState.loc("Sol Çalışma Klasörü Ağacı Paneli (Folder as Workspace)", "Left Workspace Folder Sidebar"), isOn: $appState.showLeftWorkspaceSidebar)
                    .font(.system(size: 12))

                Toggle(appState.loc("Sağ Fonksiyon Listesi ve Yer İmleri Paneli", "Right Function List and Bookmarks Sidebar"), isOn: $appState.showRightSidebar)
                    .font(.system(size: 12))

                Toggle(appState.loc("Alt Arama Sonuçları (Find result) Paneli", "Bottom Search Results Dock"), isOn: $appState.showSearchResultsDock)
                    .font(.system(size: 12))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

            Spacer()
        }
    }

    // MARK: - Tab 2: Shortcuts & Encoding
    private var shortcutsAndEncodingTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(appState.loc("Klavye Kısayol Modu:", "Keyboard Shortcut Scheme:"))
                        .font(.system(size: 12, weight: .semibold))
                    Picker("", selection: $appState.shortcutScheme) {
                        ForEach(ShortcutScheme.allCases) { scheme in
                            Text(scheme.title(for: appState.language)).tag(scheme)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 260)
                    Spacer()
                }
                Text(appState.loc("Hibrit modda hem Windows (Ctrl+Z, Ctrl+Y, Ctrl+F, Ctrl+H, Ctrl+D) hem de macOS (⌘Z, ⇧⌘Z, ⌘F) kısayolları birlikte çalışır.", "In Hybrid mode, both Windows (Ctrl+...) and macOS (⌘...) shortcuts work simultaneously."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Divider()

                Text(appState.loc("SIK KULLANILAN KISAYOLLAR", "COMMON SHORTCUTS"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 6) {
                    GridRow {
                        Text(appState.loc("Geri Al / İleri Al (Undo / Redo):", "Undo / Redo:")).foregroundStyle(.secondary)
                        Text("⌘Z / ⇧⌘Z  veya  Ctrl+Z / Ctrl+Y").font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    GridRow {
                        Text(appState.loc("Bul / Değiştir / Dosyalarda Bul:", "Find / Replace / In Files:")).foregroundStyle(.secondary)
                        Text("⌘F / ⌘R / ⇧⌘F  veya  Ctrl+F / Ctrl+H").font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    GridRow {
                        Text(appState.loc("Yer İmi Ekle / Sonraki / Önceki:", "Bookmark Add / Next / Prev:")).foregroundStyle(.secondary)
                        Text("⌘F2 (veya ⌘B)  /  F2 (veya ⌘])  /  ⇧F2 (veya ⌘[)").font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    GridRow {
                        Text(appState.loc("Çoklu İmleç (Multi-Cursor):", "Multi-Cursor:")).foregroundStyle(.secondary)
                        Text("⌥+Tık, ⌥+Sürükle, ⌥⇧↑ / ⌥⇧↓, ⌥⇧I").font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    GridRow {
                        Text(appState.loc("Sütun Düzenleyici (Column Editor):", "Column Editor:")).foregroundStyle(.secondary)
                        Text("⌥C").font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    GridRow {
                        Text(appState.loc("Satır Çoğalt / Satır Sil / Yorum:", "Duplicate / Delete / Comment:")).foregroundStyle(.secondary)
                        Text("⌘D (Ctrl+D)  /  ⇧⌘L (Ctrl+L)  /  ⌘/ (Ctrl+Q)").font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    GridRow {
                        Text(appState.loc("Sözcük Kaydırma (Word Wrap):", "Word Wrap:")).foregroundStyle(.secondary)
                        Text("⌥⌘W").font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                }
                .font(.system(size: 11))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

            Spacer()
        }
    }
}

// MARK: - Large File Guard Sheet View (Files >= 80 MB, e.g. 1GB SQL Backup)
public struct LargeFileGuardSheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var previewLimitMB: Int = 10

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.loc("Büyük Dosya Güvenlik Kalkanı", "Large File Guard"))
                        .font(.system(size: 16, weight: .bold))
                    Text(appState.loc("Açılmak istenen dosya standart metin editörleri için çok büyüktür.", "The file is too large for standard text editors."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // File Info Box
            if let file = appState.pendingLargeFile {
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.url.lastPathComponent)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(file.url.path)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }

                    Spacer()

                    Text(file.formattedSize)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.18))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            }

            Text(appState.loc(
                "100 MB veya 1 GB+ boyutundaki dosyaları doğrudan RAM'e yüklemek uygulamanın 2-4 GB bellek tüketmesine ve kilitlenmesine neden olabilir. Lütfen bir açılış yöntemi seçin:",
                "Loading 100 MB or 1 GB+ files entirely into RAM may consume 2-4 GB memory and freeze the app. Please choose an opening method:"
            ))
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Option 1: Partial Preview (Recommended)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(appState.loc("🛡️ Hızlı Güvenli Önizleme", "🛡️ Fast Safe Preview"))
                                .font(.system(size: 13, weight: .bold))
                            Text(appState.loc("(Tavsiye Edilen)", "(Recommended)"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.green)
                        }
                        Text(appState.loc(
                            "Dosyanın başlangıç bloğunu milisaniyeler içinde anında açar. Orijinal dosyayı korumak için salt okunur açılır.",
                            "Opens the initial block in milliseconds. Read-only to protect original file."
                        ))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Picker("", selection: $previewLimitMB) {
                        Text("5 MB").tag(5)
                        Text("10 MB").tag(10)
                        Text("25 MB").tag(25)
                        Text("50 MB").tag(50)
                    }
                    .frame(width: 85)

                    Button(appState.loc("Önizlemeyi Aç", "Open Preview")) {
                        appState.confirmLargeFileOpen(action: .partialPreview(limitMB: previewLimitMB))
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.08))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.3), lineWidth: 1))

            // Option 2: Hex View & Option 3: Full Open
            HStack(spacing: 12) {
                Button {
                    appState.confirmLargeFileOpen(action: .hexView)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(appState.loc("Hex / İkili Görünüm", "Hex / Binary View"), systemImage: "number.square")
                            .font(.system(size: 12, weight: .semibold))
                        Text(appState.loc("Diskten akışlı, RAM tüketmez", "Streaming from disk, zero RAM spike"))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .buttonStyle(.bordered)

                Button {
                    appState.confirmLargeFileOpen(action: .fullOpen)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(appState.loc("Tümünü Zorla Aç", "Force Open Full"), systemImage: "flame.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.red)
                        Text(appState.loc("Yavaş olabilir, yüksek RAM", "May be slow, high RAM"))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .buttonStyle(.bordered)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button(appState.loc("Vazgeç / İptal", "Cancel")) {
                    appState.confirmLargeFileOpen(action: .cancel)
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(22)
        .frame(width: 580)
    }
}

// MARK: - Large File Partial Preview Banner
public struct LargeFilePartialPreviewBanner: View {
    @ObservedObject var appState: AppState
    let doc: EditorDocument
    private var isLoadingFull: Bool { appState.fullLoadTabId == doc.id }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 14))

            if isLoadingFull {
                ProgressView()
                    .controlSize(.small)
                Text(appState.loc(
                    "Dosyanın tamamı arka planda yükleniyor, lütfen bekleyin... (\(doc.formattedTotalSize))",
                    "Loading full file in background, please wait... (\(doc.formattedTotalSize))"
                ))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.orange)
            } else {
                Text(appState.loc(
                    "Büyük Dosya Güvenli Önizleme Modu: Dosyanın yalnızca başlangıç kısmı görüntülendi. Orijinal dosyanın bozulmasını önlemek için salt okunur (read-only) kilitlendi.",
                    "Large File Safe Preview Mode: Only the beginning of the file is loaded. Locked as read-only to protect original file."
                ))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)

                if !doc.formattedTotalSize.isEmpty {
                    Text(appState.loc("Toplam Boyut: \(doc.formattedTotalSize)", "Total: \(doc.formattedTotalSize)"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                }

                Spacer()

                if let _ = doc.fileURL {
                    Button(appState.loc("Hex Modunda Aç", "Open in Hex")) {
                        appState.openTabInHex(for: doc.id)
                    }
                    .controlSize(.small)

                    Button(appState.loc("Tamamını Yükle", "Load Full File")) {
                        appState.loadFullFile(for: doc.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.12))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
