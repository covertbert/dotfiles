#!/bin/bash
zgenDirectory="${HOME}/.zgen"

if [[ ! -d $zgenDirectory ]]; then
    git clone https://github.com/tarjoilija/zgen.git "$zgenDirectory"
fi

if [[ ! -e ~/.gitconfig ]]; then
    cp -rv ./config/.gitconfig ~
fi

cp -rv ./config/.zshrc ~/.zshrc
cp -rv ./config/zsh ~/.config/

mkdir -p ~/.iterm2
cp -rv ./config/com.googlecode.iterm2.plist ~/.iterm2
