" TODO: read file extension from config

augroup vimwiki_tasks
    autocmd!
    autocmd BufWrite *.md call vimwiki_tasks#write()
augroup END
