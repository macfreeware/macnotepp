import AppKit
import SwiftUI

public struct NPPTabBarView: View {
    @ObservedObject var appState: AppState
    @State private var tabFrames: [UUID: CGRect] = [:]
    @State private var draggedTab: UUID?

    /// Swaps with a neighbour once the pointer has passed that neighbour's middle, so tabs of
    /// different widths do not swap back and forth.
    private func tabDragged(_ id: UUID, toX x: CGFloat) {
        guard let index = appState.tabs.firstIndex(where: { $0.id == id }) else { return }
        if index + 1 < appState.tabs.count, let next = tabFrames[appState.tabs[index + 1].id], x > next.midX {
            appState.moveTab(id: id, to: index + 1)
        } else if index > 0, let previous = tabFrames[appState.tabs[index - 1].id], x < previous.midX {
            appState.moveTab(id: id, to: index - 1)
        }
    }

    public var body: some View {
        let _ = appState.languageRefreshTrigger
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(appState.tabs) { tab in
                        NPPTabItemView(
                            tab: tab,
                            isActive: tab.id == appState.activeTabId,
                            onSelect: {
                                appState.activeTabId = tab.id
                                appState.updateLiveSearchMatches()
                            },
                            onClose: {
                                appState.closeTab(id: tab.id)
                            },
                            appState: appState
                        )
                        .opacity(draggedTab == tab.id ? 0.6 : 1)
                        .background(GeometryReader { geometry in
                            Color.clear.preference(key: TabFramePreferenceKey.self, value: [tab.id: geometry.frame(in: .named("tabStrip"))])
                        })
                        .gesture(
                            DragGesture(minimumDistance: 6, coordinateSpace: .named("tabStrip"))
                                .onChanged { value in
                                    if draggedTab != tab.id {
                                        draggedTab = tab.id
                                        appState.activeTabId = tab.id
                                    }
                                    NSCursor.closedHand.set()
                                    tabDragged(tab.id, toX: value.location.x)
                                }
                                .onEnded { value in
                                    draggedTab = nil
                                    // AppKit does not update the cursor by itself after a drag.
                                    let isOverStrip = (0...30).contains(value.location.y)
                                    (isOverStrip ? NSCursor.openHand : NSCursor.arrow).set()
                                    NSApp.keyWindow?.resetCursorRects()
                                }
                        )
                    }

                    Button {
                        appState.newTab()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                    .help(appState.loc("Yeni Sekme Aç (⌘N)", "New Tab (⌘N)"))
                }
                .padding(.horizontal, 6)
                .padding(.top, 3)
                .coordinateSpace(name: "tabStrip")
                .onPreferenceChange(TabFramePreferenceKey.self) { tabFrames = $0 }
                .animation(.easeOut(duration: 0.12), value: appState.tabs.map(\.id))
            }

            Spacer(minLength: 4)

