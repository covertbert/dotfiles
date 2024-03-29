#!/bin/bash
zgenDirectory="${HOME}/.zgen"

if command -v nvm &>/dev/null; then
	echo "NVM not installed. Installing now..."
	wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
fi

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

cp -rv ./config/terminal/starship.toml ~/.config/starship.toml
cp -rv ./config/zsh/.zshrc ~/.zshrc
cp -rv ./config/zsh ~/.config/

cp -rv ./config/terminal/.hyper.js ~/.hyper.js
