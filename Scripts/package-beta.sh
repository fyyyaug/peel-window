#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
derived_data="$project_root/build/DerivedData"
release_app="$derived_data/Build/Products/Release/PeelWindow.app"
staging="$project_root/dist/staging"
image="$project_root/dist/PeelWindow-0.1.0-beta.4-macos-arm64.dmg"

xcodebuild -quiet \
  -project "$project_root/App/PeelWindow/PeelWindow.xcodeproj" \
  -scheme PeelWindow \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$derived_data" \
  build CODE_SIGNING_ALLOWED=NO

codesign --force --deep --sign - --identifier com.fyyyaug.PeelWindow "$release_app"
codesign --verify --deep --strict "$release_app"

mkdir -p "$staging"
ditto "$release_app" "$staging/PeelWindow.app"
ditto "$project_root/Docs/INSTALL.md" "$staging/Read-Me.md"
if [[ ! -L "$staging/Applications" ]]; then
  ln -s /Applications "$staging/Applications"
fi

hdiutil create -quiet -ov \
  -volname 'Peel Window 0.1 beta' \
  -srcfolder "$staging" \
  -format UDZO \
  "$image"
hdiutil verify -quiet "$image"
shasum -a 256 "$image"
