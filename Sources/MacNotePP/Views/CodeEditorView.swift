import AppKit
import SwiftUI

public struct CodeEditorView: NSViewRepresentable {
    @ObservedObject var appState: AppState
    let document: EditorDocument

    public init(appState: AppState, document: EditorDocument) {
        self.appState = appState
        self.document = document
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> EditorContainerView {
        let scrollView = NonOverlappingEditorScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !appState.wordWrap
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.clipsToBounds = true
        scrollView.contentView.clipsToBounds = true

        let initialWidth: CGFloat = 600
        let textStorage = NSTextStorage()
        let layoutManager = InvisibleDrawingLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(
            containerSize: NSSize(
                width: appState.wordWrap ? initialWidth : 10_000_000,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        textContainer.lineFragmentPadding = 2
        textContainer.lineBreakMode = appState.wordWrap ? .byWordWrapping : .byClipping
        layoutManager.addTextContainer(textContainer)

        let textView = MacNoteTextView(
            frame: NSRect(origin: .zero, size: NSSize(width: initialWidth, height: 400)),
            textContainer: textContainer
        )
        textView.clipsToBounds = true
        textView.minSize = NSSize(width: 100, height: 100)
        textView.maxSize = NSSize(
            width: appState.wordWrap ? initialWidth : CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !appState.wordWrap
        textView.autoresizingMask = appState.wordWrap ? [.width] : [.width, .height]

        textView.isEditable = !document.isReadOnly
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.usesFindBar = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.delegate = context.coordinator
        textView.appState = appState
        textView.registerForDraggedTypes([.fileURL, .string])
        textView.onMultiCaretCountChange = { [weak appState] count in
            Task { @MainActor in
                if appState?.activeMultiCaretCount != count {
                    appState?.activeMultiCaretCount = count
                }
            }
        }

        scrollView.documentView = textView

        let gutter = LineNumberBookmarkGutterView(textView: textView)
        gutter.theme = appState.theme
        gutter.onToggleBookmark = { [weak appState] line in
            Task { @MainActor in
                appState?.toggleBookmark(line: line)
            }
        }

        let container = EditorContainerView(gutterView: gutter, scrollView: scrollView)
        container.showLineNumbers = appState.showLineNumbers

        context.coordinator.containerView = container
        context.coordinator.textView = textView
        context.coordinator.rulerView = gutter
        context.coordinator.layoutManager = layoutManager

        scrollView.onViewportWidthChanged = { [weak coordinator = context.coordinator] in
            MainActor.assumeIsolated {
                guard let coordinator = coordinator,
                      let tv = coordinator.textView,
                      let sv = tv.enclosingScrollView else { return }
                coordinator.handleViewportWidthChanged(textView: tv, scrollView: sv)
            }
        }

        context.coordinator.loadDocumentIfNeeded(document, appState: appState, force: true)

        appState.activeTextView = textView
        appState.activeScrollView = scrollView
        NotificationCenter.default.post(name: Notification.Name("MacNoteActiveEditorChanged"), object: nil)

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.boundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        return container
    }

    /// Hex view and Markdown modes replace the editor; the tab keeps its scroll position.
    public static func dismantleNSView(_ nsView: EditorContainerView, coordinator: Coordinator) {
        coordinator.rememberScrollPosition()
    }

    public func updateNSView(_ containerView: EditorContainerView, context: Context) {
        context.coordinator.parent = self
        if containerView.showLineNumbers != appState.showLineNumbers {
            containerView.showLineNumbers = appState.showLineNumbers
        }
        if let tv = containerView.scrollView.documentView as? MacNoteTextView {
            if appState.activeTextView !== tv {
                appState.activeTextView = tv
                appState.activeScrollView = containerView.scrollView
                NotificationCenter.default.post(name: Notification.Name("MacNoteActiveEditorChanged"), object: nil)
            }
        }
        context.coordinator.loadDocumentIfNeeded(document, appState: appState, force: false)
    }

    @MainActor
    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView
        weak var containerView: EditorContainerView?
        weak var textView: MacNoteTextView?
        weak var rulerView: LineNumberBookmarkGutterView?
        weak var layoutManager: InvisibleDrawingLayoutManager?

        private var currentDocId: UUID?
        private var isUpdatingProgrammatically = false
        private var lastAppliedPartialPreviewState: Bool?
        private var lastAppliedLanguage: SyntaxLanguage?
        private var lastAppliedTheme: EditorTheme?
        private var lastAppliedFontSize: Double?
        private var lastAppliedWordWrap: Bool?
        private var lastJumpTrigger: UUID?
        private var lastScrollTrigger: UUID?
        private var lastMultiCaretTrigger: UUID?
        private var lastMarkedCount: Int = 0
        private var lastSearchMatchesCount: Int = 0

        init(_ parent: CodeEditorView) {
            self.parent = parent
        }

        /// Stores the shown tab's scroll position in that tab before another one takes the view.
        func rememberScrollPosition() {
            guard let docId = currentDocId, let scrollView = textView?.enclosingScrollView else { return }
            let y = scrollView.contentView.bounds.origin.y
            let appState = parent.appState
            // Not during the view update itself: publishing changes there is not allowed.
            DispatchQueue.main.async {
                guard let idx = appState.tabs.firstIndex(where: { $0.id == docId }),
                      abs(appState.tabs[idx].scrollOffsetY - y) > 0.5 else { return }
                appState.tabs[idx].scrollOffsetY = y
            }
        }

        private func restoreScrollPosition(_ y: CGFloat, in textView: NSTextView) {
            guard let scrollView = textView.enclosingScrollView else { return }
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            guard y > 0 else { return }
            DispatchQueue.main.async { [weak textView] in
                guard let textView, let scrollView = textView.enclosingScrollView,
                      let layoutManager = textView.layoutManager, let container = textView.textContainer else { return }
                let visibleHeight = scrollView.contentView.bounds.height
                layoutManager.ensureLayout(forBoundingRect: NSRect(x: 0, y: 0, width: container.size.width, height: y + visibleHeight), in: container)
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: y))
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }

        func loadDocumentIfNeeded(_ doc: EditorDocument, appState: AppState, force: Bool) {
            guard let textView = textView, let scrollView = textView.enclosingScrollView else { return }

            let docChanged = (currentDocId != doc.id)
            let tvCount = textView.textContents.length
            let docCount = (doc.content as NSString).length
            let textChangedExternally = (tvCount != docCount) || (tvCount <= 500_000 && textView.string != doc.content)
            let previewStateChanged = (lastAppliedPartialPreviewState != doc.isPartialPreview)
            let themeChanged = (lastAppliedTheme != appState.theme)
            let langChanged = (lastAppliedLanguage != doc.language)
            let fontChanged = (lastAppliedFontSize != appState.fontSize)
            let wrapChanged = (lastAppliedWordWrap != appState.wordWrap)
            let marksChanged = (lastMarkedCount != doc.markedRanges.count)
            let searchChanged = (lastSearchMatchesCount != appState.liveSearchMatches.count)

            isUpdatingProgrammatically = true
            defer { isUpdatingProgrammatically = false }

            if let container = containerView, container.showLineNumbers != appState.showLineNumbers {
                container.showLineNumbers = appState.showLineNumbers
            }

            if let lm = layoutManager {
                if lm.showInvisibles != appState.showInvisibleCharacters || lm.lineEndingBadge != doc.lineEnding.shortBadge {
                    lm.showInvisibles = appState.showInvisibleCharacters
                    lm.lineEndingBadge = doc.lineEnding.shortBadge
                    textView.needsDisplay = true
                }
            }

            textView.appState = appState
            textView.currentTheme = appState.theme
            textView.backgroundColor = appState.theme.editorBackground
            textView.insertionPointColor = appState.theme.editorText
            textView.isEditable = !doc.isReadOnly

            if force || docChanged || textChangedExternally || previewStateChanged {
                if docChanged {
                    textView.clearExtraCarets()
                    rememberScrollPosition()
                }
                let savedRange = textView.selectedRange()
                textView.setSelectedRange(NSRange(location: 0, length: 0))
                textView.string = doc.content
                currentDocId = doc.id
                lastAppliedPartialPreviewState = doc.isPartialPreview
                let safeLocation = max(0, min(docChanged || textChangedExternally ? doc.cursorOffset : savedRange.location, (doc.content as NSString).length))
                textView.setSelectedRange(NSRange(location: safeLocation, length: 0))
                if docChanged {
                    // A new file starts at the top; a tab shown before returns to where it was.
                    restoreScrollPosition(doc.scrollOffsetY, in: textView)
                }
            }

            if force || docChanged || textChangedExternally || themeChanged || langChanged || fontChanged || marksChanged || searchChanged {
                applyHighlighting(doc: doc, appState: appState)
                lastAppliedLanguage = doc.language
                lastAppliedTheme = appState.theme
                lastAppliedFontSize = appState.fontSize
                lastMarkedCount = doc.markedRanges.count
                lastSearchMatchesCount = appState.liveSearchMatches.count
            }

            if force || wrapChanged || docChanged || fontChanged {
                if appState.wordWrap || scrollView.contentView.bounds.origin.x < 0 {
                    var b = scrollView.contentView.bounds
                    b.origin.x = 0
                    scrollView.contentView.bounds = b
                }
                applyWordWrapAndSizing(wordWrap: appState.wordWrap, textView: textView, scrollView: scrollView, forceRelayout: true)
                lastAppliedWordWrap = appState.wordWrap
            } else if appState.wordWrap {
                if scrollView.contentView.bounds.origin.x != 0 {
                    var b = scrollView.contentView.bounds
                    b.origin.x = 0
                    scrollView.contentView.bounds = b
                }
                let currentClipWidth = max(120, scrollView.contentView.bounds.width)
                if abs(textView.frame.size.width - currentClipWidth) > 0.5 {
                    applyWordWrapAndSizing(wordWrap: true, textView: textView, scrollView: scrollView, forceRelayout: true)
                }
            }

            if let ruler = rulerView {
                ruler.theme = appState.theme
                ruler.bookmarks = doc.bookmarks
                ruler.currentLine = doc.cursorLine
                ruler.needsDisplay = true
            }

            if lastJumpTrigger != appState.requestedJumpTrigger, let targetRange = appState.requestedJumpRange {
                lastJumpTrigger = appState.requestedJumpTrigger
                let maxLen = (textView.textContents).length
                let loc = max(0, min(targetRange.location, maxLen))
                let len = max(0, min(targetRange.length, maxLen - loc))
                let safeRange = NSRange(location: loc, length: len)
                textView.clearExtraCarets()
                textView.setSelectedRange(safeRange)
                textView.scrollRangeToVisible(safeRange)
                textView.window?.makeFirstResponder(textView)
                updateCursorMetrics(in: textView)
                textView.needsDisplay = true
                rulerView?.needsDisplay = true
            }

            if lastScrollTrigger != appState.requestedScrollTrigger, let targetLine = appState.requestedScrollToLine {
                lastScrollTrigger = appState.requestedScrollTrigger
                scrollToLine(targetLine, in: textView, scrollView: scrollView)
            }

            if lastMultiCaretTrigger != appState.requestedMultiCaretTrigger, let cmd = appState.requestedMultiCaretCommand {
                lastMultiCaretTrigger = appState.requestedMultiCaretTrigger
                switch cmd {
                case .addCursorAbove:
                    textView.addCursorVertically(direction: -1)
                case .addCursorBelow:
                    textView.addCursorVertically(direction: 1)
                case .addCursorsToSelectedLinesEnd:
                    textView.addCursorsToSelectedLines(atStart: false)
                case .addCursorsToSelectedLinesStart:
                    textView.addCursorsToSelectedLines(atStart: true)
                case .clearExtraCursors:
                    textView.clearExtraCarets()
                }
                textView.window?.makeFirstResponder(textView)
            }
            updateSmartHighlighting(in: textView)
        }

        private func applyHighlighting(doc: EditorDocument, appState: AppState) {
            guard let textView = textView, let storage = textView.textStorage else { return }
            let font = NSFont.monospacedSystemFont(ofSize: CGFloat(appState.fontSize), weight: .regular)
            textView.font = font
            layoutManager?.baseFontSize = CGFloat(appState.fontSize)
            let activeMatch: NSRange? = {
                guard !appState.liveSearchMatches.isEmpty,
                      appState.activeSearchMatchIndex < appState.liveSearchMatches.count else { return nil }
                return appState.liveSearchMatches[appState.activeSearchMatchIndex]
            }()

            SyntaxHighlighter.shared.highlight(
                textStorage: storage,
                language: doc.language,
                theme: appState.theme,
                font: font,
                markedRanges: doc.markedRanges,
                searchMatches: appState.liveSearchMatches,
                activeMatch: activeMatch
            )
        }

        public func textDidChange(_ notification: Notification) {
            guard !isUpdatingProgrammatically, let textView = textView else { return }
            if let doc = parent.appState.activeDocument, doc.id == parent.document.id, doc.isReadOnly {
                return
            }
            let newText = textView.string
            if var doc = parent.appState.activeDocument, doc.id == parent.document.id {
                let isBlockChange = abs((newText as NSString).length - (doc.content as NSString).length) >= 4
                doc.applyContentMutation(newText, newCursorOffset: textView.selectedRange().location, coalesceTyping: !isBlockChange)
                if !doc.isLanguageManuallySet && doc.fileURL == nil {
                    if doc.language == .plainText {
                        let detected = SyntaxLanguage.detect(url: nil, filename: doc.title, content: newText)
                        if detected != .plainText {
                            doc.language = detected
                        }
                    }
                }
                parent.appState.activeDocument = doc
                applyHighlighting(doc: doc, appState: parent.appState)
                updateCursorMetrics(in: textView)
                updateSmartHighlighting(in: textView)
                rulerView?.needsDisplay = true
            }
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            guard !isUpdatingProgrammatically, let textView = textView else { return }
            updateCursorMetrics(in: textView)
            updateSmartHighlighting(in: textView)
            textView.needsDisplay = true
            rulerView?.needsDisplay = true
        }

        private func updateCursorMetrics(in textView: NSTextView) {
            guard var doc = parent.appState.activeDocument, doc.id == parent.document.id else { return }
            let sel = textView.selectedRange()
            let ns = textView.textContents
            let safeOffset = min(sel.location, ns.length)

            let line = rulerView?.lineNumber(forCharacterIndex: safeOffset, in: ns) ?? 1

            // Fast backward scan to find start of current line (O(col), typically < 100 iterations)
            var lastNewlineIndex = 0
            if safeOffset > 0 {
                var p = safeOffset - 1
                while p >= 0 {
                    if ns.character(at: p) == 10 {
                        lastNewlineIndex = p + 1
                        break
                    }
                    p -= 1
                }
            }
            let col = safeOffset - lastNewlineIndex + 1

            var selLines = 0
            if sel.length > 0 && NSMaxRange(sel) <= ns.length {
                var count = 1
                let selEnd = NSMaxRange(sel)
                let scanEnd = min(selEnd, sel.location + 20_000)
                for idx in sel.location..<scanEnd {
                    if ns.character(at: idx) == 10 {
                        count += 1
                    }
                }
                selLines = count
            }

            if doc.cursorLine != line || doc.cursorColumn != col || doc.cursorOffset != safeOffset || doc.selectionLength != sel.length {
                doc.cursorLine = line
                doc.cursorColumn = col
                doc.cursorOffset = safeOffset
                doc.selectionLength = sel.length
                doc.selectedLineCount = selLines
                parent.appState.activeDocument = doc
                rulerView?.currentLine = line
            }
        }

        private func updateVisibleLines(in textView: NSTextView) {
            guard let lm = textView.layoutManager,
                  let tc = textView.textContainer,
                  var doc = parent.appState.activeDocument,
                  doc.id == parent.document.id else { return }

            let visibleRect = textView.visibleRect
            let glyphRange = lm.glyphRange(forBoundingRect: visibleRect, in: tc)
            guard glyphRange.location != NSNotFound else { return }
            let charRange = lm.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let ns = textView.textContents
            guard ns.length > 0 else { return }

            let safeStart = max(0, min(charRange.location, ns.length - 1))
            let safeEnd = max(safeStart, min(NSMaxRange(charRange), ns.length))

            let startLine = rulerView?.lineNumber(forCharacterIndex: safeStart, in: ns) ?? 1
            let endLine = rulerView?.lineNumber(forCharacterIndex: safeEnd, in: ns) ?? startLine

            if doc.visibleStartLine != startLine || doc.visibleEndLine != endLine {
                doc.visibleStartLine = startLine
                doc.visibleEndLine = max(startLine, endLine)
                parent.appState.activeDocument = doc
            }
        }

        private func scrollToLine(_ lineNumber: Int, in textView: NSTextView, scrollView: NSScrollView) {
            guard let lm = textView.layoutManager, textView.textContainer != nil else { return }
            let ns = textView.textContents
            guard ns.length > 0 else { return }

            let clampedLine = max(1, lineNumber)
            var currentLine = 1
            var charOffset = 0
            for idx in 0..<ns.length {
                if currentLine == clampedLine {
                    charOffset = idx
                    break
                }
                if ns.character(at: idx) == 10 {
                    currentLine += 1
                }
            }

            let glyphIdx = lm.glyphIndexForCharacter(at: charOffset)
            let lineRect = lm.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
            let targetY = max(0, lineRect.origin.y + textView.textContainerOrigin.y - 10)
            let targetPt = NSPoint(x: scrollView.contentView.bounds.origin.x, y: targetY)
            scrollView.contentView.scroll(to: targetPt)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            textView.needsDisplay = true
            rulerView?.needsDisplay = true
            updateVisibleLines(in: textView)
        }

        private func updateSmartHighlighting(in textView: MacNoteTextView) {
            guard parent.appState.enableSmartHighlighting else {
                if !textView.smartHighlightRanges.isEmpty || textView.smartHighlightPrimaryRange != nil {
                    textView.smartHighlightPrimaryRange = nil
                    textView.smartHighlightRanges = []
                    textView.resetSelectedTextAttributes()
                }
                return
            }

            let text = textView.string
            let ns = text as NSString
            guard ns.length > 0 else {
                textView.smartHighlightPrimaryRange = nil
                textView.smartHighlightRanges = []
                textView.resetSelectedTextAttributes()
                return
            }

            let sel = textView.selectedRange()
            var targetQuery: String? = nil
            var isWholeWord = false

            if sel.length > 0 && NSMaxRange(sel) <= ns.length {
                let raw = ns.substring(with: sel)
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !raw.contains("\n") && !raw.contains("\r") && trimmed.count <= 120 {
                    targetQuery = trimmed
                    let wordPattern = "^[A-Za-z0-9_ğüşıöçĞÜŞİÖÇ]+$"
                    if trimmed.range(of: wordPattern, options: .regularExpression) != nil {
                        isWholeWord = parent.appState.smartHighlightWholeWordOnly
                    } else {
                        isWholeWord = false
                    }
                }
            }

            guard let query = targetQuery, query.count >= 2 else {
                if !textView.smartHighlightRanges.isEmpty || textView.smartHighlightPrimaryRange != nil {
                    textView.smartHighlightPrimaryRange = nil
                    textView.smartHighlightRanges = []
                    textView.resetSelectedTextAttributes()
                }
                return
            }

            let escaped = NSRegularExpression.escapedPattern(for: query)
            let pattern: String
            if isWholeWord {
                pattern = "(?<![A-Za-z0-9_ğüşıöçĞÜŞİÖÇ])\(escaped)(?![A-Za-z0-9_ğüşıöçĞÜŞİÖÇ])"
            } else {
                pattern = escaped
            }

            var options: NSRegularExpression.Options = []
            if !parent.appState.smartHighlightCaseSensitive {
                options.insert(.caseInsensitive)
            }

            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
                textView.smartHighlightPrimaryRange = nil
                textView.smartHighlightRanges = []
                textView.resetSelectedTextAttributes()
                return
            }

            let searchStart: Int
            let searchLength: Int
            if ns.length > 80_000 {
                // Focus smart highlighting around the cursor/viewport for speed on large files
                searchStart = max(0, sel.location - 30_000)
                let searchEnd = min(ns.length, sel.location + 30_000)
                searchLength = max(0, searchEnd - searchStart)
            } else {
                searchStart = 0
                searchLength = ns.length
            }

            var matchedRanges: [NSRange] = []
            regex.enumerateMatches(in: text, options: [], range: NSRange(location: searchStart, length: searchLength)) { match, _, stop in
                if let r = match?.range {
                    matchedRanges.append(r)
                    if matchedRanges.count >= 400 {
                        stop.pointee = true
                    }
                }
            }

            var primaryRange: NSRange? = nil
            if sel.length > 0 {
                primaryRange = matchedRanges.first { NSEqualRanges($0, sel) } ?? matchedRanges.first { NSIntersectionRange($0, sel).length > 0 }
            } else {
                let safeOffset = min(sel.location, ns.length)
                primaryRange = matchedRanges.first { r in
                    safeOffset >= r.location && safeOffset <= NSMaxRange(r)
                }
            }

            if !matchedRanges.isEmpty {
                textView.smartHighlightPrimaryRange = primaryRange
                textView.smartHighlightRanges = matchedRanges
                textView.applySmartHighlightSelectedTextAttributes()
            } else {
                textView.smartHighlightPrimaryRange = nil
                textView.smartHighlightRanges = []
                textView.resetSelectedTextAttributes()
            }
        }

        private func wordRangeAt(offset: Int, in string: NSString) -> NSRange? {
            guard string.length > 0 else { return nil }
            let wordChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_ğüşıöçĞÜŞİÖÇ")
            var checkIndex = min(offset, string.length - 1)

            if offset == string.length || !wordChars.contains(UnicodeScalar(string.character(at: min(offset, string.length - 1)))!) {
                if offset > 0 && wordChars.contains(UnicodeScalar(string.character(at: offset - 1))!) {
                    checkIndex = offset - 1
                } else {
                    return nil
                }
            }

            guard wordChars.contains(UnicodeScalar(string.character(at: checkIndex))!) else {
                return nil
            }

            var start = checkIndex
            while start > 0 && wordChars.contains(UnicodeScalar(string.character(at: start - 1))!) {
                start -= 1
            }

            var end = checkIndex + 1
            while end < string.length && wordChars.contains(UnicodeScalar(string.character(at: end))!) {
                end += 1
            }

            let len = end - start
            guard len >= 2 else { return nil }
            return NSRange(location: start, length: len)
        }

        private var isApplyingWrapSizing = false

        func handleViewportWidthChanged(textView: MacNoteTextView, scrollView: NSScrollView) {
            guard parent.appState.wordWrap else { return }
            applyWordWrapAndSizing(
                wordWrap: true,
                textView: textView,
                scrollView: scrollView,
                forceRelayout: false
            )
        }

        private func applyWordWrapAndSizing(wordWrap: Bool, textView: MacNoteTextView, scrollView: NSScrollView, forceRelayout: Bool) {
            guard !isApplyingWrapSizing else { return }
            isApplyingWrapSizing = true
            defer { isApplyingWrapSizing = false }

            if scrollView.hasHorizontalScroller == wordWrap {
                scrollView.hasHorizontalScroller = !wordWrap
                scrollView.tile()
            }

            let clipSize = scrollView.contentView.bounds.size
            let safeWidth = max(120, clipSize.width)
            let safeHeight = max(100, clipSize.height)
            let insetW = textView.textContainerInset.width * 2
            let lineFragPad = (textView.textContainer?.lineFragmentPadding ?? 2) * 2
            let wrappedContainerWidth = max(80, safeWidth - insetW - lineFragPad)

            if wordWrap {
                if let clip = scrollView.contentView as? NonBouncingClipView {
                    clip.isWordWrapEnabled = true
                }
                if scrollView.contentView.bounds.origin.x != 0 {
                    var b = scrollView.contentView.bounds
                    b.origin.x = 0
                    scrollView.contentView.bounds = b
                }
                textView.isHorizontallyResizable = false
                textView.autoresizingMask = [.width]
                textView.minSize = NSSize(width: safeWidth, height: safeHeight)
                textView.maxSize = NSSize(width: safeWidth, height: CGFloat.greatestFiniteMagnitude)
                if let container = textView.textContainer {
                    container.widthTracksTextView = false
                    container.lineBreakMode = .byWordWrapping
                    if abs(container.containerSize.width - wrappedContainerWidth) > 0.5 {
                        container.containerSize = NSSize(width: wrappedContainerWidth, height: CGFloat.greatestFiniteMagnitude)
                    }
                }
                if abs(textView.frame.size.width - safeWidth) > 0.5 {
                    textView.setFrameSize(NSSize(width: safeWidth, height: max(textView.frame.size.height, safeHeight)))
                }
            } else {
                if let clip = scrollView.contentView as? NonBouncingClipView {
                    clip.isWordWrapEnabled = false
                }
                if scrollView.contentView.bounds.origin.x < 0 {
                    var b = scrollView.contentView.bounds
                    b.origin.x = 0
                    scrollView.contentView.bounds = b
                }
                textView.isHorizontallyResizable = true
                textView.autoresizingMask = [.width, .height]
                textView.minSize = NSSize(width: safeWidth, height: safeHeight)
                textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                if let container = textView.textContainer {
                    container.widthTracksTextView = false
                    container.lineBreakMode = .byClipping
                    if container.containerSize.width < 5_000_000 {
                        container.containerSize = NSSize(width: 10_000_000, height: CGFloat.greatestFiniteMagnitude)
                    }
                }
            }

            if forceRelayout {
                if let lm = textView.layoutManager, let container = textView.textContainer {
                    lm.ensureLayout(forBoundingRect: textView.visibleRect, in: container)
                }
                scrollView.reflectScrolledClipView(scrollView.contentView)
                textView.needsDisplay = true
                rulerView?.needsDisplay = true
            }
        }

        @objc func boundsDidChange(_ notification: Notification) {
            rulerView?.needsDisplay = true
            textView?.updateScrollbarMarkers()
        }
    }
}

// MARK: - Non-Bouncing ClipView (Prevents negative overscroll and drifting left gap)
public final class NonBouncingClipView: NSClipView {
    public var isWordWrapEnabled: Bool = false

