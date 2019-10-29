#!/bin/sh

git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime
sh ~/.vim_runtime/install_awesome_vimrc.sh

( cd ~/.vim_runtime && git clone https://github.com/MaxMEllon/vim-jsx-pretty.git ~/.vim_runtime/my_plugins/vim-jsx-pretty )
( cd ~/.vim_runtime && git clone https://github.com/arcticicestudio/nord-vim.git ~/.vim_runtime/nord-vim )

cp -rv ./vim/my_configs.vim ~/.vim_runtime/
