import AppKit
import SwiftUI

public enum HexEditFocusPane: String, CaseIterable {
    case hex = "HEX Sütunu"
    case ascii = "ASCII Sütunu"
}

public struct HexPatternRule: Identifiable, Equatable {
    public let id = UUID()
    public var label: String
    public var patternString: String // Hex bytes ("4D 5A") or ASCII ("SELECT")
    public var colorName: String
    public var isEnabled: Bool

    public var nsColor: NSColor {
        switch colorName {
        case "Yeşil": return .systemGreen
        case "Mavi": return .systemBlue
        case "Turuncu": return .systemOrange
        case "Kırmızı": return .systemRed
        case "Mor": return .systemPurple
        case "Turkuaz": return .systemTeal
        default: return .systemYellow
        }
    }
}

public struct HexEditorView: View {
    @ObservedObject var appState: AppState
    let document: EditorDocument

    /// The moving end of the selection, also the byte typing goes to.
    @State private var selectedByteOffset: Int = 0
    /// The fixed end of the selection; equal to `selectedByteOffset` for a single byte.
    @State private var selectionAnchor: Int = 0
    @State private var inspectedRange: Range<Int>? = nil
    @State private var inspectorBigEndian: Bool = false
    @State private var activePane: HexEditFocusPane = .hex
    @State private var pendingHighNibble: UInt8? = nil

    @State private var hexSearchInput: String = ""
    @State private var jumpOffsetInput: String = ""
    @State private var searchMatchOffsets: Set<Int> = []
    @State private var scrollRequestOffset: Int? = nil
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var statusMessage: String = ""

    private var defaultStatusMessage: String {
        appState.loc(
            "Doğrudan düzenlemek için Hex veya ASCII hücresine tıklayıp klavyeden yazın (Tab ile sütun değiştirin).",
            "Click Hex or ASCII cell to edit directly from keyboard (Tab to switch column)."
        )
    }

    // Pattern Coloring State
    @State private var enableSemanticColoring: Bool = true
    @State private var enableCustomPatterns: Bool = true
    @State private var newPatternText: String = ""
    @State private var newPatternColor: String = "Yeşil"
    @State private var patternRules: [HexPatternRule] = [
        HexPatternRule(label: "Satır Sonu (LF/CRLF)", patternString: "0A", colorName: "Turkuaz", isEnabled: true),
        HexPatternRule(label: "C/C++ #include / #define", patternString: "#", colorName: "Mor", isEnabled: true),
        HexPatternRule(label: "SQL / Kod Anahtar", patternString: "SELECT", colorName: "Mavi", isEnabled: true),
        HexPatternRule(label: "Pascal begin/end", patternString: "begin", colorName: "Yeşil", isEnabled: true),
        HexPatternRule(label: "String Tırnak (\" / ')", patternString: "\"", colorName: "Turuncu", isEnabled: true)
    ]

    /// Above this size a file is read from disk page by page and cannot be edited here.
    private static let inMemoryLimit = 20 * 1024 * 1024

    private var byteSource: HexByteSource {
        if let url = document.fileURL, !document.isModified,
           let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = (attributes[.size] as? NSNumber)?.intValue, size > Self.inMemoryLimit {
            return HexByteSource(pager: .pager(for: url, size: size, modificationDate: attributes[.modificationDate] as? Date))
        }
        if let raw = document.rawData {
            return HexByteSource(data: raw)
        }
        return HexByteSource(data: Data(document.content.utf8.prefix(Self.inMemoryLimit)))
    }

    private var activePatterns: [HexPattern] {
        guard enableCustomPatterns else { return [] }
        return patternRules.filter(\.isEnabled).compactMap { rule in
            let needle = parsePatternBytes(rule.patternString)
            return needle.isEmpty ? nil : HexPattern(needle: needle, color: rule.nsColor)
        }
    }

    public var body: some View {
        let currentBytes = byteSource
        let selection = selectedRange(in: currentBytes)
        let hasRange = selection.count > 1
        let canEdit = !currentBytes.isPaged && !document.isPartialPreview && !document.isReadOnly

        VStack(spacing: 0) {
            // Top Two-Row Responsive Control Panel
            VStack(spacing: 6) {
                // Row 1: Header / Mode Picker / Toggles / Actions
                HStack(spacing: 10) {
                    Label(appState.loc("HEX EDİTÖR", "HEX EDITOR"), systemImage: "00.square.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.purple)
                        .fixedSize()

                    Picker("", selection: $activePane) {
                        Text(appState.loc("HEX Yazım", "HEX Edit")).tag(HexEditFocusPane.hex)
                        Text(appState.loc("ASCII Yazım", "ASCII Edit")).tag(HexEditFocusPane.ascii)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 175)
                    .controlSize(.small)
                    .help(appState.loc("Hex veya ASCII sütununa tıklayarak ya da Tab tuşuyla aktif yazım sütununu değiştirebilirsiniz", "Click Hex or ASCII column, or press Tab to switch active editing column"))

                    Divider().frame(height: 16)

                    Toggle(appState.loc("Byte Renkleri", "Byte Colors"), isOn: $enableSemanticColoring)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11))
                        .fixedSize()

                    Toggle(appState.loc("Patern Vurgusu", "Pattern Highlight"), isOn: $enableCustomPatterns)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11))
                        .fixedSize()

                    Spacer(minLength: 8)

                    Menu(hasRange ? appState.loc("Seçimi Kopyala", "Copy Selection") : appState.loc("Tümünü Kopyala", "Copy All")) {
                        Button(appState.loc("Hex Dizisi (AA BB CC)", "Hex Sequence (AA BB CC)")) {
                            guard let copyTarget = bytesToCopy(selection, in: currentBytes) else { return }
                            let dump = copyTarget.map { String(format: "%02X", $0) }.joined(separator: " ")
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(dump, forType: .string)
                            statusMessage = appState.loc("\(copyTarget.count) byte Hex olarak kopyalandı.", "\(copyTarget.count) bytes copied as Hex.")
                        }
                        Button(appState.loc("C Dizisi ({ 0xAA, 0xBB })", "C Array ({ 0xAA, 0xBB })")) {
                            guard let copyTarget = bytesToCopy(selection, in: currentBytes) else { return }
                            let items = copyTarget.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
                            let cArray = "const uint8_t data[\(copyTarget.count)] = { \(items) };"
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(cArray, forType: .string)
                            statusMessage = appState.loc("C dizisi panoya kopyalandı.", "C array copied to clipboard.")
                        }
                        Button(appState.loc("Pascal Dizisi (($AA, $BB))", "Pascal Array (($AA, $BB))")) {
                            guard let copyTarget = bytesToCopy(selection, in: currentBytes) else { return }
                            let items = copyTarget.map { String(format: "$%02X", $0) }.joined(separator: ", ")
                            let pasArray = "const Data: array[0..\(max(0, copyTarget.count - 1))] of Byte = (\(items));"
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(pasArray, forType: .string)
                            statusMessage = appState.loc("Pascal dizisi panoya kopyalandı.", "Pascal array copied to clipboard.")
                        }
                    }
                    .controlSize(.small)
                    .fixedSize()

                    Button {
                        appState.toggleHexView()
                    } label: {
                        Label(appState.loc("Metin Görünümü", "Text View"), systemImage: "doc.text")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.small)
                    .fixedSize()
                }

