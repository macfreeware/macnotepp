import SwiftUI

public struct NPPStatusBarView: View {
    @ObservedObject var appState: AppState

    public var body: some View {
        let _ = appState.languageRefreshTrigger
        let doc = appState.activeDocument

        HStack(spacing: 0) {
            // 1. Language Picker (Far Left)
            Menu {
                ForEach(SyntaxLanguage.allCases) { lang in
                    Button {
                        if var d = appState.activeDocument {
                            d.language = lang
                            d.isLanguageManuallySet = true
                            appState.activeDocument = d
                            appState.saveSession()
                        }
                    } label: {
                        HStack {
                            if doc?.language == lang {
                                Image(systemName: "checkmark")
                            }
                            Text("\(lang.rawValue)  —  \(lang.statusDescription)")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10))
                    Text(doc?.language.statusDescription ?? "Normal text file")
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
            }
            .menuStyle(.borderlessButton)
            .focusable(false)
            .fixedSize()
            .help(appState.loc("Sözdizimi Renklendirme Dilini Değiştir", "Change Syntax Highlighting Language"))

            Spacer()

            if appState.isRecordingMacro {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                    Text(appState.loc("MAKRO KAYDEDİLİYOR (\(appState.currentRecordedActions.count) adım)", "RECORDING MACRO (\(appState.currentRecordedActions.count) steps)"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 8)
                StatusDivider()
            }

            // 2. Document Length & Line Count
            Button {
                appState.showSummarySheet = true
            } label: {
                Text("length : \(doc?.byteLength ?? 0)    lines : \(doc?.totalLines ?? 1)")
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)
            .help(appState.loc("Belge Özeti ve İstatistikler için tıklayın", "Click for Document Summary & Statistics"))

            StatusDivider()

            // 3. Cursor Line, Column & Selection
            Button {
                appState.showGoToLineSheet = true
            } label: {
                let ln = doc?.cursorLine ?? 1
                let col = doc?.cursorColumn ?? 1
                let selLen = doc?.selectionLength ?? 0
                let selLines = doc?.selectedLineCount ?? 0
                Text("Ln : \(ln)    Col : \(col)    Sel : \(selLen) | \(selLines)")
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)
            .help(appState.loc("Satıra / Ofsete Git (⌘G)", "Go to Line / Offset (⌘G)"))

            StatusDivider()

            // 4. Line Ending (EOL) Switcher
            Menu {
                ForEach(LineEndingType.allCases) { eol in
                    Button {
                        if var d = appState.activeDocument {
                            d.lineEnding = eol
                            d.isModified = true
                            appState.activeDocument = d
                            appState.saveSession()
                        }
                    } label: {
                        HStack {
                            if doc?.lineEnding == eol {
                                Image(systemName: "checkmark")
                            }
                            Text(eol.rawValue)
                        }
                    }
                }
            } label: {
                Text(doc?.lineEnding.rawValue ?? "Unix (LF)")
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.horizontal, 8)
            }
            .menuStyle(.borderlessButton)
            .focusable(false)
            .fixedSize()
            .help(appState.loc("Satır Sonu Biçimini (EOL) Dönüştür", "Convert Line Ending Format (EOL)"))

            StatusDivider()

            // 5. Encoding Switcher
            Menu {
                ForEach(TextEncodingOption.allCases) { enc in
                    Button {
                        if var d = appState.activeDocument {
                            d.encoding = enc
                            d.isModified = true
                            appState.activeDocument = d
                            appState.saveSession()
                        }
                    } label: {
                        HStack {
                            if doc?.encoding == enc {
                                Image(systemName: "checkmark")
                            }
                            Text(enc.title(for: appState.language))
                        }
                    }
                }
            } label: {
                Text(doc?.encoding.title(for: appState.language) ?? "UTF-8")
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.horizontal, 8)
            }
            .menuStyle(.borderlessButton)
            .focusable(false)
            .fixedSize()
            .help(appState.loc("Karakter Kodlamasını (Encoding) Değiştir", "Change Character Encoding"))

            StatusDivider()

            // 6. Mode Indicator (INS / HEX / DIFF)
            Button {
                appState.toggleHexView()
            } label: {
                let badgeText: String = {
                    if appState.isCompareMode { return "DIFF" }
                    if doc?.viewMode == .hex { return "HEX" }
                    return "INS"
                }()
                Text(badgeText)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(doc?.viewMode == .hex ? Color.purple : (appState.isCompareMode ? Color.orange : Color.primary))
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)
            .help(appState.loc("Metin / Hex Görünümü Geçişi", "Toggle Text / Hex View"))

            // 7. Read-Only Indicator (RO)
            if doc?.isReadOnly == true {
                StatusDivider()
                Button {
                    appState.toggleReadOnly()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                        Text("RO")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(Color.orange)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                .help(appState.loc("Salt Okunur (Read-Only) — Kilidi değiştirmek için tıklayın", "Read-Only — Click to toggle lock"))
            }
        }
        .frame(height: 23)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct StatusDivider: View {
    var body: some View {
        Divider()
            .frame(height: 15)
    }
}
