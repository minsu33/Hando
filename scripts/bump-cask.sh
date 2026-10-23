#!/bin/zsh
# GitHub Release에 올라간 zip으로 cask 버전/sha256 갱신
#   ./scripts/bump-cask.sh 1.5.0   → packaging/homebrew/hando.rb 수정
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?버전을 넣어주세요 (예: 1.5.0)}"
VERSION="${VERSION#v}"
URL="https://github.com/minsu33/Hando/releases/download/v$VERSION/Hando-$VERSION.zip.sha256"
SHA="$(curl -fsSL "$URL" | tr -d '[:space:]')"
[[ ${#SHA} -eq 64 ]] || { echo "sha256을 못 가져왔어요: $URL"; exit 1; }

CASK=packaging/homebrew/hando.rb
sed -i '' -e "s/^  version \".*\"/  version \"$VERSION\"/" -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASK"
echo "✓ $CASK → $VERSION ($SHA)"
echo "  이 파일을 minsu33/homebrew-tap 의 Casks/hando.rb 로 복사해서 push"
