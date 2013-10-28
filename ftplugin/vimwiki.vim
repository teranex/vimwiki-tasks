
execute "autocmd BufWrite ".expand('%:p')." call vimwiki_tasks#write()"