    public override var bounds: NSRect {
        get { super.bounds }
        set {
            var b = newValue
            if isWordWrapEnabled || b.origin.x < 0 {
                b.origin.x = 0
            }
            super.bounds = b
        }
    }

    public override func setBoundsOrigin(_ newOrigin: NSPoint) {
        var pt = newOrigin
        if isWordWrapEnabled || pt.x < 0 {
            pt.x = 0
        }
        super.setBoundsOrigin(pt)
    }

    public override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        if isWordWrapEnabled || rect.origin.x < 0 {
            rect.origin.x = 0
        }
        return rect
    }

    public override func scroll(to newOrigin: NSPoint) {
        var pt = newOrigin
        if isWordWrapEnabled || pt.x < 0 {
            pt.x = 0
        }
        super.scroll(to: pt)
    }

    public override func autoscroll(with event: NSEvent) -> Bool {
        let res = super.autoscroll(with: event)
        if isWordWrapEnabled || bounds.origin.x < 0 {
            var b = bounds
            b.origin.x = 0
            bounds = b
        }
        return res
    }

    public override func layout() {
        super.layout()
        if isWordWrapEnabled || bounds.origin.x < 0 {
            var b = bounds
            b.origin.x = 0
            bounds = b
        }
        if let doc = documentView, doc.frame.origin.x != 0 {
            var f = doc.frame
            f.origin.x = 0
            doc.frame = f
        }
    }
}

