call plug#begin('~/.vim/plugged')

Plug 'vim-airline/vim-airline'
Plug 'arcticicestudio/nord-vim'
Plug 'scrooloose/nerdtree'
Plug 'tpope/vim-sensible'
Plug 'prettier/vim-prettier', { 'do': 'yarn install' }

call plug#end()

colorscheme nord
