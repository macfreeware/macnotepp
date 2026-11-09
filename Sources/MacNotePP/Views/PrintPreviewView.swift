import AppKit
import PDFKit
import SwiftUI

public struct PrintPreviewSheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage: Int = 1
    @State private var printFontSize: Double = 9.5
    @State private var showLineNumbers: Bool = true
    @State private var showHeaderFooter: Bool = true
    @State private var isWordWrap: Bool = true
    @State private var zoomScale: Double = 0.85

    public init(appState: AppState) {
        self.appState = appState
    }

    private var document: EditorDocument? {
        appState.activeDocument
    }

    // A4 Boyutları (Points): 595.2 x 841.8 pt
    private let a4Width: CGFloat = 595.0
    private let a4Height: CGFloat = 842.0
    private let margin: CGFloat = 40.0

    // Sayfa Başına Satır Sayısı Hesabı
    private var linesPerPage: Int {
        let contentHeight = a4Height - (margin * 2) - (showHeaderFooter ? 44.0 : 0.0)
        let lineHeight = CGFloat(printFontSize) * 1.35
        return max(15, Int(contentHeight / lineHeight))
    }

    private var pages: [[(Int, String)]] {
        guard let content = document?.content else { return [] }
        let rawLines = content.components(separatedBy: "\n")
        var wrappedLines: [(Int, String)] = []

        let charsPerLine = isWordWrap ? max(40, Int((a4Width - margin * 2 - (showLineNumbers ? 40 : 0)) / (CGFloat(printFontSize) * 0.6))) : 9999

        for (idx, line) in rawLines.enumerated() {
            let lineNum = idx + 1
            if line.count <= charsPerLine || !isWordWrap {
                wrappedLines.append((lineNum, line))
            } else {
                var remaining = line
                var isFirst = true
                while !remaining.isEmpty {
                    let takeCount = min(charsPerLine, remaining.count)
                    let sub = String(remaining.prefix(takeCount))
                    remaining = String(remaining.dropFirst(takeCount))
                    wrappedLines.append((isFirst ? lineNum : 0, sub))
                    isFirst = false
                }
            }
        }

        let lpp = linesPerPage
        var result: [[(Int, String)]] = []
        var cur: [(Int, String)] = []

        for item in wrappedLines {
            cur.append(item)
            if cur.count >= lpp {
                result.append(cur)
                cur = []
            }
        }
        if !cur.isEmpty || result.isEmpty {
            result.append(cur)
        }
        return result
    }

    private var totalPages: Int {
        max(1, pages.count)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                Image(systemName: "printer.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 1) {
                    Text(appState.loc("Yazdırma Önizleme", "Print Preview"))
                        .font(.system(size: 14, weight: .bold))
                    Text("\(document?.displayTitle ?? appState.loc("Belge", "Document")) — \(totalPages) \(appState.loc("Sayfa", "Pages"))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Quick Zoom
                HStack(spacing: 4) {
                    Button {
                        zoomScale = max(0.5, zoomScale - 0.1)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .controlSize(.small)

                    Text("\(Int(zoomScale * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 40)

                    Button {
                        zoomScale = min(1.3, zoomScale + 0.1)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .controlSize(.small)
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Main Content: Controls on Left + Canvas on Right
            HStack(spacing: 0) {
                // Settings Sidebar
                VStack(alignment: .leading, spacing: 14) {
                    Text(appState.loc("SAYFA & DÜZEN", "PAGE & LAYOUT"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    // Page Navigation
                    HStack {
                        Button {
                            currentPage = max(1, currentPage - 1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(currentPage <= 1)

                        Spacer()

                        Text(appState.loc("Sayfa \(currentPage) / \(totalPages)", "Page \(currentPage) of \(totalPages)"))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))

                        Spacer()

                        Button {
                            currentPage = min(totalPages, currentPage + 1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(currentPage >= totalPages)
                    }

                    Divider()

                    // Font Size Slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(appState.loc("Yazı Boyutu:", "Font Size:"))
                                .font(.system(size: 11, weight: .medium))
                            Spacer()
                            Text("\(String(format: "%.1f", printFontSize)) pt")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        Slider(value: $printFontSize, in: 7.0...15.0, step: 0.5)
                    }

                    Divider()

                    // Toggles
                    Toggle(appState.loc("Satır Numaralarını Yazdır", "Print Line Numbers"), isOn: $showLineNumbers)
                        .font(.system(size: 11))

                    Toggle(appState.loc("Üstbilgi & Altbilgi (Tarih, Başlık, Sayfa)", "Header & Footer (Date, Title, Page)"), isOn: $showHeaderFooter)
                        .font(.system(size: 11))

                    Toggle(appState.loc("Sözcük Kaydırma (Word Wrap)", "Word Wrap"), isOn: $isWordWrap)
                        .font(.system(size: 11))

                    Spacer()

                    Divider()

                    // Action Buttons
                    Button {
                        exportToPDF()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                            Text(appState.loc("PDF Olarak Dışa Aktar...", "Export to PDF..."))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .controlSize(.regular)

                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            appState.printDocumentDirectly()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "printer.fill")
                            Text(appState.loc("Yazdır... (⌘P)", "Print... (⌘P)"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .frame(width: 230)
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))

                Divider()

                // Paper Canvas (Centered in Gray Background)
                ScrollView([.horizontal, .vertical]) {
                    VStack {
                        paperSheetView(forPage: min(currentPage, totalPages))
                            .scaleEffect(zoomScale)
                            .frame(width: a4Width * zoomScale, height: a4Height * zoomScale)
                            .padding(24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(Color.secondary.opacity(0.15))
            }
        }
        .frame(width: 860, height: 680)
    }

    // A4 Paper Canvas View
    @ViewBuilder
    private func paperSheetView(forPage pageIdx: Int) -> some View {
        let linesOnPage: [(Int, String)] = {
            let actual = pageIdx - 1
            if actual >= 0 && actual < pages.count {
                return pages[actual]
            }
            return []
        }()

        let docTitle = document?.displayTitle ?? "MacNote++ Belgesi"
        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)

        VStack(alignment: .leading, spacing: 0) {
            // Header
            if showHeaderFooter {
                HStack {
                    Text(docTitle)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.black)
                    Spacer()
                    Text(dateString)
                        .font(.system(size: 7.5))
                        .foregroundStyle(.gray)
                }
                .padding(.bottom, 4)

                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(height: 0.5)
                    .padding(.bottom, 8)
            }

            // Code Lines Body
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(linesOnPage.enumerated()), id: \.offset) { _, item in
                    let (lineNum, text) = item
                    HStack(alignment: .top, spacing: 6) {
                        if showLineNumbers {
                            Text(lineNum > 0 ? "\(lineNum)" : " ")
                                .font(.system(size: CGFloat(printFontSize) - 1.5, design: .monospaced))
                                .foregroundStyle(Color.gray.opacity(0.8))
                                .frame(width: 26, alignment: .trailing)

                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 0.5)
                        }

                        Text(text.isEmpty ? " " : text)
                            .font(.system(size: CGFloat(printFontSize), design: .monospaced))
                            .foregroundStyle(Color.black)

                        Spacer(minLength: 0)
                    }
                    .frame(height: CGFloat(printFontSize) * 1.35, alignment: .leading)
                }
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            // Footer
            if showHeaderFooter {
                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(height: 0.5)
                    .padding(.bottom, 4)

                HStack {
                    Text("MacNote++")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(appState.loc("Sayfa \(pageIdx) / \(totalPages)", "Page \(pageIdx) of \(totalPages)"))
                        .font(.system(size: 7.5))
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding(margin)
        .frame(width: a4Width, height: a4Height)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
    }

    private func exportToPDF() {
        guard let doc = document else { return }
        let panel = NSSavePanel()
        panel.title = appState.loc("PDF Olarak Kaydet — MacNote++", "Save as PDF — MacNote++")
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(doc.title).pdf"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return }

        var mediaBox = CGRect(x: 0, y: 0, width: a4Width, height: a4Height)
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }

        let font = NSFont.monospacedSystemFont(ofSize: CGFloat(printFontSize), weight: .regular)
        let numFont = NSFont.monospacedSystemFont(ofSize: CGFloat(printFontSize) - 1.5, weight: .regular)
        let headerFont = NSFont.boldSystemFont(ofSize: 8)
        let footerFont = NSFont.systemFont(ofSize: 7.5)

        for (pageIdx, linesOnPage) in pages.enumerated() {
            pdfContext.beginPage(mediaBox: &mediaBox)

            let pageNum = pageIdx + 1
            let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)

            // Flipped context for Cocoa text drawing
            let graphicsContext = NSGraphicsContext(cgContext: pdfContext, flipped: true)
            NSGraphicsContext.current = graphicsContext

            // Header
            if showHeaderFooter {
                (doc.displayTitle as NSString).draw(
                    at: CGPoint(x: margin, y: margin - 15),
                    withAttributes: [.font: headerFont, .foregroundColor: NSColor.black]
                )
                (dateStr as NSString).draw(
                    at: CGPoint(x: a4Width - margin - 80, y: margin - 15),
                    withAttributes: [.font: footerFont, .foregroundColor: NSColor.gray]
                )
                NSColor.gray.withAlphaComponent(0.4).setFill()
                NSRect(x: margin, y: margin - 3, width: a4Width - (margin * 2), height: 0.5).fill()
            }

            // Body Lines
            let startY = margin + (showHeaderFooter ? 10 : 0)
            let lineHeight = CGFloat(printFontSize) * 1.35

            for (idx, item) in linesOnPage.enumerated() {
                let (lineNum, text) = item
                let y = startY + (CGFloat(idx) * lineHeight)

                if showLineNumbers && lineNum > 0 {
                    (String(lineNum) as NSString).draw(
                        at: CGPoint(x: margin, y: y),
                        withAttributes: [.font: numFont, .foregroundColor: NSColor.gray]
                    )
                }

                let textX = margin + (showLineNumbers ? 32 : 0)
                (text as NSString).draw(
                    at: CGPoint(x: textX, y: y),
                    withAttributes: [.font: font, .foregroundColor: NSColor.black]
                )
            }

            // Footer
            if showHeaderFooter {
                let footerY = a4Height - margin + 6
                NSColor.gray.withAlphaComponent(0.4).setFill()
                NSRect(x: margin, y: a4Height - margin, width: a4Width - (margin * 2), height: 0.5).fill()

                ("MacNote++" as NSString).draw(
                    at: CGPoint(x: margin, y: footerY),
                    withAttributes: [.font: footerFont, .foregroundColor: NSColor.gray]
                )
                let pageStr = "\(pageNum) / \(totalPages)" as NSString
                pageStr.draw(
                    at: CGPoint(x: a4Width - margin - 40, y: footerY),
                    withAttributes: [.font: footerFont, .foregroundColor: NSColor.gray]
                )
            }

            pdfContext.endPage()
        }

        pdfContext.closePDF()
        try? (pdfData as Data).write(to: url, options: .atomic)
    }
}