// MARK: - Custom Scroller with Smart Highlight & Search Match Markers
public final class MarkedIndicatorScroller: NSScroller {
    public var highlightNormalizedOffsets: [CGFloat] = [] {
        didSet { needsDisplay = true }
    }

    public override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        super.drawKnobSlot(in: slotRect, highlight: flag)
        guard !highlightNormalizedOffsets.isEmpty else { return }

        let markerColor = NSColor(calibratedRed: 0.10, green: 0.85, blue: 0.22, alpha: 0.95)
        markerColor.setFill()

        for ratio in highlightNormalizedOffsets {
            let clamped = max(0.0, min(1.0, ratio))
            let y = slotRect.minY + clamped * max(10, slotRect.height - 3)
            let markRect = NSRect(x: slotRect.minX + 2, y: y, width: max(4, slotRect.width - 4), height: 3.0)
            NSBezierPath(roundedRect: markRect, xRadius: 1, yRadius: 1).fill()
        }
    }
}

// MARK: - Custom ScrollView Preventing Any Scrollbar Overlap Over Text or Gutter
public final class NonOverlappingEditorScrollView: NSScrollView {
    public var onViewportWidthChanged: (() -> Void)?
    private var lastClipWidth: CGFloat = 0
    private var isEnforcingFrames: Bool = false

    public override var scrollerStyle: NSScroller.Style {
        get { .legacy }
        set { super.scrollerStyle = .legacy }
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupCustomClipView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCustomClipView()
    }

    private func setupCustomClipView() {
        let customClip = NonBouncingClipView()
        customClip.drawsBackground = true
        customClip.clipsToBounds = true
        customClip.wantsLayer = true
        customClip.layer?.masksToBounds = true
        self.contentView = customClip
        self.horizontalScrollElasticity = .none
        self.verticalScrollElasticity = .none

        let vScroller = MarkedIndicatorScroller()
        vScroller.scrollerStyle = .legacy
        self.verticalScroller = vScroller
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        automaticallyAdjustsContentInsets = false
        contentInsets = NSEdgeInsetsZero
        super.scrollerStyle = .legacy
        if !(verticalScroller is MarkedIndicatorScroller) {
            let vScroller = MarkedIndicatorScroller()
            vScroller.scrollerStyle = .legacy
            self.verticalScroller = vScroller
        }
        verticalScroller?.scrollerStyle = .legacy
        horizontalScroller?.scrollerStyle = .legacy
        tile()
    }

    public override func layout() {
        super.layout()
        enforceNonOverlappingFrames()
    }

    public override func reflectScrolledClipView(_ cView: NSClipView) {
        super.reflectScrolledClipView(cView)
        enforceNonOverlappingFrames()
    }

    public override func tile() {
        automaticallyAdjustsContentInsets = false
        contentInsets = NSEdgeInsetsZero
        super.scrollerStyle = .legacy
        verticalScroller?.scrollerStyle = .legacy
        horizontalScroller?.scrollerStyle = .legacy
        super.tile()
        enforceNonOverlappingFrames()
    }

    private func enforceNonOverlappingFrames() {
        guard !isEnforcingFrames, bounds.width > 20, bounds.height > 20 else { return }
        isEnforcingFrames = true
        defer { isEnforcingFrames = false }

        let scrollerThickness = max(16, NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy))
        let vScrollerW: CGFloat = hasVerticalScroller ? scrollerThickness : 0
        let hScrollerH: CGFloat = hasHorizontalScroller ? scrollerThickness : 0

        let clipW = max(40, bounds.width - vScrollerW)
        let clipH = max(40, bounds.height - hScrollerH)

        let targetClipFrame = NSRect(x: 0, y: 0, width: clipW, height: clipH)
        if contentView.frame != targetClipFrame {
            contentView.frame = targetClipFrame
        }
        contentView.clipsToBounds = true
        contentView.wantsLayer = true
        contentView.layer?.masksToBounds = true

        if let clip = contentView as? NonBouncingClipView {
            clip.isWordWrapEnabled = !hasHorizontalScroller
        }

        if contentView.bounds.origin.x < 0 || (!hasHorizontalScroller && contentView.bounds.origin.x != 0) {
            var b = contentView.bounds
            b.origin.x = 0
            contentView.bounds = b
        }

        if let doc = documentView, doc.frame.origin.x != 0 {
            var f = doc.frame
            f.origin.x = 0
            doc.frame = f
        }

        if hasVerticalScroller, let vScroller = verticalScroller {
            vScroller.scrollerStyle = .legacy
            vScroller.isHidden = false
            let targetVFrame = NSRect(x: bounds.width - vScrollerW, y: 0, width: vScrollerW, height: clipH)
            if vScroller.frame != targetVFrame {
                vScroller.frame = targetVFrame
            }
        }

        if hasHorizontalScroller, let hScroller = horizontalScroller {
            hScroller.scrollerStyle = .legacy
            hScroller.isHidden = false
            let targetHFrame = NSRect(x: 0, y: clipH, width: clipW, height: hScrollerH)
            if hScroller.frame != targetHFrame {
                hScroller.frame = targetHFrame
            }
        }

        if abs(clipW - lastClipWidth) > 0.5 {
            lastClipWidth = clipW
            onViewportWidthChanged?()
        }
    }

    public override func scrollWheel(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) || flags.contains(.command) {
            if let tv = documentView as? MacNoteTextView {
                tv.scrollWheel(with: event)
                return
            }
        }
        super.scrollWheel(with: event)
    }

    public override func magnify(with event: NSEvent) {
        if let tv = documentView as? MacNoteTextView {
            tv.magnify(with: event)
            return
        }
        super.magnify(with: event)
    }
}

extension NSTextView {
    /// The text without the copy that `string` makes, which takes real time on very large files.
    var textContents: NSString { textStorage?.mutableString ?? (string as NSString) }
}

/// One cursor of a multi-cursor session: `anchor` stays put while `head` moves.
public struct TextCaret: Equatable {
    public var anchor: Int
    public var head: Int

    public init(anchor: Int, head: Int) {
        self.anchor = anchor
        self.head = head
    }

    public init(at offset: Int) {
        self.init(anchor: offset, head: offset)
    }

    public var range: NSRange { NSRange(location: min(anchor, head), length: abs(anchor - head)) }
    public var isEmpty: Bool { anchor == head }
}

// MARK: - Custom NSTextView with Multi-Cursor (Çoklu İmleç), Current-Line Highlight & Auto-Indent
public final class MacNoteTextView: NSTextView {
    public weak var appState: AppState?
    public var currentTheme: EditorTheme = .nppClassicLight
    /// Two or more while in multi-cursor mode; otherwise empty and AppKit's own selection applies.
    public private(set) var carets: [TextCaret] = [] {
        didSet {
            if carets.count != oldValue.count {
                onMultiCaretCountChange?(max(1, carets.count))
            }
            needsDisplay = true
        }
    }
    public var isMultiCaret: Bool { !carets.isEmpty }
    private var isApplyingCarets = false
    /// Column each caret tries to return to while moving up and down through shorter lines.
    private var verticalGoals: [CGFloat] = []
    public var onMultiCaretCountChange: ((Int) -> Void)?

    public var smartHighlightRanges: [NSRange] = [] {
        didSet {
            if smartHighlightRanges != oldValue {
                updateScrollbarMarkers()
                needsDisplay = true
            }
        }
    }

    public var smartHighlightPrimaryRange: NSRange? = nil {
        didSet {
            if smartHighlightPrimaryRange != oldValue {
                needsDisplay = true
            }
        }
    }

    public func updateScrollbarMarkers() {
        guard let sv = enclosingScrollView,
              let scroller = sv.verticalScroller as? MarkedIndicatorScroller else { return }
        guard let lm = self.layoutManager,
              let tc = self.textContainer,
              !smartHighlightRanges.isEmpty else {
            scroller.highlightNormalizedOffsets = []
            return
        }

        let ns = self.textContents
        guard ns.length > 0 else {
            scroller.highlightNormalizedOffsets = []
            return
        }

        let usedRect = lm.usedRect(for: tc)
        let docHeight = max(1, usedRect.height + textContainerInset.height * 2)
        let clipHeight = sv.contentView.bounds.height > 0 ? sv.contentView.bounds.height : bounds.height
        let totalDocHeight = max(clipHeight, docHeight)

        var offsets: [CGFloat] = []
        for range in smartHighlightRanges {
            guard NSMaxRange(range) <= ns.length else { continue }
            let glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            guard glyphRange.location != NSNotFound else { continue }
            let lineRect = lm.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            let lineY = lineRect.origin.y + textContainerOrigin.y
            let ratio = max(0.0, min(1.0, lineY / totalDocHeight))
            offsets.append(ratio)
        }

        var uniqueOffsets: [CGFloat] = []
        for o in offsets {
            if !uniqueOffsets.contains(where: { abs($0 - o) < 0.003 }) {
                uniqueOffsets.append(o)
            }
        }
        scroller.highlightNormalizedOffsets = uniqueOffsets
    }

    public func applySmartHighlightSelectedTextAttributes() {
        let isDark = currentTheme.isDark
        let bg = isDark
            ? NSColor(calibratedRed: 0.12, green: 0.72, blue: 0.28, alpha: 0.90)
            : NSColor(calibratedRed: 0.18, green: 0.90, blue: 0.35, alpha: 0.95)
        self.selectedTextAttributes = [
            .backgroundColor: bg,
            .foregroundColor: isDark ? NSColor.white : NSColor.black
        ]
    }

