#!/bin/bash
# Compila e empacota o WindFree.app em ./build
# Uso: ./build.sh            -> só compila
#      ./build.sh --install  -> compila, instala em /Applications e abre
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/WindFree.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/WindFreeBar "$APP/Contents/MacOS/WindFreeBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/*.png "$APP/Contents/Resources/"

# Versão: a de "marketing" (0.2, 1.0…) fica em Resources/Info.plist e é subida à mão. O build é o número de
# commits do git e o commit fica registrado; "+" indica mudanças ainda não commitadas.
PLIST="$APP/Contents/Info.plist"
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 0)
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "?")
git diff --quiet HEAD 2>/dev/null || COMMIT="$COMMIT+"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :WindFreeCommit string $COMMIT" "$PLIST"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")

# Assinatura local (ad-hoc), suficiente para rodar no seu próprio Mac
codesign --force --sign - "$APP"
echo "Pronto: $APP (versão $VERSION, build $BUILD, commit $COMMIT)"

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
