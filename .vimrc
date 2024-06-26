set encoding=utf-8
syntax on
set number relativenumber
set laststatus=2
set nobackup
set nowritebackup
filetype plugin indent on
set clipboard=unnamed
set hlsearch

highlight Normal ctermbg=None
highlight LineNr ctermfg=DarkGrey

" Turn off highlighting after search [https://stackoverflow.com/questions/4372660/get-rid-of-vims-highlight-after-searching-text]
nnoremap <esc> :noh<return><esc>

nmap <C-h> <C-w>h
nmap <C-j> <C-w>j
nmap <C-k> <C-w>k
nmap <C-l> <C-w>l
