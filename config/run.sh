#!/bin/bash
zgenDirectory="${HOME}/.zgen"

if [[ ! -d $zgenDirectory ]]; then
    git clone https://github.com/tarjoilija/zgen.git "$zgenDirectory"
fi

if [[ ! -e ~/.gitconfig ]]; then
    cp -rv ./config/.gitconfig ~
fi

cp -rv ./config/starship.toml ~/.config/starship.toml
cp -rv ./config/.zshrc ~/.zshrc
cp -rv ./config/zsh ~/.config/

cp -rv ./config/.hyper.js ~/.hyper.js
