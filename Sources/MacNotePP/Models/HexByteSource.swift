import Foundation

/// Reads a file through a small cache of pages, so a file of any size can be shown in hex.
public final class HexFilePager {
    public let url: URL
    public let size: Int
    private let modificationDate: Date?
    private let handle: FileHandle?

    private static let pageSize = 1 << 20
    private static let maximumPages = 16
    private var pages: [Int: [UInt8]] = [:]
    private var recentPages: [Int] = []

    private init(url: URL, size: Int, modificationDate: Date?) {
        self.url = url
        self.size = size
        self.modificationDate = modificationDate
        self.handle = try? FileHandle(forReadingFrom: url)
    }

    deinit {
        try? handle?.close()
    }

    private static var latest: HexFilePager?

    /// The views ask for the pager on every update; the same file keeps the same cache.
    public static func pager(for url: URL, size: Int, modificationDate: Date?) -> HexFilePager {
        if let latest, latest.url == url, latest.size == size, latest.modificationDate == modificationDate {
            return latest
        }
        let created = HexFilePager(url: url, size: size, modificationDate: modificationDate)
        latest = created
        return created
    }

    private func page(_ index: Int) -> [UInt8] {
        if let cached = pages[index] { return cached }
        var loaded: [UInt8] = []
        if let handle {
            try? handle.seek(toOffset: UInt64(index * Self.pageSize))
            if let data = try? handle.read(upToCount: Self.pageSize) { loaded = [UInt8](data) }
        }
        pages[index] = loaded
        recentPages.append(index)
        if recentPages.count > Self.maximumPages {
            pages[recentPages.removeFirst()] = nil
        }
        return loaded
    }

    public func byte(at offset: Int) -> UInt8 {
        let content = page(offset / Self.pageSize)
        let position = offset % Self.pageSize
        return position < content.count ? content[position] : 0
    }

    public func bytes(in range: Range<Int>) -> [UInt8] {
        var result: [UInt8] = []
        result.reserveCapacity(range.count)
        var offset = range.lowerBound
        while offset < range.upperBound {
            let content = page(offset / Self.pageSize)
            let position = offset % Self.pageSize
            guard position < content.count else { break }
            let length = min(content.count - position, range.upperBound - offset)
            result.append(contentsOf: content[position..<position + length])
            offset += length
        }
        return result
    }
}

/// The bytes the hex editor works on: held in memory, or paged from a file too large to hold.
public struct HexByteSource {
    private enum Storage {
        case memory(Data)
        case file(HexFilePager)
    }

    private let storage: Storage

    public init(data: Data) {
        storage = .memory(data)
    }

    public init(pager: HexFilePager) {
        storage = .file(pager)
    }

    public var isPaged: Bool {
        if case .file = storage { return true }
        return false
    }

    public var count: Int {
        switch storage {
        case .memory(let data): return data.count
        case .file(let pager): return pager.size
        }
    }

    public var isEmpty: Bool { count == 0 }

    public subscript(offset: Int) -> UInt8 {
        switch storage {
        case .memory(let data): return data[data.startIndex + offset]
        case .file(let pager): return pager.byte(at: offset)
        }
    }

    public func bytes(in range: Range<Int>) -> [UInt8] {
        switch storage {
        case .memory(let data): return [UInt8](data[(data.startIndex + range.lowerBound)..<(data.startIndex + range.upperBound)])
        case .file(let pager): return pager.bytes(in: range)
        }
    }

    /// Start offsets of `needle`, at most `limit` of them. Runs away from the main thread and
    /// reads the file through its own handle.
    public func search(for needle: [UInt8], limit: Int) -> [Int] {
        guard !needle.isEmpty else { return [] }
        var hits: [Int] = []

        func scan(_ buffer: UnsafeRawBufferPointer, base: Int, stopBefore: Int) {
            guard let start = buffer.baseAddress, buffer.count >= needle.count else { return }
            var position = 0
            while hits.count < limit, position <= buffer.count - needle.count, !Task.isCancelled {
                guard let found = needle.withUnsafeBytes({
                    memmem(start + position, buffer.count - position, $0.baseAddress!, needle.count)
                }) else { return }
                let index = start.distance(to: UnsafeRawPointer(found))
                if base + index >= stopBefore { return }
                hits.append(base + index)
                position = index + needle.count
            }
        }

        switch storage {
        case .memory(let data):
            data.withUnsafeBytes { scan($0, base: 0, stopBefore: Int.max) }
        case .file(let pager):
            guard let handle = try? FileHandle(forReadingFrom: pager.url) else { return [] }
            defer { try? handle.close() }
            let chunkSize = 8 << 20
            var offset = 0
            while offset < pager.size, hits.count < limit, !Task.isCancelled {
                try? handle.seek(toOffset: UInt64(offset))
                guard let chunk = try? handle.read(upToCount: chunkSize + needle.count - 1), !chunk.isEmpty else { break }
                // The overlap catches matches across chunks; each is counted in the chunk it starts in.
                chunk.withUnsafeBytes { scan($0, base: offset, stopBefore: offset + chunkSize) }
                offset += chunkSize
            }
        }
        return hits
    }
}
