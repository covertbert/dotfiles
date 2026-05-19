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

# Copies Pi config
mkdir -p ~/.pi/agent
[[ -e ./config/pi/settings.json ]] && cp -rv ./config/pi/settings.json ~/.pi/agent/settings.json
[[ -e ./config/pi/keybindings.json ]] && cp -rv ./config/pi/keybindings.json ~/.pi/agent/keybindings.json
[[ -e ./config/pi/models.json ]] && cp -rv ./config/pi/models.json ~/.pi/agent/models.json
[[ -e ./config/pi/AGENTS.md ]] && cp -rv ./config/pi/AGENTS.md ~/.pi/agent/AGENTS.md
[[ -e ./config/pi/SYSTEM.md ]] && cp -rv ./config/pi/SYSTEM.md ~/.pi/agent/SYSTEM.md
[[ -e ./config/pi/APPEND_SYSTEM.md ]] && cp -rv ./config/pi/APPEND_SYSTEM.md ~/.pi/agent/APPEND_SYSTEM.md
[[ -d ./config/pi/prompts ]] && cp -rv ./config/pi/prompts ~/.pi/agent/
[[ -d ./config/pi/skills ]] && cp -rv ./config/pi/skills ~/.pi/agent/
[[ -d ./config/pi/extensions ]] && cp -rv ./config/pi/extensions ~/.pi/agent/
[[ -d ./config/pi/themes ]] && cp -rv ./config/pi/themes ~/.pi/agent/

cp -rv ./config/terminal/.hyper.js ~/.hyper.js