                // Row 2: Navigation (Jump to Offset) & Search (Find in Hex/Text)
                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.right.to.line")
                            .font(.system(size: 10))
                            .foregroundStyle(.purple)
                        Text(appState.loc("Ofset:", "Offset:"))
                            .font(.system(size: 11, weight: .medium))
                            .fixedSize()
                        TextField("0x0000", text: $jumpOffsetInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 85)
                            .controlSize(.small)
                            .onSubmit { jumpToOffset() }
                        Button(appState.loc("Git", "Go")) { jumpToOffset() }
                            .controlSize(.small)
                            .fixedSize()
                    }

                    Divider().frame(height: 16)

                    HStack(spacing: 5) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundStyle(.purple)
                        Text(appState.loc("Ara:", "Find:"))
                            .font(.system(size: 11, weight: .medium))
                            .fixedSize()
                        TextField(appState.loc("Hex (4D 61) veya Metin...", "Hex (4D 61) or Text..."), text: $hexSearchInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 140, maxWidth: 240)
                            .controlSize(.small)
                            .onSubmit { performHexSearch() }
                        Button(appState.loc("Bul", "Find")) { performHexSearch() }
                            .controlSize(.small)
                            .fixedSize()
                    }

                    Spacer(minLength: 8)

                    Text("\(currentBytes.count) bytes")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Status & Color Legend Bar (Row 3)
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle().fill(Color.purple).frame(width: 7, height: 7)
                    Text(statusMessage.isEmpty
                         ? (currentBytes.isPaged
                            ? appState.loc("Büyük dosya: tamamı diskten okunuyor, bu görünümde düzenlenemez.", "Large file: read from disk as you scroll, not editable in this view.")
                            : (document.isReadOnly
                               ? appState.loc("Salt okunur: düzenlemek için alttaki RO kilidine tıklayıp kilidi açın.", "Read-only: click the RO lock below to unlock editing.")
                               : defaultStatusMessage))
                         : statusMessage)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                if enableSemanticColoring {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            LegendDot(color: .blue, label: appState.loc("Harf (A-Z)", "Letter (A-Z)"))
                            LegendDot(color: .orange, label: appState.loc("Rakam (0-9)", "Digit (0-9)"))
                            LegendDot(color: .green, label: appState.loc("Sembol", "Symbol"))
                            LegendDot(color: .teal, label: appState.loc("Boşluk/EOL", "Space/EOL"))
                            LegendDot(color: .red, label: appState.loc("Kontrol", "Control"))
                            LegendDot(color: .purple, label: "UTF-8/High")
                            LegendDot(color: .gray, label: "NULL (00)")
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.06))

            Divider()

            HStack(spacing: 0) {
                // Left: High-Speed AppKit Native Hex + ASCII Canvas with Direct Editing
                VStack(spacing: 0) {
                    // Column Header Row
                    HStack(spacing: 0) {
                        Text("OFFSET")
                            .frame(width: 88, alignment: .leading)
                            .foregroundStyle(.secondary)

                        ForEach(0..<16, id: \.self) { col in
                            Text(String(format: "%02X", col))
                                .frame(width: 26, alignment: .center)
                                .foregroundStyle(col == (selectedByteOffset % 16) ? Color.orange : Color.secondary)
                            if col == 7 {
                                Text("│")
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 12, alignment: .center)
                            }
                        }

                        Text("│")
                            .foregroundStyle(.tertiary)
                            .frame(width: 18, alignment: .center)

                        Text("ASCII")
                            .frame(width: 190, alignment: .leading)
                            .foregroundStyle(activePane == .ascii ? Color.orange : Color.secondary)

                        Spacer()
                    }
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.10))

                    Divider()

                    NativeHexGridRepresentable(
                        bytes: currentBytes,
                        selectedOffset: $selectedByteOffset,
                        selectionAnchor: $selectionAnchor,
                        inspectedRange: inspectedRange,
                        activePane: $activePane,
                        pendingHighNibble: $pendingHighNibble,
                        searchMatchOffsets: searchMatchOffsets,
                        patterns: activePatterns,
                        isDataEditable: canEdit,
                        enableSemanticColoring: enableSemanticColoring,
                        theme: appState.theme,
                        scrollRequestOffset: scrollRequestOffset,
                        onMutateByte: { offset, newVal in
                            if var doc = appState.activeDocument, !doc.isPartialPreview, !doc.isReadOnly {
                                doc.updateByte(at: offset, value: newVal)
                                appState.activeDocument = doc
                                statusMessage = appState.loc(
                                    String(format: "Ofset 0x%06X -> 0x%02X ('%@') olarak düzenlendi.", offset, newVal, (newVal >= 32 && newVal <= 126) ? String(UnicodeScalar(newVal)) : "."),
                                    String(format: "Offset 0x%06X -> 0x%02X ('%@') edited.", offset, newVal, (newVal >= 32 && newVal <= 126) ? String(UnicodeScalar(newVal)) : ".")
                                )
                            }
                        },
                        onInsertByte: { offset, newVal in
                            if var doc = appState.activeDocument {
                                doc.insertByte(at: offset, value: newVal)
                                appState.activeDocument = doc
                            }
                        },
                        onDeleteByte: { offset in
                            if var doc = appState.activeDocument {
                                doc.deleteByte(at: offset)
                                appState.activeDocument = doc
                            }
                        },
                        onDeleteRange: { range in
                            deleteBytes(in: range)
                        }
                    )
                }

                Divider()

                // Right: Data Inspector & Pattern Manager Sidebar
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "magnifyingglass.circle.fill")
                                .foregroundStyle(.purple)
                            Text(appState.loc("VERİ DENETÇİSİ (INSPECTOR)", "DATA INSPECTOR"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        if selection.lowerBound < currentBytes.count {
                            let exactWidth = [2, 4, 8].contains(selection.count) ? selection.count : nil
                            VStack(alignment: .leading, spacing: 6) {
                                InspectorRow(
                                    label: hasRange ? appState.loc("Seçim", "Selection") : appState.loc("Ofset", "Offset"),
                                    value: hasRange
                                        ? String(format: "0x%06X – 0x%06X", selection.lowerBound, selection.upperBound - 1)
                                        : String(format: "0x%06X (%d)", selection.lowerBound, selection.lowerBound)
                                )
                                if hasRange {
                                    InspectorRow(label: appState.loc("Uzunluk", "Length"), value: "\(selection.count) byte")
                                }

                                HStack {
                                    Text(appState.loc("Bayt Sırası", "Byte Order"))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .fixedSize()
                                    Spacer()
                                    Picker("", selection: $inspectorBigEndian) {
                                        Text("LE").tag(false)
                                        Text("BE").tag(true)
                                    }
                                    .pickerStyle(.segmented)
                                    .labelsHidden()
                                    .controlSize(.small)
                                    .fixedSize()
                                    .help(appState.loc("LE: düşük bayt önce (Intel, ARM). BE: yüksek bayt önce (ağ biçimi).", "LE: lowest byte first (Intel, ARM). BE: highest byte first (network order)."))
                                }

                                Text(appState.loc(
                                    "Değerler seçimin ilk baytından başlayıp sağa doğru okunur. Üzerine geldiğiniz satırın kullandığı baytlar tabloda çerçevelenir.",
                                    "Values are read from the first selected byte onwards. The bytes a row uses are outlined in the table when you hover it."
                                ))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                                ForEach(inspectorValues(in: currentBytes, at: selection.lowerBound)) { item in
                                    InspectorValueRow(item: item, isEmphasized: item.range?.count == exactWidth && exactWidth != nil)
                                        .onHover { hovering in
                                            inspectedRange = hovering ? item.range : nil
                                        }
                                }
                            }

                            HStack(spacing: 6) {
                                Button {
                                    if var doc = appState.activeDocument {
                                        doc.insertByte(at: selection.lowerBound, value: 0x00)
                                        appState.activeDocument = doc
                                    }
                                } label: {
                                    Label(appState.loc("0x00 Ekle", "Insert 0x00"), systemImage: "plus.circle")
                                        .font(.system(size: 11))
                                }
                                .controlSize(.small)
                                .disabled(!canEdit)

                                Button(role: .destructive) {
                                    deleteBytes(in: selection)
                                } label: {
                                    Label(hasRange ? appState.loc("\(selection.count) Byte Sil", "Delete \(selection.count) Bytes") : appState.loc("Byte Sil", "Delete Byte"), systemImage: "trash")
                                        .font(.system(size: 11))
                                }
                                .controlSize(.small)
                                .disabled(!canEdit)
                            }
                        }

                        Divider()

                        // Custom Pattern Coloring Section
                        HStack {
                            Image(systemName: "paintpalette.fill")
                                .foregroundStyle(.orange)
                            Text(appState.loc("PATERN RENKLENDİRME", "PATTERN HIGHLIGHTING"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        Text(appState.loc("Hex (örn. `0D 0A`, `4D 5A`) veya metin paternlerini otomatik renklendirir:", "Automatically highlights hex (e.g. `0D 0A`, `4D 5A`) or text patterns:"))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            TextField(appState.loc("Hex veya Metin...", "Hex or Text..."), text: $newPatternText)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.small)

                            Picker("", selection: $newPatternColor) {
                               ForEach(["Yeşil", "Mavi", "Turuncu", "Kırmızı", "Mor", "Turkuaz"], id: \.self) { c in
                                    Text(colorTitle(c)).tag(c)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 78)
                            .controlSize(.small)

                            Button {
                                let trimmed = newPatternText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                patternRules.append(
                                    HexPatternRule(
                                        label: trimmed,
                                        patternString: trimmed,
                                        colorName: newPatternColor,
                                        isEnabled: true
                                    )
                                )
                                newPatternText = ""
                            } label: {
                                Image(systemName: "plus")
                            }
                            .controlSize(.small)
                            .help(appState.loc("Yeni patern ekle", "Add pattern"))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach($patternRules) { $rule in
                                HStack(spacing: 6) {
                                    Toggle("", isOn: $rule.isEnabled)
                                        .labelsHidden()
                                        .controlSize(.mini)

                                    Circle()
                                        .fill(Color(nsColor: rule.nsColor))
                                        .frame(width: 8, height: 8)

                                    Text(rule.patternString)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .lineLimit(1)

                                    Spacer()

                                    Button {
                                        patternRules.removeAll { $0.id == rule.id }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.08)))
                            }
                        }
                    }
                    .padding(10)
                }
                .frame(width: 275)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
    }

    private func parsePatternBytes(_ input: String) -> [UInt8] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let parts = trimmed.split(separator: " ")
        var hexBytes: [UInt8] = []
        var allHex = !parts.isEmpty
        for part in parts {
            let clean = part.hasPrefix("0x") ? String(part.dropFirst(2)) : String(part)
            if clean.count == 2, let b = UInt8(clean, radix: 16) {
                hexBytes.append(b)
            } else {
                allHex = false
                break
            }
        }
        if allHex {
            return hexBytes
        }
        return Array(trimmed.utf8)
    }

    private func jumpToOffset() {
        let trimmed = jumpOffsetInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        let target: Int?
        if trimmed.hasPrefix("0x") {
            target = Int(trimmed.dropFirst(2), radix: 16)
        } else if trimmed.allSatisfy({ $0.isNumber }) {
            target = Int(trimmed)
        } else {
            target = Int(trimmed, radix: 16)
        }
        if let t = target {
            let clamped = max(0, min(t, max(0, byteSource.count - 1)))
            selectedByteOffset = clamped
            selectionAnchor = clamped
            scrollRequestOffset = clamped
            statusMessage = appState.loc(
                String(format: "Ofset 0x%06X konumuna gidildi.", clamped),
                String(format: "Jumped to offset 0x%06X.", clamped)
            )
        }
    }

    private func performHexSearch() {
        let needle = parsePatternBytes(hexSearchInput)
        let source = byteSource
        searchTask?.cancel()
        guard !needle.isEmpty, source.count >= needle.count else {
            searchMatchOffsets.removeAll()
            statusMessage = appState.loc("Eşleşme bulunamadı.", "No matches found.")
            return
        }
        let limit = 20_000
        statusMessage = appState.loc("Aranıyor...", "Searching...")
        searchTask = Task.detached(priority: .userInitiated) {
            let hits = source.search(for: needle, limit: limit)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                var matches = Set<Int>()
                for hit in hits {
                    for k in 0..<needle.count { matches.insert(hit + k) }
                }
                searchMatchOffsets = matches
                guard let first = hits.first else {
                    statusMessage = appState.loc("Eşleşme bulunamadı.", "No matches found.")
                    return
                }
                selectionAnchor = first
                selectedByteOffset = first + needle.count - 1
                scrollRequestOffset = first
                let more = hits.count == limit
                statusMessage = appState.loc(
                    more ? "İlk \(limit) eşleşme gösteriliyor." : "\(hits.count) eşleşme bulundu.",
                    more ? "Showing the first \(limit) matches." : "\(hits.count) match(es) found."
                )
            }
        }
    }

    private func bytesToCopy(_ selection: Range<Int>, in source: HexByteSource) -> [UInt8]? {
        let range = selection.count > 1 ? selection : 0..<source.count
        guard range.count <= Self.inMemoryLimit else {
            statusMessage = appState.loc("Kopyalanacak bölüm en fazla 20 MB olabilir.", "At most 20 MB can be copied at once.")
            return nil
        }
        return source.bytes(in: range)
    }

    private func padBinary(_ b: UInt8) -> String {
        let s = String(b, radix: 2)
        return String(repeating: "0", count: max(0, 8 - s.count)) + s
    }

    private func asciiDescription(_ b: UInt8) -> String {
        if b >= 32 && b <= 126 {
            return "'\(UnicodeScalar(b))'"
        }
        switch b {
        case 0x00: return "NUL (\\0)"
        case 0x09: return "TAB (\\t)"
        case 0x0A: return "LF (\\n)"
        case 0x0D: return "CR (\\r)"
        default: return "CTL"
        }
    }

    private func colorTitle(_ name: String) -> String {
        let english = ["Yeşil": "Green", "Mavi": "Blue", "Turuncu": "Orange", "Kırmızı": "Red", "Mor": "Purple", "Turkuaz": "Teal"]
        return appState.loc(name, english[name] ?? name)
    }

    private func selectedRange(in data: HexByteSource) -> Range<Int> {
        guard !data.isEmpty else { return 0..<0 }
        let lower = max(0, min(selectionAnchor, selectedByteOffset))
        let upper = min(data.count - 1, max(selectionAnchor, selectedByteOffset))
        return lower..<(max(lower, upper) + 1)
    }

    private func deleteBytes(in range: Range<Int>) {
        guard var doc = appState.activeDocument else { return }
        doc.deleteBytes(in: range)
        appState.activeDocument = doc
        let count = doc.rawData?.count ?? 0
        let next = max(0, min(range.lowerBound, count - 1))
        selectionAnchor = next
        selectedByteOffset = next
    }

    /// The value of `width` bytes in the chosen order, with those bytes as they appear in the file.
    private func inspectorRead(_ data: HexByteSource, at offset: Int, width: Int) -> (value: UInt64, range: Range<Int>, bytes: String)? {
        guard offset >= 0, offset + width <= data.count else { return nil }
        let slice = data.bytes(in: offset..<offset + width)
        let ordered = inspectorBigEndian ? slice : Array(slice.reversed())
        let value = ordered.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        var text = slice.map { String(format: "%02X", $0) }.joined(separator: " ")
        if width > 1 && width <= 4 {
            text += " = " + "0x" + ordered.map { String(format: "%02X", $0) }.joined()
        }
        return (value, offset..<offset + width, text)
    }

    private func inspectorValues(in data: HexByteSource, at offset: Int) -> [InspectorValue] {
        func row(_ label: String, width: Int, _ format: (UInt64) -> String) -> InspectorValue {
            guard let read = inspectorRead(data, at: offset, width: width) else {
                return InspectorValue(id: label, label: label, value: "—", range: nil, bytes: "")
            }
            return InspectorValue(id: label, label: label, value: format(read.value), range: read.range, bytes: read.bytes)
        }
        return [
            row("ASCII", width: 1) { asciiDescription(UInt8($0)) },
            row("Binary", width: 1) { padBinary(UInt8($0)) },
            row("UInt8", width: 1) { "\($0)" },
            row("Int8", width: 1) { "\(Int8(bitPattern: UInt8($0)))" },
            row("UInt16", width: 2) { "\($0)" },
            row("Int16", width: 2) { "\(Int16(bitPattern: UInt16($0)))" },
            row("UInt32", width: 4) { "\($0)" },
            row("Int32", width: 4) { "\(Int32(bitPattern: UInt32($0)))" },
            row("Float32", width: 4) { String(format: "%.6g", Float(bitPattern: UInt32($0))) },
            row("UInt64", width: 8) { "\($0)" },
            row("Int64", width: 8) { "\(Int64(bitPattern: $0))" },
            row("Float64", width: 8) { String(format: "%.10g", Double(bitPattern: $0)) }
        ]
    }
}

