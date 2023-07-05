#!/bin/bash
zgenDirectory="${HOME}/.zgen"

if [[ ! -d $zgenDirectory ]]; then
	git clone https://github.com/tarjoilija/zgen.git "$zgenDirectory"
fi

# Copies main gitconfig
cp -rv ./config/git/.gitconfig ~/.gitconfig
# Copies git delta themes
cp -rv ./config/git/themes.gitconfig ~/themes.gitconfig
# Copies [user] section of git config if it does not exist.
if [[ ! -e ~/user.gitconfig ]]; then
	cp -rv ./config/git/user.gitconfig ~
fi

cp -rv ./config/starship.toml ~/.config/starship.toml
cp -rv ./config/zsh/.zshrc ~/.zshrc
cp -rv ./config/zsh ~/.config/

cp -rv ./config/.hyper.js ~/.hyper.js