    public func resetSelectedTextAttributes() {
        self.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.selectedTextColor
        ]
    }

    // MARK: - Localized Context Menu
    public override func menu(for event: NSEvent) -> NSMenu? {
        guard let appState = self.appState else { return super.menu(for: event) }
        let isTr = appState.isTurkish
        let menu = NSMenu()
        menu.autoenablesItems = true

        // Undo / Redo
        let undoItem = NSMenuItem(
            title: isTr ? "Geri Al (Undo)" : "Undo",
            action: #selector(undo(_:)),
            keyEquivalent: "z"
        )
        undoItem.keyEquivalentModifierMask = [.command]
        undoItem.isEnabled = self.undoManager?.canUndo ?? false
        menu.addItem(undoItem)

        let redoItem = NSMenuItem(
            title: isTr ? "İleri Al / Yinele (Redo)" : "Redo",
            action: #selector(redo(_:)),
            keyEquivalent: "z"
        )
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        redoItem.isEnabled = self.undoManager?.canRedo ?? false
        menu.addItem(redoItem)

        menu.addItem(NSMenuItem.separator())

        // Cut / Copy / Paste / Delete / Select All
        let hasSelection = self.selectedRange().length > 0
        let cutItem = NSMenuItem(
            title: isTr ? "Kes (Cut)" : "Cut",
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        )
        cutItem.keyEquivalentModifierMask = [.command]
        cutItem.isEnabled = hasSelection && self.isEditable
        menu.addItem(cutItem)

        let copyItem = NSMenuItem(
            title: isTr ? "Kopyala (Copy)" : "Copy",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        copyItem.keyEquivalentModifierMask = [.command]
        copyItem.isEnabled = hasSelection
        menu.addItem(copyItem)

        let pasteItem = NSMenuItem(
            title: isTr ? "Yapıştır (Paste)" : "Paste",
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        pasteItem.keyEquivalentModifierMask = [.command]
        pasteItem.isEnabled = self.isEditable && (NSPasteboard.general.string(forType: .string) != nil)
        menu.addItem(pasteItem)

        let deleteItem = NSMenuItem(
            title: isTr ? "Sil (Delete)" : "Delete",
            action: #selector(NSText.delete(_:)),
            keyEquivalent: ""
        )
        deleteItem.isEnabled = hasSelection && self.isEditable
        menu.addItem(deleteItem)

        let selectAllItem = NSMenuItem(
            title: isTr ? "Tümünü Seç (Select All)" : "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        selectAllItem.keyEquivalentModifierMask = [.command]
        menu.addItem(selectAllItem)

        menu.addItem(NSMenuItem.separator())

        // Line and Text Operations
        let dupItem = NSMenuItem(
            title: isTr ? "Mevcut Satırı Çoğalt (⌘D)" : "Duplicate Current Line (⌘D)",
            action: #selector(handleContextMenuAction(_:)),
            keyEquivalent: "d"
        )
        dupItem.keyEquivalentModifierMask = [.command]
        dupItem.representedObject = "duplicateLine"
        dupItem.target = self
        menu.addItem(dupItem)

        let delLineItem = NSMenuItem(
            title: isTr ? "Mevcut Satırı Sil (⇧⌘L)" : "Delete Current Line (⇧⌘L)",
            action: #selector(handleContextMenuAction(_:)),
            keyEquivalent: "l"
        )
        delLineItem.keyEquivalentModifierMask = [.command, .shift]
        delLineItem.representedObject = "deleteLine"
        delLineItem.target = self
        menu.addItem(delLineItem)

        let commentItem = NSMenuItem(
            title: isTr ? "Yorum Satırı Aç / Kapat (⌘/)" : "Toggle Comment (⌘/)",
            action: #selector(handleContextMenuAction(_:)),
            keyEquivalent: "/"
        )
        commentItem.keyEquivalentModifierMask = [.command]
        commentItem.representedObject = "toggleComment"
        commentItem.target = self
        menu.addItem(commentItem)

        let colItem = NSMenuItem(
            title: isTr ? "Sütun Düzenleyici (⌥C)..." : "Column Editor (⌥C)...",
            action: #selector(handleContextMenuAction(_:)),
            keyEquivalent: "c"
        )
        colItem.keyEquivalentModifierMask = [.option]
        colItem.representedObject = "columnEditor"
        colItem.target = self
        menu.addItem(colItem)

        // Case Conversion Submenu
        let caseSubmenu = NSMenu(title: isTr ? "Harf Durumu Dönüştür" : "Convert Case")
        for conv in CaseConversionType.allCases {
            let item = NSMenuItem(
                title: conv.title(for: appState.language),
                action: #selector(handleContextMenuAction(_:)),
                keyEquivalent: ""
            )
            item.representedObject = conv
            item.target = self
            caseSubmenu.addItem(item)
        }
        let caseMenuItem = NSMenuItem(
            title: isTr ? "Harf Durumu Dönüştür" : "Convert Case",
            action: nil,
            keyEquivalent: ""
        )
        caseMenuItem.submenu = caseSubmenu
        menu.addItem(caseMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Find / Replace / Go to Line
        let findItem = NSMenuItem(
            title: isTr ? "Bul / Değiştir... (⌘F)" : "Find / Replace... (⌘F)",
            action: #selector(handleContextMenuAction(_:)),
            keyEquivalent: "f"
        )
        findItem.keyEquivalentModifierMask = [.command]
        findItem.representedObject = "find"
        findItem.target = self
        menu.addItem(findItem)

        let goToLineItem = NSMenuItem(
            title: isTr ? "Satıra / Ofsete Git... (⌘G)" : "Go to Line / Offset... (⌘G)",
            action: #selector(handleContextMenuAction(_:)),
            keyEquivalent: "g"
        )
        goToLineItem.keyEquivalentModifierMask = [.command]
        goToLineItem.representedObject = "goToLine"
        goToLineItem.target = self
        menu.addItem(goToLineItem)

        let bookmarkItem = NSMenuItem(
            title: isTr ? "Satıra Yer İmi Ekle / Kaldır (F2)" : "Toggle Bookmark (F2)",
            action: #selector(handleContextMenuAction(_:)),
            keyEquivalent: "b"
        )
        bookmarkItem.keyEquivalentModifierMask = [.command]
        bookmarkItem.representedObject = "toggleBookmark"
        bookmarkItem.target = self
        menu.addItem(bookmarkItem)

        menu.addItem(NSMenuItem.separator())

        // Read-only Lock Toggle
        let roTitle = (appState.activeDocument?.isReadOnly == true)
            ? (isTr ? "Salt Okunur Kilidini Kaldır" : "Unlock Read-Only")
            : (isTr ? "Salt Okunur Yap (Düzenlemeyi Kilitle)" : "Set Read-Only (Lock Editing)")
        let roItem = NSMenuItem(
            title: roTitle,
            action: #selector(handleContextMenuAction(_:)),
            keyEquivalent: ""
        )
        roItem.representedObject = "toggleReadOnly"
        roItem.target = self
        menu.addItem(roItem)

        let summaryItem = NSMenuItem(
            title: isTr ? "Belge Özeti ve İstatistikler..." : "Document Summary & Stats...",
            action: #selector(handleContextMenuAction(_:)),
            keyEquivalent: ""
        )
        summaryItem.representedObject = "summary"
        summaryItem.target = self
        menu.addItem(summaryItem)

        return menu
    }

    @objc private func handleContextMenuAction(_ sender: NSMenuItem) {
        guard let appState = self.appState else { return }
        if let actionKey = sender.representedObject as? String {
            switch actionKey {
            case "duplicateLine":
                appState.duplicateCurrentLine()
            case "deleteLine":
                appState.deleteCurrentLine()
            case "toggleComment":
                appState.toggleCommentOnActiveDocument()
            case "columnEditor":
                appState.showColumnEditorSheet = true
            case "find":
                appState.findPanelTab = .find
                appState.showFindPanel = true
            case "goToLine":
                appState.showGoToLineSheet = true
            case "toggleBookmark":
                appState.toggleBookmark()
            case "toggleReadOnly":
                appState.toggleReadOnly()
            case "summary":
                appState.showSummarySheet = true
            default:
                break
            }
        } else if let conv = sender.representedObject as? CaseConversionType {
            appState.applyCaseConversion(conv)
        }
    }

    public override func setFrameOrigin(_ newOrigin: NSPoint) {
        var fixed = newOrigin
        if fixed.x != 0 {
            fixed.x = 0
        }
        super.setFrameOrigin(fixed)
    }

    public override func autoscroll(with event: NSEvent) -> Bool {
        let result = super.autoscroll(with: event)
        if let clip = enclosingScrollView?.contentView {
            if appState?.wordWrap == true || clip.bounds.origin.x < 0 {
                var b = clip.bounds
                b.origin.x = 0
                clip.bounds = b
            }
        }
        return result
    }

    public override func setFrameSize(_ newSize: NSSize) {
        var adjusted = newSize
        if let sv = self.enclosingScrollView, self.appState?.wordWrap == true {
            let clipW = max(120, sv.contentView.bounds.width)
            adjusted.width = clipW
            if let container = self.textContainer {
                let insetW = self.textContainerInset.width * 2
                let padW = container.lineFragmentPadding * 2
                let targetContainerW = max(80, clipW - insetW - padW)
                if abs(container.containerSize.width - targetContainerW) > 0.5 {
                    container.containerSize = NSSize(width: targetContainerW, height: CGFloat.greatestFiniteMagnitude)
                }
            }
        }
        super.setFrameSize(adjusted)
    }

    private var optionDragStartLineCol: (line: Int, col: Int)? = nil
    private var didOptionDragAcrossLines: Bool = false

    public var allCarets: [Int] {
        if isMultiCaret { return carets.map(\.head) }
        return [max(0, min(self.selectedRange().location, (self.textContents).length))]
    }

    public func clearExtraCarets() {
        guard isMultiCaret else { return }
        let head = min(carets[0].head, (self.textContents).length)
        applyCarets([TextCaret(at: head)])
    }

    // Any selection change that does not come from the cursors themselves ends multi-cursor mode.
    public override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        if !isApplyingCarets && isMultiCaret { carets = [] }
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelectingFlag)
    }

    public override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        if !isApplyingCarets && isMultiCaret { carets = [] }
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)
    }

    private var caretsOrCurrentSelection: [TextCaret] {
        if isMultiCaret { return carets }
        let sel = selectedRange()
        return [TextCaret(anchor: sel.location, head: NSMaxRange(sel))]
    }

    /// Sorted, inside the text and with overlapping cursors joined.
    private func mergedCarets(_ proposed: [TextCaret]) -> [TextCaret] {
        let length = (self.textContents).length
        let clamped = proposed.map { TextCaret(anchor: max(0, min($0.anchor, length)), head: max(0, min($0.head, length))) }
        var merged: [TextCaret] = []
        for caret in clamped.sorted(by: { ($0.range.location, NSMaxRange($0.range)) < ($1.range.location, NSMaxRange($1.range)) }) {
            guard let last = merged.last else {
                merged.append(caret)
                continue
            }
            let start = caret.range.location
            let lastEnd = NSMaxRange(last.range)
            if start < lastEnd || (start == lastEnd && (caret.isEmpty || last.isEmpty)) {
                let lower = last.range.location
                let upper = max(lastEnd, NSMaxRange(caret.range))
                let forward = caret.head >= caret.anchor
                merged[merged.count - 1] = forward ? TextCaret(anchor: lower, head: upper) : TextCaret(anchor: upper, head: lower)
            } else {
                merged.append(caret)
            }
        }
        return merged
    }

    private func applyCarets(_ proposed: [TextCaret], keepVerticalGoals: Bool = false) {
        let merged = mergedCarets(proposed)
        if !keepVerticalGoals { verticalGoals = [] }
        isApplyingCarets = true
        defer { isApplyingCarets = false }
        if merged.count <= 1 {
            carets = []
            setSelectedRange(merged.first?.range ?? NSRange(location: 0, length: 0))
            return
        }
        let selections = merged.filter { !$0.isEmpty }.map { NSValue(range: $0.range) }
        super.setSelectedRanges(
            selections.isEmpty ? [NSValue(range: NSRange(location: merged[0].head, length: 0))] : selections,
            affinity: .downstream,
            stillSelecting: false
        )
        carets = merged
    }

    // MARK: - Multi-Caret Expansion Helpers
    public func addCursorVertically(direction: Int) {
        var list = mergedCarets(caretsOrCurrentSelection)
        guard let edge = (direction < 0 ? list.first : list.last) else { return }
        let (line, col) = lineAndColumn(forOffset: edge.head)
        let targetLine = line + direction
        let lines = self.string.components(separatedBy: "\n")
        guard targetLine >= 1 && targetLine <= lines.count else { return }
        list.append(TextCaret(at: offsetFor(line: targetLine, column: col, inLines: lines)))
        applyCarets(list)
    }

    public func addCursorsToSelectedLines(atStart: Bool) {
        let sel = self.selectedRange()
        let lines = self.string.components(separatedBy: "\n")
        guard !lines.isEmpty else { return }

        let startLine: Int
        let endLine: Int
        if sel.length > 0 {
            startLine = lineAndColumn(forOffset: sel.location).line
            endLine = lineAndColumn(forOffset: NSMaxRange(sel)).line
        } else {
            let cur = lineAndColumn(forOffset: sel.location).line
            startLine = cur
            endLine = min(lines.count, cur + 4)
        }

        guard startLine <= endLine else { return }
        var newCarets: [TextCaret] = []
        var runningOffset = 0
        for (idx, lineStr) in lines.enumerated() {
            let lineNum = idx + 1
            let lineLen = (lineStr as NSString).length
            if lineNum >= startLine && lineNum <= endLine {
                if atStart {
                    let indentLen = lineStr.prefix(while: { $0 == " " || $0 == "\t" }).utf16.count
                    newCarets.append(TextCaret(at: runningOffset + indentLen))
                } else {
                    newCarets.append(TextCaret(at: runningOffset + lineLen))
                }
            }
            runningOffset += lineLen + 1
        }
        applyCarets(newCarets)
    }

    // MARK: - Multi-Caret Movement
    public override func doCommand(by selector: Selector) {
        if isMultiCaret && performCaretCommand(selector) { return }
        super.doCommand(by: selector)
    }

    private func previousCharacter(before offset: Int) -> Int {
        guard offset > 0 else { return 0 }
        return (self.textContents).rangeOfComposedCharacterSequence(at: offset - 1).location
    }

    private func nextCharacter(after offset: Int) -> Int {
        let ns = self.textContents
        guard offset < ns.length else { return ns.length }
        return NSMaxRange(ns.rangeOfComposedCharacterSequence(at: offset))
    }

    private func wordBoundary(from offset: Int, forward: Bool) -> Int {
        guard let storage = textStorage else { return offset }
        if forward && offset >= storage.length { return storage.length }
        if !forward && offset <= 0 { return 0 }
        return storage.nextWord(from: offset, forward: forward)
    }

    private func lineStart(of offset: Int) -> Int {
        (self.textContents).lineRange(for: NSRange(location: offset, length: 0)).location
    }

    private func lineEnd(of offset: Int) -> Int {
        let ns = self.textContents
        let range = ns.lineRange(for: NSRange(location: offset, length: 0))
        let end = NSMaxRange(range)
        return (end > range.location && ns.character(at: end - 1) == 10) ? end - 1 : end
    }

    private func moveCarets(extending: Bool, to target: (TextCaret) -> Int) {
        applyCarets(carets.map { caret in
            let destination = target(caret)
            return extending ? TextCaret(anchor: caret.anchor, head: destination) : TextCaret(at: destination)
        })
        scrollLastCaretToVisible()
    }

    private func scrollLastCaretToVisible() {
        if let last = carets.last {
            scrollRangeToVisible(NSRange(location: last.head, length: 0))
        } else {
            scrollRangeToVisible(selectedRange())
        }
    }

    /// Where a caret at `offset` sits, in text container coordinates.
    private func caretFrame(at offset: Int) -> NSRect {
        let lineHeight = (self.font?.pointSize ?? 13) * 1.35
        guard let lm = layoutManager, let tc = textContainer, lm.numberOfGlyphs > 0 else {
            return NSRect(x: 0, y: 0, width: 0, height: lineHeight)
        }
        let ns = self.textContents
        lm.ensureLayout(for: tc)
        if offset >= ns.length {
            let extra = lm.extraLineFragmentRect
            if extra.height > 0 {
                return NSRect(x: extra.minX + tc.lineFragmentPadding, y: extra.minY, width: 0, height: extra.height)
            }
            let glyph = max(0, lm.numberOfGlyphs - 1)
            let used = lm.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
            return NSRect(x: used.maxX, y: used.minY, width: 0, height: used.height)
        }
        let glyph = lm.glyphIndexForCharacter(at: offset)
        let fragment = lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        return NSRect(x: fragment.minX + lm.location(forGlyphAt: glyph).x, y: fragment.minY, width: 0, height: fragment.height)
    }

    private func moveCaretsVertically(direction: Int, extending: Bool) {
        guard let lm = layoutManager, let tc = textContainer else { return }
        let ns = self.textContents
        let starts = carets.map { caret -> Int in
            if extending || caret.isEmpty { return caret.head }
            return direction < 0 ? caret.range.location : NSMaxRange(caret.range)
        }
        if verticalGoals.count != carets.count {
            verticalGoals = starts.map { caretFrame(at: $0).minX }
        }
        let extra = lm.extraLineFragmentRect
        let bottom = lm.usedRect(for: tc).maxY

        var moved: [TextCaret] = []
        for (index, caret) in carets.enumerated() {
            let frame = caretFrame(at: starts[index])
            let y = frame.midY + CGFloat(direction) * frame.height
            var destination: Int
            if y < 0 {
                destination = 0
            } else if y >= bottom || (extra.height > 0 && y >= extra.minY) {
                destination = ns.length
            } else {
                var fraction: CGFloat = 0
                destination = lm.characterIndex(for: NSPoint(x: verticalGoals[index], y: y), in: tc, fractionOfDistanceBetweenInsertionPoints: &fraction)
                if fraction > 0.5 && destination < ns.length && ns.character(at: destination) != 10 {
                    destination += 1
                }
            }
            destination = max(0, min(destination, ns.length))
            moved.append(extending ? TextCaret(anchor: caret.anchor, head: destination) : TextCaret(at: destination))
        }
        applyCarets(moved, keepVerticalGoals: true)
        scrollLastCaretToVisible()
    }

    private func performCaretCommand(_ selector: Selector) -> Bool {
        var name = NSStringFromSelector(selector)
        let extending = name.hasSuffix("AndModifySelection:")
        if extending {
            name = String(name.dropLast("AndModifySelection:".count)) + ":"
        }
        let keyCode = NSApp.currentEvent?.type == .keyDown ? NSApp.currentEvent?.keyCode : nil

        switch name {
        case "moveLeft:", "moveBackward:":
            moveCarets(extending: extending) { (!extending && !$0.isEmpty) ? $0.range.location : self.previousCharacter(before: $0.head) }
        case "moveRight:", "moveForward:":
            moveCarets(extending: extending) { (!extending && !$0.isEmpty) ? NSMaxRange($0.range) : self.nextCharacter(after: $0.head) }
        case "moveUp:":
            moveCaretsVertically(direction: -1, extending: extending)
        case "moveDown:":
            moveCaretsVertically(direction: 1, extending: extending)
        case "moveWordLeft:", "moveWordBackward:":
            moveCarets(extending: extending) { self.wordBoundary(from: $0.head, forward: false) }
        case "moveWordRight:", "moveWordForward:":
            moveCarets(extending: extending) { self.wordBoundary(from: $0.head, forward: true) }
        case "moveToLeftEndOfLine:", "moveToBeginningOfLine:", "moveToBeginningOfParagraph:", "scrollToBeginningOfDocument:":
            moveCarets(extending: extending) { self.lineStart(of: $0.head) }
        case "moveToRightEndOfLine:", "moveToEndOfLine:", "moveToEndOfParagraph:", "scrollToEndOfDocument:":
            moveCarets(extending: extending) { self.lineEnd(of: $0.head) }
        case "moveToBeginningOfDocument:":
            // Shift+Home arrives under this name, but with several cursors it means the start of each line.
            if keyCode == 115 {
                moveCarets(extending: extending) { self.lineStart(of: $0.head) }
            } else {
                moveCarets(extending: extending) { _ in 0 }
            }
        case "moveToEndOfDocument:":
            if keyCode == 119 {
                moveCarets(extending: extending) { self.lineEnd(of: $0.head) }
            } else {
                let length = (self.textContents).length
                moveCarets(extending: extending) { _ in length }
            }
        case "deleteWordBackward:":
            deleteAtCarets { self.wordBoundary(from: $0, forward: false) }
        case "deleteWordForward:":
            deleteAtCarets { self.wordBoundary(from: $0, forward: true) }
        case "deleteToBeginningOfLine:", "deleteToBeginningOfParagraph:":
            deleteAtCarets { self.lineStart(of: $0) }
        case "deleteToEndOfLine:", "deleteToEndOfParagraph:":
            deleteAtCarets { self.lineEnd(of: $0) }
        case "deleteBackwardByDecomposingPreviousCharacter:":
            deleteBackward(nil)
        default:
            return false
        }
        return true
    }

    // MARK: - Multi-Caret Editing
    private var canEditText: Bool {
        isEditable && !(appState?.activeDocument?.isReadOnly ?? false)
    }

    /// One replacement per cursor. Each cursor ends up right after its own new text.
    private func editAtCarets(_ edit: (TextCaret, Int) -> (range: NSRange, text: String)) {
        guard canEditText else {
            NSSound.beep()
            return
        }
        var edits: [(range: NSRange, text: String)] = []
        var previousEnd = 0
        for (index, caret) in carets.enumerated() {
            var item = edit(caret, index)
            if item.range.location < previousEnd {
                let trimmed = min(previousEnd - item.range.location, item.range.length)
                item.range = NSRange(location: item.range.location + trimmed, length: item.range.length - trimmed)
            }
            previousEnd = NSMaxRange(item.range)
            edits.append(item)
        }
        var delta = 0
        var moved: [TextCaret] = []
        for item in edits {
            let textLength = (item.text as NSString).length
            moved.append(TextCaret(at: item.range.location + delta + textLength))
            delta += textLength - item.range.length
        }
        commitCaretEdits(edits, carets: moved)
    }

    private func commitCaretEdits(_ edits: [(range: NSRange, text: String)], carets moved: [TextCaret]) {
        guard let storage = textStorage else { return }
        isApplyingCarets = true
        storage.beginEditing()
        for item in edits.reversed() {
            storage.replaceCharacters(in: item.range, with: item.text)
        }
        storage.endEditing()
        isApplyingCarets = false
        applyCarets(moved)
        didChangeText()
        scrollLastCaretToVisible()
        needsDisplay = true
    }

    private func deleteAtCarets(to target: (Int) -> Int) {
        editAtCarets { caret, _ in
            if !caret.isEmpty { return (caret.range, "") }
            let other = target(caret.head)
            return (NSRange(location: min(other, caret.head), length: abs(other - caret.head)), "")
        }
    }

    private func insertAtCarets(_ text: String) {
        editAtCarets { caret, _ in (caret.range, text) }
    }

    /// Shift+Tab with several cursors: every line holding a cursor loses one indent level.
    private func outdentCaretLines() {
        guard canEditText else {
            NSSound.beep()
            return
        }
        let ns = self.textContents
        var removals: [NSRange] = []
        for start in Set(carets.map { lineStart(of: $0.head) }).sorted() {
            var length = 0
            if start < ns.length && ns.character(at: start) == 9 {
                length = 1
            } else {
                while length < 4 && start + length < ns.length && ns.character(at: start + length) == 32 { length += 1 }
            }
            if length > 0 { removals.append(NSRange(location: start, length: length)) }
        }
        guard !removals.isEmpty else { return }
        func shifted(_ offset: Int) -> Int {
            var removedBefore = 0
            for range in removals {
                if offset >= NSMaxRange(range) {
                    removedBefore += range.length
                } else if offset > range.location {
                    return range.location - removedBefore
                }
            }
            return offset - removedBefore
        }
        commitCaretEdits(removals.map { ($0, "") }, carets: carets.map { TextCaret(anchor: shifted($0.anchor), head: shifted($0.head)) })
    }

    private func lineAndColumn(forOffset offset: Int) -> (line: Int, col: Int) {
        let ns = self.textContents
        let clamped = max(0, min(offset, ns.length))
        var line = 1
        var lastLineStart = 0
        for i in 0..<clamped {
            if ns.character(at: i) == 10 {
                line += 1
                lastLineStart = i + 1
            }
        }
        return (line, clamped - lastLineStart + 1)
    }

    private func offsetFor(line targetLine: Int, column targetCol: Int, inLines lines: [String]) -> Int {
        var acc = 0
        let clampedLine = max(1, min(targetLine, lines.count))
        for i in 0..<(clampedLine - 1) {
            acc += (lines[i] as NSString).length + 1
        }
        let lineLen = (lines[clampedLine - 1] as NSString).length
        let colOffset = max(0, min(targetCol - 1, lineLen))
        return acc + colOffset
    }

    // MARK: - Mouse Handling for Option+Click and Option+Drag Multi-Line Carets & Rectangular Selection
    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.option) {
            let pt = convert(event.locationInWindow, from: nil)
            let clickedOffset = characterIndex(at: pt)
            let (clickedLine, clickedCol) = lineAndColumn(forOffset: clickedOffset)
            optionDragStartLineCol = (clickedLine, clickedCol)
            didOptionDragAcrossLines = false
            return
        }

        // Standard click clears extra carets and lets native super.mouseDown position caret anywhere
        clearExtraCarets()
        super.mouseDown(with: event)
    }

    private func characterIndex(at localPoint: NSPoint) -> Int {
        guard let lm = self.layoutManager, let tc = self.textContainer else { return 0 }
        let containerPoint = NSPoint(
            x: localPoint.x - textContainerOrigin.x,
            y: localPoint.y - textContainerOrigin.y
        )
        let glyphIdx = lm.glyphIndex(for: containerPoint, in: tc)
        let charIdx = lm.characterIndexForGlyph(at: glyphIdx)
        let totalLen = (self.textContents).length
        return max(0, min(charIdx, totalLen))
    }

    public override func mouseDragged(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.option), let anchor = optionDragStartLineCol {
            let pt = convert(event.locationInWindow, from: nil)
            let currentOffset = characterIndex(at: pt)
            let (currentLine, currentCol) = lineAndColumn(forOffset: currentOffset)

            let minLine = min(anchor.line, currentLine)
            let maxLine = max(anchor.line, currentLine)
            let minCol = min(anchor.col, currentCol)
            let maxCol = max(anchor.col, currentCol)
            let lines = self.string.components(separatedBy: "\n")

            if currentLine != anchor.line || minCol < maxCol {
                didOptionDragAcrossLines = true
                var rectangle: [TextCaret] = []
                for ln in minLine...maxLine {
                    guard ln >= 1 && ln <= lines.count else { continue }
                    let lineLen = (lines[ln - 1] as NSString).length
                    let lineStartOffset = offsetFor(line: ln, column: 1, inLines: lines)
                    rectangle.append(TextCaret(
                        anchor: lineStartOffset + max(0, min(anchor.col - 1, lineLen)),
                        head: lineStartOffset + max(0, min(currentCol - 1, lineLen))
                    ))
                }
                applyCarets(rectangle)
            }
            return
        }
        super.mouseDragged(with: event)
        if let clip = enclosingScrollView?.contentView {
            if appState?.wordWrap == true || clip.bounds.origin.x < 0 {
                var b = clip.bounds
                b.origin.x = 0
                clip.bounds = b
            }
        }
    }

    public override func mouseUp(with event: NSEvent) {
        if !didOptionDragAcrossLines, let anchor = optionDragStartLineCol {
            // It was a single option+click without dragging: toggle extra caret at click
            let lines = self.string.components(separatedBy: "\n")
            let clickedOffset = offsetFor(line: anchor.line, column: anchor.col, inLines: lines)
            var list = caretsOrCurrentSelection
            if list.contains(where: { $0.isEmpty && $0.head == clickedOffset }) {
                if list.count > 1 { list.removeAll { $0.isEmpty && $0.head == clickedOffset } }
            } else {
                list.append(TextCaret(at: clickedOffset))
            }
            applyCarets(list)
        }
        optionDragStartLineCol = nil
        didOptionDragAcrossLines = false
        super.mouseUp(with: event)
        if let clip = enclosingScrollView?.contentView {
            if appState?.wordWrap == true || clip.bounds.origin.x < 0 {
                var b = clip.bounds
                b.origin.x = 0
                clip.bounds = b
            }
        }
    }

    // MARK: - File Drag & Drop (Open Dropped Files in New Tab Instead of Pasting Filename)
    private func extractDroppedFileURLs(from sender: NSDraggingInfo) -> [URL] {
        let pb = sender.draggingPasteboard
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            return urls
        }
        return []
    }

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if !extractDroppedFileURLs(from: sender).isEmpty {
            return .copy
        }
        return super.draggingEntered(sender)
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if !extractDroppedFileURLs(from: sender).isEmpty {
            return .copy
        }
        return super.draggingUpdated(sender)
    }

    public override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if !extractDroppedFileURLs(from: sender).isEmpty {
            return true
        }
        return super.prepareForDragOperation(sender)
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = extractDroppedFileURLs(from: sender)
        if !urls.isEmpty {
            Task { @MainActor [weak self] in
                guard let appState = self?.appState else { return }
                for url in urls {
                    appState.openFile(url: url)
                }
            }
            return true
        }
        return super.performDragOperation(sender)
    }

    // MARK: - Undo / Redo Actions
    @objc public func undo(_ sender: Any?) {
        appState?.performUndo()
    }

    @objc public func redo(_ sender: Any?) {
        appState?.performRedo()
    }

    // MARK: - Keyboard Handling for Windows (Ctrl) / macOS (Cmd) Shortcuts & Multi-Caret
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleCustomShortcuts(event: event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    public override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        if !isEditable || (appState?.activeDocument?.isReadOnly ?? false) {
            return false
        }
        return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
    }

    public override func keyDown(with event: NSEvent) {
        if handleCustomShortcuts(event: event) {
            return
        }

        let isLocked = !isEditable || (appState?.activeDocument?.isReadOnly ?? false)
        if isLocked {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Allow Command / Control keyboard shortcuts (Copy ⌘C, Select All ⌘A, Find ⌘F, Print ⌘P, etc.)
            if flags.contains(.command) || flags.contains(.control) {
                super.keyDown(with: event)
                return
            }

            // Allow safe navigation keys: Arrows (123-126), Home (115), PageUp (116), End (119), PageDown (121), Esc (53)
            switch event.keyCode {
            case 123, 124, 125, 126, 115, 116, 119, 121, 53:
                super.keyDown(with: event)
                return
            default:
                // Any character typing, space, return, backspace, delete, tab: Beep and reject immediately!
                NSSound.beep()
                return
            }
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Tab (keyCode 48) - Multi-line Indent & Shift+Tab Outdent
        if event.keyCode == 48 {
            if isMultiCaret {
                if flags.contains(.shift) { outdentCaretLines() } else { insertAtCarets("    ") }
                return
            }
            if flags.contains(.shift) {
                indentSelectedLines(direction: -1)
                return
            } else if shouldIndentSelection() {
                indentSelectedLines(direction: 1)
                return
            }
        }

        // Option + Shift + Up (keyCode 126) or Control + Option + Up -> Add cursor above
        if event.keyCode == 126 && ((flags.contains(.option) && flags.contains(.shift)) || (flags.contains(.control) && flags.contains(.option))) {
            addCursorVertically(direction: -1)
            return
        }

        // Option + Shift + Down (keyCode 125) or Control + Option + Down -> Add cursor below
        if event.keyCode == 125 && ((flags.contains(.option) && flags.contains(.shift)) || (flags.contains(.control) && flags.contains(.option))) {
            addCursorVertically(direction: 1)
            return
        }

        // Option + Shift + I (keyCode 34) -> Put cursors on all selected lines
        if event.keyCode == 34 && flags.contains(.option) && flags.contains(.shift) {
            addCursorsToSelectedLines(atStart: false)
            return
        }

        // Escape (keyCode 53) clears multi-carets
        if event.keyCode == 53 && isMultiCaret {
            clearExtraCarets()
            return
        }

        super.keyDown(with: event)
    }

    private func handleCustomShortcuts(event: NSEvent) -> Bool {
        guard let appState = self.appState else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        // F2: Bookmark Navigation / Toggle (Works in all shortcut schemes!)
        if event.keyCode == 120 { // F2
            if flags.contains(.command) || flags.contains(.control) {
                appState.toggleBookmark()
            } else if flags.contains(.shift) {
                appState.navigateBookmark(forward: false)
            } else {
                appState.navigateBookmark(forward: true)
            }
            return true
        }

        // F3: Find Next / Previous (Works in all shortcut schemes!)
        if event.keyCode == 99 { // F3
            appState.findNext(forward: !flags.contains(.shift))
            return true
        }

        let scheme = appState.shortcutScheme
        let allowMacCmd = (scheme == .macStandard || scheme == .hybrid)
        let allowWinCtrl = (scheme == .windowsNPP || scheme == .hybrid)

        // Mac Command (⌘) Undo/Redo & Bookmark nav
        if allowMacCmd && flags.contains(.command) && !flags.contains(.control) && !flags.contains(.option) {
            if key == "z" {
                if flags.contains(.shift) {
                    appState.performRedo()
                } else {
                    appState.performUndo()
                }
                return true
            }
            if key == "y" && !flags.contains(.shift) {
                appState.performRedo()
                return true
            }
            if key == "]" {
                appState.navigateBookmark(forward: true)
                return true
            }
            if key == "[" {
                appState.navigateBookmark(forward: false)
                return true
            }
        }

        // Windows Control (⌃ Ctrl) Shortcuts
        if allowWinCtrl && flags.contains(.control) && !flags.contains(.command) && !flags.contains(.option) {
            switch key {
            case "z":
                if flags.contains(.shift) {
                    appState.performRedo()
                } else {
                    appState.performUndo()
                }
                return true
            case "y":
                appState.performRedo()
                return true
            case "s":
                if flags.contains(.shift) {
                    appState.saveAllTabs()
                } else {
                    appState.saveActiveTab()
                }
                return true
            case "n":
                appState.newTab()
                return true
            case "o":
                appState.openFilesPanel()
                return true
            case "w":
                if let id = appState.activeTabId {
                    appState.closeTab(id: id)
                }
                return true
            case "f":
                if flags.contains(.shift) {
                    appState.findPanelTab = .findInFiles
                } else {
                    appState.findPanelTab = .find
                }
                appState.showFindPanel = true
                return true
            case "h":
                appState.findPanelTab = .replace
                appState.showFindPanel = true
                return true
            case "g":
                appState.showGoToLineSheet = true
                return true
            case "d":
                appState.duplicateCurrentLine()
                return true
            case "l":
                appState.deleteCurrentLine()
                return true
            case "q", "/":
                appState.toggleCommentOnActiveDocument()
                return true
            case "a":
                self.selectAll(nil)
                return true
            case "c":
                self.copy(nil)
                return true
            case "x":
                self.cut(nil)
                return true
            case "v":
                self.paste(nil)
                return true
            default:
                break
            }
        }

        return false
    }

    public override func copy(_ sender: Any?) {
        let selected = carets.filter { !$0.isEmpty }
        if selected.count > 1 {
            let ns = self.textContents
            let pboard = NSPasteboard.general
            pboard.clearContents()
            pboard.setString(selected.map { ns.substring(with: $0.range) }.joined(separator: "\n"), forType: .string)
            return
        }
        super.copy(sender)
    }

    public override func cut(_ sender: Any?) {
        if isMultiCaret {
            self.copy(sender)
            insertAtCarets("")
            return
        }
        super.cut(sender)
    }

    public override func cancelOperation(_ sender: Any?) {
        clearExtraCarets()
    }

    public override func insertText(_ string: Any, replacementRange: NSRange) {
        if !isEditable || (appState?.activeDocument?.isReadOnly ?? false) {
            NSSound.beep()
            return
        }
        guard isMultiCaret else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }
        if let text = string as? String {
            insertAtCarets(text)
        } else if let attributed = string as? NSAttributedString {
            insertAtCarets(attributed.string)
        }
    }

    public override func insertTab(_ sender: Any?) {
        if !isMultiCaret && shouldIndentSelection() {
            indentSelectedLines(direction: 1)
        } else if isMultiCaret {
            insertAtCarets("    ")
        } else {
            super.insertTab(sender)
        }
    }

    public override func insertBacktab(_ sender: Any?) {
        indentSelectedLines(direction: -1)
    }

    // MARK: - Multi-Line Indent (Tab) & Outdent (Shift+Tab)
    public func shouldIndentSelection() -> Bool {
        let sel = self.selectedRange()
        guard sel.length > 0 else { return false }
        let ns = self.textContents
        guard NSMaxRange(sel) <= ns.length else { return false }
        let sub = ns.substring(with: sel)
        if sub.contains("\n") || sub.contains("\r") {
            return true
        }
        let lineRange = ns.lineRange(for: sel)
        if sel.location == lineRange.location && NSMaxRange(sel) >= lineRange.location + max(1, lineRange.length - 1) {
            return true
        }
        return false
    }

    public func indentSelectedLines(direction: Int) {
        let ns = self.textContents
        guard ns.length > 0 else { return }
        let sel = self.selectedRange()

        var effectiveRange = sel
        if sel.length > 0 && NSMaxRange(sel) <= ns.length {
            let lastChar = ns.character(at: NSMaxRange(sel) - 1)
            if lastChar == 10 || lastChar == 13 {
                effectiveRange = NSRange(location: sel.location, length: max(0, sel.length - 1))
            }
        }
        let fullLineRange = ns.lineRange(for: effectiveRange)
        guard fullLineRange.location != NSNotFound, NSMaxRange(fullLineRange) <= ns.length else { return }

        var lineStart = fullLineRange.location
        var modifiedBlock = ""
        var firstLineDelta = 0
        var totalDelta = 0
        var isFirstLine = true

        while lineStart < NSMaxRange(fullLineRange) {
            let thisLineRange = ns.lineRange(for: NSRange(location: lineStart, length: 0))
            let lineText = ns.substring(with: thisLineRange)

            var lineContent = lineText
            var lineEnding = ""
            if lineContent.hasSuffix("\r\n") {
                lineContent.removeLast(2)
                lineEnding = "\r\n"
            } else if lineContent.hasSuffix("\n") || lineContent.hasSuffix("\r") {
                lineEnding = String(lineContent.removeLast())
            }

            var delta = 0
            if direction > 0 {
                // Indent (Tab): Prepend 4 spaces if line has content or is the only line
                if !lineContent.isEmpty || fullLineRange.length == thisLineRange.length {
                    lineContent = "    " + lineContent
                    delta = 4
                }
            } else {
                // Outdent (Shift+Tab): Remove up to 4 spaces or 1 tab
                if lineContent.hasPrefix("    ") {
                    lineContent.removeFirst(4)
                    delta = -4
                } else if lineContent.hasPrefix("\t") {
                    lineContent.removeFirst(1)
                    delta = -1
                } else {
                    var removed = 0
                    while removed < 4 && lineContent.hasPrefix(" ") {
                        lineContent.removeFirst(1)
                        removed += 1
                    }
                    delta = -removed
                }
            }

            if isFirstLine {
                firstLineDelta = delta
                isFirstLine = false
            }
            totalDelta += delta
            modifiedBlock += lineContent + lineEnding
            lineStart = NSMaxRange(thisLineRange)
        }

        let newSelLocation: Int
        let newSelLength: Int

        if sel.length == 0 {
            let colInLine = sel.location - fullLineRange.location
            if firstLineDelta > 0 {
                newSelLocation = fullLineRange.location + colInLine + firstLineDelta
            } else {
                newSelLocation = fullLineRange.location + max(0, colInLine + firstLineDelta)
            }
            newSelLength = 0
        } else {
            if sel.location == fullLineRange.location {
                newSelLocation = fullLineRange.location
                newSelLength = max(0, sel.length + totalDelta)
            } else {
                if firstLineDelta > 0 {
                    newSelLocation = sel.location + firstLineDelta
                } else {
                    newSelLocation = max(fullLineRange.location, sel.location + firstLineDelta)
                }
                let startShift = newSelLocation - sel.location
                newSelLength = max(0, sel.length + totalDelta - startShift)
            }
        }

        if self.shouldChangeText(in: fullLineRange, replacementString: modifiedBlock) {
            self.replaceCharacters(in: fullLineRange, with: modifiedBlock)
            self.didChangeText()

            let totalLength = (self.textContents).length
            let safeLoc = max(0, min(newSelLocation, totalLength))
            let safeLen = max(0, min(newSelLength, totalLength - safeLoc))
            self.setSelectedRange(NSRange(location: safeLoc, length: safeLen))
        }
    }

    // MARK: - Ctrl + Mouse Wheel Zoom
    private var scrollZoomAccumulator: CGFloat = 0
    private var pinchZoomAccumulator: CGFloat = 0

    public override func scrollWheel(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if (flags.contains(.control) || flags.contains(.command)),
           let appState = self.appState, appState.enableScrollWheelZoom {
            let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY * 10
            scrollZoomAccumulator += delta
            let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 12 : 3
            if scrollZoomAccumulator >= threshold {
                scrollZoomAccumulator = 0
                appState.fontSize = min(64.0, appState.fontSize + 1.0)
            } else if scrollZoomAccumulator <= -threshold {
                scrollZoomAccumulator = 0
                appState.fontSize = max(7.0, appState.fontSize - 1.0)
            }
            if let clip = self.enclosingScrollView?.contentView {
                if appState.wordWrap || clip.bounds.origin.x < 0 {
                    var b = clip.bounds
                    b.origin.x = 0
                    clip.bounds = b
                }
            }
            return
        }
        scrollZoomAccumulator = 0
        super.scrollWheel(with: event)
        if let clip = self.enclosingScrollView?.contentView {
            if self.appState?.wordWrap == true || clip.bounds.origin.x < 0 {
                var b = clip.bounds
                b.origin.x = 0
                clip.bounds = b
            }
        }
    }

    public override func magnify(with event: NSEvent) {
        guard let appState = self.appState, appState.enableTrackpadPinchZoom else {
            super.magnify(with: event)
            return
        }

        pinchZoomAccumulator += event.magnification
        let threshold: CGFloat = 0.08
        if pinchZoomAccumulator >= threshold {
            pinchZoomAccumulator = 0
            appState.fontSize = min(64.0, appState.fontSize + 1.0)
        } else if pinchZoomAccumulator <= -threshold {
            pinchZoomAccumulator = 0
            appState.fontSize = max(7.0, appState.fontSize - 1.0)
        }
        if let clip = self.enclosingScrollView?.contentView {
            if appState.wordWrap || clip.bounds.origin.x < 0 {
                var b = clip.bounds
                b.origin.x = 0
                clip.bounds = b
            }
        }
    }

    public override func deleteBackward(_ sender: Any?) {
        if !isEditable || (appState?.activeDocument?.isReadOnly ?? false) {
            NSSound.beep()
            return
        }
        if isMultiCaret {
            deleteAtCarets { self.previousCharacter(before: $0) }
        } else {
            super.deleteBackward(sender)
        }
    }

    public override func deleteForward(_ sender: Any?) {
        if !isEditable || (appState?.activeDocument?.isReadOnly ?? false) {
            NSSound.beep()
            return
        }
        if isMultiCaret {
            deleteAtCarets { self.nextCharacter(after: $0) }
        } else {
            super.deleteForward(sender)
        }
    }

    public override func paste(_ sender: Any?) {
        guard isMultiCaret, let clip = NSPasteboard.general.string(forType: .string) else {
            super.paste(sender)
            return
        }
        var lines = LineEndingType.normalizeToLF(clip).components(separatedBy: "\n")
        if lines.count == carets.count + 1 && lines.last == "" { lines.removeLast() }
        // One line per cursor when the counts match; otherwise the whole text at each cursor.
        if lines.count == carets.count {
            editAtCarets { caret, index in (caret.range, lines[index]) }
        } else {
            insertAtCarets(clip)
        }
    }

    public override func insertNewline(_ sender: Any?) {
        if !isEditable || (appState?.activeDocument?.isReadOnly ?? false) {
            NSSound.beep()
            return
        }
        if isMultiCaret {
            let text = self.textContents
            editAtCarets { caret, _ in
                let line = text.substring(with: text.lineRange(for: NSRange(location: min(caret.range.location, text.length), length: 0)))
                return (caret.range, "\n" + String(line.prefix(while: { $0 == " " || $0 == "\t" })))
            }
            return
        }
        let ns = self.textContents
        let sel = self.selectedRange()
        let lineRange = ns.lineRange(for: NSRange(location: min(sel.location, ns.length), length: 0))
        let currentLineStr = ns.substring(with: lineRange)
        let indentPrefix = String(currentLineStr.prefix(while: { $0 == " " || $0 == "\t" }))
        super.insertNewline(sender)
        if !indentPrefix.isEmpty {
            super.insertText(indentPrefix, replacementRange: self.selectedRange())
        }
    }

    // MARK: - Background & Multi-Cursor Drawing
    public override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)

        guard let layoutManager = self.layoutManager,
              let textContainer = self.textContainer else { return }

        let ns = self.textContents
        let caretsToHighlight = allCarets

        for caretOffset in caretsToHighlight {
            guard caretOffset <= ns.length else { continue }
            let lineCharRange = ns.lineRange(for: NSRange(location: caretOffset, length: 0))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineCharRange, actualCharacterRange: nil)
            var lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            if lineRect.height == 0 {
                lineRect.size.height = (self.font?.pointSize ?? 13) * 1.35
            }
            lineRect.origin.x = 0
            lineRect.origin.y += textContainerOrigin.y
            lineRect.size.width = bounds.width

            currentTheme.currentLineHighlight.setFill()
            NSBezierPath(rect: lineRect).fill()
        }

        // Draw Smart Highlighting (Aynı Metinleri / Kelimeleri Vurgula)
        if !smartHighlightRanges.isEmpty {
            let isDark = currentTheme.isDark
            // Odaktaki/seçili birincil kelime (canlı zümrüt yeşili ve belirgin kenarlık)
            let primaryFill = isDark
                ? NSColor(calibratedRed: 0.12, green: 0.72, blue: 0.28, alpha: 0.90)
                : NSColor(calibratedRed: 0.18, green: 0.90, blue: 0.35, alpha: 0.95)
            let primaryStroke = isDark
                ? NSColor(calibratedRed: 0.35, green: 1.0, blue: 0.50, alpha: 1.0)
                : NSColor(calibratedRed: 0.0, green: 0.55, blue: 0.16, alpha: 1.0)

            // Metindeki diğer eşleşen kelimeler (daha yumuşak nane yeşili ve ince kenarlık)
            let secondaryFill = isDark
                ? NSColor(calibratedRed: 0.10, green: 0.45, blue: 0.20, alpha: 0.60)
                : NSColor(calibratedRed: 0.65, green: 0.96, blue: 0.72, alpha: 0.65)
            let secondaryStroke = isDark
                ? NSColor(calibratedRed: 0.20, green: 0.70, blue: 0.32, alpha: 0.75)
                : NSColor(calibratedRed: 0.20, green: 0.75, blue: 0.35, alpha: 0.80)

            for range in smartHighlightRanges {
                guard NSMaxRange(range) <= ns.length else { continue }
                let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                guard glyphRange.location != NSNotFound else { continue }

                let isPrimary = (range == smartHighlightPrimaryRange)
                let fillColor = isPrimary ? primaryFill : secondaryFill
                let strokeColor = isPrimary ? primaryStroke : secondaryStroke
                let lineWidth: CGFloat = isPrimary ? 1.5 : 1.0

                layoutManager.enumerateEnclosingRects(
                    forGlyphRange: glyphRange,
                    withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                    in: textContainer
                ) { enclosingRect, _ in
                    let drawRect = NSRect(
                        x: enclosingRect.origin.x + self.textContainerOrigin.x,
                        y: enclosingRect.origin.y + self.textContainerOrigin.y,
                        width: enclosingRect.width,
                        height: enclosingRect.height
                    ).insetBy(dx: -1.0, dy: -0.5)

                    let path = NSBezierPath(roundedRect: drawRect, xRadius: 2.5, yRadius: 2.5)
                    fillColor.setFill()
                    path.fill()
                    strokeColor.setStroke()
                    path.lineWidth = lineWidth
                    path.stroke()
                }
            }
        }
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw vivid vertical cursor bars for all multi-carets when in Multi-Cursor mode
        guard isMultiCaret,
              let layoutManager = self.layoutManager,
              let textContainer = self.textContainer else { return }

        let ns = self.textContents
        let defaultHeight = (self.font?.pointSize ?? 13) * 1.35

        for caretOffset in allCarets {
            let clamped = max(0, min(caretOffset, ns.length))
            var caretRect: NSRect

            if ns.length == 0 || layoutManager.numberOfGlyphs == 0 {
                caretRect = NSRect(x: textContainerOrigin.x, y: textContainerOrigin.y, width: 2.5, height: defaultHeight)
            } else if clamped < ns.length {
                let glyphIdx = layoutManager.glyphIndexForCharacter(at: clamped)
                let bRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIdx, length: 1), in: textContainer)
                caretRect = NSRect(
                    x: bRect.minX + textContainerOrigin.x,
                    y: bRect.minY + textContainerOrigin.y,
                    width: 2.5,
                    height: max(15, bRect.height)
                )
            } else {
                // At end of string
                let lastCharIdx = max(0, ns.length - 1)
                if ns.character(at: lastCharIdx) == 10 {
                    let extraRect = layoutManager.extraLineFragmentRect
                    caretRect = NSRect(
                        x: textContainerOrigin.x,
                        y: extraRect.minY + textContainerOrigin.y,
                        width: 2.5,
                        height: max(15, extraRect.height > 0 ? extraRect.height : defaultHeight)
                    )
                } else {
                    let glyphIdx = layoutManager.glyphIndexForCharacter(at: lastCharIdx)
                    let bRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIdx, length: 1), in: textContainer)
                    caretRect = NSRect(
                        x: bRect.maxX + textContainerOrigin.x,
                        y: bRect.minY + textContainerOrigin.y,
                        width: 2.5,
                        height: max(15, bRect.height)
                    )
                }
            }

            NSColor.systemOrange.setFill()
            NSBezierPath(roundedRect: caretRect, xRadius: 1, yRadius: 1).fill()
        }
    }
}

