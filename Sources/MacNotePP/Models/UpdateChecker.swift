import Foundation

/// Asks GitLab for the latest MacNote++ release. The project path is used rather than its id,
/// so the address survives the repository being recreated. While the repository is private
/// GitLab answers "not found": the automatic check stays silent, the manual one says so.
enum UpdateChecker {
    struct Release: Identifiable, Sendable {
        var id: String { version }
        let version: String
        /// The release notes as published, in both languages.
        let notes: String
        let url: URL
        /// `MacNotePP.zip` and its SHA-256 file; missing on releases older than the updater.
        let archive: URL?
        let checksum: URL?
    }

    enum Outcome {
        case newer(Release), upToDate(String), failed(String)
    }

    static let archiveName = "MacNotePP.zip"
    static let checksumName = "MacNotePP.zip.sha256"
    static let repositoryURL = URL(string: "https://gitlab.com/freeware2/macnotepp")!

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static var apiURL: URL {
        #if DEBUG
        if let text = ProcessInfo.processInfo.environment["MACNOTEPP_UPDATE_URL"], let url = URL(string: text) { return url }
        #endif
        return URL(string: "https://gitlab.com/api/v4/projects/freeware2%2Fmacnotepp/releases/permalink/latest")!
    }

    static func check() async -> Outcome {
        var request = URLRequest(url: apiURL, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                return .failed(failureText(forHTTP: http.statusCode))
            }
            let release = try parse(data)
            let mine = currentVersion
            return isNewer(release.version, than: mine) ? .newer(release) : .upToDate(mine)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    static func failureText(forHTTP code: Int) -> String {
        switch code {
        case 404:
            return loc("Sürüm bilgisine ulaşılamadı. Depo henüz herkese açık değilse bu beklenen bir durumdur.",
                       "Release information could not be found. This is expected while the repository is not public yet.")
        case 429:
            return loc("GitLab şu an çok fazla istek aldığı için yanıt vermedi. Bir saat içinde yeniden deneyin.",
                       "GitLab is receiving too many requests right now. Try again within an hour.")
        default:
            return loc("GitLab yanıtı: HTTP \(code)", "GitLab response: HTTP \(code)")
        }
    }

    static func parse(_ data: Data) throws -> Release {
        struct Payload: Decodable {
            let tag_name: String
            let description: String?
            let _links: Links?
            let assets: Assets?
            struct Links: Decodable { let `self`: String? }
            struct Assets: Decodable { let links: [Link]? }
            struct Link: Decodable { let name: String; let url: String; let direct_asset_url: String? }
        }
        let p = try JSONDecoder().decode(Payload.self, from: data)
        let version = p.tag_name.hasPrefix("v") ? String(p.tag_name.dropFirst()) : p.tag_name
        func asset(_ name: String) -> URL? {
            guard let link = p.assets?.links?.first(where: { $0.name == name }) else { return nil }
            return trusted(URL(string: link.direct_asset_url ?? link.url))
        }
        return Release(version: version, notes: p.description ?? "",
                       url: trusted(p._links?.`self`.flatMap(URL.init(string:)))
                           ?? repositoryURL.appendingPathComponent("-/releases/\(p.tag_name)"),
                       archive: asset(archiveName), checksum: asset(checksumName))
    }

    /// Only https://gitlab.com is opened or downloaded from, whatever the release says.
    static func trusted(_ url: URL?) -> URL? {
        guard let url else { return nil }
        if url.scheme?.lowercased() == "https", url.host?.lowercased() == "gitlab.com" { return url }
        #if DEBUG
        if url.isFileURL { return url }
        #endif
        return nil
    }

    /// Numeric comparison of dotted versions: 1.10 > 1.9, 1.2.1 > 1.2.
    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
        let y = b.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    /// The digest in `shasum -a 256` output ("abc…  MacNotePP.zip"), lowercased.
    static func parseChecksum(_ text: String) -> String? {
        guard let first = text.split(whereSeparator: \.isWhitespace).first else { return nil }
        let hex = first.lowercased()
        return hex.count == 64 && hex.allSatisfy(\.isHexDigit) ? hex : nil
    }

    /// Whether the app can be swapped where it is: a writable .app in a writable folder. Not so for
    /// a copy run straight from a download (App Translocation) or installed by another user.
    static func canReplace(app: URL, fileManager: FileManager = .default) -> Bool {
        app.pathExtension == "app"
            && fileManager.isWritableFile(atPath: app.path)
            && fileManager.isWritableFile(atPath: app.deletingLastPathComponent().path)
    }

    /// The "what's new" part of the notes in the interface language, as plain text;
    /// the whole notes if they have no such heading.
    static func whatsNew(in notes: String) -> String {
        let lines = notes.components(separatedBy: .newlines)
        let start = lines.firstIndex {
            $0.hasPrefix("#") && $0.localizedCaseInsensitiveContains(isTurkish ? "yenilikler" : "what's new")
        }
        guard let start else { return notes }
        let rest = lines[(start + 1)...]
        let end = rest.firstIndex { $0.hasPrefix("#") || $0.hasPrefix("---") } ?? rest.endIndex
        return rest[..<end].joined(separator: "\n")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The interface language, read directly so this also works away from the main actor.
    static var isTurkish: Bool {
        let saved = UserDefaults.standard.string(forKey: "MacNotePP.appLanguage").flatMap(AppLanguage.init(rawValue:))
        return (saved ?? .system).resolvedLanguage == .turkish
    }

    static func loc(_ turkish: String, _ english: String) -> String {
        isTurkish ? turkish : english
    }
}
