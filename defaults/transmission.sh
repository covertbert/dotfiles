#!/bin/bash

defaults write org.m0k.transmission UseIncompleteDownloadFolder -bool true
defaults write org.m0k.transmission IncompleteDownloadFolder -string "${HOME}/Downloads"
defaults write org.m0k.transmission DownloadLocationConstant -integer 1

defaults write org.m0k.transmission DownloadAsk -bool false

defaults write org.m0k.transmission DeleteOriginalTorrent -bool true

defaults write org.m0k.transmission WarningDonate -bool false

defaults write org.m0k.transmission WarningLegal -bool false