// MARK: - LayoutManager for "Show All Characters" (Spaces, Tabs, CRLF/LF Badges)
public final class InvisibleDrawingLayoutManager: NSLayoutManager {
    public var showInvisibles: Bool = false
    public var lineEndingBadge: String = "LF"
    public var baseFontSize: CGFloat = 13.0

    public override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard showInvisibles, let textStorage = self.textStorage else { return }

        let ns = textStorage.string as NSString
        guard ns.length > 0 else { return }
        let charRange = self.characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        guard charRange.location < ns.length else { return }

        // Derive font size dynamically so badges and symbols scale cleanly with zoom
        var baseSize = baseFontSize
        if let fontAttr = textStorage.attribute(.font, at: min(charRange.location, ns.length - 1), effectiveRange: nil) as? NSFont {
            baseSize = fontAttr.pointSize
        }
        if baseSize <= 0 { baseSize = 13.0 }

        let symbolSize = max(9.0, round(baseSize * 0.85))
        let symbolFont = NSFont.monospacedSystemFont(ofSize: symbolSize, weight: .bold)
        let symbolAttrs: [NSAttributedString.Key: Any] = [
            .font: symbolFont,
            .foregroundColor: NSColor.systemOrange.withAlphaComponent(0.85)
        ]

        let eolSize = max(9.0, round(baseSize * 0.72))
        let eolFont = NSFont.monospacedSystemFont(ofSize: eolSize, weight: .bold)
        let eolAttrs: [NSAttributedString.Key: Any] = [
            .font: eolFont,
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.systemGray.withAlphaComponent(0.8)
        ]

