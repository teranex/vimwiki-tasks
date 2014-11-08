" TODO: task add: description in quotes? (to fix (bw))
" a list of open tasks which should be checked to see if they are completed
" when the file is written
let b:open_tasks = []
" the date/time when the file was read. Used to compare with last_modified
" date of tasks in taskwarrior, to avoid overwriting changes from taskwarrior
let b:read_time = ''

function! vimwiki_tasks#write()
    call vimwiki_tasks#verify_taskwarrior()
    let l:defaults = vimwiki_tasks#get_defaults()
    let l:i = 1
    while l:i <= line('$')
        let l:line = getline(l:i)
        " check if this is a line with an open task with a due date
        if match(l:line, '\v\* \[[^X]\].*(\(\d{4}-\d\d-\d\d( \d\d:\d\d)?\)|#TW\s*$|#[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') != -1
            let l:task = vimwiki_tasks#parse_task(l:line, l:defaults)
            " add the task if it does not have a uuid
            if l:task.uuid == ""
                call <SID>Task(l:task.task_args.' add '.shellescape(l:task.description).' '.<SID>JoinTags(l:task.tags_list).' '.l:task.task_meta)
                " find the id and the uuid of the newly created task
                let l:id = substitute(<SID>Task("newest limit:1 rc.verbose=nothing rc.color=off rc.defaultwidth=999 rc.report.newest.columns=id rc.report.newest.labels=ID"), "\n", "", "")
                let l:uuid = substitute(<SID>Task(l:id." uuid"), "\n", "", "")
                " add the uuid to the line and remove the #TW indicator
                call setline(l:i, <SID>RemoveTwIndicator(l:line)." #".l:uuid)

                if vimwiki_tasks#config('annotate_origin', 0)
                    " annotate the task to reference the vimwiki file
                    call <SID>Task(l:id.' annotate vimwiki:'.expand('%:p'))
                endif
            " see if we need to update the task in TW
            else
                let l:tw_task = vimwiki_tasks#load_task(l:task.uuid)
                " don't update deleted tasks
                if l:tw_task.status !=# 'Deleted'
                    if l:task.description !=# l:tw_task.description || l:task.due !=# l:tw_task.due || l:task.project !=# l:defaults.project || <SID>JoinTags(l:task.tags_list) !=# <SID>JoinTags(l:tw_task.tags_list)
                        let l:continue = 1
                        if l:tw_task.last_modified > b:read_time
                            let l:continue =  confirm("The task was modified in taskwarrior after this file was opened. Which version do you want to keep?\nTaskwarrior: ".l:tw_task.description."\nVimwiki:     ".l:task.description, "&Taskwarrior\n&Vimwiki") > 1
                        endif
                        if l:continue
                            call <SID>Task(l:task.task_args.' rc.confirmation=no uuid:'.l:task.uuid.
                                            \ ' modify '.shellescape(l:task.description).' '.
                                            \ <SID>JoinTags(l:task.tags_list).' '.<SID>TagsToRemove(l:tw_task.tags_list, l:task.tags_list).
                                            \ ' '.l:task.task_meta)
                        endif
                    endif
                endif
            endif
        " check if the line is a closed task which was still open when reading the file
        elseif match(l:line, '\v\* \[X\].*#[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}') != -1
            let l:task = vimwiki_tasks#parse_task(l:line, l:defaults)
            if index(b:open_tasks, l:task.uuid) >= 0
                call <SID>Task('uuid:'.l:task.uuid.' done')
            endif
        endif
        let l:i += 1
    endwhile
    " do a new read to sync with TW and to refresh the b:open_tasks list
    call vimwiki_tasks#read()
endfunction

