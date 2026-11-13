#!/bin/zsh
# MacNote++.app paketini üretir.  Kullanım: ./build_app.sh [release|debug]
# UNIVERSAL=1 ortam değişkeni ile arm64+x86_64 evrensel ikili üretilir (scripts/make_release.sh böyle çağırır).
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${1:-release}"
ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then ARCH_FLAGS=(--arch arm64 --arch x86_64); fi
APP_NAME="MacNote++"
BUNDLE_DIR="$PROJECT_DIR/${APP_NAME}.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Building ${APP_NAME}.app bundle..."
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" /tmp/swift-module-cache

cd "$PROJECT_DIR"
swift build -c "$CONFIG" --product MacNotePP $ARCH_FLAGS
BIN_DIR="$(swift build -c "$CONFIG" $ARCH_FLAGS --show-bin-path)"
cp "$BIN_DIR/MacNotePP" "$MACOS_DIR/MacNotePP"
chmod +x "$MACOS_DIR/MacNotePP"
cp "$PROJECT_DIR/LICENSE" "$RESOURCES_DIR/LICENSE"

# Generate multi-resolution AppIcon.icns using iconutil
ICONSET_DIR="/tmp/MacNotePP.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

swift -module-cache-path /tmp/swift-module-cache -e '
import AppKit

