#!/bin/sh

# Set custom preferencews location
defaults write com.googlecode.iterm2.plist PrefsCustomFolder -string "$HOME/.iterm2"
defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true