private struct InspectorValue: Identifiable {
    let id: String
    let label: String
    let value: String
    let range: Range<Int>?
    let bytes: String
}

/// One reading of the selected bytes, showing which bytes it uses and in what order.
private struct InspectorValueRow: View {
    let item: InspectorValue
    let isEmphasized: Bool
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text(item.label)
                    .font(.system(size: 11, weight: isEmphasized ? .bold : .regular))
                    .foregroundStyle(isEmphasized ? Color.orange : Color.secondary)
                Spacer()
                Text(item.value)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if item.range.map({ $0.count > 1 }) == true {
                Text(item.bytes)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 4).fill(isHovering ? Color.orange.opacity(0.14) : Color.clear))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

private struct InspectorRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Native AppKit High-Speed Hex + ASCII Canvas View (0ms Click + Direct Typing)
public struct HexPattern {
    let needle: [UInt8]
    let color: NSColor
}

/// The canvas with its scroll bar. The canvas draws only visible rows and tracks its own top
/// row, because a view as tall as a gigabyte of rows is beyond what AppKit can position.
private final class HexGridContainerView: NSView {
    let horizontalScrollView = NSScrollView()
    let verticalScroller = NSScroller()
    let canvas = NativeHexCanvasNSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        horizontalScrollView.hasHorizontalScroller = true
        horizontalScrollView.hasVerticalScroller = false
        horizontalScrollView.autohidesScrollers = true
        horizontalScrollView.borderType = .noBorder
        horizontalScrollView.documentView = canvas
        addSubview(horizontalScrollView)

