if vimwiki_tasks#config('taskwarrior_integration', 1)
    augroup vimwiki_tasks
        " when saving the file sync the tasks from vimwiki to TW
        autocmd!
        execute "autocmd BufWrite *.".expand('%:e')." call vimwiki_tasks#write()"
    augroup END

    " sync the tasks from TW to vimwiki
    call vimwiki_tasks#read()

    command! DisplayTaskID call vimwiki_tasks#display_task_id(0)
    command! CopyTaskID call vimwiki_tasks#display_task_id(1)
endif