            // Quick open tabs dropdown on far right of tab bar
            Menu {
                ForEach(appState.tabs) { tab in
                    Button {
                        appState.activeTabId = tab.id
                    } label: {
                        HStack {
                            if tab.id == appState.activeTabId {
                                Image(systemName: "checkmark")
                            }
                            Text("\(tab.isModified ? "● " : "")\(tab.isReadOnly ? "🔒 " : "")\(tab.displayTitle)  [\(tab.language.rawValue)]\(tab.isReadOnly ? " [RO]" : "")")
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(appState.tabs.count)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .focusable(false)
            .fixedSize()
            .padding(.trailing, 6)
            .help(appState.loc("Açık Sekmeler Listesi", "Open Tabs List"))
        }
        .frame(height: 30)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct TabFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct NPPTabItemView: View {
    let tab: EditorDocument
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @ObservedObject var appState: AppState

    @State private var isHovering = false

    var body: some View {
        let _ = appState.languageRefreshTrigger
        HStack(spacing: 6) {
            if tab.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
            }

            if tab.isReadOnly {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.orange)
                    .help(appState.loc("Salt Okunur (Read-Only) — Düzenleme kilitli", "Read-Only — Editing locked"))
            } else {
                // Classic blue/red save disk icon
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(tab.isModified ? Color.red : Color.blue.opacity(0.8))
            }

            Text(tab.displayTitle)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .lineLimit(1)

            if tab.isReadOnly {
                Text("RO")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.orange.opacity(0.2)))
                    .foregroundStyle(.orange)
                    .help(appState.loc("Salt Okunur (Read-Only) — Düzenleme kilitli", "Read-Only — Editing locked"))
            }

            if tab.isPartialPreview {
                Text(appState.loc("Önizleme", "Preview"))
                    .font(.system(size: 8, weight: .semibold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.blue.opacity(0.18)))
                    .foregroundStyle(.blue)
                    .help(appState.loc("Büyük Dosya Güvenli Önizleme Modu", "Large File Safe Preview Mode"))
            }

            if tab.viewMode == .hex {
                Text("HEX")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.purple.opacity(0.22)))
                    .foregroundStyle(.purple)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isHovering || isActive ? Color.primary : Color.secondary.opacity(0.6))
                    .frame(width: 15, height: 15)
                    .background(
                        Circle()
                            .fill(isHovering ? Color.red.opacity(0.2) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help(appState.loc("Sekmeyi Kapat (⌘W)", "Close Tab (⌘W)"))
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(
            ZStack(alignment: .top) {
                UnevenRoundedRectangle(
                    topLeadingRadius: 5,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 5
                )
                .fill(
                    isActive
                        ? Color(nsColor: .textBackgroundColor)
                        : (isHovering ? Color.secondary.opacity(0.14) : Color.secondary.opacity(0.07))
                )

                // Classic orange highlight bar on top of active tab
                if isActive {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 5,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 5
                    )
                    .fill(Color.orange)
                    .frame(height: 3)
                }
            }
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 5,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 5
            )
            .stroke(Color.secondary.opacity(isActive ? 0.35 : 0.15), lineWidth: 1)
        )
        .background(TabCursorArea())
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .overlay(
            MiddleClickDetectorView(onMiddleClick: onClose)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button(appState.loc("Kapat", "Close")) {
                onClose()
            }
            Button(appState.loc("Bunun Dışındaki Tüm Sekmeleri Kapat", "Close Other Tabs")) {
                appState.closeOtherTabs(keeping: tab.id)
            }
            Button(appState.loc("Sağdaki Sekmeleri Kapat", "Close Tabs to the Right")) {
                appState.closeTabsToRight(of: tab.id)
            }
            Button(appState.loc("Değiştirilmemiş Sekmeleri Kapat", "Close Unmodified Tabs")) {
                appState.closeUnmodifiedTabs()
            }

            Divider()

            Button(tab.isPinned ? appState.loc("Sekme Sabitlemesini Kaldır", "Unpin Tab") : appState.loc("Sekmeyi Sabitle (Pin)", "Pin Tab")) {
                appState.togglePinTab(id: tab.id)
            }
            Button(tab.isReadOnly ? appState.loc("Salt Okunur Kilidini Kaldır (Düzenlenebilir Yap)", "Unlock Read-Only (Make Editable)") : appState.loc("Salt Okunur Yap (Kilitle)", "Set Read-Only (Lock Editing)")) {
                appState.toggleReadOnly(id: tab.id)
            }
            Divider()

            Button(appState.loc("Sola Taşı", "Move Left")) {
                appState.moveTab(id: tab.id, by: -1)
            }
            .disabled(appState.tabs.first?.id == tab.id)
            Button(appState.loc("Sağa Taşı", "Move Right")) {
                appState.moveTab(id: tab.id, by: 1)
            }
            .disabled(appState.tabs.last?.id == tab.id)
            Button(appState.loc("Başa Taşı", "Move to Start")) {
                appState.moveTab(id: tab.id, to: 0)
            }
            Button(appState.loc("Sona Taşı", "Move to End")) {
                appState.moveTab(id: tab.id, to: appState.tabs.count - 1)
            }

            Divider()

            Button(appState.loc("Kaydet", "Save")) {
                appState.saveTab(id: tab.id, saveAs: false)
            }
            Button(appState.loc("Farklı Kaydet...", "Save As...")) {
                appState.saveTab(id: tab.id, saveAs: true)
            }

            Divider()

            Button(appState.loc("Bu Sekmeyi Aktif Sekme ile Karşılaştır (Diff)", "Compare with Active Tab (Diff)")) {
                appState.toggleCompareMode(withTabId: tab.id)
            }
            Button(tab.viewMode == .hex ? appState.loc("Metin Görünümüne Geç", "Switch to Text View") : appState.loc("Hex Görünümüne Geç (Hex View)", "Switch to Hex View")) {
                appState.activeTabId = tab.id
                appState.toggleHexView()
            }

            if let url = tab.fileURL {
                Divider()
                Button(appState.loc("Tam Dosya Yolunu Panoya Kopyala", "Copy Full Path")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.path, forType: .string)
                }
                Button(appState.loc("Dosya Adını Panoya Kopyala", "Copy File Name")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.lastPathComponent, forType: .string)
                }
                Button(appState.loc("Finder'da Göster", "Show in Finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
        }
    }
}

// MARK: - Open-Hand Cursor Over a Tab
private final class TabCursorNSView: NSView {
    /// The close button at the trailing end keeps the normal arrow.
    private let closeButtonWidth: CGFloat = 26

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        var area = bounds
        area.size.width = max(0, area.width - closeButtonWidth)
        addCursorRect(area, cursor: .openHand)
    }
}

private struct TabCursorArea: NSViewRepresentable {
    func makeNSView(context: Context) -> TabCursorNSView { TabCursorNSView() }
    func updateNSView(_ nsView: TabCursorNSView, context: Context) {}
}

// MARK: - Middle Click Detector (Mouse Button 2 / Wheel Click to Close Tab)
private final class MiddleClickDetectorNSView: NSView {
    var onMiddleClick: (() -> Void)?

    override func otherMouseDown(with event: NSEvent) {
        if event.buttonNumber == 2 {
            onMiddleClick?()
            return
        }
        super.otherMouseDown(with: event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only intercept middle clicks; let left/right clicks pass through to SwiftUI
        if let currentEvent = NSApp.currentEvent, currentEvent.type == .otherMouseDown, currentEvent.buttonNumber == 2 {
            return self
        }
        return nil
    }
}

private struct MiddleClickDetectorView: NSViewRepresentable {
    let onMiddleClick: () -> Void

    func makeNSView(context: Context) -> MiddleClickDetectorNSView {
        let v = MiddleClickDetectorNSView()
        v.onMiddleClick = onMiddleClick
        return v
    }

    func updateNSView(_ nsView: MiddleClickDetectorNSView, context: Context) {
        nsView.onMiddleClick = onMiddleClick
    }
}