        verticalScroller.scrollerStyle = .legacy
        verticalScroller.isEnabled = true
        verticalScroller.target = canvas
        verticalScroller.action = #selector(NativeHexCanvasNSView.verticalScrollerMoved(_:))
        addSubview(verticalScroller)
        canvas.verticalScroller = verticalScroller
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let width = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
        horizontalScrollView.frame = NSRect(x: 0, y: 0, width: max(0, bounds.width - width), height: bounds.height)
        verticalScroller.frame = NSRect(x: bounds.width - width, y: 0, width: width, height: bounds.height)
        canvas.recalculateFrameSize(in: horizontalScrollView)
    }
}

private struct NativeHexGridRepresentable: NSViewRepresentable {
    let bytes: HexByteSource
    @Binding var selectedOffset: Int
    @Binding var selectionAnchor: Int
    let inspectedRange: Range<Int>?
    @Binding var activePane: HexEditFocusPane
    @Binding var pendingHighNibble: UInt8?
    let searchMatchOffsets: Set<Int>
    let patterns: [HexPattern]
    let isDataEditable: Bool
    let enableSemanticColoring: Bool
    let theme: EditorTheme
    let scrollRequestOffset: Int?
    let onMutateByte: (Int, UInt8) -> Void
    let onInsertByte: (Int, UInt8) -> Void
    let onDeleteByte: (Int) -> Void
    let onDeleteRange: (Range<Int>) -> Void

