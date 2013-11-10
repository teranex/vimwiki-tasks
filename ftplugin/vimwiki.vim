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
    command! DisplayTaskUUID call vimwiki_tasks#display_task_uuid(0)
    command! CopyTaskUUID call vimwiki_tasks#display_task_uuid(1)
    command! -nargs=1 -bang InsertTasks call vimwiki_tasks#insert_tasks(<q-args>, '<bang>')
endif
