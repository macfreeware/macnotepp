import AppKit

/// The choices in Print Preview. They apply to PDF export and to printing alike.
public struct PrintSettings: Codable, Equatable {
    public var fontSize: Double = 9.5
    public var showLineNumbers: Bool = true
    public var showHeaderFooter: Bool = true
    public var wordWrap: Bool = true
}

/// Lays a document out on A4 pages, for the preview, the PDF and the printer.
public enum PrintLayout {
    public static let pageWidth: CGFloat = 595
    public static let pageHeight: CGFloat = 842
    public static let margin: CGFloat = 40

    /// Pagination walks the whole text, and larger documents would run to thousands of pages.
    public static let maximumTextBytes = 20 * 1024 * 1024

    public static func canPrint(_ content: String) -> Bool {
        content.utf8.count <= maximumTextBytes
    }

    public static func linesPerPage(_ settings: PrintSettings) -> Int {
        let contentHeight = pageHeight - (margin * 2) - (settings.showHeaderFooter ? 44 : 0)
        return max(15, Int(contentHeight / (CGFloat(settings.fontSize) * 1.35)))
    }

    /// Each page is a list of (line number, text); a continued wrapped line has number 0.
    public static func pages(for content: String, settings: PrintSettings) -> [[(Int, String)]] {
        var wrapped: [(Int, String)] = []
        let textWidth = pageWidth - margin * 2 - (settings.showLineNumbers ? 40 : 0)
        let charsPerLine = max(40, Int(textWidth / (CGFloat(settings.fontSize) * 0.6)))

        for (index, line) in content.components(separatedBy: "\n").enumerated() {
            let lineNumber = index + 1
            guard settings.wordWrap, line.count > charsPerLine else {
                wrapped.append((lineNumber, line))
                continue
            }
            var remaining = Substring(line)
            var isFirst = true
            while !remaining.isEmpty {
                wrapped.append((isFirst ? lineNumber : 0, String(remaining.prefix(charsPerLine))))
                remaining = remaining.dropFirst(charsPerLine)
                isFirst = false
            }
        }

        let perPage = linesPerPage(settings)
        var result = stride(from: 0, to: wrapped.count, by: perPage).map {
            Array(wrapped[$0..<min($0 + perPage, wrapped.count)])
        }
        if result.isEmpty { result = [[]] }
        return result
    }

    public static func makePDF(title: String, content: String, settings: PrintSettings) -> Data? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        let font = NSFont.monospacedSystemFont(ofSize: CGFloat(settings.fontSize), weight: .regular)
        let numberFont = NSFont.monospacedSystemFont(ofSize: CGFloat(settings.fontSize) - 1.5, weight: .regular)
        let headerFont = NSFont.boldSystemFont(ofSize: 8)
        let footerFont = NSFont.systemFont(ofSize: 7.5)
        let lineHeight = CGFloat(settings.fontSize) * 1.35
        let date = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        let allPages = pages(for: content, settings: settings)

        for (pageIndex, lines) in allPages.enumerated() {
            context.beginPage(mediaBox: &mediaBox)

            // PDF pages grow upwards. The drawing below measures from the top of the page, and
            // `flipped: true` only tells AppKit about the flip, so the context has to be flipped too.
            context.saveGState()
            context.translateBy(x: 0, y: pageHeight)
            context.scaleBy(x: 1, y: -1)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)

            if settings.showHeaderFooter {
                (title as NSString).draw(
                    at: CGPoint(x: margin, y: margin - 15),
                    withAttributes: [.font: headerFont, .foregroundColor: NSColor.black]
                )
                (date as NSString).draw(
                    at: CGPoint(x: pageWidth - margin - 80, y: margin - 15),
                    withAttributes: [.font: footerFont, .foregroundColor: NSColor.gray]
                )
                NSColor.gray.withAlphaComponent(0.4).setFill()
                NSRect(x: margin, y: margin - 3, width: pageWidth - margin * 2, height: 0.5).fill()
            }

            let startY = margin + (settings.showHeaderFooter ? 10 : 0)
            let textX = margin + (settings.showLineNumbers ? 32 : 0)
            for (index, item) in lines.enumerated() {
                let y = startY + CGFloat(index) * lineHeight
                if settings.showLineNumbers && item.0 > 0 {
                    (String(item.0) as NSString).draw(
                        at: CGPoint(x: margin, y: y),
                        withAttributes: [.font: numberFont, .foregroundColor: NSColor.gray]
                    )
                }
                (item.1 as NSString).draw(
                    at: CGPoint(x: textX, y: y),
                    withAttributes: [.font: font, .foregroundColor: NSColor.black]
                )
            }

            if settings.showHeaderFooter {
                let footerY = pageHeight - margin + 6
                NSColor.gray.withAlphaComponent(0.4).setFill()
                NSRect(x: margin, y: pageHeight - margin, width: pageWidth - margin * 2, height: 0.5).fill()
                ("MacNote++" as NSString).draw(
                    at: CGPoint(x: margin, y: footerY),
                    withAttributes: [.font: footerFont, .foregroundColor: NSColor.gray]
                )
                ("\(pageIndex + 1) / \(allPages.count)" as NSString).draw(
                    at: CGPoint(x: pageWidth - margin - 40, y: footerY),
                    withAttributes: [.font: footerFont, .foregroundColor: NSColor.gray]
                )
            }

            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
            context.endPage()
        }

        context.closePDF()
        return data as Data
    }
}
