# typed: strict
# frozen_string_literal: true

cask "bluenap" do
  version "2.4"
  sha256 "8f02a64b07f4de9c537eeadfb891c1497b700e19afc12d1d49e739519e8cb831"

  url "https://github.com/jorchford/BlueNap/releases/download/v#{version}/BlueNap.dmg"
  name "BlueNap"
  name "蓝憩"
  desc "Bluetooth sleep/wake power manager and Wi-Fi static IP auto-switcher"
  homepage "https://github.com/jorchford/BlueNap"

  depends_on macos: :sonoma

  app "BlueNap.app"

  uninstall quit: "com.needai.bluesnooze"

  zap trash: [
    "~/Library/Application Scripts/com.needai.bluesnooze",
    "~/Library/Caches/com.needai.bluesnooze",
    "~/Library/Containers/com.needai.bluesnooze",
    "~/Library/HTTPStorages/com.needai.bluesnooze",
    "~/Library/Preferences/com.needai.bluesnooze.plist",
  ]
end