    func makeNSView(context: Context) -> NSView {
        let container = HexGridContainerView()
        let canvas = container.canvas
        canvas.clipsToBounds = true
        canvas.onSelect = { anchor, offset, pane in
            selectionAnchor = anchor
            selectedOffset = offset
            activePane = pane
            pendingHighNibble = nil
        }
        canvas.onUpdatePendingNibble = { nibble in
            pendingHighNibble = nibble
        }
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let container = nsView as? HexGridContainerView else { return }
        let canvas = container.canvas
        canvas.bytes = bytes
        if !canvas.isDragSelecting {
            canvas.selectedOffset = selectedOffset
            canvas.selectionAnchor = selectionAnchor
        }
        canvas.inspectedRange = inspectedRange
        canvas.isDataEditable = isDataEditable
        canvas.onDeleteRange = onDeleteRange
        canvas.activePane = activePane
        canvas.pendingHighNibble = pendingHighNibble
        canvas.searchMatchOffsets = searchMatchOffsets
        canvas.patterns = patterns
        canvas.enableSemanticColoring = enableSemanticColoring
        canvas.theme = theme
        canvas.onMutateByte = onMutateByte
        canvas.onInsertByte = onInsertByte
        canvas.onDeleteByte = onDeleteByte

        container.horizontalScrollView.backgroundColor = theme.editorBackground
        canvas.recalculateFrameSize(in: container.horizontalScrollView)

        if let req = scrollRequestOffset, canvas.lastScrolledRequestOffset != req {
            canvas.lastScrolledRequestOffset = req
            canvas.scrollOffsetToVisible(req)
        }
        canvas.needsDisplay = true
    }
}

public final class NativeHexCanvasNSView: NSView {
    var bytes = HexByteSource(data: Data())
    var isDataEditable = true
    /// The row shown at the top of the canvas.
    private(set) var topRow = 0
    weak var verticalScroller: NSScroller?
    private var scrollAccumulator: CGFloat = 0
    var selectedOffset: Int = 0
    var selectionAnchor: Int = 0
    var inspectedRange: Range<Int>? = nil
    var isDragSelecting = false
    private var dragPane: HexEditFocusPane = .hex
    var activePane: HexEditFocusPane = .hex
    var pendingHighNibble: UInt8? = nil
    var searchMatchOffsets: Set<Int> = []
    var patterns: [HexPattern] = []
    var enableSemanticColoring: Bool = true
    var theme: EditorTheme = .nppClassicLight
    var lastScrolledRequestOffset: Int? = nil

    var onSelect: ((Int, Int, HexEditFocusPane) -> Void)?
    var onUpdatePendingNibble: ((UInt8?) -> Void)?
    var onMutateByte: ((Int, UInt8) -> Void)?
    var onInsertByte: ((Int, UInt8) -> Void)?
    var onDeleteByte: ((Int) -> Void)?
    var onDeleteRange: ((Range<Int>) -> Void)?

