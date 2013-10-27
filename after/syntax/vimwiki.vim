syn match VimwikiTag /\v\+[a-zA-Z0-9:_-]+/ containedin=VimwikiTableRow
hi link VimwikiTag VimwikiTodo

syn match VimwikiDate /\v\(\d{4}-\d\d-\d\d( \d\d:\d\d)?\)/
hi link VimwikiDate VimwikiCheckBox

syn match VimwikiTaskUuid /\v#[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
hi link VimwikiTaskUuid Comment
