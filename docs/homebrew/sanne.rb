cask "sanne" do
  version "0.2.0"
  sha256 :no_check

  url "https://github.com/anandghegde/sanne/releases/download/v#{version}/Sanne-#{version}.dmg"
  name "Sanne"
  desc "Gestures for Magic Mouse and trackpad"
  homepage "https://github.com/anandghegde/sanne"

  app "Sanne.app"

  zap trash: [
    "~/Library/Application Support/Sanne",
    "~/Library/Logs/Sanne",
    "~/Library/Preferences/app.sanne.Sanne.plist",
  ]
end
