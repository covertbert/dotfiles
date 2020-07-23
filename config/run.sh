#!/bin/bash

git clone https://github.com/tarjoilija/zgen.git "${HOME}/.zgen"

cp -rv ./config/.gitconfig ~
cp -rv ./config/.zshrc ~/.zshrc
cp -rv ./config/zsh ~/.config/

mkdir -p ~/.iterm2
cp -rv ./config/com.googlecode.iterm2.plist ~/.iterm2
