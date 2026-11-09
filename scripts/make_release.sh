#!/bin/bash
# Sürüm dosyalarını hazırlar: evrensel (arm64 + x86_64) uygulama, build/release/MacNotePP.zip ve özeti
# build/release/MacNotePP.zip.sha256. Uygulamanın kendi kendini güncellemesi bu iki sabit adı arar (bkz. Updater.swift).
#
#   scripts/make_release.sh                       # yalnızca dosyaları hazırlar
#   scripts/make_release.sh --publish notlar.md   # ayrıca GitLab'da v<sürüm> sürümünü oluşturur (glab ile)
#
# Sürüm numarası build_app.sh içindeki CFBundleShortVersionString'den gelir; önce onu yükseltip commit'leyin.
# Notlar dosyasında "## What's new" ve "## Yenilikler" başlıkları olmalı; güncelleme penceresi yalnızca bunları gösterir.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="MacNote++.app"
OUT="build/release"
PB=/usr/libexec/PlistBuddy

UNIVERSAL=1 ./build_app.sh release
VERSION=$("$PB" -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")

rm -rf "$OUT"
mkdir -p "$OUT/MacNote++"
# Zip bir klasör içerir: uygulama ve GPL lisans metni. Updater.swift bu düzeni arar.
cp -R "$APP" "$OUT/MacNote++/"
cp LICENSE "$OUT/MacNote++/LICENSE.txt"
# --norsrc --noextattr: macOS'un com.apple.provenance özniteliği zip'e "._" dosyaları olarak girmesin.
ditto -c -k --norsrc --noextattr --keepParent "$OUT/MacNote++" "$OUT/MacNotePP.zip"
rm -rf "$OUT/MacNote++"
(cd "$OUT" && shasum -a 256 MacNotePP.zip > MacNotePP.zip.sha256)

# Denetim: güncelleyicinin bakacağı yerde, imzalı ve doğru sürümde bir uygulama var mı?
CHECK=$(mktemp -d)
trap 'rm -rf "$CHECK"' EXIT
ditto -x -k "$OUT/MacNotePP.zip" "$CHECK"
UNPACKED="$CHECK/MacNote++/MacNote++.app"
codesign --verify --deep --strict "$UNPACKED"
[[ "$("$PB" -c "Print :CFBundleShortVersionString" "$UNPACKED/Contents/Info.plist")" == "$VERSION" ]]
[[ -f "$CHECK/MacNote++/LICENSE.txt" ]]

ARCHS=$(lipo -archs "$UNPACKED/Contents/MacOS/MacNotePP")
if [[ "$ARCHS" != *arm64* || "$ARCHS" != *x86_64* ]]; then
  echo "✘ Uygulama evrensel değil: $ARCHS" >&2
  exit 1
fi

# Ad-hoc imzalı sürüm yayımlanmasın: kullanıcıların Gizlilik izinleri güncellemeyle kaybolur.
# Denetimler çıktıyı önce değişkene alır: pipefail altında grep -q erken çıkınca sol taraf SIGPIPE ile başarısız sayılır.
SIGNATURE=$(codesign -dvv "$UNPACKED" 2>&1)
if ! grep -q "^Authority=freeware2 Code Signing$" <<<"$SIGNATURE"; then
  echo "✘ Uygulama freeware2 sertifikasıyla imzalı değil" >&2
  exit 1
fi

LISTING=$(unzip -l "$OUT/MacNotePP.zip")
if grep -q '/\._\|__MACOSX' <<<"$LISTING"; then
  echo "✘ Zip'te ._ dosyaları var" >&2
  exit 1
fi

# Deneme ayarları (yalnızca DEBUG) yayımlanan ikilide olmamalı.
BINARY_STRINGS=$(strings "$UNPACKED/Contents/MacOS/MacNotePP")
if grep -q "MACNOTEPP_UPDATE_" <<<"$BINARY_STRINGS"; then
  echo "✘ Yayım ikilisinde deneme ayarı var" >&2
  exit 1
fi

echo "✔ $OUT/MacNotePP.zip ($VERSION, $ARCHS)"
cat "$OUT/MacNotePP.zip.sha256"

if [[ "${1:-}" == "--publish" ]]; then
  NOTES="${2:?Notlar dosyası gerekli: scripts/make_release.sh --publish notlar.md}"
  glab release create "v$VERSION" \
    "$OUT/MacNotePP.zip#MacNotePP.zip" \
    "$OUT/MacNotePP.zip.sha256#MacNotePP.zip.sha256" \
    --ref main --name "MacNote++ $VERSION" --notes-file "$NOTES"
fi