function! vimwiki_tasks#read()
    call vimwiki_tasks#verify_taskwarrior()
    let b:read_time = strftime("%Y-%m-%dT%H:%M")
    let b:open_tasks = []

    " if the file is a tasknote update it first
    if vimwiki_tasks#buffer_is_tasknote()
        call vimwiki_tasks#update_tasknote()
    endif

    " now update all the tasks in lists
    let l:defaults = vimwiki_tasks#get_defaults()
    let l:i = 1
    while l:i <= line('$')
        let l:line = getline(l:i)
        " if this is an open task with a uuid, check if we can update it from TW
        if match(l:line, '\v\* \[[^X]\].*#[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}') != -1
            let l:task = vimwiki_tasks#parse_task(l:line, l:defaults)
            let l:tw_task = vimwiki_tasks#load_task(l:task.uuid)
            if l:tw_task.error != ''
                " task has errors. Notify if not already done before
                if match(l:line, l:tw_task.error) == -1
                    call setline(l:i, l:line.' '.l:tw_task.error)
                    echoerr <SID>ErrorMsg(l:tw_task.error).": ".l:line
                    let &mod = 1
                endif
            elseif l:tw_task.status ==# 'Completed'
                call setline(l:i, vimwiki_tasks#build_task(l:line, l:tw_task, l:task, 1))
                let &mod = 1
            elseif l:tw_task.status ==# 'Deleted'
                " Deleted is already handled above as being an error
            else
                " task is still open in TW, see if it was updated
                if l:task.description !=# l:tw_task.description || l:task.due !=# l:tw_task.due || <SID>JoinTags(l:task.tags_list) !=# <SID>JoinTags(l:tw_task.tags_list)
                    " and replace it in the file
                    call setline(l:i, vimwiki_tasks#build_task(l:line, l:tw_task, l:task))
                    " mark the buffer as modified
                    let &mod = 1
                endif
                " and add the open task to the list for later reference
                call add(b:open_tasks, l:task.uuid)
            end
        endif
        let l:i += 1
    endwhile
    if vimwiki_tasks#config('update_tasklists', 1)
        call vimwiki_tasks#update_task_lists()
    endif
endfunction

function! vimwiki_tasks#get_defaults()
    let l:defaults = {'project': '', 'tags_list': []}
    let l:i = 1
    while l:i <= 10
        let l:line = getline(l:i)
        let l:project = matchstr(l:line, '\v\%\%\s*Project:\s*\zs(\w+)')
        if l:project != ""
            let l:defaults.project = l:project
        endif
        let l:tags = matchstr(l:line, '\v\%\%\s*Tags:\s*\zs(.+)\s*$')
        if l:tags != ""
            let l:defaults.tags_list = <SID>SplitTags(l:tags)
        endif
        let l:i +=1
    endwhile
    return l:defaults
endfunction

" a:1 boolean, 1 if the task should be marked as finished, otherwise the state
"              is reused from the task text
function! vimwiki_tasks#build_task(line, tw_task, task, ...)
    " build the new task line
    let l:match = matchlist(a:line, '\v^(\s*)\* \[(.)\]')
    let l:indent = l:match[1]
    let l:state = l:match[2]
    if a:0 > 0 && a:1 == 1
        let l:state = 'X'
    endif
    let l:newline = l:indent."* [".l:state."] ".a:tw_task.description
    if len(a:tw_task.tags_list) > 0
        " filter the default tags out so they are not added to the line
        let l:tags = copy(a:tw_task.tags_list)
        call filter(l:tags, "!<SID>HasItem(a:task.tags_default, v:val)")
        " if there are still tags left, add them to the line
        if len(l:tags) > 0
            let l:newline .= ' '.<SID>JoinTags(l:tags)
        endif
    endif
    if a:tw_task.due != ""
        " change the T date/time separator into a space
        let l:due_printable = substitute(a:tw_task.due, 'T', " ", "")
        " remove the seconds as we don't use them in Vimwiki
        let l:due_printable = substitute(l:due_printable, '\v:00$', "", "")
        let l:newline .= " (".l:due_printable.")"
    endif
    let l:newline .= " #".a:tw_task.uuid
    return l:newline
endfunction

function s:HasItem(list, item)
    return index(a:list, a:item) != -1
endfunction

function! vimwiki_tasks#parse_task(line, defaults)
    let l:task = vimwiki_tasks#empty_task()
    " create the task
    let l:match = matchlist(a:line, '\v\* \[.\]\s+(.*)\s*')
    let l:task.description = l:match[1]
    " construct the task creation command and create
    let l:task.task_args = ''
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
        " add seconds so we have the correct date/time format
        let l:task.due_time .= ":00"
        " remove date in line
        let l:task.description = substitute(l:task.description, '\v\(\d{4}-\d\d-\d\d( \d\d:\d\d)?\)', "", "")
        " set the due in task_meta
        let l:task.due = l:task.due_date.'T'.l:task.due_time
        let l:task.task_meta .= ' due:'.l:task.due
        " set the dateformat in task_args
        let l:task.task_args .= ' rc.dateformat=Y-M-DTH:N:S'
    endif
    " get the uuid from the task if it is there, and remove it from the task description
    let l:task.uuid = matchstr(a:line, '\v#\zs([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})')
    if l:task.uuid != ""
        let l:task.description = substitute(l:task.description, '\v#[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', "", "")
    endif

    " Parse the normal tags from the description
    call extend(l:task.tags_list, <SID>ParseTags(l:task.description))
    " and remove the tags from the description
    let l:task.description = <SID>StripTags(l:task.description)

    " Parse the default tags. Add them to the tags_list, but also add them to
    " the tags_default list so we can keep track of which tags where added
    " automatically (= should not end up in the vimwiki-line)
    call extend(l:task.tags_list, a:defaults.tags_list)
    call extend(l:task.tags_default, a:defaults.tags_list)
    " add the tags specific for the type of task
    let l:default_tags_key = ''
    if l:task.due == ""
        let l:default_tags_key = 'tags_nodue'
    else
        if get(l:due, 3, '') != ""
            let l:default_tags_key = 'tags_duetime'
        else
            let l:task.tags .= ' '.vimwiki_tasks#config('tags_duedate', '')
            let l:default_tags_key = 'tags_duedate'
        endif
    endif
    let l:task_tags = <SID>SplitTags(vimwiki_tasks#config(l:default_tags_key, ''))
    call extend(l:task.tags_list, l:task_tags)
    call extend(l:task.tags_default, l:task_tags)

    " remove any #TW at the end (= a new task without a due)
    let l:task.description = <SID>RemoveTwIndicator(l:task.description)

    " and strip any whitespace
    let l:task.description = <SID>Strip(l:task.description)

    return l:task
endfunction

function! vimwiki_tasks#load_task(uuid)
    let l:task = vimwiki_tasks#empty_task()
    let l:cmd = 'rc.verbose=nothing rc.defaultwidth=999 rc.dateformat.info=Y-M-DTH:N:S rc.color=off '
                    \ .a:uuid.' info | grep "^\(ID\|UUID\|Description\|Status\|Due\|Project\|Tags\|Last modified\)"'
    let l:result = split(<SID>Task(l:cmd), '\n')
    for l:result_line in l:result
        let l:match = matchlist(l:result_line, '\v(Last modified|\w+)\s+(.*)')
        let l:key = substitute(l:match[1], '\v\s+', '_', 'g')
        let l:task[tolower(l:key)] = l:match[2]
    endfor
    " check for any errors
    if l:task.uuid == ''
        let l:task.error = 'TASK_NOT_FOUND'
    elseif l:task.status ==# 'Deleted'
        let l:task.error = 'TASK_DELETED'
    endif
    " get the correct modification date
    if l:task.last_modified != -1
        let l:datetime = matchstr(l:task.last_modified, '\v\S{19}')
        if l:datetime != ''
            let l:task.last_modified = l:datetime
        endif
    endif
    " split the tags
    let l:task.tags_list = <SID>SplitTags(l:task.tags)
    return l:task
endfunction

function! s:Strip(input_string)
    return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

function! s:RemoveTwIndicator(input)
    return substitute(a:input, '\v\s?#TW\s*$', "", "")
endfunction

function! s:SplitTags(tagstr)
    let l:tags = split(a:tagstr, '\v\s+')
    let l:i = 0
    while l:i < len(l:tags)
        if match(l:tags[l:i], '\v^\+') == -1
            let l:tags[l:i] = '+'.l:tags[l:i]
        endif
        let l:i += 1
    endwhile
    return l:tags
endfunction

function! s:ParseTags(str)
    let l:tags = []
    let l:i = 1
    while l:i != -1
        let l:tag = matchstr(a:str, '\v(\+\w+)', 0, l:i)
        if l:tag == ''
            let l:i = -1
        else
            call add(l:tags, l:tag)
            let l:i += 1
        endif
    endwhile
    return l:tags
endfunction

function! s:StripTags(str)
    " strip tags
    let l:str = substitute(a:str, '\v\+\w+', '', 'g')
    " strip multiple spaces
    let l:str = substitute(l:str, '\v\s+', ' ', 'g')
    " strip spaces
    return <SID>Strip(l:str)
endfunction

function! s:JoinTags(taglist)
    call sort(a:taglist)
    return join(a:taglist, ' ')
endfunction

function! s:TagsToRemove(old_tags, new_tags)
    let l:remove = []
    for l:tag in a:old_tags
        if index(a:new_tags, l:tag) == -1
            call add(l:remove, l:tag)
        endif
    endfor
    let l:remove_str = <SID>JoinTags(l:remove)
    " replace the + sign by a - sign so the tags are removed by TW
    return substitute(l:remove_str, '\v\+', '-', 'g')
endfunction

function! s:System(cmd)
    " echom a:cmd
    return system(a:cmd)
endfunction

function! s:Task(args)
    " execute task with the given args + any optional args specified by the user
    return system('task '.vimwiki_tasks#config('task_args', '').' '.a:args)
endfunction

function! s:ErrorMsg(error)
    if a:error ==# 'TASK_DELETED'
        return 'Task was deleted in taskwarrior'
    elseif a:error ==# 'TASK_NOT_FOUND'
        return 'Task was not found in taskwarrior'
    endif
    return 'Unknown error'
endfunction

function! vimwiki_tasks#empty_task()
    return {
        \ 'id': 0,
        \'uuid': '',
        \ 'description': '',
        \ 'due': '',
        \ 'status': '',
        \ 'project': '',
        \ 'tags': '',
        \ 'tags_list': [],
        \ 'tags_default': [],
        \ 'error': '',
        \ 'last_modified': -1,
    \ }
endfunction

function! vimwiki_tasks#config(key, default)
    if exists('g:vimwiki_tasks_'.a:key)
        return g:vimwiki_tasks_{a:key}
    endif
    return a:default
endfunction

function! vimwiki_tasks#verify_taskwarrior()
    if !executable('task')
        throw "`task` not found or not executable"
    endif
endfunction

function! vimwiki_tasks#display_task_id(copy_to_clipboard)
    let l:uuid = matchstr(getline(line('.')), '\v\* \[.\].*#\zs[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    if l:uuid != ''
        let l:tw_task = vimwiki_tasks#load_task(l:uuid)
        let l:msg = "Task ID: ".l:tw_task.id
        if (a:copy_to_clipboard)
            let @+ = l:tw_task.id
            let l:msg .= ", copied to clipboard"
        endif
        echo l:msg
    else
        echo "Could not find a task on this line!"
    endif
endfunction

function! vimwiki_tasks#display_task_uuid(copy_to_clipboard)
    let l:uuid = matchstr(getline(line('.')), '\v\* \[.\].*#\zs[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    if l:uuid != ''
        let l:msg = "Task UUID: ".l:uuid
        if a:copy_to_clipboard
            let @+ = l:uuid
            let l:msg .= ", copied to clipboard"
        endif
        echo l:msg
    else
        echo "Could not find a task on this line!"
    endif
endfunction

function! s:UuidsInBuffer()
    let l:i = 1
    let l:uuids = []
    while l:i <= line('$')
        let l:uuid = matchstr(getline(l:i), '\v\* \[.\].*#\zs[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
        if l:uuid != ''
            call add(l:uuids, l:uuid)
        endif
        let l:i += 1
    endwhile
    return l:uuids
endfunction

" a:1 boolean, if 1 the tasklist filter will be inserted, otherwise not (not
" that the config parameter is also taken into account, but it can be
" overriden by setting a:1 to a value other than 1. This case is used during
" the updating of the taskslists where the filter should not be inserted again
function! vimwiki_tasks#insert_tasks(filter, bang, line, ...)
    echo "Loading tasks..."
    redraw
    let l:report = vimwiki_tasks#config('report', 'all')
    let l:cmd = l:report
    let l:cmd .= ' rc.report.'.l:report.'.columns=uuid rc.report.'.l:report.'.labels=UUID rc.verbose=nothing '
    let l:cmd .= a:filter
    let l:uuids = split(<SID>Task(l:cmd), '\n')
    let l:empty_task = vimwiki_tasks#empty_task()
    let l:lines = []
    let l:uuids_in_buffer = <SID>UuidsInBuffer()
    for l:uuid in l:uuids
        if a:bang == '!' || index(l:uuids_in_buffer, l:uuid) == -1
            let l:tw_task = vimwiki_tasks#load_task(l:uuid)
            let l:line = vimwiki_tasks#build_task('* [ ]', l:tw_task, l:empty_task, l:tw_task.status == 'Completed')
            call add(l:lines, l:line)
        endif
    endfor
    let l:num_added = 0
    if len(l:lines) > 0
        " XXX: check if current line is empty and replace it, otherwise append?
        if vimwiki_tasks#config('include_tasklist', 1) && (a:0 == 0 || a:0 > 0 && a:1 == 1)
            let l:num_added += 1
            call append(a:line, '%% TaskList: '.a:filter)
        endif
        call append(a:line + l:num_added, l:lines)
        " fix the indent of the new lines
        exec "normal! ".(len(l:lines)+1)."=="
        redraw " get rid of the 'XX lines indented' message
        " and set the '[ to the first new line
        normal jm[
    endif
    echo "Inserted ".len(l:lines)." task(s)"
    return len(l:lines) + l:num_added
endfunction

" TODO: make it also work on a tasknote file
" TODO: add a `:TaskModify` command (with optional confirmation)
function! vimwiki_tasks#current_task_do(task_cmd)
    " TODO: shellescape?
    let l:line = getline(line('.'))
    let l:uuid = matchstr(l:line, '\v\* \[.\].*#\zs[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    if l:uuid != ''
        let l:tw_task_before = vimwiki_tasks#load_task(l:uuid)
        let l:cmd = "!task ".vimwiki_tasks#config('task_args', '')." ".l:uuid." ".a:task_cmd
        if has("gui_running")
            let l:cmd .= " rc.color=off rc.defaultwidth=".&columns
        endif
        execute l:cmd
        " and rebuild the task if the last_modified has changed
        let l:tw_task = vimwiki_tasks#load_task(l:uuid)
        if l:tw_task_before.last_modified != l:tw_task.last_modified
            let l:task = vimwiki_tasks#parse_task(l:line, vimwiki_tasks#get_defaults())
            let l:new_line = vimwiki_tasks#build_task(l:line, l:tw_task, l:task, l:tw_task.status == 'Completed')
            call setline('.', l:new_line)
            let &mod = 1
        endif
    else
        echo "Could not find a task on this line!"
    endif
endfunction

function! vimwiki_tasks#update_task_lists()
    let l:i = 1
    while l:i <= line('$')
        let l:line = getline(l:i)
        let l:tasklist = matchstr(l:line, '\v\%\%\s*TaskList:\s*\zs(.*$)')
        if l:tasklist != ''
            " ok we found a tasklist, try to add new tasks
            let l:num_added = 0
            let l:num_added += vimwiki_tasks#insert_tasks(l:tasklist, '', l:i, 0)
            let l:i += l:num_added + 1
        else
            let l:i += 1
        endif
    endwhile
endfunction

function! vimwiki_tasks#load_full_task(uuid)
    " TODO: check how blocked and blocking tasks are presented
    let l:cmd = 'rc.verbose=labels rc.defaultwidth=999 rc.dateformat.info=Y-M-D\ H:N:S rc.color=off '.a:uuid.' info'
    let l:result = split(<SID>Task(l:cmd), '\n')
    let l:task_details = {'details': [], 'annotations': [], 'description': '', 'last_modified': ''}
    if len(l:result) > 5 " for a valid task we will have at least 5 lines or so
        let l:i = 3
        " get the width of the labels, yes this is dirty but avoids having to
        " depend on a JSON parser
        let l:width = matchstr(l:result[1], '\v^\-+')
        let l:width = strlen(l:width)
        while l:i < len(l:result)
            if match(l:result[l:i], '\v^\s*$') != -1
                " last detail line reached before the history log
                break
            else
                let l:match = matchlist(l:result[l:i], '\v^(.{'.l:width.'})(.*)')
                if match(l:match[1], '\v^\s+$') > -1
                    call add(l:task_details.annotations, '* '.<SID>Strip(l:match[2]))
                elseif match(l:match[1], '\v^Description|UUID') == -1
                    call add(l:task_details.details, l:match[1].'::'.l:match[2])
                endif
                " store the description in a separate key
                if match(l:match[1], '\v^Description') != -1
                    let l:task_details.description = l:match[2]
                endif
                " store the last modified also in a separate key
                if match(l:match[1], '\v^Last modified') != -1
                    let l:task_details.last_modified = l:match[1].'::'.l:match[2]
                endif
            endif
            let l:i += 1
        endwhile
    endif
    return l:task_details
endfunction

function! s:TaskNotesPath()
    let l:path = VimwikiGet('path')
    let l:path .= vimwiki_tasks#config('note_path', '')
    if match(l:path, '\v/$') == -1
        let l:path .= '/'
    endif
    echom l:path
    return l:path
endfunction

function! vimwiki_tasks#open_tasknotes()
    " TODO: load the correct task note path from the task annotations
    let l:line = getline(line('.'))
    " TODO: make sure it works on any UUID
    let l:uuid = matchstr(l:line, '\v\* \[.\].*#\zs[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    if l:uuid != ''
        let l:tw_task = vimwiki_tasks#load_task(l:uuid)
        let l:taskpath = <SID>TaskNotesPath().l:uuid.".".expand('%:e')
        execute "edit ".l:taskpath
        if glob(l:taskpath, 1) == ''
            " file does not yet exist on disk, fill the buffer with the initial content
            call vimwiki_tasks#insert_task_details(l:uuid)
            " Insert the notes header
            " call append(line('$'), '')
            call append(line('$') - 1, <SID>CreateHeader('Notes'))
            " put the cursor on the last line
            normal G
        endif
    else
        echo "Could not find a task on this line!"
    endif
endfunction

function! vimwiki_tasks#insert_task_details(uuid)
    let l:details = vimwiki_tasks#load_full_task(a:uuid)
    call append(0, '%% TaskUUID: '.a:uuid)
    call append(1, '')
    call append(2, <SID>Strip(l:details.description))
    normal 3gg
    call vimwiki#base#AddHeaderLevel()
    call append(3, <SID>CreateHeader('Task details'))
    let l:i = 4
    for l:detail in l:details.details
        call append(l:i, l:detail)
        let l:i += 1
    endfor
    call append(0 + l:i, '')
    call append(1 + l:i, <SID>CreateHeader('Annotations'))
    let l:i += 2
    for l:annotation in l:details.annotations
        call append(l:i, l:annotation)
        let l:i += 1
    endfor
    call append(l:i, '')
endfunction

function! vimwiki_tasks#buffer_is_tasknote()
    return match(getline(1), '\v^\%\% TaskUUID: [0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}') != -1
endfunction

function! vimwiki_tasks#update_tasknote()
    " TODO: error checking?
    let l:uuid = matchstr(getline(1), '\v^\%\% TaskUUID: \zs[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    let l:tw_full_task = vimwiki_tasks#load_full_task(l:uuid)
    let l:i = 2
    let l:last_modified_line = ''
    let l:last_header_match = 0
    while l:i < line('$')
        let l:line = getline(l:i)
        " find the last modified line, this will be used to check if the task
        " details should be updated
        if match(l:line, '\v^Last modified') != -1
            let l:last_modified_line = l:line
        endif
        " check if we already match the Annotations header
        if match(l:line, '\v^'.<SID>CreateHeader('Annotations')) != -1
            let l:last_header_match = 1
        endif
        " check if we are past the last header, then the first empty line
        " means the end of the generated content and the start of the actual
        " note which should be left untouched
        if l:last_header_match && match(l:line, '\v^\s*$') != -1
            " ok last generated line reached, break out of the loop
            " l:i now also contains the line number where the generated
            " content ends
            break
        endif
        let l:i += 1
    endwhile

    " update the task if it is was updated
    if l:last_modified_line != l:tw_full_task.last_modified
        " remove the old copy of the task details
        execute '1,'.l:i.'delete'
        " and insert the new updated details
        call vimwiki_tasks#insert_task_details(l:uuid)
        redraw " get rid of the 'xx fewer lines'
        let &mod = 1
        echo "Updated the task details"
    endif
endfunction

function! s:CreateHeader(header)
    let hdr = g:vimwiki_rxH.g:vimwiki_rxH.' '.a:header
    if g:vimwiki_symH
        let hdr .= ' '.g:vimwiki_rxH.g:vimwiki_rxH
    endif
    return hdr
endfunction
