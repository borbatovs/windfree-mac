#!/bin/bash
# Compila e empacota o WindFree.app em ./build
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
echo "Para instalar: cp -R \"$APP\" /Applications/ && open /Applications/WindFree.app"
