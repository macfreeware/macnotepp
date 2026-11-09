# MacNote++

macOS için yerel (**Swift / AppKit + SwiftUI**), gelişmiş metin ve kaynak kod editörü.

## Öne Çıkan Özellikler

1. **Otomatik Sözdizimi Renklendirme (22 Dil)**:
   - Dosya uzantısına ve ilk satır içeriğine göre otomatik algılama:
     - **Pascal / Delphi** (`.pas`, `.dpr`, `.dpk`, `.inc`, `.pp`, `.dfm`)
     - **C / C++** (`.c`, `.cpp`, `.h`, `.hpp`, `.cc`, `.ino`)
     - **SQL** (`.sql`, `.ddl`, `.dml`, `.pgsql`, `.tsql`)
     - **Python**, **JavaScript / TypeScript**, **HTML / XML**, **CSS / SCSS**, **JSON**, **YAML**, **Markdown**, **Bash / Shell**, **Swift**, **Rust**, **Go**, **Java**, **C#**, **PHP**, **INI / Config**, **Assembly (ASM)**, **Batch / PowerShell**, **Log** dosyaları.
2. **Yan Yana Dosya Karşılaştırma (Compare / Diff View — `⇧⌘D`)**:
   - Açık herhangi iki sekmeyi satır ve karakter farklarıyla yan yana karşılaştırma
   - `+Eklendi`, `-Silindi`, `~Değişti`, `=Aynı` özet sayaçları ve sağ dikey **Diff Haritası (NavBar)**
   - **İlk / Önceki / Sonraki / Son Fark** gezintisi, boşluk ve büyük/küçük harf yoksayma seçenekleri
3. **Hex Görünümü ve Düzenleyici (Hex View — `⇧⌘H`)**:
   - Her satırda 16 byte Hexadecimal (`00..0F`) + `ASCII` görünümü + Ofset sütunu
   - Doğrudan byte düzenleme (Hex veya ASCII olarak), byte ekleme/silme, Hex/ASCII arama, ofsete gitme
   - Sağ panelde canlı **Veri Denetçisi (Data Inspector)**: `Binary (8-bit)`, `Octal`, `Int8`, `UInt8`, `Int16 (LE/BE)`, `UInt16 (LE/BE)`, `Int32 (LE/BE)`, `UInt32 (LE/BE)`, `Float32`
   - Seçimi veya dosyayı **Hex Dizisi**, **C `uint8_t` Dizisi** veya **Pascal `Byte` Dizisi** olarak kopyalama
4. **Oturumu Koruma**:
   - Açık sekmeler ve oturum bilgileri korunur; uygulama açıldığında kaldığınız yerden devam eder. Kaydedilmemiş değişiklikler beklenmedik kapanmalarda ve güncellemelerde de geri gelir; çıkışta **Kaydetme** seçerseniz silinir.
5. **Gelişmiş Bul / Değiştir / Dosyalarda Bul / İşaretle (`⌘F`, `⌘R`, `⇧⌘F`, `⇧⌘M`)**:
   - **Normal**, **Genişletilmiş (`\n`, `\r`, `\t`, `\0`)** ve **Düzenli İfade (Regex)** arama modları
   - **Aktif Belgede Tümünü Bul**, **Açık Tüm Belgelerde Bul**, **Klasördeki Dosyalarda Bul (Find in Files)** ve tıklanabilir **Alt Arama Sonuçları Paneli (Find result)**
   - **İşaretle (Mark All)**: Eşleşen tüm kelimeleri renklendirme ve bulunan satırlara otomatik yer imi (Bookmark) koyma
6. **Satır İşlemleri, Harf Dönüştürme ve Sütun Düzenleyici (`⌥C`)**:
   - Alfabetik (A-Z / Z-A), Sayısal (0-9 / 9-0), Uzunluğa Göre Sıralama, Ters Çevirme, Rastgele Karıştırma
   - Tekrarlayan satırları (tüm belgede veya ardışık) silme, boş satırları temizleme, Trim (baş/son boşluk silme), TAB ↔ Boşluk dönüşümü
   - **Sütun / Çoklu Satır Düzenleyici (`⌥C`)**: Belirtilen sütuna metin veya otomatik artan sayı dizisi (`Decimal`, `Hex`, `Octal`, `Binary`, başına sıfır eklemeli) ekleme + `⌥ (Option) + Fare Sürükleme` ile dikdörtgen blok seçimi
7. **Yer İmleri (Bookmarks — `⌘B` veya Satır Numarası Sütununa Tıklama)**:
   - Yer imli satırlar arasında gezinti, yer imli satırları kopyalama/kesme/silme, yer imi olmayan satırları silme, yer imlerini tersine çevirme
8. **Karakter Kodlaması & Satır Sonu (EOL) Dönüştürücü**:
   - `UTF-8`, `UTF-8-BOM`, `UTF-16 LE`, `UTF-16 BE`, `Windows-1254 (Türkçe)`, `ISO-8859-9 (Türkçe)`, `Windows-1252 (ANSI)`, `ASCII`
   - `Unix (LF)`, `Windows (CR LF)`, `Macintosh (CR)` geçişi
9. **Fonksiyon Listesi, Belge Haritası, ASCII Tablosu ve Makro Kayıt/Oynatma**:
   - Sağ panelde Pascal `procedure/function/class`, C/C++ fonksiyonları, SQL `CREATE TABLE/PROCEDURE` vb. yapıların otomatik listesi

## Çalıştırma ve Derleme

Derlemek ve çalıştırmak için:

```bash
./build_app.sh
open "MacNote++.app"
```

## Güncelleme

MacNote++ günde en fazla bir kez `gitlab.com` üzerinden yeni sürüm olup olmadığına bakar; yeni sürüm varsa kurmadan önce sorar. Bu denetim Ayarlar'dan kapatılabilir; **Hakkında** penceresinden ve Yardım menüsünden elle de yapılabilir. Denetim sırasında sürüm bilgisi dışında hiçbir veri gönderilmez.

Sürüm dosyaları `scripts/make_release.sh` ile hazırlanır. GitLab sürümünde `MacNotePP.zip` ve `MacNotePP.zip.sha256` dosyaları tam bu adlarla bulunmalıdır; zip içinde `MacNote++/MacNote++.app` olmalıdır.