    // Geometry constants matching header
    private let rowHeight: CGFloat = 21.0
    private let leftPadding: CGFloat = 12.0
    private let offsetColWidth: CGFloat = 88.0
    private let hexCellWidth: CGFloat = 26.0
    private let midDividerWidth: CGFloat = 12.0
    private let asciiDividerWidth: CGFloat = 18.0
    private let asciiCellWidth: CGFloat = 11.5

    public override var isFlipped: Bool { true }
    public override var acceptsFirstResponder: Bool { true }

    private var totalRows: Int { max(1, (bytes.count + 15) / 16) }
    private var fullyVisibleRows: Int { max(1, Int((bounds.height - 4) / rowHeight)) }
    private var lastTopRow: Int { max(0, totalRows - fullyVisibleRows) }

    func recalculateFrameSize(in scrollView: NSScrollView) {
        let size = NSSize(width: max(scrollView.contentSize.width, 760), height: scrollView.contentSize.height)
        if frame.size != size {
            frame.size = size
        }
        setTopRow(topRow)
    }

    private func setTopRow(_ row: Int) {
        let clamped = max(0, min(row, lastTopRow))
        if clamped != topRow {
            topRow = clamped
            needsDisplay = true
        }
        updateVerticalScroller()
    }

    private func updateVerticalScroller() {
        guard let scroller = verticalScroller else { return }
        scroller.isEnabled = lastTopRow > 0
        scroller.knobProportion = min(1, CGFloat(fullyVisibleRows) / CGFloat(totalRows))
        scroller.doubleValue = lastTopRow > 0 ? Double(topRow) / Double(lastTopRow) : 0
    }

    @objc func verticalScrollerMoved(_ sender: NSScroller) {
        switch sender.hitPart {
        case .decrementPage: setTopRow(topRow - fullyVisibleRows)
        case .incrementPage: setTopRow(topRow + fullyVisibleRows)
        default: setTopRow(Int((sender.doubleValue * Double(lastTopRow)).rounded()))
        }
    }

