#!/usr/bin/env bash

set -euo pipefail

sudo -v

###############################################################################
# General UI                                                                  #
###############################################################################

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save to disk (not iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Disable the "Are you sure you want to open this application?" dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Disable the crash reporter
defaults write com.apple.CrashReporter DialogType -string "none"

# Automatically quit printer app once print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

###############################################################################
# Keyboard & Input                                                            #
###############################################################################

# Disable smart quotes and dashes
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Enable full keyboard access for all controls (Tab in modal dialogs)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Fast keyboard repeat rate
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 15

###############################################################################
# Screenshots                                                                 #
###############################################################################

# Save screenshots to the Desktop
defaults write com.apple.screencapture location -string "${HOME}/Desktop"

# PNG format
defaults write com.apple.screencapture type -string "png"

# No shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

###############################################################################
# Finder                                                                      #
###############################################################################

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Allow text selection in Quick Look
defaults write com.apple.finder QLEnableTextSelection -bool true

# Show full POSIX path as window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Search current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# No warning when changing file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# No .DS_Store on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# List view by default
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# No warning before emptying Trash
defaults write com.apple.finder WarnOnEmptyTrash -bool false

# Default new window to home directory
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"

###############################################################################
# Dock                                                                        #
###############################################################################

# Auto-hide
defaults write com.apple.dock autohide -bool true

# Hidden app icons translucent
defaults write com.apple.dock showhidden -bool true

# No icon bouncing
defaults write com.apple.dock no-bouncing -bool true

# Don't rearrange Spaces by recent use
defaults write com.apple.dock mru-spaces -bool false

# Don't show recently used apps
defaults write com.Apple.Dock show-recents -bool false

# Tile size
defaults write com.apple.Dock tilesize -integer 55

# Show indicator lights for open apps
defaults write com.apple.dock show-process-indicators -bool true

###############################################################################
# Software Updates                                                            #
###############################################################################

# Enable automatic update check
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

# Download updates in background
defaults write com.apple.SoftwareUpdate AutomaticDownload -bool true

# Install security updates
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -bool true

###############################################################################
# Restart affected apps                                                       #
###############################################################################

for app in "Dock" "Finder" "SystemUIServer"; do
	killall "${app}" &>/dev/null || true
done
