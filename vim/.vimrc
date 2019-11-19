"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Vim-Plug Configuration
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  call plug#begin('~/.vim/plugged')

  Plug 'tpope/vim-sensible'
  Plug 'vim-airline/vim-airline'
  Plug 'arcticicestudio/nord-vim'
  Plug 'scrooloose/nerdtree'
  Plug 'Xuyuanp/nerdtree-git-plugin'
  Plug 'prettier/vim-prettier', { 'do': 'yarn install' }
  Plug 'dense-analysis/ale'
  Plug 'airblade/vim-gitgutter'
  Plug 'Shougo/vimproc.vim', {'do' : 'make'}
  Plug 'Quramy/tsuquyomi'
  Plug 'cohama/lexima.vim'
  Plug 'leafgarland/typescript-vim'
  Plug 'peitalin/vim-jsx-typescript'
  
  if has('fzf')
    Plug '/usr/local/opt/fzf'
  else
    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
  endif
    Plug 'junegunn/fzf.vim'
  
  if has('nvim')
    Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
  else
    Plug 'Shougo/deoplete.nvim'
    Plug 'roxma/nvim-yarp'
    Plug 'roxma/vim-hug-neovim-rpc'
  endif

  call plug#end()

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" General Settings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  " show line numbers in margin
  set number
  " auto-save when losing focus
  :au FocusLost * :wa
  " space as leader
  map <Space> <Leader>
  " reduce vim update time
  set updatetime=100
  " set vim shell
  set shell=zsh

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Colors and Fonts
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  colorscheme nord

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Plugin Options
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  " Deoplete
  let g:deoplete#enable_at_startup = 1

  " FZF
  nnoremap <leader>e :Files<cr>
  nnoremap <leader>f :execute 'Ag ' . input('Ag/')<cr>
