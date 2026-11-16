#!/bin/zsh
# GitHub Release에 올라간 zip으로 homebrew-tap의 cask 버전/sha256 갱신 (Hando 레포는 안 건드림)
#   ./scripts/bump-cask.sh 1.6.0            → ../homebrew-tap/Casks/hando.rb 수정 + 커밋 + push
#   TAP_DIR=경로 ./scripts/bump-cask.sh ...  → tap 레포 위치 지정
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?버전을 넣어주세요 (예: 1.6.0)}"
VERSION="${VERSION#v}"
TAP_DIR="${TAP_DIR:-../homebrew-tap}"
CASK="$TAP_DIR/Casks/hando.rb"
[[ -d "$TAP_DIR/.git" ]] || { echo "tap 레포가 없어요: $TAP_DIR (git clone https://github.com/minsu33/homebrew-tap.git)"; exit 1; }

URL="https://github.com/minsu33/Hando/releases/download/v$VERSION/Hando-$VERSION.zip.sha256"
SHA="$(curl -fsSL "$URL" | tr -d '[:space:]')"
[[ ${#SHA} -eq 64 ]] || { echo "sha256을 못 가져왔어요 (Release가 아직 없거나 실패): $URL"; exit 1; }

git -C "$TAP_DIR" pull -q
mkdir -p "$TAP_DIR/Casks"
# 템플릿(packaging/homebrew/hando.rb)에서 앞 주석 빼고 버전·sha만 채움
sed -e '1,/^cask /{/^#/d;}' -e "s/^  version \".*\"/  version \"$VERSION\"/" -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" \
  packaging/homebrew/hando.rb > "$CASK"
ruby -c "$CASK" >/dev/null

git -C "$TAP_DIR" add Casks/hando.rb
git -C "$TAP_DIR" commit -q -m "hando $VERSION"
git -C "$TAP_DIR" push -q
echo "✓ tap 갱신: hando $VERSION ($SHA)"
