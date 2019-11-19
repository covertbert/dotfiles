#!/bin/sh

VIMPLUG_PATH="$HOME/.local/share/nvim/site/autoload/plug.vim"
NVIM_PATH="$HOME/.config/nvim"

if [ -f "$VIMPLUG_PATH" ]; then
    printf "\\n\\nVimPlug is already installed.\\n\\n"
else
    printf "\\n\\nInstalling VimPlug.\\n\\n"
    curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

if command -v python3 &>/dev/null; then
    printf "Python 3 is already installed.\\n\\n"
else
    printf "Python 3 is not installed.\\n\\n"
    printf "Installing pynvim.\\n\\n"
    pip3 install --user pynvim
fi

printf "Copying nvim init.\\n\\n"
mkdir -p "$NVIM_PATH"
cp ./vim/init.vim "$NVIM_PATH"

printf "Copying vimrc.\\n\\n"
cp ./vim/.vimrc ~/