func renderIcon(size: Int, filename: String) {
    let s = CGFloat(size)
    let scale = s / 512.0
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let outerRect = NSRect(x: 28 * scale, y: 28 * scale, width: 456 * scale, height: 456 * scale)
    let squircle = NSBezierPath(roundedRect: outerRect, xRadius: 102 * scale, yRadius: 102 * scale)
    let bgGrad = NSGradient(colors: [
        NSColor(calibratedRed: 0.07, green: 0.22, blue: 0.14, alpha: 1.0),
        NSColor(calibratedRed: 0.11, green: 0.48, blue: 0.24, alpha: 1.0),
        NSColor(calibratedRed: 0.22, green: 0.72, blue: 0.34, alpha: 1.0)
    ])!
    bgGrad.draw(in: squircle, angle: 135)

    let sheetRect = NSRect(x: 72 * scale, y: 80 * scale, width: 368 * scale, height: 352 * scale)
    let sheetPath = NSBezierPath(roundedRect: sheetRect, xRadius: 36 * scale, yRadius: 36 * scale)
    NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.16, alpha: 0.94).setFill()
    sheetPath.fill()

    let stripeRect = NSRect(x: 72 * scale, y: 404 * scale, width: 368 * scale, height: 28 * scale)
    let stripePath = NSBezierPath(roundedRect: stripeRect, xRadius: 14 * scale, yRadius: 14 * scale)
    NSColor(calibratedRed: 1.0, green: 0.56, blue: 0.12, alpha: 1.0).setFill()
    stripePath.fill()

    let lineColors: [(CGFloat, CGFloat, NSColor)] = [
        (104, 150, NSColor(calibratedRed: 0.35, green: 0.75, blue: 1.0, alpha: 0.9)),
        (138, 220, NSColor(calibratedRed: 0.52, green: 0.90, blue: 0.45, alpha: 0.9)),
        (172, 180, NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.28, alpha: 0.9))
    ]
    for (idx, item) in lineColors.enumerated() {
        let yPos = (348 - CGFloat(idx) * 34) * scale
        let bar = NSBezierPath(
            roundedRect: NSRect(x: item.0 * scale, y: yPos, width: item.1 * scale, height: 14 * scale),
            xRadius: 7 * scale,
            yRadius: 7 * scale
        )
        item.2.setFill()
        bar.fill()
    }

    let nppAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 122 * scale, weight: .black),
        .foregroundColor: NSColor.white
    ]
    let nppStr = "N++" as NSString
    let nppSize = nppStr.size(withAttributes: nppAttrs)
    nppStr.draw(at: NSPoint(x: (512 * scale - nppSize.width) / 2, y: 112 * scale), withAttributes: nppAttrs)

    NSColor.white.withAlphaComponent(0.28).setStroke()
    squircle.lineWidth = 6 * scale
    squircle.stroke()

    NSGraphicsContext.restoreGraphicsState()
    if let png = rep.representation(using: .png, properties: [:]) {
        try! png.write(to: URL(fileURLWithPath: "/tmp/MacNotePP.iconset/" + filename))
    }
}

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (192, "icon_192x192.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]
for (sz, name) in sizes {
    renderIcon(size: sz, filename: name)
}
'

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

# Save application icon copies to project root directory
cp "$RESOURCES_DIR/AppIcon.icns" "$PROJECT_DIR/AppIcon.icns"
cp "$ICONSET_DIR/icon_192x192.png" "$PROJECT_DIR/AppIcon_192x192.png"
cp "$ICONSET_DIR/icon_512x512.png" "$PROJECT_DIR/AppIcon_512x512.png"
cp "$ICONSET_DIR/icon_512x512@2x.png" "$PROJECT_DIR/AppIcon.png"
echo "==> App icons saved to project directory ($PROJECT_DIR/AppIcon.icns, AppIcon_192x192.png, AppIcon_512x512.png, AppIcon.png)"

cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>tr</string>
    <key>CFBundleDisplayName</key>
    <string>MacNote++</string>
    <key>CFBundleExecutable</key>
    <string>MacNotePP</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.macnotepp.editor</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MacNote++</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.2</string>
    <key>CFBundleVersion</key>
    <string>5</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.macnotepp.editor.view</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>macnotepp</string>
            </array>
        </dict>
    </array>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Source Code &amp; Text Document</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.text</string>
                <string>public.plain-text</string>
                <string>public.source-code</string>
                <string>public.script</string>
            </array>
        </dict>
    </array>
    <key>UTImportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.macnotepp.type.sql</string>
            <key>UTTypeDescription</key>
            <string>SQL script</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.source-code</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>sql</string>
                    <string>ddl</string>
                    <string>dml</string>
                    <string>pgsql</string>
                    <string>tsql</string>
                </array>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.macnotepp.type.delphi</string>
            <key>UTTypeDescription</key>
            <string>Delphi source</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.source-code</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>dpr</string>
                    <string>dpk</string>
                    <string>pp</string>
                    <string>dfm</string>
                    <string>inc</string>
                </array>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.macnotepp.type.arduino</string>
            <key>UTTypeDescription</key>
            <string>Arduino sketch</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.source-code</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>ino</string>
                </array>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.macnotepp.type.jsx</string>
            <key>UTTypeDescription</key>
            <string>JSX source</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.source-code</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>jsx</string>
                </array>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.macnotepp.type.stylesheet</string>
            <key>UTTypeDescription</key>
            <string>Style sheet source</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.source-code</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>scss</string>
                    <string>sass</string>
                    <string>less</string>
                </array>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.macnotepp.type.rust</string>
            <key>UTTypeDescription</key>
            <string>Rust source</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.source-code</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>rs</string>
                </array>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.macnotepp.type.go</string>
            <key>UTTypeDescription</key>
            <string>Go source</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.source-code</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>go</string>
                </array>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.macnotepp.type.csharp</string>
            <key>UTTypeDescription</key>
            <string>C# source</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.source-code</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>cs</string>
                </array>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.macnotepp.type.kotlin</string>
            <key>UTTypeDescription</key>
            <string>Kotlin source</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.source-code</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>kt</string>
                </array>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.macnotepp.type.lua</string>
            <key>UTTypeDescription</key>
            <string>Lua source</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.source-code</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>lua</string>
                </array>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.macnotepp.type.assembly</string>
            <key>UTTypeDescription</key>
            <string>Assembly source</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.source-code</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>asm</string>
                </array>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.macnotepp.type.batch</string>
            <key>UTTypeDescription</key>
            <string>Batch file</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.source-code</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>bat</string>
                    <string>cmd</string>
                </array>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.macnotepp.type.powershell</string>
            <key>UTTypeDescription</key>
            <string>PowerShell script</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.source-code</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>ps1</string>
                </array>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.macnotepp.type.config</string>
            <key>UTTypeDescription</key>
            <string>Configuration file</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.plain-text</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>ini</string>
                    <string>cfg</string>
                    <string>conf</string>
                    <string>toml</string>
                    <string>env</string>
                </array>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOF

# Sabit imza: macOS Gizlilik izinlerini imzaya bağlar; ad-hoc imzada her derleme yeni uygulama sayılır ve izinler
# yeniden sorulur. Sertifika bu Mac'te yoksa ad-hoc imzalanır; scripts/make_release.sh bunu reddeder.
SIGN_NAME="freeware2 Code Signing"
if [[ -z "${SIGN_IDENTITY:-}" ]] && security find-identity -p codesigning | grep -q "\"$SIGN_NAME\""; then
    SIGN_IDENTITY="$SIGN_NAME"
fi
codesign --force --sign "${SIGN_IDENTITY:--}" --timestamp=none "$BUNDLE_DIR"

touch "$BUNDLE_DIR"
echo "==> Done! Application bundle created at: $BUNDLE_DIR"
