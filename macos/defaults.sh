#!/bin/bash
# macOS system preferences — idempotent, safe to re-run
# Requires restart of affected apps (handled at bottom)

set -e

echo "Applying macOS defaults..."

# ── Dock ────────────────────────────────────────────────────────────
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int 36
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock minimize-to-application -bool true

# ── Stage Manager ───────────────────────────────────────────────────
# Click wallpaper to reveal desktop: only in Stage Manager
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false

# ── Trackpad ────────────────────────────────────────────────────────
# Tap to click
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Tracking speed (0.0 to 3.0)
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 2.0

# ── Keyboard ────────────────────────────────────────────────────────
# Fast key repeat rate
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# ── Finder ──────────────────────────────────────────────────────────
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true

# ── Spotlight ───────────────────────────────────────────────────────
# Disable Spotlight hotkey (to use Raycast with Cmd+Space)
# Note: Raycast hotkey must be set manually in Raycast settings
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 \
  "<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>1048576</integer></array><key>type</key><string>standard</string></dict></dict>"

# ── Screenshots ─────────────────────────────────────────────────────
defaults write com.apple.screencapture location -string "$HOME/Desktop"
defaults write com.apple.screencapture type -string "png"

# ── Chrome as Default Browser ───────────────────────────────────────
# Note: macOS may prompt for confirmation on first run
if command -v defaultbrowser &>/dev/null; then
  defaultbrowser chrome
else
  echo "  Install 'defaultbrowser' (brew install defaultbrowser) to auto-set Chrome as default"
fi

# ── Restart Affected Apps ───────────────────────────────────────────
killall Dock &>/dev/null || true
killall Finder &>/dev/null || true
killall SystemUIServer &>/dev/null || true

echo "macOS defaults applied. Some changes may require logout/restart."