cask "findkey" do
  version :latest
  sha256 :no_check

  url "https://github.com/bssm-oss/findkey/releases/latest/download/FindKey.dmg",
      verified: "github.com/bssm-oss/findkey/"
  name "FindKey"
  desc "GitHub repository secret scanner for macOS"
  homepage "https://github.com/bssm-oss/findkey"

  app "FindKey.app"

  caveats do
    unsigned_accessibility
  end
end
