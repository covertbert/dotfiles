#!/bin/sh

mkdir -p ~/.config/nvim

curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

pip3 install --user pynvim

cp ./vim/init.vim ~/.config/nvim
cp ./vim/.vimrc ~/
