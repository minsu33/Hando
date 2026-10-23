#!/bin/zsh
# Hando.app 만들기
#   ./scripts/build-app.sh            → dist/Hando.app
#   ./scripts/build-app.sh --install  → /Applications에 넣고 실행
#   ./scripts/build-app.sh --zip      → dist/Hando-<버전>.zip + .sha256 (릴리즈용)
#
# 서명: SIGN_IDENTITY 환경변수 > 키체인에 "Hando Self Signed" 인증서 있으면 그걸로 > ad-hoc(-)
#   같은 인증서로 계속 서명하면 다시 빌드해도 키체인 "항상 허용"이 유지됨 (scripts/make-signing-cert.sh)
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Hando"
BUNDLE_ID="io.github.minsu33.hando"
# 버전: 환경변수 > git 태그(vX.Y.Z) > 최근 커밋 제목이 vX.Y면 그거 > 0.0.0
version_from_git() {
  local tag; tag="$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)"
  if [[ -n "$tag" ]]; then echo "${tag#v}"; return; fi
  local subject; subject="$(git log -1 --pretty=%s 2>/dev/null || true)"
  if [[ "$subject" =~ ^v([0-9]+(\.[0-9]+)*)$ ]]; then echo "${match[1]}"; return; fi
  echo "0.0.0"
}
VERSION="${VERSION:-$(version_from_git)}"
VERSION="${VERSION#v}"   # 태그 이름(v1.5.0)으로 넘겨도 됨
# CFBundleShortVersionString은 세 자리까지. "1.4" → "1.4.0"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+$ ]] && VERSION="$VERSION.0"
BUILD="${BUILD:-$(date +%Y%m%d%H%M)}"
DIST="dist"
APP="$DIST/$APP_NAME.app"

echo "▸ 버전 $VERSION"
echo "▸ 빌드 (release, universal)"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$APP_NAME"

echo "▸ 번들 만들기"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST

SELF_CERT="Hando Self Signed"
if [[ -z "${SIGN_IDENTITY:-}" ]] && security find-certificate -c "$SELF_CERT" >/dev/null 2>&1; then
  SIGN_IDENTITY="$SELF_CERT"
fi
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
echo "▸ 서명 ($([[ "$SIGN_IDENTITY" == "-" ]] && echo ad-hoc || echo "$SIGN_IDENTITY"))"
codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$APP"

echo "✓ $APP"

if [[ "${1:-}" == "--zip" ]]; then
  ZIP="$DIST/$APP_NAME-$VERSION.zip"
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"   # 확장 속성·서명 유지
  shasum -a 256 "$ZIP" | awk '{print $1}' > "$ZIP.sha256"
  echo "✓ $ZIP  sha256 $(cat "$ZIP.sha256")"
fi

if [[ "${1:-}" == "--install" ]]; then
  pkill -x "$APP_NAME" 2>/dev/null && sleep 1 || true   # 꺼지기 전에 열면 -600 에러
  rm -rf "/Applications/$APP_NAME.app"
  cp -R "$APP" /Applications/
  open "/Applications/$APP_NAME.app"
  echo "✓ /Applications/$APP_NAME.app 실행함"
fi
