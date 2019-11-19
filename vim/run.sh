#!/bin/sh

VIMPLUG_PATH="$HOME/.local/share/nvim/site/autoload/plug.vim"
NVIM_PATH="$HOME/.config/nvim"

if [ -f "$VIMPLUG_PATH" ]; then
    echo "VimPlug is already installed"
else
    echo "Installing VimPlug"
    curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

if command -v python3 &>/dev/null; then
    echo "Python 3 is already installed"
else
    echo "Python 3 is not installed"
    echo "Installing pynvim"
    pip3 install --user pynvim
fi

echo "Copying nvim init"
mkdir -p "$NVIM_PATH"
cp ./vim/init.vim "$NVIM_PATH"

echo "Copying vimrc"
cp ./vim/.vimrc ~/