    public override func scrollWheel(with event: NSEvent) {
        guard abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX) else {
            super.scrollWheel(with: event)
            return
        }
        scrollAccumulator += event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / rowHeight : event.scrollingDeltaY * 3
        let rows = Int(scrollAccumulator)
        scrollAccumulator -= CGFloat(rows)
        if rows != 0 { setTopRow(topRow - rows) }
    }

    func scrollOffsetToVisible(_ offset: Int) {
        let row = max(0, offset / 16)
        if row < topRow {
            setTopRow(row)
        } else if row >= topRow + fullyVisibleRows {
            setTopRow(row - fullyVisibleRows + 1)
        }
    }

    /// Pattern colors for what is on screen, so the cost does not depend on the file size.
    private func patternColors(firstRow: Int, lastRow: Int) -> [Int: NSColor] {
        guard let longest = patterns.map(\.needle.count).max() else { return [:] }
        let start = max(0, firstRow * 16 - longest)
        let end = min(bytes.count, (lastRow + 1) * 16 + longest)
        guard start < end else { return [:] }
        let window = bytes.bytes(in: start..<end)
        var map: [Int: NSColor] = [:]
        for pattern in patterns where window.count >= pattern.needle.count {
            let first = pattern.needle[0]
            for index in 0...(window.count - pattern.needle.count) where window[index] == first {
                if window[index..<index + pattern.needle.count].elementsEqual(pattern.needle) {
                    for k in 0..<pattern.needle.count { map[start + index + k] = pattern.color }
                }
            }
        }
        return map
    }

    public override func draw(_ dirtyRect: NSRect) {
        theme.editorBackground.setFill()
        dirtyRect.fill()

        let firstRow = topRow
        let lastRow = min(totalRows - 1, topRow + Int(ceil(bounds.height / rowHeight)))
        guard firstRow <= lastRow else { return }
        let visiblePatternColors = patternColors(firstRow: firstRow, lastRow: lastRow)

        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)

        let selectedRow = selectedOffset / 16
        let selectionLower = min(selectionAnchor, selectedOffset)
        let selectionUpper = max(selectionAnchor, selectedOffset)

        for row in firstRow...lastRow {
            let y = CGFloat(row - firstRow) * rowHeight + 4
            let rowRect = NSRect(x: 0, y: y, width: bounds.width, height: rowHeight)

            if row == selectedRow {
                theme.currentLineHighlight.setFill()
                rowRect.fill()
            }

            let baseOffset = row * 16

            // 1. Draw Offset Column
            let offsetStr = String(format: "%08llX", baseOffset) as NSString
            let offsetAttrs: [NSAttributedString.Key: Any] = [
                .font: row == selectedRow ? boldFont : font,
                .foregroundColor: row == selectedRow ? NSColor.systemOrange : theme.gutterText
            ]
            offsetStr.draw(at: NSPoint(x: leftPadding, y: y + 3), withAttributes: offsetAttrs)

            // 2. Draw 16 Hex Columns & 16 ASCII Columns
            for col in 0..<16 {
                let offset = baseOffset + col
                let hexX = hexColumnX(col)
                let asciiX = asciiColumnX(col)

                if col == 8 {
                    let divX = leftPadding + offsetColWidth + 8 * hexCellWidth + 3
                    ("│" as NSString).draw(
                        at: NSPoint(x: divX, y: y + 3),
                        withAttributes: [.font: font, .foregroundColor: theme.gutterText.withAlphaComponent(0.35)]
                    )
                }

                guard offset < bytes.count else { continue }
                let b = bytes[offset]
                let isSelected = (selectionLower...selectionUpper).contains(offset)
                let continuesRight = isSelected && offset < selectionUpper && col != 7 && col != 15
                let isSearchHit = searchMatchOffsets.contains(offset)
                let customPatternColor = visiblePatternColors[offset]
                let semanticColor = semanticForegroundColor(for: b)

                let hexCellRect = NSRect(x: hexX, y: y + 1, width: continuesRight ? hexCellWidth + 1 : hexCellWidth - 2, height: rowHeight - 2)
                let asciiCellRect = NSRect(x: asciiX, y: y + 1, width: continuesRight ? asciiCellWidth + 0.5 : asciiCellWidth, height: rowHeight - 2)

                // Draw background highlights (Pattern / Search / Selection)
                if isSelected {
                    let activeHexBg = (activePane == .hex) ? NSColor.systemPurple : NSColor.systemPurple.withAlphaComponent(0.35)
                    let activeAsciiBg = (activePane == .ascii) ? NSColor.systemOrange : NSColor.systemOrange.withAlphaComponent(0.35)

                    activeHexBg.setFill()
                    NSBezierPath(roundedRect: hexCellRect, xRadius: 3, yRadius: 3).fill()

                    activeAsciiBg.setFill()
                    NSBezierPath(roundedRect: asciiCellRect, xRadius: 3, yRadius: 3).fill()
                } else if isSearchHit {
                    NSColor.systemYellow.withAlphaComponent(0.45).setFill()
                    NSBezierPath(roundedRect: hexCellRect, xRadius: 2, yRadius: 2).fill()
                    NSBezierPath(roundedRect: asciiCellRect, xRadius: 2, yRadius: 2).fill()
                } else if let patColor = customPatternColor {
                    patColor.withAlphaComponent(theme.isDark ? 0.30 : 0.22).setFill()
                    NSBezierPath(roundedRect: hexCellRect, xRadius: 2, yRadius: 2).fill()
                    NSBezierPath(roundedRect: asciiCellRect, xRadius: 2, yRadius: 2).fill()
                }

                if inspectedRange?.contains(offset) == true {
                    NSColor.systemOrange.setStroke()
                    for rect in [NSRect(x: hexX, y: y + 1, width: hexCellWidth - 2, height: rowHeight - 2),
                                 NSRect(x: asciiX, y: y + 1, width: asciiCellWidth, height: rowHeight - 2)] {
                        let outline = NSBezierPath(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), xRadius: 3, yRadius: 3)
                        outline.lineWidth = 1.5
                        outline.stroke()
                    }
                }

                // Determine text color
                let fgColor: NSColor = {
                    if isSelected {
                        return .white
                    }
                    if let patColor = customPatternColor {
                        return patColor
                    }
                    if enableSemanticColoring {
                        return semanticColor
                    }
                    return theme.editorText
                }()

                // Draw Hex String (or pending high nibble if editing)
                let hexText: String
                if offset == selectedOffset, activePane == .hex, let high = pendingHighNibble {
                    hexText = String(format: "%1X_", high)
                } else {
                    hexText = String(format: "%02X", b)
                }

                (hexText as NSString).draw(
                    at: NSPoint(x: hexX + 4, y: y + 3),
                    withAttributes: [
                        .font: isSelected ? boldFont : font,
                        .foregroundColor: (isSelected && activePane != .hex) ? theme.editorText : fgColor
                    ]
                )

                // Draw ASCII Character
                let asciiChar: String = (b >= 32 && b <= 126) ? String(UnicodeScalar(b)) : "·"
                (asciiChar as NSString).draw(
                    at: NSPoint(x: asciiX + 2, y: y + 3),
                    withAttributes: [
                        .font: isSelected ? boldFont : font,
                        .foregroundColor: isSelected ? (activePane == .ascii ? .white : theme.editorText) : ((b >= 32 && b <= 126) ? fgColor : theme.gutterText.withAlphaComponent(0.5))
                    ]
                )
            }

            // Divider between Hex & ASCII
            let sepX = leftPadding + offsetColWidth + 16 * hexCellWidth + midDividerWidth + 5
            ("│" as NSString).draw(
                at: NSPoint(x: sepX, y: y + 3),
                withAttributes: [.font: font, .foregroundColor: theme.gutterText.withAlphaComponent(0.45)]
            )
        }
    }

    private func hexColumnX(_ col: Int) -> CGFloat {
        var x = leftPadding + offsetColWidth + CGFloat(col) * hexCellWidth
        if col >= 8 {
            x += midDividerWidth
        }
        return x
    }

    private func asciiColumnX(_ col: Int) -> CGFloat {
        let asciiStart = leftPadding + offsetColWidth + 16 * hexCellWidth + midDividerWidth + asciiDividerWidth
        return asciiStart + CGFloat(col) * asciiCellWidth
    }

    private func semanticForegroundColor(for b: UInt8) -> NSColor {
        if b == 0x00 {
            return theme.gutterText.withAlphaComponent(0.55)
        }
        if b == 0x09 || b == 0x0A || b == 0x0D || b == 0x20 {
            return .systemTeal
        }
        if b >= 0x30 && b <= 0x39 {
            return .systemOrange
        }
        if (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A) {
            return .systemBlue
        }
        if b >= 0x21 && b <= 0x7E {
            return .systemGreen
        }
        if b < 0x20 || b == 0x7F {
            return .systemRed
        }
        return .systemPurple
    }

    // MARK: - Selection
    private var hasRangeSelection: Bool { selectionAnchor != selectedOffset }

    private var selectionRange: Range<Int> {
        let lower = max(0, min(selectionAnchor, selectedOffset))
        let upper = min(bytes.count - 1, max(selectionAnchor, selectedOffset))
        return lower..<(max(lower, upper) + 1)
    }

    private func publishSelection() {
        onSelect?(selectionAnchor, selectedOffset, activePane)
    }

    private func moveCaret(to offset: Int, extending: Bool) {
        selectedOffset = offset
        if !extending { selectionAnchor = offset }
        pendingHighNibble = nil
        publishSelection()
        scrollOffsetToVisible(offset)
        needsDisplay = true
    }

    /// Typing replaces bytes from the start of a selection onwards.
    private func collapseSelectionForTyping() {
        guard hasRangeSelection else { return }
        let start = selectionRange.lowerBound
        selectionAnchor = start
        selectedOffset = start
        publishSelection()
    }

    @objc public func copy(_ sender: Any?) {
        guard !bytes.isEmpty else { return }
        guard selectionRange.count <= 20 * 1024 * 1024 else {
            NSSound.beep()
            return
        }
        let selected = bytes.bytes(in: selectionRange)
        let text = activePane == .hex
            ? selected.map { String(format: "%02X", $0) }.joined(separator: " ")
            : String(decoding: selected, as: UTF8.self)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc public override func selectAll(_ sender: Any?) {
        guard !bytes.isEmpty else { return }
        selectionAnchor = 0
        selectedOffset = bytes.count - 1
        pendingHighNibble = nil
        publishSelection()
        needsDisplay = true
    }

    // MARK: - Instant Mouse Hit-Testing
    private func hitTest(_ pt: NSPoint, lockedTo lockedPane: HexEditFocusPane?) -> (offset: Int, pane: HexEditFocusPane) {
        let row = topRow + max(0, Int((pt.y - 4) / rowHeight))

        let hexStart = leftPadding + offsetColWidth
        let hexEnd = hexStart + 16 * hexCellWidth + midDividerWidth
        let asciiStart = hexEnd + asciiDividerWidth
        let asciiEnd = asciiStart + 16 * asciiCellWidth

        let pane: HexEditFocusPane
        if let lockedPane {
            pane = lockedPane
        } else if pt.x >= hexStart && pt.x <= hexEnd {
            pane = .hex
        } else if pt.x >= asciiStart && pt.x <= asciiEnd + 20 {
            pane = .ascii
        } else {
            pane = activePane
        }

        let col: Int
        if pane == .hex {
            var relX = pt.x - hexStart
            if relX >= 8 * hexCellWidth + midDividerWidth / 2 {
                relX -= midDividerWidth
            }
            col = max(0, min(15, Int(relX / hexCellWidth)))
        } else {
            col = max(0, min(15, Int((pt.x - asciiStart) / asciiCellWidth)))
        }
        return (max(0, min(row * 16 + col, max(0, bytes.count - 1))), pane)
    }

    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let hit = hitTest(convert(event.locationInWindow, from: nil), lockedTo: nil)
        selectedOffset = hit.offset
        if !event.modifierFlags.contains(.shift) {
            selectionAnchor = hit.offset
        }
        activePane = hit.pane
        dragPane = hit.pane
        pendingHighNibble = nil
        isDragSelecting = true
        publishSelection()
        needsDisplay = true
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isDragSelecting else { return }
        let point = convert(event.locationInWindow, from: nil)
        if point.y < 0 {
            setTopRow(topRow - 3)
        } else if point.y > bounds.height {
            setTopRow(topRow + 3)
        }
        let offset = hitTest(point, lockedTo: dragPane).offset
        guard offset != selectedOffset else { return }
        selectedOffset = offset
        // Large files redo a lot of work per update, so they catch up when the button is released.
        if bytes.count < 256 * 1024 { publishSelection() }
        needsDisplay = true
    }

    public override func mouseUp(with event: NSEvent) {
        guard isDragSelecting else { return }
        isDragSelecting = false
        publishSelection()
    }

    // MARK: - Direct Keyboard Editing in Both Hex and ASCII Columns
    public override func keyDown(with event: NSEvent) {
        guard !bytes.isEmpty else { return }
        let extending = event.modifierFlags.contains(.shift)

        // Navigation & special keys
        switch event.keyCode {
        case 48: // Tab -> Toggle between Hex and ASCII pane!
            activePane = (activePane == .hex) ? .ascii : .hex
            pendingHighNibble = nil
            publishSelection()
            needsDisplay = true
            return

        case 123: // Left Arrow
            moveCaret(to: max(0, selectedOffset - 1), extending: extending)
            return

        case 124: // Right Arrow
            moveCaret(to: min(bytes.count - 1, selectedOffset + 1), extending: extending)
            return

        case 126: // Up Arrow
            moveCaret(to: max(0, selectedOffset - 16), extending: extending)
            return

        case 125: // Down Arrow
            moveCaret(to: min(bytes.count - 1, selectedOffset + 16), extending: extending)
            return

        case 115: // Home
            moveCaret(to: selectedOffset - selectedOffset % 16, extending: extending)
            return

        case 119: // End
            moveCaret(to: min(bytes.count - 1, selectedOffset - selectedOffset % 16 + 15), extending: extending)
            return

        case 116: // Page Up
            moveCaret(to: max(selectedOffset % 16, selectedOffset - fullyVisibleRows * 16), extending: extending)
            return

        case 121: // Page Down
            moveCaret(to: min(bytes.count - 1, selectedOffset + fullyVisibleRows * 16), extending: extending)
            return

        case 51, 117: // Backspace, Forward Delete
            if pendingHighNibble != nil {
                pendingHighNibble = nil
                onUpdatePendingNibble?(nil)
                needsDisplay = true
            } else if hasRangeSelection {
                if isDataEditable { onDeleteRange?(selectionRange) } else { NSSound.beep() }
            } else if event.keyCode == 51 && selectedOffset > 0 {
                moveCaret(to: selectedOffset - 1, extending: false)
            }
            return

        default:
            break
        }

        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
            super.keyDown(with: event)
            return
        }

        guard isDataEditable else {
            NSSound.beep()
            return
        }

        guard let chars = event.characters, let firstChar = chars.first else { return }

        if activePane == .hex {
            // Parse hex digit 0-9, a-f, A-F
            let str = String(firstChar)
            if let nibble = UInt8(str, radix: 16) {
                collapseSelectionForTyping()
                if let high = pendingHighNibble {
                    let combined = (high << 4) | nibble
                    pendingHighNibble = nil
                    onUpdatePendingNibble?(nil)
                    onMutateByte?(selectedOffset, combined)
                    moveCaret(to: min(bytes.count - 1, selectedOffset + 1), extending: false)
                } else {
                    pendingHighNibble = nibble
                    onUpdatePendingNibble?(nibble)
                }
                needsDisplay = true
            }
        } else {
            // Direct ASCII editing! Any typed printable character updates byte & advances
            if let asciiVal = firstChar.asciiValue, asciiVal >= 32 || asciiVal == 9 || asciiVal == 10 || asciiVal == 13 {
                collapseSelectionForTyping()
                let valueToWrite: UInt8 = (asciiVal == 13) ? 10 : asciiVal
                onMutateByte?(selectedOffset, valueToWrite)
                moveCaret(to: min(bytes.count - 1, selectedOffset + 1), extending: false)
            }
        }
    }
}
