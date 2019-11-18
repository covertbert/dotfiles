call plug#begin('~/.vim/plugged')

" Sensible config
Plug 'tpope/vim-sensible'
" Status bar
Plug 'vim-airline/vim-airline'
" Nord theme
Plug 'arcticicestudio/nord-vim'
" Project tree
Plug 'scrooloose/nerdtree'
" Prettier code formatter
Plug 'prettier/vim-prettier', { 'do': 'yarn install' }
" Linting engine
Plug 'dense-analysis/ale'
" Git diff in gutter
Plug 'airblade/vim-gitgutter'
" TS support
Plug 'Shougo/vimproc.vim', {'do' : 'make'}
Plug 'Quramy/tsuquyomi'
" Auto close brackets
Plug 'cohama/lexima.vim'

" Intellisense
if has('nvim')
  Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
else
  Plug 'Shougo/deoplete.nvim'
  Plug 'roxma/nvim-yarp'
  Plug 'roxma/vim-hug-neovim-rpc'
endif
let g:deoplete#enable_at_startup = 1

call plug#end()

" Settings
colorscheme nord
set number
