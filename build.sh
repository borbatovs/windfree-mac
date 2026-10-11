#!/bin/bash
# Compila e empacota o WindFree.app em ./build
# Uso: ./build.sh            -> só compila
#      ./build.sh --install  -> compila, instala em /Applications e abre
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/WindFree.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/WindFreeBar "$APP/Contents/MacOS/WindFreeBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Assinatura local (ad-hoc), suficiente para rodar no seu próprio Mac
codesign --force --sign - "$APP"
echo "Pronto: $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x WindFreeBar 2>/dev/null || true
    sleep 0.5
    rm -rf /Applications/WindFree.app
    cp -R "$APP" /Applications/
    open /Applications/WindFree.app
    echo "Instalado em /Applications/WindFree.app"
else
    echo "Para instalar: ./build.sh --install"
fi
