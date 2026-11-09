import AppKit
import SwiftUI

public struct CompareView: View {
    @ObservedObject var appState: AppState
    @State private var showOnlyDifferences: Bool = false

    public var body: some View {
        let diff = appState.diffResult ?? DiffEngine.compare(leftText: "", rightText: "")
        let displayedRows = showOnlyDifferences
            ? diff.rows.filter { $0.kind != .unchanged }
            : diff.rows

        VStack(spacing: 0) {
            // Two rows, so nothing has to squeeze on a normal window width
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Label(appState.loc("Karşılaştır", "Compare"), systemImage: "arrow.left.and.right.square.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.orange)
                        .fixedSize()

                    Divider().frame(height: 18)

                    documentPicker(
                        title: appState.loc("Sol", "Left"),
                        selection: Binding(
                            get: { appState.compareLeftTabId ?? appState.tabs.first?.id ?? UUID() },
                            set: { newVal in
                                appState.compareLeftTabId = newVal
                                appState.recomputeDiff()
                            }
                        )
                    )

                    Button {
                        appState.swapCompareSides()
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                    }
                    .controlSize(.small)
                    .help(appState.loc("Sol ve sağ dosyanın yerini değiştir", "Swap left and right"))

                    documentPicker(
                        title: appState.loc("Sağ", "Right"),
                        selection: Binding(
                            get: { appState.compareRightTabId ?? appState.tabs.last?.id ?? UUID() },
                            set: { newVal in
                                appState.compareRightTabId = newVal
                                appState.recomputeDiff()
                            }
                        )
                    )

                    Spacer(minLength: 8)

                    HStack(spacing: 3) {
                        navigationButton("backward.end.fill", help: appState.loc("İlk fark", "First difference"), diff: diff) {
                            appState.navigateFirstDiff()
                        }
                        navigationButton("chevron.up", help: appState.loc("Önceki fark", "Previous difference"), diff: diff) {
                            appState.navigateDiff(delta: -1)
                        }
                        navigationButton("chevron.down", help: appState.loc("Sonraki fark", "Next difference"), diff: diff) {
                            appState.navigateDiff(delta: 1)
                        }
                        navigationButton("forward.end.fill", help: appState.loc("Son fark", "Last difference"), diff: diff) {
                            appState.navigateLastDiff()
                        }
                    }
                    .fixedSize()

                    Button {
                        appState.isCompareMode = false
                    } label: {
                        Label(appState.loc("Kapat", "Close"), systemImage: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                    .fixedSize()
                }

                HStack(spacing: 12) {
                    Toggle(appState.loc("Yalnızca farklar", "Differences only"), isOn: $showOnlyDifferences)
                    Toggle(appState.loc("Boşlukları yoksay", "Ignore whitespace"), isOn: $appState.compareIgnoreWhitespace)
                    Toggle(appState.loc("Büyük/küçük harfi yoksay", "Ignore case"), isOn: $appState.compareIgnoreCase)

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        DiffBadge(text: "+\(diff.addedCount) \(appState.loc("eklendi", "added"))", color: .green)
                        DiffBadge(text: "−\(diff.removedCount) \(appState.loc("silindi", "removed"))", color: .red)
                        DiffBadge(text: "~\(diff.modifiedCount) \(appState.loc("değişti", "changed"))", color: .orange)
                        DiffBadge(text: "=\(diff.unchangedCount) \(appState.loc("aynı", "same"))", color: .secondary)
                    }
                }
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if diff.isIdentical {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text(diff.finalNewlineDiffers
                         ? appState.loc("Dosyalar yalnızca sondaki satır sonunda farklı.", "The files differ only in the final line break.")
                         : appState.loc("Dosyalar seçili ölçütlere göre aynı.", "The files are the same under the selected options."))
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                Divider()
            }

            // Column Header Bar
            HStack(spacing: 0) {
                let leftDoc = appState.tabs.first(where: { $0.id == appState.compareLeftTabId })
                let rightDoc = appState.tabs.first(where: { $0.id == appState.compareRightTabId })

                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text(leftDoc?.displayTitle ?? appState.loc("Sol", "Left"))
                        .font(.system(size: 11, weight: .bold))
                    if let path = leftDoc?.fileURL?.path {
                        Text("(\(path))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.08))

                Divider().frame(height: 22)

                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text(rightDoc?.displayTitle ?? appState.loc("Sağ", "Right"))
                        .font(.system(size: 11, weight: .bold))
                    if let path = rightDoc?.fileURL?.path {
                        Text("(\(path))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.08))

                // Space for minimap bar
                Spacer().frame(width: 18)
            }

            Divider()

            // Synchronized Side-by-Side Diff Rows + Right Diff NavBar
            HStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(displayedRows) { row in
                                SideBySideDiffRowView(
                                    row: row,
                                    fontSize: appState.fontSize,
                                    isDark: appState.theme.isDark,
                                    onJumpLeft: {
                                        if let ln = row.leftLineNumber, let leftId = appState.compareLeftTabId {
                                            appState.isCompareMode = false
                                            appState.activeTabId = leftId
                                            appState.jumpToLine(ln)
                                        }
                                    },
                                    onJumpRight: {
                                        if let ln = row.rightLineNumber, let rightId = appState.compareRightTabId {
                                            appState.isCompareMode = false
                                            appState.activeTabId = rightId
                                            appState.jumpToLine(ln)
                                        }
                                    }
                                )
                                .id(row.id)
                            }
                        }
                    }
                    .background(Color(nsColor: appState.theme.editorBackground))
                    .onChange(of: appState.scrollToDiffRowTrigger) { _, targetRow in
                        if let targetRow = targetRow {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(targetRow, anchor: .center)
                            }
                        }
                    }
                }

                Divider()

                // Compare Vertical Diff Overview Map
                DiffMinimapBar(rows: diff.rows) { clickedRowId in
                    appState.scrollToDiffRowTrigger = clickedRowId
                }
                .frame(width: 18)
            }
        }
    }
}

