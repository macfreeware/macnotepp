import AppKit
import SwiftUI

/// VS Code tarzı gerçek zamanlı senkronize Belge Haritası (Minimap) NSView
public final class MinimapCanvasView: NSView {
    public weak var appState: AppState?
    private var isDraggingSlider: Bool = false
    private var dragOffsetY: CGFloat = 0.0
    private var trackingArea: NSTrackingArea?

    public override var isFlipped: Bool { true }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupObservers()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScrollNotification(_:)),
            name: NSView.boundsDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEditorChanged(_:)),
            name: Notification.Name("MacNoteActiveEditorChanged"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEditorChanged(_:)),
            name: NSText.didChangeNotification,
            object: nil
        )
    }

    @objc private func handleScrollNotification(_ note: Notification) {
        guard let clipView = note.object as? NSClipView,
              let activeSV = appState?.activeScrollView,
              clipView == activeSV.contentView else { return }
        needsDisplay = true
    }

    @objc private func handleEditorChanged(_ note: Notification) {
        needsDisplay = true
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    public override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    private var cachedDocId: UUID? = nil
    private var cachedContentLen: Int = -1
    private var cachedLineStarts: [Int] = [0]

    private func ensureLineStarts(for ns: NSString, docId: UUID) {
        if cachedDocId == docId && cachedContentLen == ns.length { return }
        cachedDocId = docId
        cachedContentLen = ns.length
        guard ns.length <= 10_000_000 else {
            cachedLineStarts = [0]
            return
        }
        var starts = [0]
        let len = ns.length
        for i in 0..<len {
            if ns.character(at: i) == 10 {
                starts.append(i + 1)
            }
        }
        cachedLineStarts = starts
    }

    private func lineString(at lineIndex: Int, in ns: NSString) -> String {
        guard lineIndex >= 0 && lineIndex < cachedLineStarts.count else { return "" }
        let start = cachedLineStarts[lineIndex]
        let nextStart = (lineIndex + 1 < cachedLineStarts.count) ? cachedLineStarts[lineIndex + 1] : (ns.length + 1)
        let end = max(start, nextStart - 1)
        let length = min(end - start, 80) // Clamp to 80 chars max for minimap
        guard length > 0 && start + length <= ns.length else { return "" }
        return ns.substring(with: NSRange(location: start, length: length))
    }

    private struct Geometry {
        let totalLines: Int
        let lineHeight: CGFloat
        let totalMinimapHeight: CGFloat
        let minimapScrollY: CGFloat
        let sliderRect: NSRect
        let totalDocHeight: CGFloat
        let visibleRect: NSRect
    }

    private func computeGeometry() -> Geometry? {
        guard let appState = appState, let doc = appState.activeDocument else { return nil }

        let totalLines = max(1, doc.totalLines)

        let sv = appState.activeScrollView
        let tv = appState.activeTextView

        let visibleRect = sv?.contentView.bounds ?? bounds
        let totalDocHeight = max(visibleRect.height, tv?.bounds.height ?? CGFloat(totalLines * 16))

        let availableHeight = max(10.0, bounds.height)
        let rawLineH = availableHeight / CGFloat(totalLines)
        let lineHeight = max(2.5, min(10.0, rawLineH))
        let totalMinimapHeight = CGFloat(totalLines) * lineHeight

        var minimapScrollY: CGFloat = 0.0
        if totalMinimapHeight > availableHeight {
            let maxDocScroll = max(1.0, totalDocHeight - visibleRect.height)
            let maxMinimapScroll = totalMinimapHeight - availableHeight
            let scrollRatio = max(0.0, min(1.0, visibleRect.origin.y / maxDocScroll))
            minimapScrollY = scrollRatio * maxMinimapScroll
        }

        let scrollFractionTop = max(0.0, min(1.0, visibleRect.origin.y / max(1.0, totalDocHeight)))
        let scrollFractionHeight = max(0.02, min(1.0, visibleRect.height / max(1.0, totalDocHeight)))

        let sliderY = scrollFractionTop * totalMinimapHeight - minimapScrollY
        let sliderHeight = max(24.0, scrollFractionHeight * totalMinimapHeight)
        let sliderRect = NSRect(
            x: 1.0,
            y: max(0.0, min(bounds.height - sliderHeight, sliderY)),
            width: max(10.0, bounds.width - 2.0),
            height: min(bounds.height, sliderHeight)
        )

        return Geometry(
            totalLines: totalLines,
            lineHeight: lineHeight,
            totalMinimapHeight: totalMinimapHeight,
            minimapScrollY: minimapScrollY,
            sliderRect: sliderRect,
            totalDocHeight: totalDocHeight,
            visibleRect: visibleRect
        )
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let appState = appState,
              let doc = appState.activeDocument,
              doc.byteLength < 20 * 1024 * 1024,
              !doc.isPartialPreview,
              let geo = computeGeometry() else {
            return
        }

        // Arka plan
        let bg = appState.theme.editorBackground
        bg.setFill()
        bounds.fill()

        // Sol kenarlık çizgisi
        NSColor.separatorColor.withAlphaComponent(0.4).setFill()
        NSRect(x: 0, y: 0, width: 1, height: bounds.height).fill()

        let ns = doc.content as NSString
        ensureLineStarts(for: ns, docId: doc.id)
        let totalLines = geo.totalLines
        let lineHeight = geo.lineHeight
        let minimapScrollY = geo.minimapScrollY
        let sliderRect = geo.sliderRect

        let font = NSFont.monospacedSystemFont(ofSize: max(4.0, min(7.0, lineHeight - 1.0)), weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: max(4.0, min(7.0, lineHeight - 1.0)), weight: .semibold)

        let normalTextColor = appState.theme.editorText.withAlphaComponent(0.30)
        let activeTextColor = appState.theme.editorText
        let lineNumColor = NSColor.secondaryLabelColor.withAlphaComponent(0.35)
        let activeLineNumColor = NSColor.secondaryLabelColor

        let firstVisibleLineIdx = max(0, Int(minimapScrollY / lineHeight))
        let lastVisibleLineIdx = min(totalLines - 1, Int((minimapScrollY + bounds.height) / lineHeight) + 1)

        for i in firstVisibleLineIdx...lastVisibleLineIdx {
            let lineNum = i + 1
            let lineY = CGFloat(i) * lineHeight - minimapScrollY
            let isInsideViewport = (lineY + lineHeight >= sliderRect.minY && lineY <= sliderRect.maxY)
            let isCursor = (doc.cursorLine == lineNum)
            let hasBookmark = doc.bookmarks.contains(lineNum)

            // Yer İmi İndikatörü
            if hasBookmark {
                NSColor.systemCyan.setFill()
                let dotRect = NSRect(x: 3, y: lineY + (lineHeight - 3) / 2, width: 3.5, height: 3.5)
                NSBezierPath(ovalIn: dotRect).fill()
            }

            // İmleç Satırı Sol İşareti
            if isCursor {
                NSColor.systemOrange.setFill()
                let curRect = NSRect(x: 1, y: lineY, width: 2, height: lineHeight)
                curRect.fill()
            }

            // Küçük Satır Numarası (Sadece çizgi yüksekliği 6pt ve üzeri ise okunaklı çiz)
            if lineHeight >= 5.5 {
                let lineNumStr = "\(lineNum)" as NSString
                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: isInsideViewport ? activeLineNumColor : lineNumColor
                ]
                let numRect = NSRect(x: 5, y: lineY, width: 18, height: lineHeight)
                lineNumStr.draw(in: numRect, withAttributes: numAttrs)
            }

            // Metin Önizlemesi
            let rawLine = lineString(at: i, in: ns)
            if !rawLine.isEmpty {
                let textStr = rawLine as NSString
                let textAttrs: [NSAttributedString.Key: Any] = [
                    .font: isInsideViewport ? boldFont : font,
                    .foregroundColor: hasBookmark ? NSColor.systemCyan : (isInsideViewport ? activeTextColor : normalTextColor)
                ]
                let textX: CGFloat = (lineHeight >= 5.5) ? 24 : 6
                let textRect = NSRect(x: textX, y: lineY, width: max(0, bounds.width - textX - 4), height: lineHeight)
                textStr.draw(in: textRect, withAttributes: textAttrs)
            }
        }

        // VS Code Tarzı Viewport Kaydırıcı (Slider) Kutusu
        let sliderPath = NSBezierPath(roundedRect: sliderRect, xRadius: 3, yRadius: 3)
        let sliderFill = appState.theme.isDark
            ? NSColor(white: 1.0, alpha: 0.15)
            : NSColor.controlAccentColor.withAlphaComponent(0.18)
        sliderFill.setFill()
        sliderPath.fill()

        // Kaydırıcı Üst Vurgu Çizgisi
        NSColor.controlAccentColor.withAlphaComponent(0.85).setFill()
        NSRect(x: sliderRect.minX, y: sliderRect.minY, width: sliderRect.width, height: 1.5).fill()

        // Kaydırıcı Alt Vurgu Çizgisi
        NSRect(x: sliderRect.minX, y: sliderRect.maxY - 1.5, width: sliderRect.width, height: 1.5).fill()

        // Kaydırıcı Çerçevesi
        NSColor.controlAccentColor.withAlphaComponent(0.40).setStroke()
        sliderPath.lineWidth = 1.0
        sliderPath.stroke()
    }

    public override func mouseDown(with event: NSEvent) {
        guard let geo = computeGeometry() else { return }
        let pt = convert(event.locationInWindow, from: nil)
        let sliderRect = geo.sliderRect

        if sliderRect.contains(pt) {
            isDraggingSlider = true
            dragOffsetY = pt.y - sliderRect.minY
        } else {
            // Kaydırıcı dışına tıklandığında: kaydırıcıyı tıklanan noktaya ortala ve editörü kaydır
            isDraggingSlider = true
            dragOffsetY = sliderRect.height / 2
            scrollToMinimapY(pt.y - dragOffsetY)
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isDraggingSlider else { return }
        let pt = convert(event.locationInWindow, from: nil)
        scrollToMinimapY(pt.y - dragOffsetY)
    }

    public override func mouseUp(with event: NSEvent) {
        isDraggingSlider = false
    }

    private func scrollToMinimapY(_ sliderY: CGFloat) {
        guard let appState = appState,
              let sv = appState.activeScrollView,
              let tv = appState.activeTextView,
              let doc = appState.activeDocument else { return }

        let linesCount = max(1, doc.totalLines)
        let visibleRect = sv.contentView.bounds
        let totalDocHeight = max(visibleRect.height, tv.bounds.height)

        let rawLineH = bounds.height / CGFloat(linesCount)
        let lineHeight = max(2.5, min(10.0, rawLineH))
        let totalMinimapHeight = CGFloat(linesCount) * lineHeight

        let maxDocScroll = max(0.0, totalDocHeight - visibleRect.height)
        guard maxDocScroll > 0 else { return }

        let scrollFractionHeight = max(0.02, min(1.0, visibleRect.height / max(1.0, totalDocHeight)))
        let sliderHeight = max(24.0, scrollFractionHeight * totalMinimapHeight)

        let effectiveTrack = max(1.0, bounds.height - sliderHeight)
        let clampedSliderY = max(0.0, min(effectiveTrack, sliderY))
        let ratio = clampedSliderY / effectiveTrack

        let targetY = max(0.0, min(maxDocScroll, ratio * maxDocScroll))
        let targetPt = NSPoint(x: sv.contentView.bounds.origin.x, y: targetY)
        sv.contentView.scroll(to: targetPt)
        sv.reflectScrolledClipView(sv.contentView)
        tv.needsDisplay = true
        self.needsDisplay = true
    }
}

/// SwiftUI Sarmalayıcısı: VS Code Tarzı Belge Haritası
public struct VSCodeMinimapView: NSViewRepresentable {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public func makeNSView(context: Context) -> MinimapCanvasView {
        let view = MinimapCanvasView()
        view.appState = appState
        return view
    }

    public func updateNSView(_ nsView: MinimapCanvasView, context: Context) {
        nsView.appState = appState
        nsView.needsDisplay = true
    }
}
