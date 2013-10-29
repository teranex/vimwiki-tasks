" TODO: finish tasks in TW when they are marked as done in vimwiki
" TODO: how to handle deleted tasks?
" TODO: hide the uuid's
" TODO: add utility task_notifier scripts
" TODO: `:InsertTask <ID>` command
" TODO: tags are removed from vimwiki after sync, add all tags into tasks?
" TODO: add default tags for tasks with due date, due time, without due

function! vimwiki_tasks#write()
    let l:defaults = vimwiki_tasks#get_defaults()
    let l:i = 1
    while l:i <= line('$')
        let l:line = getline(l:i)
        " check if this is a line with an open task with a due date
        if match(l:line, '\v\* \[[^X]\].*(\(\d{4}-\d\d-\d\d( \d\d:\d\d)?\)|#TW\s*$|#[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') != -1
            let l:task = vimwiki_tasks#parse_task(l:line, l:defaults)
            " add the task if it does not have a uuid
            if l:task.uuid == ""
                call system(l:task.task_cmd.' add '.shellescape(l:task.description).' '.l:task.task_meta)
                " find the id and the uuid of the newly created task
                let l:id = substitute(system("task newest limit:1 rc.verbose=nothing rc.color=off rc.defaultwidth=999 rc.report.newest.columns=id rc.report.newest.labels=ID"), "\n", "", "")
                " TODO: check for valid id and successful task creation before continuing?
                let l:uuid = substitute(system("task ".l:id." uuid"), "\n", "", "")
                " add the uuid to the line and remove the #TW indicator
                call setline(l:i, <SID>RemoveTwIndicator(l:line)." #".l:uuid)
                " annotate the task to reference the vimwiki file
                let l:cmd = 'task '.l:id.' annotate vimwiki:'.expand('%:p')
                call system(l:cmd)
            " see if we need to update the task in TW
            else
                let l:tw_task = vimwiki_tasks#load_task(l:task.uuid)
                if l:task.description !=# l:tw_task.description || l:task.due !=# l:tw_task.due || l:task.project !=# l:defaults.project
                    call system(l:task.task_cmd.' uuid:'.l:task.uuid.' modify '.shellescape(l:task.description).' '.l:task.task_meta)
                endif
            endif
        endif
        let l:i += 1
    endwhile
endfunction

function! vimwiki_tasks#read()
    let l:defaults = vimwiki_tasks#get_defaults()
    let l:i = 1
    while l:i <= line('$')
        let l:line = getline(l:i)
        " if this is an open task with a uuid, check if we can update it from TW
        if match(l:line, '\v\* \[[^X]\].*#[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}') != -1
            let l:task = vimwiki_tasks#parse_task(l:line, l:defaults)
            let l:tw_task = vimwiki_tasks#load_task(l:task.uuid)
            if l:tw_task.status ==# 'Completed'
                call setline(l:i, vimwiki_tasks#build_task(l:line, l:tw_task, 1))
                let &mod = 1
            elseif l:tw_task.status ==# 'Deleted'
                " TODO: handle deleted task (remove the uuid from the line?)
            else
                " task is still open in TW, see if it was updated
                if l:task.description !=# l:tw_task.description || l:task.due !=# l:tw_task.due
                    " and replace it in the file
                    call setline(l:i, vimwiki_tasks#build_task(l:line, l:tw_task))
                    " mark the buffer as modified
                    let &mod = 1
                endif
            end
        endif
        let l:i += 1
    endwhile
endfunction

function! vimwiki_tasks#get_defaults()
    let l:defaults = {'project': ''}
    let l:i = 1
    while l:i <= 10
        let l:line = getline(l:i)
        let l:project = matchstr(l:line, '\v\%\%\s*Project:\s*\zs(\w+)')
        if l:project != ""
            let l:defaults.project = l:project
        endif
        let l:i +=1
    endwhile
    return l:defaults
endfunction

" a:1 boolean, 1 if the task should be marked as finished, otherwise the state
"              is reused from the task text
function! vimwiki_tasks#build_task(line, tw_task, ...)
    " build the new task line
    let l:match = matchlist(a:line, '\v^(\s*)\* \[(.)\]')
    let l:indent = l:match[1]
    let l:state = l:match[2]
    if a:0 > 0 && a:1 == 1
        let l:state = 'X'
    endif
    let l:newline = l:indent."* [".l:state."] ".a:tw_task.description
    if a:tw_task.due != ""
        let l:due_printable = substitute(a:tw_task.due, 'T', " ", "")
        let l:newline .= " (".l:due_printable.")"
    endif
    let l:newline .= " #".a:tw_task.uuid
    return l:newline
endfunction

function! vimwiki_tasks#parse_task(line, defaults)
    let l:task = vimwiki_tasks#empty_task()
    " create the task
    let l:match = matchlist(a:line, '\v\* \[[^X]\]\s+(.*)\s*')
    let l:task.description = l:match[1]
    " construct the task creation command and create
    let l:task.task_cmd = 'task'
    let l:task.task_meta = ''
    " add a project if necessary
    if has_key(a:defaults, 'project')
        let l:task.task_meta .= ' project:'.a:defaults.project
    endif
    " add due date if available
    let l:due = matchlist(a:line, '\v\((\d{4}-\d\d-\d\d)( (\d\d:\d\d))?\)')
    if !empty(l:due)
        let l:task.due_date = l:due[1]
        let l:task.due_time = get(l:due, 3, '00:00')
        if l:task.due_time == ""
            let l:task.due_time = '00:00'
        endif
        " remove date in line
        let l:task.description = substitute(l:task.description, '\v\(\d{4}-\d\d-\d\d( \d\d:\d\d)?\)', "", "")
        " set the due in task_meta
        let l:task.due = l:task.due_date.'T'.l:task.due_time
        let l:task.task_meta .= ' due:'.l:task.due
        " set the dateformat in task_cmd
        let l:task.task_cmd .= ' rc.dateformat=Y-M-DTH:N'
    endif
    " get the uuid from the task if it is there, and remove it from the task description
    let l:task.uuid = matchstr(a:line, '\v#\zs([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})')
    if l:task.uuid != ""
        let l:task.description = substitute(l:task.description, '\v#[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', "", "")
    endif

    " remove any #TW at the end (= a new task without a due)
    let l:task.description = <SID>RemoveTwIndicator(l:task.description)

    " and strip any whitespace
    let l:task.description = <SID>Strip(l:task.description)

    return l:task
endfunction

function! vimwiki_tasks#load_task(uuid)
    let l:task = vimwiki_tasks#empty_task()
    let l:cmd = 'task rc.verbose=nothing rc.defaultwidth=999 rc.dateformat.info=Y-M-DTH:N rc.color=off uuid:'.a:uuid.' info | grep "^\(ID\|UUID\|Description\|Status\|Due\|Project\)"'
    let l:result = split(system(l:cmd), '\n')
    for l:result_line in l:result
        let l:match = matchlist(l:result_line, '\v(\w+)\s+(.*)')
        let l:task[tolower(l:match[1])] = l:match[2]
    endfor
    return l:task
endfunction

function! s:Strip(input_string)
    return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

function! s:RemoveTwIndicator(input)
     return substitute(a:input, '\v\s?#TW\s*$', "", "")
endfunction

function! vimwiki_tasks#empty_task()
    return {'id': 0, 'description': '', 'due': '', 'status': '', 'project': ''}
endfunction
