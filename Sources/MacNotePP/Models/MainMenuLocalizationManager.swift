import AppKit
import Foundation

@MainActor
public final class MainMenuLocalizationManager: NSObject, NSMenuDelegate {
    public static let shared = MainMenuLocalizationManager()

    public private(set) var currentLanguage: AppLanguage = .system

    /// Çift yönlü çeviri haritası (Türkçe <-> İngilizce)
    private let translationPairs: [(tr: String, en: String)] = [
        // System menus and encoding names
        ("Dosya", "File"),
        ("Düzen", "Edit"),
        ("Görünüm", "View"),
        ("Pencere", "Window"),
        ("Yardım", "Help"),
        ("Gizle: MacNote++", "Hide MacNote++"),
        ("MacNote++ Gizle", "Hide MacNote++"),
        ("Diğerlerini Gizle", "Hide Others"),
        ("Tümünü Göster", "Show All"),
        ("Servisler", "Services"),
        ("Kes", "Cut"),
        ("Kopyala", "Copy"),
        ("Yapıştır", "Paste"),
        ("Tümünü Seç", "Select All"),
        ("Yazma Araçları", "Writing Tools"),
        ("Yazma Araçları’nı Göster", "Show Writing Tools"),
        ("Yazım Hatalarını Denetle", "Proofread"),
        ("Yeniden Yaz", "Rewrite"),
        ("Samimi Yap", "Make Friendly"),
        ("Profesyonel Yap", "Make Professional"),
        ("Kısa ve Öz Yap", "Make Concise"),
        ("Özetle", "Summarize"),
        ("Önemli Noktalar Yarat", "Create Key Points"),
        ("Liste Oluştur", "Make List"),
        ("Tablo Oluştur", "Make Table"),
        ("Oluştur…", "Compose…"),
        ("Otomatik Doldur", "AutoFill"),
        ("Kişiler…", "Contacts…"),
        ("Parolalar…", "Passwords…"),
        ("Kredi Kartı…", "Credit Card…"),
        ("Dikte’yi Başlat…", "Start Dictation…"),
        ("Emoji ve Semboller", "Emoji & Symbols"),
        ("Simge Durumuna Küçült", "Minimize"),
        ("Büyüt/Küçült", "Zoom"),
        ("Tümünü Öne Getir", "Bring All to Front"),
        ("Tam Ekrana Geç", "Enter Full Screen"),
        ("Tam Ekrandan Çık", "Exit Full Screen"),
        ("Windows-1254 (Türkçe)", "Windows-1254 (Turkish)"),
        ("ISO-8859-9 (Türkçe)", "ISO-8859-9 (Turkish)"),

        // Generated from the titles in MainMenuCommands.swift
        ("MacNote++ Hakkında", "About MacNote++"),
        ("Güncellemeleri Denetle...", "Check for Updates..."),
        ("Ayarlar...", "Settings..."),
        ("MacNote++ Uygulamasından Çık", "Quit MacNote++"),
        ("Yeni Sekme", "New Tab"),
        ("Aç...", "Open..."),
        ("Klasör Aç...", "Open Folder..."),
        ("Kaydet", "Save"),
        ("Farklı Kaydet...", "Save As..."),
        ("Tümünü Kaydet", "Save All"),
        ("Diskten Yeniden Yükle", "Reload from Disk"),
        ("Baskı Önizleme...", "Print Preview..."),
        ("Yazdır...", "Print..."),
        ("Sekmeyi Kapat", "Close Tab"),
        ("Değişmemiş Sekmeleri Kapat", "Close Unmodified Tabs"),
        ("Sekmeyi Sola Taşı", "Move Tab Left"),
        ("Sekmeyi Sağa Taşı", "Move Tab Right"),
        ("Geri Al", "Undo"),
        ("Yinele", "Redo"),
        ("Satır", "Line"),
        ("Çoğalt", "Duplicate"),
        ("Sil", "Delete"),
        ("Yukarı Taşı", "Move Up"),
        ("Aşağı Taşı", "Move Down"),
        ("Harf Durumu", "Change Case"),
        ("Çoklu İmleç", "Multiple Cursors"),
        ("Üste İmleç Ekle", "Add Cursor Above"),
        ("Alta İmleç Ekle", "Add Cursor Below"),
        ("Satır Sonlarına İmleç Koy", "Add Cursors to Line Ends"),
        ("Satır Başlarına İmleç Koy", "Add Cursors to Line Starts"),
        ("Tek İmlece Dön", "Single Cursor"),
        ("Sütun Düzenleyici...", "Column Editor..."),
        ("Yorum Yap / Kaldır", "Toggle Comment"),
        ("Tarih ve Saat Ekle", "Insert Date and Time"),
        ("Salt Okunur", "Read-Only"),
        ("Sözcük Kaydırma", "Word Wrap"),
        ("Görünmez Karakterler", "Invisible Characters"),
        ("Satır Numaraları", "Line Numbers"),
        ("Yakınlaştır", "Zoom In"),
        ("Uzaklaştır", "Zoom Out"),
        ("Gerçek Boyut", "Actual Size"),
        ("Klasör Paneli", "Folder Panel"),
        ("Fonksiyon Listesi", "Function List"),
        ("Kod Haritası", "Minimap"),
        ("Arama Sonuçları", "Search Results"),
        ("Hex Görünümü", "Hex View"),
        ("Markdown Önizleme", "Markdown Preview"),
        ("Markdown Düzeni", "Markdown Layout"),
        ("Tema", "Theme"),
        ("Araç Çubuğu", "Toolbar"),
        ("Çok Satırlı", "Multiple Rows"),
        ("Özelleştir", "Customize"),
        ("Her Zaman Üstte", "Always on Top"),
        ("Bul", "Find"),
        ("Bul...", "Find..."),
        ("Değiştir...", "Replace..."),
        ("Dosyalarda Bul...", "Find in Files..."),
        ("İşaretle...", "Mark..."),
        ("Sonrakini Bul", "Find Next"),
        ("Satıra Git...", "Go to Line..."),
        ("Yer İmleri", "Bookmarks"),
        ("Yer İmi Koy / Kaldır", "Toggle Bookmark"),
        ("Sonraki Yer İmi", "Next Bookmark"),
        ("Önceki Yer İmi", "Previous Bookmark"),
        ("İmli Satırları Kopyala", "Copy Bookmarked Lines"),
        ("İmli Satırları Kes", "Cut Bookmarked Lines"),
        ("İmli Satırları Sil", "Delete Bookmarked Lines"),
        ("İmsiz Satırları Sil", "Delete Unbookmarked Lines"),
        ("Yer İmlerini Tersine Çevir", "Invert Bookmarks"),
        ("Tüm Yer İmlerini Temizle", "Clear All Bookmarks"),
        ("Biçim", "Format"),
        ("Dil", "Language"),
        ("Kodlama", "Encoding"),
        ("Satır Sonu", "Line Endings"),
        ("Araçlar", "Tools"),
        ("Karşılaştır", "Compare"),
        ("Biçimlendir", "Pretty Print"),
        ("Sıkıştır", "Minify"),
        ("SQL Biçimlendir", "Format SQL"),
        ("Kodla", "Encode"),
        ("Çöz", "Decode"),
        ("Özeti Kopyala", "Copy Hash"),
        ("Makro", "Macro"),
        ("Kayıt", "Record"),
        ("Oynat", "Play"),
        ("Çok Kez Oynat...", "Play Multiple Times..."),
        ("Belge Bilgisi...", "Document Info..."),
        ("Klavye Kısayolları", "Keyboard Shortcuts"),
        ("MacNote++ Web Sayfası", "MacNote++ Website")
    ]

