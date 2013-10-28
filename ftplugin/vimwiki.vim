
execute "autocmd BufWrite ".expand('%:p')." call vimwiki_tasks#write()"

" sync the contact of the file with TW
call vimwiki_tasks#read()
