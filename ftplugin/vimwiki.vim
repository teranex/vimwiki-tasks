
augroup vimwiki_tasks
    " when saving the file sync the tasks from vimwiki to TW
    autocmd!
    execute "autocmd BufWrite *.".expand('%:e')." call vimwiki_tasks#write()"
augroup END

" sync the tasks from TW to vimwiki
call vimwiki_tasks#read()
