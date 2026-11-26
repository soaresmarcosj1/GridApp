#!/bin/bash
set -e

APP_NAME="GridApp"
APP_BUNDLE="${APP_NAME}.app"

echo "🔨 Compilando ${APP_NAME} (Otimizado para macOS Apple Silicon)..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources/pt-BR.lproj"
mkdir -p "${APP_BUNDLE}/Contents/Resources/pt.lproj"

# 1. Empacotamento do Ícone Oficial (Assets.car + AppIcon.icns fallback)
echo "🎨 Processando ícone oficial..."

HAS_ASSETS_CAR=0

# Caso o Xcode completo esteja instalado localmente, compila o Assets.car diretamente
if /usr/bin/xcrun --find actool >/dev/null 2>&1 && [ -d "Resources/AppIcon.icon" ]; then
    echo "⚙️  Compilando Resources/AppIcon.icon localmente com actool..."
    /usr/bin/actool "Resources/AppIcon.icon" \
        --compile "${APP_BUNDLE}/Contents/Resources" \
        --platform macosx \
        --minimum-deployment-target 14.0 \
        --target-device mac \
        --app-icon AppIcon \
        --output-partial-info-plist /tmp/assetcatalog_generated_info.plist < /dev/null >/dev/null 2>&1 || true
    if [ -f "${APP_BUNDLE}/Contents/Resources/Assets.car" ]; then
        HAS_ASSETS_CAR=1
    fi
fi

# Caso não haja Xcode local, utiliza o Assets.car pré-compilado (ex: via GitHub Actions)
if [ "${HAS_ASSETS_CAR}" -eq 0 ] && [ -f "Resources/Assets.car" ]; then
    cp "Resources/Assets.car" "${APP_BUNDLE}/Contents/Resources/Assets.car"
    HAS_ASSETS_CAR=1
fi

# Garante um AppIcon.icns de fallback caso o actool não tenha gerado um
if [ ! -f "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" ]; then
    if [ ! -f "Resources/AppIcon.icns" ] && [ -f "Resources/generate_icns.swift" ]; then
        swiftc -module-cache-path /tmp/swift-module-cache "Resources/generate_icns.swift" -o /tmp/generate_icns
        /tmp/generate_icns
        /usr/bin/iconutil -c icns "Resources/AppIcon.iconset" -o "Resources/AppIcon.icns"
    fi
    if [ -f "Resources/AppIcon.icns" ]; then
        cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    fi
fi

if [ "${HAS_ASSETS_CAR}" -eq 1 ]; then
    echo "✅ Assets.car embutido (suporte a Dark, Clear e Tinted Liquid Glass ativo)."
else
    echo "⚠️  Resources/Assets.car não encontrado — usando apenas AppIcon.icns estático."
    echo "   Dica: faça push ou dispare o workflow '.github/workflows/compile-icon.yml' no GitHub e execute 'git pull'."
fi

# 2. Compilação do binário principal
swiftc -module-cache-path /tmp/swift-module-cache \
    -O \
    -target arm64-apple-macosx14.0 \
    Sources/GridApp/*.swift \
    -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# 3. Geração do Info.plist com CFBundleIconFile e CFBundleIconName
cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.marcos.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>GridApp</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>pt-BR</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>pt-BR</string>
        <string>pt</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Arquivo de Vídeo</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.movie</string>
                <string>public.video</string>
                <string>public.mpeg-4</string>
                <string>com.apple.quicktime-movie</string>
                <string>public.avi</string>
                <string>org.matroska.mkv</string>
                <string>org.webmproject.webm</string>
            </array>
        </dict>
    </array>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>Criar Contact Sheet (GridApp)</string>
            </dict>
            <key>NSMessage</key>
            <string>createContactSheetService</string>
            <key>NSPortName</key>
            <string>GridApp</string>
            <key>NSSendFileTypes</key>
            <array>
                <string>public.movie</string>
                <string>public.video</string>
                <string>public.folder</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

# Atualiza o timestamp do bundle para o Finder e o LaunchServices recarregarem o ícone
touch "${APP_BUNDLE}"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${APP_BUNDLE}" >/dev/null 2>&1 || true

echo "✅ Aplicativo gerado com sucesso em: $(pwd)/${APP_BUNDLE}"
