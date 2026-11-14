import AppKit

/// Where this copy of MacNote++ really lives.
///
/// A downloaded app keeps the quarantine mark until Finder moves it. If it was copied some other
/// way (another file manager, Terminal, an unzip in place), macOS runs it from a hidden, read-only
/// copy (App Translocation). That copy cannot update itself, and file associations point at a path
/// that changes on every launch. The real app stays where the user put it.
enum AppLocation {
    static var isTranslocated: Bool {
        Bundle.main.bundlePath.contains("/AppTranslocation/")
    }

    /// The app the user installed: the original of a translocated copy, otherwise this one.
    static var installedBundleURL: URL {
        guard isTranslocated else { return Bundle.main.bundleURL }
        return originalURL(ofTranslocated: Bundle.main.bundleURL) ?? Bundle.main.bundleURL
    }

    static var isInApplicationsFolder: Bool {
        let folder = installedBundleURL.deletingLastPathComponent().path
        return folder == "/Applications" || folder == NSHomeDirectory() + "/Applications"
    }

    /// The real path behind a translocated one, from the Security framework. The function is
    /// public in the framework but not in its headers, so it is looked up at run time.
    private static func originalURL(ofTranslocated url: URL) -> URL? {
        typealias Original = @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?
        guard let handle = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY),
              let symbol = dlsym(handle, "SecTranslocateCreateOriginalPathForURL") else { return nil }
        let original = unsafeBitCast(symbol, to: Original.self)
        guard let result = original(url as CFURL, nil)?.takeRetainedValue() as URL? else { return nil }
        return result.path.contains("/AppTranslocation/") ? nil : result
    }

    /// Clears the quarantine mark on the installed app only, so the next launch runs it from
    /// where it is. The user asks for this with a button; it is never done on its own.
    static func clearQuarantineOfInstalledApp() -> Bool {
        let app = installedBundleURL
        guard isTranslocated, app != Bundle.main.bundleURL, app.pathExtension == "app",
              Bundle(url: app)?.bundleIdentifier == Bundle.main.bundleIdentifier else { return false }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        p.arguments = ["-dr", "com.apple.quarantine", app.path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    static var noticeText: String {
        UpdateChecker.loc(
            "macOS, MacNote++'ı karantina işareti yüzünden geçici bir kopyadan çalıştırıyor. Bu kopya kendini güncelleyemez ve dosya ilişkilendirmeleri kalıcı olmaz. Düzeltmek için işareti kaldırıp uygulamayı \(installedBundleURL.deletingLastPathComponent().path) klasöründen yeniden açın.",
            "macOS is running MacNote++ from a temporary copy because of the quarantine mark. That copy cannot update itself, and file associations will not last. To fix it, clear the mark and reopen the app from \(installedBundleURL.deletingLastPathComponent().path)."
        )
    }
}