extension CompareView {
    fileprivate func documentPicker(title: String, selection: Binding<UUID>) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .fixedSize()
            Picker("", selection: selection) {
                ForEach(appState.tabs) { tab in
                    Text(tab.displayTitle).tag(tab.id)
                }
            }
            .labelsHidden()
            .frame(minWidth: 110, maxWidth: 200)
            .controlSize(.small)
        }
    }

    fileprivate func navigationButton(_ symbol: String, help: String, diff: DiffResult, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .controlSize(.small)
        .disabled(diff.diffBlockRowIndices.isEmpty)
        .help(help)
    }
}

private struct DiffBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.16)))
            .foregroundStyle(color)
    }
}

private struct SideBySideDiffRowView: View {
    let row: DiffRow
    let fontSize: Double
    let isDark: Bool
    let onJumpLeft: () -> Void
    let onJumpRight: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Left Pane
            HStack(spacing: 0) {
                Text(row.leftLineNumber.map { "\($0)" } ?? "")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
                    .padding(.trailing, 6)
                    .background(Color.secondary.opacity(0.08))

                Text(leftMarker)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(leftMarkerColor)
                    .frame(width: 16, alignment: .center)

                highlightedText(
                    text: row.leftText ?? "",
                    ranges: row.leftHighlightRanges,
                    highlightColor: row.kind == .removed
                        ? Color.red.opacity(isDark ? 0.35 : 0.25)
                        : Color.orange.opacity(isDark ? 0.45 : 0.38)
                )
                .font(.system(size: CGFloat(fontSize), design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
            .background(leftBackground)
            .onTapGesture(count: 2) {
                onJumpLeft()
            }

            Divider()

            // Right Pane
            HStack(spacing: 0) {
                Text(row.rightLineNumber.map { "\($0)" } ?? "")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
                    .padding(.trailing, 6)
                    .background(Color.secondary.opacity(0.08))

                Text(rightMarker)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(rightMarkerColor)
                    .frame(width: 16, alignment: .center)

                highlightedText(
                    text: row.rightText ?? "",
                    ranges: row.rightHighlightRanges,
                    highlightColor: row.kind == .added
                        ? Color.green.opacity(isDark ? 0.35 : 0.25)
                        : Color.orange.opacity(isDark ? 0.45 : 0.38)
                )
                .font(.system(size: CGFloat(fontSize), design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
            .background(rightBackground)
            .onTapGesture(count: 2) {
                onJumpRight()
            }
        }
        .overlay(alignment: .bottom) {
            if row.kind != .unchanged {
                Divider().opacity(0.25)
            }
        }
    }

    private var leftMarker: String {
        switch row.kind {
        case .unchanged: return " "
        case .removed: return "-"
        case .modified: return "~"
        case .added: return " "
        }
    }

    private var rightMarker: String {
        switch row.kind {
        case .unchanged: return " "
        case .added: return "+"
        case .modified: return "~"
        case .removed: return " "
        }
    }

    private var leftMarkerColor: Color {
        switch row.kind {
        case .removed: return .red
        case .modified: return .orange
        default: return .secondary
        }
    }

    private var rightMarkerColor: Color {
        switch row.kind {
        case .added: return .green
        case .modified: return .orange
        default: return .secondary
        }
    }

    private var leftBackground: Color {
        switch row.kind {
        case .unchanged: return .clear
        case .removed: return Color.red.opacity(isDark ? 0.20 : 0.14)
        case .modified: return Color.orange.opacity(isDark ? 0.16 : 0.12)
        case .added: return Color.secondary.opacity(0.08)
        }
    }

    private var rightBackground: Color {
        switch row.kind {
        case .unchanged: return .clear
        case .added: return Color.green.opacity(isDark ? 0.20 : 0.14)
        case .modified: return Color.orange.opacity(isDark ? 0.16 : 0.12)
        case .removed: return Color.secondary.opacity(0.08)
        }
    }

    private func highlightedText(text: String, ranges: [NSRange], highlightColor: Color) -> Text {
        guard !text.isEmpty, !ranges.isEmpty, let first = ranges.first else {
            return Text(text.isEmpty ? " " : text)
        }
        let ns = text as NSString
        guard NSMaxRange(first) <= ns.length else {
            return Text(text)
        }
        let prefix = ns.substring(to: first.location)
        let mid = ns.substring(with: first)
        let suffix = ns.substring(from: NSMaxRange(first))

        var attr = AttributedString(prefix)
        var midAttr = AttributedString(mid)
        midAttr.backgroundColor = highlightColor
        let sufAttr = AttributedString(suffix)
        attr.append(midAttr)
        attr.append(sufAttr)
        return Text(attr)
    }
}

private struct DiffMinimapBar: View {
    let rows: [DiffRow]
    let onSelectRow: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let total = max(1, rows.count)
                for (index, row) in rows.enumerated() where row.kind != .unchanged {
                    let y = (CGFloat(index) / CGFloat(total)) * size.height
                    let h = max(2.5, size.height / CGFloat(total))
                    let rect = CGRect(x: 1, y: y, width: size.width - 2, height: h)
                    let color: Color
                    switch row.kind {
                    case .added: color = .green
                    case .removed: color = .red
                    case .modified: color = .orange
                    case .unchanged: color = .clear
                    }
                    context.fill(Path(rect), with: .color(color))
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let ratio = max(0, min(1, value.location.y / max(1, geo.size.height)))
                        let idx = Int(ratio * CGFloat(max(0, rows.count - 1)))
                        if idx < rows.count {
                            onSelectRow(rows[idx].id)
                        }
                    }
            )
        }
    }
}