        let endChar = min(NSMaxRange(charRange), ns.length)
        for charIdx in charRange.location..<endChar {
            let ch = ns.character(at: charIdx)
            if ch == 32 {
                let glyphIdx = self.glyphIndexForCharacter(at: charIdx)
                guard let container = self.textContainer(forGlyphAt: glyphIdx, effectiveRange: nil) else { continue }
                let glyphRect = self.boundingRect(forGlyphRange: NSRange(location: glyphIdx, length: 1), in: container)
                let lineRect = self.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
                let symStr = "·" as NSString
                let symSize = symStr.size(withAttributes: symbolAttrs)
                let symX = glyphRect.midX + origin.x - symSize.width / 2
                let symY = lineRect.midY + origin.y - symSize.height / 2
                symStr.draw(at: NSPoint(x: symX, y: symY), withAttributes: symbolAttrs)
            } else if ch == 9 {
                let glyphIdx = self.glyphIndexForCharacter(at: charIdx)
                guard let container = self.textContainer(forGlyphAt: glyphIdx, effectiveRange: nil) else { continue }
                let glyphRect = self.boundingRect(forGlyphRange: NSRange(location: glyphIdx, length: 1), in: container)
                let lineRect = self.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
                let tabStr = "→" as NSString
                let tabSize = tabStr.size(withAttributes: symbolAttrs)
                let tabX = glyphRect.minX + origin.x + 2
                let tabY = lineRect.midY + origin.y - tabSize.height / 2
                tabStr.draw(at: NSPoint(x: tabX, y: tabY), withAttributes: symbolAttrs)
            } else if ch == 10 {
                let glyphIdx = self.glyphIndexForCharacter(at: charIdx)
                guard self.textContainer(forGlyphAt: glyphIdx, effectiveRange: nil) != nil else { continue }
                let lineRect = self.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
                let usedRect = self.lineFragmentUsedRect(forGlyphAt: glyphIdx, effectiveRange: nil)
                let badgeLabel = (charIdx > 0 && ns.character(at: charIdx - 1) == 13) ? "CRLF" : lineEndingBadge
                let badgeStr = " \(badgeLabel) " as NSString
                let badgeSize = badgeStr.size(withAttributes: eolAttrs)
                let badgeX = usedRect.maxX + origin.x + max(4, round(baseSize * 0.25))
                let badgeY = lineRect.midY + origin.y - badgeSize.height / 2
                badgeStr.draw(at: NSPoint(x: badgeX, y: badgeY), withAttributes: eolAttrs)
            } else if ch == 13 {
                if charIdx + 1 >= ns.length || ns.character(at: charIdx + 1) != 10 {
                    let glyphIdx = self.glyphIndexForCharacter(at: charIdx)
                    guard self.textContainer(forGlyphAt: glyphIdx, effectiveRange: nil) != nil else { continue }
                    let lineRect = self.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
                    let usedRect = self.lineFragmentUsedRect(forGlyphAt: glyphIdx, effectiveRange: nil)
                    let badgeStr = " CR " as NSString
                    let badgeSize = badgeStr.size(withAttributes: eolAttrs)
                    let badgeX = usedRect.maxX + origin.x + max(4, round(baseSize * 0.25))
                    let badgeY = lineRect.midY + origin.y - badgeSize.height / 2
                    badgeStr.draw(at: NSPoint(x: badgeX, y: badgeY), withAttributes: eolAttrs)
                }
            }
        }
    }
}

