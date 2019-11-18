.PHONY: test vim

all: sudo packages git vim config defaults

sudo:
	sudo -v
	while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

git:
	brew install git git-extras

vim: 
	sh ./vim/run.sh

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
