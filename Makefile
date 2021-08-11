.PHONY: sudo brew git config defaults packages

all: sudo brew git config defaults packages

sudo:
	sudo -v
	while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

brew:
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"


git:
	brew install git git-extras

defaults:
	sh ./defaults/run.sh

config:
	sh ./config/run.sh

packages: brew-packages cask-apps

brew-packages:
	brew bundle --file=./brew/Brewfile
	/usr/local/opt/fzf/install --all

cask-apps:
	brew bundle --file=./brew/Caskfile
