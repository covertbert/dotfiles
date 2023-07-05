#!/usr/bin/env bash

brew bundle --verbose --file=./brew/Brewfile
brew bundle --verbose --file=./brew/Caskfile

"$(brew --prefix)"/opt/fzf/install