// MARK: - Editor Container View (Gutter on Left, Clean ScrollView on Right)
public final class EditorContainerView: NSView {
    public let gutterView: LineNumberBookmarkGutterView
    public let scrollView: NonOverlappingEditorScrollView
    public var showLineNumbers: Bool = true {
        didSet {
            needsLayout = true
            updateChildFrames()
        }
    }

    public override var isFlipped: Bool { true }

    public init(gutterView: LineNumberBookmarkGutterView, scrollView: NonOverlappingEditorScrollView) {
        self.gutterView = gutterView
        self.scrollView = scrollView
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        addSubview(gutterView)
        addSubview(scrollView)
        updateChildFrames()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layout() {
        super.layout()
        updateChildFrames()
    }

    public override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        updateChildFrames()
    }

    public func updateChildFrames() {
        let gutterW: CGFloat = showLineNumbers ? 56 : 0
        let totalW = bounds.width
        let totalH = bounds.height
        gutterView.frame = NSRect(x: 0, y: 0, width: gutterW, height: totalH)
        gutterView.isHidden = !showLineNumbers
        scrollView.frame = NSRect(x: gutterW, y: 0, width: max(0, totalW - gutterW), height: totalH)
    }
}

// MARK: - Line Numbers + Clickable Bookmark Gutter View
public final class LineNumberBookmarkGutterView: NSView {
    public weak var textView: NSTextView?
    public var theme: EditorTheme = .nppClassicLight
    public var bookmarks: Set<Int> = []
    public var currentLine: Int = 1
    public var onToggleBookmark: ((Int) -> Void)?

