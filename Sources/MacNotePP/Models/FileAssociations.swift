import AppKit
import UniformTypeIdentifiers

/// One row of the File Types settings: file extensions that open together.
public struct FileAssociation: Identifiable {
    public let id: String
    let turkishTitle: String
    let englishTitle: String
    public let extensions: [String]

    init(_ turkish: String, _ english: String, _ extensions: [String]) {
        id = english
        turkishTitle = turkish
        englishTitle = english
        self.extensions = extensions
    }

    public func title(for language: AppLanguage) -> String {
        language.resolvedLanguage == .turkish ? turkishTitle : englishTitle
    }

    public var extensionList: String {
        extensions.map { "." + $0 }.joined(separator: " ")
    }

    /// The system's types for these extensions, without duplicates. An extension no app has
    /// declared yields a throwaway dynamic type, which cannot be given a default app.
    public var contentTypes: [UTType] {
        var seen = Set<String>()
        return extensions.compactMap { UTType(filenameExtension: $0) }
            .filter { !$0.isDynamic && seen.insert($0.identifier).inserted }
    }
}

public struct FileAssociationGroup: Identifiable {
    public let id: String
    let turkishTitle: String
    let englishTitle: String
    public let associations: [FileAssociation]

    public func title(for language: AppLanguage) -> String {
        language.resolvedLanguage == .turkish ? turkishTitle : englishTitle
    }

    // `.ts` is left out on purpose: macOS assigns it to MPEG video, which must not open here.
    public static let all: [FileAssociationGroup] = [
        FileAssociationGroup(id: "text", turkishTitle: "Metin", englishTitle: "Text", associations: [
            FileAssociation("Düz metin", "Plain text", ["txt", "text"]),
            FileAssociation("Günlük", "Log", ["log"]),
            FileAssociation("Markdown", "Markdown", ["md", "markdown"]),
            FileAssociation("CSV ve TSV", "CSV and TSV", ["csv", "tsv"])
        ]),
        FileAssociationGroup(id: "code", turkishTitle: "Kaynak kod", englishTitle: "Source code", associations: [
            FileAssociation("C / C++ / Objective-C", "C / C++ / Objective-C", ["c", "h", "cpp", "cc", "cxx", "hpp", "hh", "ino", "m", "mm"]),
            FileAssociation("Pascal / Delphi", "Pascal / Delphi", ["pas", "pp", "dpr", "dpk", "dfm", "inc"]),
            FileAssociation("SQL", "SQL", ["sql", "ddl", "dml", "pgsql", "tsql"]),
            FileAssociation("Python", "Python", ["py"]),
            FileAssociation("JavaScript", "JavaScript", ["js", "mjs", "jsx", "tsx"]),
            FileAssociation("Swift", "Swift", ["swift"]),
            FileAssociation("Java / Kotlin", "Java / Kotlin", ["java", "kt"]),
            FileAssociation("C#", "C#", ["cs"]),
            FileAssociation("PHP", "PHP", ["php"]),
            FileAssociation("Ruby", "Ruby", ["rb"]),
            FileAssociation("Go", "Go", ["go"]),
            FileAssociation("Rust", "Rust", ["rs"]),
            FileAssociation("Lua", "Lua", ["lua"]),
            FileAssociation("Assembly", "Assembly", ["asm", "s"])
        ]),
        FileAssociationGroup(id: "scripts", turkishTitle: "Betik", englishTitle: "Scripts", associations: [
            FileAssociation("Shell", "Shell", ["sh", "bash", "zsh"]),
            FileAssociation("Batch / PowerShell", "Batch / PowerShell", ["bat", "cmd", "ps1"])
        ]),
        FileAssociationGroup(id: "web", turkishTitle: "Web ve veri", englishTitle: "Web and data", associations: [
            FileAssociation("HTML", "HTML", ["html", "htm", "xhtml"]),
            FileAssociation("CSS", "CSS", ["css", "scss", "sass", "less"]),
            FileAssociation("JSON", "JSON", ["json"]),
            FileAssociation("XML", "XML", ["xml"]),
            FileAssociation("YAML", "YAML", ["yaml", "yml"]),
            FileAssociation("INI ve yapılandırma", "INI and config", ["ini", "cfg", "conf", "toml", "env"])
        ])
    ]
}