    /// Tüm LineOperationType çevirilerini dinamik ekle
    private var allLineOpPairs: [(tr: String, en: String)] {
        LineOperationType.allCases.map {
            ($0.title(for: .turkish), $0.title(for: .english))
        } + CaseConversionType.allCases.map {
            ($0.title(for: .turkish), $0.title(for: .english))
        } + EditorTheme.allCases.map {
            ($0.title(for: .turkish), $0.title(for: .english))
        } + MarkdownDisplayMode.allCases.map {
            ($0.title(for: .turkish), $0.title(for: .english))
        }
    }

    private var isObservingMenuChanges = false
    private var isSyncScheduled = false

    /// SwiftUI writes the system menu titles back whenever it rebuilds the menu bar, so every
    /// menu change is followed by another pass. Titles that are already right are left alone,
    /// so a pass that finds nothing to do causes no further changes.
    private func observeMenuChanges() {
        guard !isObservingMenuChanges else { return }
        isObservingMenuChanges = true
        for name in [NSMenu.didAddItemNotification, NSMenu.didChangeItemNotification, NSMenu.didRemoveItemNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleSync() }
            }
        }
    }

    private func scheduleSync() {
        guard !isSyncScheduled else { return }
        isSyncScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isSyncScheduled = false
            self.syncMenu(to: self.currentLanguage)
        }
    }

    private func setTitle(_ title: String, of item: NSMenuItem) {
        if item.title != title { item.title = title }
        if let submenu = item.submenu, submenu.title != title { submenu.title = title }
    }

    public func syncMenu(to language: AppLanguage) {
        self.currentLanguage = language
        observeMenuChanges()
        guard let mainMenu = NSApp.mainMenu else { return }
        mainMenu.delegate = self
        let isTr = (language.resolvedLanguage == .turkish)

        var map: [String: String] = [:]
        for pair in translationPairs + allLineOpPairs {
            if isTr {
                map[pair.en] = pair.tr
            } else {
                map[pair.tr] = pair.en
            }
        }

        // The system's own menus go by position, whatever language macOS gave them.
        let positional = isTr ? ["Dosya", "Düzen", "Görünüm"] : ["File", "Edit", "View"]
        for (offset, title) in positional.enumerated() where mainMenu.items.count > offset + 1 {
            setTitle(title, of: mainMenu.items[offset + 1])
        }

        // Recursively translate all items in all menus
        for item in mainMenu.items {
            translateMenuItem(item, map: map)
            if let sub = item.submenu {
                sub.delegate = self
                translateMenu(sub, map: map)
            }
        }
    }

    public func menuWillOpen(_ menu: NSMenu) {
        syncMenu(to: currentLanguage)
    }

    private func translateMenu(_ menu: NSMenu, map: [String: String]) {
        for item in menu.items {
            translateMenuItem(item, map: map)
            if let sub = item.submenu {
                translateMenu(sub, map: map)
            }
        }
    }

    private func translateMenuItem(_ item: NSMenuItem, map: [String: String]) {
        let currentTitle = item.title.trimmingCharacters(in: .whitespaces)
        if let target = map[currentTitle] {
            setTitle(target, of: item)
        }
    }
}
