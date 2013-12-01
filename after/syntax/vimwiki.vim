syn match VimwikiTag /\v\+[a-zA-Z0-9:_-]+/ containedin=VimwikiTableRow
hi link VimwikiTag VimwikiTodo

syn match VimwikiDate /\v\(\d{4}-\d\d-\d\d( \d\d:\d\d)?\)/
hi link VimwikiDate VimwikiCheckBox

let s:conceal = exists("+conceallevel") ? ' conceal cchar=T' : ''
execute 'syn match VimwikiTaskUuid containedin=VimwikiCheckBoxDone /\v#[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/'.s:conceal
hi link VimwikiTaskUuid Comment

syn match TaskError /\vTASK_NOT_FOUND|TASK_DELETED/
hi link TaskError Error