    private var lineYMap: [(line: Int, minY: CGFloat, maxY: CGFloat)] = []

    private var cachedStringLength: Int = -1
    private var cachedLineStarts: [Int] = [0]
    private var checkpoints: [(charOffset: Int, lineNum: Int)] = [(0, 1)]

    private func resetLineIndex(for ns: NSString) {
        if cachedStringLength == ns.length { return }
        cachedStringLength = ns.length
        cachedLineStarts = [0]
        checkpoints = [(0, 1)]

        // Precompute full line-starts index only for files under 200 KB
        if ns.length <= 200_000 {
            var starts = [0]
            let len = ns.length
            for i in 0..<len {
                if ns.character(at: i) == 10 {
                    starts.append(i + 1)
                }
            }
            cachedLineStarts = starts
        }
    }

    public func lineNumber(forCharacterIndex index: Int, in ns: NSString) -> Int {
        resetLineIndex(for: ns)
        let clamped = max(0, min(index, ns.length))
        if clamped == 0 { return 1 }

        if ns.length <= 200_000 {
            var low = 0
            var high = cachedLineStarts.count - 1
            var ans = 0
            while low <= high {
                let mid = (low + high) / 2
                if cachedLineStarts[mid] <= clamped {
                    ans = mid
                    low = mid + 1
                } else {
                    high = mid - 1
                }
            }
            return ans + 1
        }

        // Fast sparse checkpoint lookup for large files (10MB - 1GB)
        var bestIdx = 0
        for (i, cp) in checkpoints.enumerated() {
            if cp.charOffset <= clamped {
                bestIdx = i
            } else {
                break
            }
        }
        var currentOffset = checkpoints[bestIdx].charOffset
        var currentLine = checkpoints[bestIdx].lineNum

        var buf = [UniChar](repeating: 0, count: 4096)
        while currentOffset < clamped {
            let nextScanEnd = min(clamped, currentOffset + 50_000)
            while currentOffset < nextScanEnd {
                let chunkSize = min(4096, nextScanEnd - currentOffset)
                ns.getCharacters(&buf, range: NSRange(location: currentOffset, length: chunkSize))
                for i in 0..<chunkSize {
                    if buf[i] == 10 {
                        currentLine += 1
                    }
                }
                currentOffset += chunkSize
            }
            if currentOffset % 50_000 == 0 && (checkpoints.last?.charOffset ?? 0) < currentOffset {
                checkpoints.append((currentOffset, currentLine))
            }
        }
        return currentLine
    }

    public override var isFlipped: Bool { true }

    public init(textView: NSTextView? = nil) {
        self.textView = textView
        super.init(frame: NSRect(x: 0, y: 0, width: 56, height: 600))
        self.wantsLayer = true
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        theme.gutterBackground.setFill()
        bounds.fill()

        NSColor.separatorColor.setStroke()
        let border = NSBezierPath()
        border.move(to: NSPoint(x: bounds.width - 0.5, y: bounds.minY))
        border.line(to: NSPoint(x: bounds.width - 0.5, y: bounds.maxY))
        border.lineWidth = 1.0
        border.stroke()

        guard let textView = self.textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let ns = textView.textContents

        var lineNum = lineNumber(forCharacterIndex: charRange.location, in: ns)

        lineYMap.removeAll()

        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let activeFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)

        var charIndex = charRange.location
        let maxCharIndex = NSMaxRange(charRange)

        while charIndex <= maxCharIndex {
            let lineCharRange = ns.lineRange(for: NSRange(location: min(charIndex, ns.length), length: 0))
            let lineGlyphRange = layoutManager.glyphRange(forCharacterRange: lineCharRange, actualCharacterRange: nil)
            var lineRect: NSRect
            if ns.length == 0 || layoutManager.numberOfGlyphs == 0 || lineGlyphRange.location >= layoutManager.numberOfGlyphs {
                if layoutManager.extraLineFragmentTextContainer != nil {
                    lineRect = layoutManager.extraLineFragmentRect
                } else {
                    lineRect = NSRect(x: 0, y: 0, width: bounds.width, height: 17)
                }
            } else {
                lineRect = layoutManager.lineFragmentRect(
                    forGlyphAt: lineGlyphRange.location,
                    effectiveRange: nil
                )
            }

            let yPos = lineRect.origin.y + textView.textContainerOrigin.y - visibleRect.origin.y
            let rowHeight = max(16, lineRect.height)
            lineYMap.append((line: lineNum, minY: yPos, maxY: yPos + rowHeight))

            if bookmarks.contains(lineNum) {
                let circleRect = NSRect(x: 5, y: yPos + (rowHeight - 11) / 2, width: 11, height: 11)
                let path = NSBezierPath(ovalIn: circleRect)
                NSColor.systemCyan.setFill()
                path.fill()
                NSColor.systemBlue.setStroke()
                path.lineWidth = 1.2
                path.stroke()
            }

            let isCurrent = (lineNum == currentLine)
            let label = "\(lineNum)" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: isCurrent ? activeFont : font,
                .foregroundColor: isCurrent ? theme.editorText : theme.gutterText
            ]
            let size = label.size(withAttributes: attrs)
            let drawPoint = NSPoint(
                x: bounds.width - size.width - 7,
                y: yPos + (rowHeight - size.height) / 2
            )
            label.draw(at: drawPoint, withAttributes: attrs)

            if charIndex == ns.length { break }
            let nextIndex = NSMaxRange(lineCharRange)
            if nextIndex <= charIndex { break }
            charIndex = nextIndex
            lineNum += 1
        }
    }

    public override func mouseDown(with event: NSEvent) {
        let localPoint = self.convert(event.locationInWindow, from: nil)
        if let hit = lineYMap.first(where: { localPoint.y >= $0.minY && localPoint.y <= $0.maxY }) {
            onToggleBookmark?(hit.line)
            needsDisplay = true
        }
    }

    public override func scrollWheel(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) || flags.contains(.command) {
            if let tv = textView as? MacNoteTextView {
                tv.scrollWheel(with: event)
                return
            }
        }
        if let sv = textView?.enclosingScrollView {
            sv.scrollWheel(with: event)
            return
        }
        super.scrollWheel(with: event)
    }

    public override func magnify(with event: NSEvent) {
        if let tv = textView as? MacNoteTextView {
            tv.magnify(with: event)
            return
        }
        super.magnify(with: event)
    }
}

public typealias LineNumberBookmarkRulerView = LineNumberBookmarkGutterView
