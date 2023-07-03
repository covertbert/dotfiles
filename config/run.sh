#!/bin/bash
zgenDirectory="${HOME}/.zgen"

if [[ ! -d $zgenDirectory ]]; then
    git clone https://github.com/tarjoilija/zgen.git "$zgenDirectory"
fi

cp -rv ./config/.gitconfig ~/.gitconfig

if [[ ! -e ~/.git-config-user ]]; then
    cp -rv ./config/.git-config-user ~
fi

cp -rv ./config/starship.toml ~/.config/starship.toml
cp -rv ./config/.zshrc ~/.zshrc
cp -rv ./config/zsh ~/.config/

cp -rv ./config/.hyper.js ~/.hyper.js
