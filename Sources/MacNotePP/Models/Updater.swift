import AppKit
import CryptoKit

/// Installs a release over the running app: downloads `MacNotePP.zip`, checks it against
/// `MacNotePP.zip.sha256`, checks the app inside, swaps it in and relaunches. MacNote++ is not
/// notarized, so the signature only shows that the app is intact, not who built it.
enum Updater {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// On return the new app is in place; the old one keeps running until `relaunch()`.
    static func install(_ release: UpdateChecker.Release) async throws {
        guard let archive = release.archive, let checksum = release.checksum else {
            throw Failure(message: UpdateChecker.loc("Bu sürümde \(UpdateChecker.archiveName) ya da özet dosyası yok.",
                                                     "This release has no \(UpdateChecker.archiveName) or checksum file."))
        }
        let current = Bundle.main.bundleURL
        guard UpdateChecker.canReplace(app: current) else {
            throw Failure(message: UpdateChecker.loc("Bu kopya bulunduğu yerde güncellenemiyor (yazma izni yok).",
                                                     "This copy cannot be updated where it is (no write permission)."))
        }
        let (checksumFile, checksumResponse) = try await URLSession.shared.data(from: checksum)
        try requireSuccess(checksumResponse)
        guard let expected = UpdateChecker.parseChecksum(String(decoding: checksumFile, as: UTF8.self)) else {
            throw Failure(message: UpdateChecker.loc("Özet dosyası okunamadı.", "The checksum file could not be read."))
        }
        let (downloaded, response) = try await URLSession.shared.download(from: archive)
        try requireSuccess(response)
        try Task.checkCancellation()

        // On the app's own volume, so the swap is a rename and cannot stop halfway.
        let fm = FileManager.default
        let work = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: current, create: true)
        defer { try? fm.removeItem(at: work) }
        let zip = work.appendingPathComponent(UpdateChecker.archiveName)
        try fm.moveItem(at: downloaded, to: zip)

        let app = try verified(zip, expected: expected, version: release.version, in: work)
        try Task.checkCancellation()
        do {
            _ = try fm.replaceItemAt(current, withItemAt: app, backupItemName: nil, options: [])
        } catch {
            let folder = current.deletingLastPathComponent().path
            throw Failure(message: UpdateChecker.loc("\(folder) klasörüne yazılamadı: \(error.localizedDescription)",
                                                     "Could not write to \(folder): \(error.localizedDescription)"))
        }
    }

    private static func requireSuccess(_ response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw Failure(message: UpdateChecker.failureText(forHTTP: http.statusCode))
        }
    }

    /// Unpacks the zip and returns the app inside it, ready to install.
    private static func verified(_ zip: URL, expected: String, version: String, in work: URL) throws -> URL {
        let digest = SHA256.hash(data: try Data(contentsOf: zip, options: .mappedIfSafe))
        guard digest.map({ String(format: "%02x", $0) }).joined() == expected else {
            throw Failure(message: UpdateChecker.loc("İndirilen dosyanın özeti tutmuyor; dosya bozuk ya da değiştirilmiş olabilir.",
                                                     "The downloaded file's checksum does not match; it may be damaged or altered."))
        }
        let unpacked = work.appendingPathComponent("unpacked", isDirectory: true)
        guard run("/usr/bin/ditto", ["-x", "-k", zip.path, unpacked.path]) else {
            throw Failure(message: UpdateChecker.loc("Arşiv açılamadı.", "The archive could not be opened."))
        }
        // The zip holds a MacNote++ folder with the app and the license text.
        let app = unpacked.appendingPathComponent("MacNote++/MacNote++.app", isDirectory: true)
        guard let bundle = Bundle(url: app), bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == version else {
            throw Failure(message: UpdateChecker.loc("Arşivdeki uygulama beklenen MacNote++ sürümü değil.",
                                                     "The app in the archive is not the expected MacNote++ version."))
        }
        guard run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path]) else {
            throw Failure(message: UpdateChecker.loc("Uygulamanın imzası doğrulanamadı.", "The app's signature could not be verified."))
        }
        // The user has just approved this update; macOS need not ask again.
        _ = run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", app.path])
        return app
    }

    private static func run(_ tool: String, _ arguments: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = arguments
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    /// Leaves a small shell job that opens the new app once this one has quit, then quits.
    /// Only call after `AppState.prepareForUpdateRestart()` said yes, or the job outlives a cancelled quit.
    @MainActor
    static func relaunch() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"",
                       Bundle.main.bundleURL.path]
        try? p.run()
        NSApp.terminate(nil)
    }

    #if DEBUG
    /// MACNOTEPP_UPDATE_TEST=1: checks and installs without a window, prints the result and
    /// exits. Runs before the app starts, so nothing appears on screen.
    static func runSelfTestIfRequested() {
        guard ProcessInfo.processInfo.environment["MACNOTEPP_UPDATE_TEST"] != nil else { return }
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            let result: String
            switch await UpdateChecker.check() {
            case .newer(let release):
                do {
                    try await install(release)
                    result = "installed \(release.version)\nwhatsNew: \(UpdateChecker.whatsNew(in: release.notes))"
                } catch {
                    result = "refused \(release.version): \(error.localizedDescription)"
                }
            case .upToDate(let version): result = "upToDate \(version)"
            case .failed(let reason): result = "failed: \(reason)"
            }
            FileHandle.standardError.write(Data("update test: \(result)\n".utf8))
            done.signal()
        }
        done.wait()
        exit(0)
    }
    #endif
}
