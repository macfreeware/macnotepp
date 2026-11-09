import AppKit
import PDFKit
import SwiftUI

public struct PrintPreviewSheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage: Int = 1
    @State private var pages: [[(Int, String)]] = [[]]
    @State private var zoomScale: Double = 0.85

    public init(appState: AppState) {
        self.appState = appState
    }

    private var document: EditorDocument? {
        appState.activeDocument
    }

    private let a4Width = PrintLayout.pageWidth
    private let a4Height = PrintLayout.pageHeight
    private let margin = PrintLayout.margin

    private var printFontSize: Double { appState.printSettings.fontSize }
    private var showLineNumbers: Bool { appState.printSettings.showLineNumbers }
    private var showHeaderFooter: Bool { appState.printSettings.showHeaderFooter }

    private var isTooLarge: Bool {
        !PrintLayout.canPrint(document?.content ?? "")
    }

    /// Laying out the pages walks the whole text, so it happens only when something changed.
    private func updatePages() {
        guard let content = document?.content, !isTooLarge else {
            pages = [[]]
            return
        }
        pages = PrintLayout.pages(for: content, settings: appState.printSettings)
        currentPage = min(currentPage, max(1, pages.count))
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
                        Slider(value: $appState.printSettings.fontSize, in: 7.0...15.0, step: 0.5)
                    }

                    Divider()

                    // Toggles
                    Toggle(appState.loc("Satır Numaralarını Yazdır", "Print Line Numbers"), isOn: $appState.printSettings.showLineNumbers)
                        .font(.system(size: 11))

                    Toggle(appState.loc("Üstbilgi & Altbilgi (Tarih, Başlık, Sayfa)", "Header & Footer (Date, Title, Page)"), isOn: $appState.printSettings.showHeaderFooter)
                        .font(.system(size: 11))

                    Toggle(appState.loc("Sözcük Kaydırma (Word Wrap)", "Word Wrap"), isOn: $appState.printSettings.wordWrap)
                        .font(.system(size: 11))

                    if isTooLarge {
                        Text(appState.loc("Bu belge yazdırmak için çok büyük (en fazla 20 MB).", "This document is too large to print (20 MB at most)."))
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

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
                    .disabled(isTooLarge)

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
                    .disabled(isTooLarge)
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
        .onAppear(perform: updatePages)
        .onChange(of: appState.printSettings) { _, _ in updatePages() }
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
        panel.nameFieldStringValue = "\(doc.displayTitle).pdf"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            guard let data = PrintLayout.makePDF(title: doc.displayTitle, content: doc.content, settings: appState.printSettings) else { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: url, options: .atomic)
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = appState.loc("PDF kaydedilemedi", "Could not save the PDF")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
