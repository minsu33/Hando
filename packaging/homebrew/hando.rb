# minsu33/homebrew-tap 레포의 Casks/hando.rb 로 복사해서 씀
# 버전 올릴 때: ./scripts/bump-cask.sh 1.5.0
cask "hando" do
  version "1.5.0"
  sha256 "SHA256"

  url "https://github.com/minsu33/Hando/releases/download/v#{version}/Hando-#{version}.zip"
  name "Hando"
  desc "Menu bar gauge for Claude and Codex usage limits"
  homepage "https://github.com/minsu33/Hando"

  depends_on macos: ">= :sonoma"

  app "Hando.app"
  binary "#{appdir}/Hando.app/Contents/MacOS/Hando", target: "hando"

  caveats <<~EOS
    Apple 공증이 없는 앱이라 처음 열 때 막힐 수 있음:
      시스템 설정 > 개인정보 보호 및 보안 > "그래도 열기"
    또는
      xattr -dr com.apple.quarantine /Applications/Hando.app
  EOS

  zap trash: [
    "~/Library/Application Support/Hando",
    "~/Library/Preferences/io.github.minsu33.hando.plist",
  ]
end
