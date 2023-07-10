#!/usr/bin/env bash

if ! command -v brew &>/dev/null; then
	echo "Homebrew not installed. Installing now..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

brew bundle --verbose --file=./brew/Brewfile
brew bundle --verbose --file=./brew/Caskfile

"$(brew --prefix)"/opt/fzf/install