/// Makes MacNote++ the default app for file types, and can put the earlier apps back.
/// Nothing happens here unless the user asks for it in Settings. macOS shows its own
/// confirmation for every single type and offers no way around it.
@MainActor
public final class FileAssociationsModel: ObservableObject {
    private static let previousHandlersKey = "MacNotePP.previousFileHandlers"

    @Published public private(set) var revision = 0
    @Published public private(set) var isWorking = false
    @Published public private(set) var failure: String?

    private let workspace = NSWorkspace.shared

    public init() {}

    /// Copies that run from a download or a build folder make poor default apps.
    public var isInstalledInApplications: Bool {
        let path = Bundle.main.bundleURL.deletingLastPathComponent().path
        return path == "/Applications" || path == NSHomeDirectory() + "/Applications"
    }

    private func isThisApp(_ url: URL?) -> Bool {
        guard let url else { return false }
        return Bundle(url: url)?.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    public func isDefault(_ association: FileAssociation) -> Bool {
        let types = association.contentTypes
        return !types.isEmpty && types.allSatisfy { isThisApp(workspace.urlForApplication(toOpen: $0)) }
    }

    /// Who opens these files now, in words.
    public func currentHandlerName(_ association: FileAssociation, language: AppLanguage) -> String {
        let names = Set(association.contentTypes.compactMap { type -> String? in
            guard let url = workspace.urlForApplication(toOpen: type) else { return nil }
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        })
        if names.count > 1 {
            return language.resolvedLanguage == .turkish ? "Karışık" : "Mixed"
        }
        return names.first ?? "—"
    }

    private var previousHandlers: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: Self.previousHandlersKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: Self.previousHandlersKey) }
    }

    public var canRestore: Bool { !previousHandlers.isEmpty }

    private func run(_ work: () async throws -> Void) async {
        isWorking = true
        failure = nil
        do {
            try await work()
        } catch where Self.isUserCancellation(error) {
            // "Keep" in the macOS confirmation also ends the remaining questions of a batch.
        } catch {
            failure = error.localizedDescription
        }
        isWorking = false
        refresh()
    }

    private static func isUserCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        return nsError.code == userCanceledErr || underlying?.code == userCanceledErr
    }

    /// The answer to a confirmation can arrive after the call returns, so views also ask again later.
    public func refresh() {
        revision += 1
    }

    private var allTypes: [UTType] {
        var seen = Set<String>()
        return FileAssociationGroup.all.flatMap(\.associations).flatMap(\.contentTypes)
            .filter { seen.insert($0.identifier).inserted }
    }

    /// How many confirmations "Select All" would cause.
    public var typesNotYetDefault: Int {
        allTypes.filter { !isThisApp(workspace.urlForApplication(toOpen: $0)) }.count
    }

    /// How many confirmations "Restore" would cause.
    public var typesAlreadyDefault: Int {
        allTypes.filter { isThisApp(workspace.urlForApplication(toOpen: $0)) }.count
    }

    func takeOver(_ types: [UTType]) async throws {
        for type in types {
            let current = workspace.urlForApplication(toOpen: type)
            if let current, !isThisApp(current), previousHandlers[type.identifier] == nil {
                previousHandlers[type.identifier] = current.path
            }
            try await workspace.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: type)
        }
    }

    /// Gives types back to the app that had them, or else to another app that can open them.
    func giveBack(_ types: [UTType]) async throws {
        let fileManager = FileManager.default
        for type in types where isThisApp(workspace.urlForApplication(toOpen: type)) {
            let saved = previousHandlers[type.identifier].map { URL(fileURLWithPath: $0) }
            let other = workspace.urlsForApplications(toOpen: type).first { !isThisApp($0) }
            let target = saved.flatMap { fileManager.fileExists(atPath: $0.path) ? $0 : nil } ?? other
            if let target {
                try await workspace.setDefaultApplication(at: target, toOpen: type)
            }
            previousHandlers[type.identifier] = nil
        }
    }

    public func setDefault(_ association: FileAssociation, enabled: Bool) async {
        await run {
            if enabled {
                try await takeOver(association.contentTypes)
            } else {
                try await giveBack(association.contentTypes)
            }
        }
    }

    public func selectAll() async {
        let types = allTypes.filter { !isThisApp(workspace.urlForApplication(toOpen: $0)) }
        await run { try await takeOver(types) }
    }

    public func restoreAll() async {
        let types = allTypes
        await run { try await giveBack(types) }
    }
}
