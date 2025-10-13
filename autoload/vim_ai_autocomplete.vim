let s:plugin_root = expand('<sfile>:p:h:h')
let s:timer_id = -1
let s:is_active = 0
let s:needs_reschedule = 0
let s:setup_done = 0

let s:is_nvim = has('nvim')
if s:is_nvim
  let s:ns_id = nvim_create_namespace('vim_ai_autocomplete')
else
  let s:ns_id = -1
endif

let s:ghost_state = {
      \ 'bufnr': -1,
      \ 'id': -1,
      \ 'text': '',
      \ 'request_id': 0,
      \ }
let s:active_request_id = 0
let s:active_cancelled = 0
let s:ghost_prop_type = 'vim_ai_autocomplete_ghost'
let s:ghost_resources_ready = 0
let s:mappings_applied = 0

function! s:EnsurePythonModules() abort
  if !has('python3')
    return
  endif
  for py_module in ['types', 'utils', 'context', 'complete', 'autocomplete']
    if !py3eval("'" . py_module . "_py_imported' in globals()")
      execute 'py3file ' . s:plugin_root . '/py/' . py_module . '.py'
    endif
  endfor
endfunction

function! s:ResetGhostState() abort
  let s:ghost_state = {
        \ 'bufnr': -1,
        \ 'id': -1,
        \ 'text': '',
        \ 'request_id': 0,
        \ }
endfunction

function! s:EnsureGhostResources() abort
  if s:ghost_resources_ready
    return
  endif
  let s:ghost_resources_ready = 1
  if !hlexists('VimAIAutocompleteGhostText')
    silent! execute 'highlight default link VimAIAutocompleteGhostText Comment'
  endif
  if !s:is_nvim && exists('*prop_type_add')
    if exists('*prop_type_get')
      let l:type_info = prop_type_get(s:ghost_prop_type)
    else
      let l:type_info = {}
    endif
    if empty(l:type_info)
      call prop_type_add(s:ghost_prop_type, {
            \ 'highlight': 'VimAIAutocompleteGhostText',
            \ 'combine': 1,
            \ 'priority': 99,
            \ })
    endif
  endif
endfunction

function! vim_ai_autocomplete#ClearGhostText() abort
  if s:ghost_state['bufnr'] == -1
    return
  endif
  if s:is_nvim
    if bufexists(s:ghost_state['bufnr'])
      call nvim_buf_clear_namespace(s:ghost_state['bufnr'], s:ns_id, 0, -1)
    endif
  elseif exists('*prop_remove') && bufexists(s:ghost_state['bufnr'])
    call prop_remove(s:ghost_prop_type, 1, -1, {'bufnr': s:ghost_state['bufnr']})
  endif
  call s:ResetGhostState()
endfunction

function! vim_ai_autocomplete#HasGhostText() abort
  return s:ghost_state['bufnr'] != -1 && s:ghost_state['text'] !=# ''
endfunction

function! s:ShowGhostText(text, request_id) abort
  call vim_ai_autocomplete#ClearGhostText()
  if a:text ==# ''
    return
  endif
  call s:EnsureGhostResources()
  let l:lines = split(a:text, "\n", 1)
  let l:first_line = get(l:lines, 0, '')
  let s:ghost_state['text'] = a:text
  let s:ghost_state['bufnr'] = bufnr('%')
  let s:ghost_state['request_id'] = a:request_id
  if s:is_nvim
    let l:virt_text = [[l:first_line, 'VimAIAutocompleteGhostText']]
    let l:opts = {
          \ 'virt_text': l:virt_text,
          \ 'virt_text_pos': 'overlay',
          \ 'hl_mode': 'combine',
          \ }
    if len(l:lines) > 1
      let l:opts['virt_lines'] = map(l:lines[1:], {idx, val -> [[val, 'VimAIAutocompleteGhostText']]})
    endif
    let l:id = nvim_buf_set_extmark(0, s:ns_id, line('.') - 1, col('.') - 1, l:opts)
    let s:ghost_state['id'] = l:id
  elseif exists('*prop_add')
    let l:display = l:first_line
    if len(l:lines) > 1
      let l:display .= ' …'
    endif
    try
      let l:prop_id = prop_add(line('.'), col('.'), {
            \ 'bufnr': s:ghost_state['bufnr'],
            \ 'type': s:ghost_prop_type,
            \ 'text': l:display,
            \ 'text_align': 'after',
            \ 'hl_mode': 'combine',
            \ })
      let s:ghost_state['id'] = l:prop_id
    catch /^Vim\%((\a\+)\)\=:/
      call s:ResetGhostState()
    endtry
  endif
endfunction

function! s:OnUserActivity(event) abort
  call vim_ai_autocomplete#ClearGhostText()
  if s:is_active && (a:event ==# 'text' || a:event ==# 'cursor')
    let s:active_cancelled = 1
  endif
endfunction

function! s:KeyAsTermcodes(key) abort
  if a:key ==# ''
    return ''
  endif
  let l:escaped = substitute(a:key, '\\', '\\\\', 'g')
  let l:escaped = substitute(l:escaped, '"', '\\"', 'g')
  return eval('"' . l:escaped . '"')
endfunction

function! s:CommitCompletion() abort
  if !vim_ai_autocomplete#HasGhostText()
    return ''
  endif
  let l:text = s:ghost_state['text']
  call vim_ai_autocomplete#ClearGhostText()
  if exists('g:vim_ai_autocomplete_state') && type(g:vim_ai_autocomplete_state) == v:t_dict
    let g:vim_ai_autocomplete_state['completion'] = ''
  endif
  return "\<C-g>u" . l:text . "\<C-g>u"
endfunction

function! vim_ai_autocomplete#AcceptMapping() abort
  if vim_ai_autocomplete#HasGhostText()
    return s:CommitCompletion()
  endif
  return s:KeyAsTermcodes(get(g:, 'vim_ai_autocomplete_accept_key', '<Tab>'))
endfunction

function! vim_ai_autocomplete#DismissMapping() abort
  if vim_ai_autocomplete#HasGhostText()
    call vim_ai_autocomplete#ClearGhostText()
    if exists('g:vim_ai_autocomplete_state') && type(g:vim_ai_autocomplete_state) == v:t_dict
      let g:vim_ai_autocomplete_state['completion'] = ''
    endif
    return ''
  endif
  return s:KeyAsTermcodes(get(g:, 'vim_ai_autocomplete_dismiss_key', '<C-]>'))
endfunction

function! s:MapInsertKey(key, plug_mapping) abort
  if a:key ==# ''
    return
  endif
  let l:info = maparg(a:key, 'i', 0, 1)
  if !empty(l:info) && get(l:info, 'rhs', '') !~ a:plug_mapping
    return
  endif
  if !empty(l:info)
    execute 'silent! iunmap ' . a:key
  endif
  execute 'inoremap <silent> ' . a:key . ' ' . a:plug_mapping
endfunction

function! s:EnsurePlugMappings() abort
  silent! iunmap <Plug>(VimAIAutocompleteAccept)
  silent! iunmap <Plug>(VimAIAutocompleteDismiss)
  inoremap <silent><expr> <Plug>(VimAIAutocompleteAccept) vim_ai_autocomplete#AcceptMapping()
  inoremap <silent><expr> <Plug>(VimAIAutocompleteDismiss) vim_ai_autocomplete#DismissMapping()
endfunction

function! s:ApplyMappings() abort
  if s:mappings_applied
    return
  endif
  let s:mappings_applied = 1
  if !exists('g:vim_ai_autocomplete_accept_key')
    let g:vim_ai_autocomplete_accept_key = '<Tab>'
  endif
  if !exists('g:vim_ai_autocomplete_dismiss_key')
    let g:vim_ai_autocomplete_dismiss_key = '<C-]>'
  endif
  call s:EnsurePlugMappings()
  call s:MapInsertKey(g:vim_ai_autocomplete_accept_key, '<Plug>(VimAIAutocompleteAccept)')
  call s:MapInsertKey(g:vim_ai_autocomplete_dismiss_key, '<Plug>(VimAIAutocompleteDismiss)')
endfunction

function! vim_ai_autocomplete#Setup() abort
  if s:setup_done
    return
  endif
  let s:setup_done = 1
  if !has('timers') || !has('python3')
    return
  endif
  call s:EnsureGhostResources()
  call s:ResetGhostState()
  call s:EnsurePythonModules()
  call s:ApplyMappings()
  augroup VimAIAutocomplete
    autocmd!
    autocmd TextChanged,TextChangedI * call vim_ai_autocomplete#HandleEvent('text')
    autocmd CursorMoved,CursorMovedI * call vim_ai_autocomplete#HandleEvent('cursor')
    autocmd BufLeave,BufUnload * call vim_ai_autocomplete#CancelTimer()
    autocmd OptionSet buftype call vim_ai_autocomplete#CancelTimer()
    autocmd OptionSet modifiable call vim_ai_autocomplete#CancelTimer()
    autocmd InsertLeave * call vim_ai_autocomplete#ClearGhostText()
    autocmd BufEnter * call vim_ai_autocomplete#ClearGhostText()
  augroup END
endfunction

function! vim_ai_autocomplete#HandleEvent(event) abort
  call s:OnUserActivity(a:event)
  if !vim_ai_autocomplete#ShouldTrigger()
    call vim_ai_autocomplete#CancelTimer()
    let s:needs_reschedule = 0
    return
  endif
  if s:is_active
    let s:needs_reschedule = 1
    return
  endif
  call vim_ai_autocomplete#Schedule()
endfunction

function! vim_ai_autocomplete#Schedule() abort
  call vim_ai_autocomplete#CancelTimer()
  let s:needs_reschedule = 0
  let l:delay = vim_ai_autocomplete#get_debounce_ms()
  if l:delay <= 0
    call vim_ai_autocomplete#RunPipeline()
    return
  endif
  let s:timer_id = timer_start(l:delay, function('vim_ai_autocomplete#OnTimer'))
endfunction

function! vim_ai_autocomplete#CancelTimer() abort
  if s:timer_id != -1
    call timer_stop(s:timer_id)
    let s:timer_id = -1
  endif
  call vim_ai_autocomplete#ClearGhostText()
endfunction

function! vim_ai_autocomplete#OnTimer(timer) abort
  let s:timer_id = -1
  if !vim_ai_autocomplete#ShouldTrigger()
    return
  endif
  call vim_ai_autocomplete#RunPipeline()
endfunction

function! vim_ai_autocomplete#RunPipeline() abort
  if s:is_active
    return
  endif
  let s:is_active = 1
  let s:active_cancelled = 0
  let s:active_request_id += 1
  let l:request_id = s:active_request_id
  try
    call s:EnsurePythonModules()
    let l:config = { 'context_lines': g:vim_ai_autocomplete_context_lines }
    let l:result = py3eval("autocomplete.request_autocomplete(unwrap('l:config'))")
    let l:completion = get(l:result, 'completion', '')
    let g:vim_ai_autocomplete_state = {
          \ 'completion': l:completion,
          \ 'prompt': get(l:result, 'prompt', ''),
          \ 'metadata': get(l:result, 'metadata', {}),
          \ 'request_id': l:request_id,
          \ }
    if l:completion ==# '' || s:active_cancelled || !vim_ai_autocomplete#ShouldTrigger()
      call vim_ai_autocomplete#ClearGhostText()
    else
      call s:ShowGhostText(l:completion, l:request_id)
    endif
  finally
    let l:reschedule = s:needs_reschedule
    let s:needs_reschedule = 0
    let s:is_active = 0
    if l:reschedule && vim_ai_autocomplete#ShouldTrigger()
      call vim_ai_autocomplete#Schedule()
    endif
  endtry
endfunction

function! vim_ai_autocomplete#ShouldTrigger() abort
  if !exists('g:vim_ai_autocomplete_enabled') || !g:vim_ai_autocomplete_enabled
    return 0
  endif
  if !has('timers') || !has('python3')
    return 0
  endif
  call s:EnsurePythonModules()
  return py3eval("bool(autocomplete.should_trigger())") ? 1 : 0
endfunction

function! vim_ai_autocomplete#get_debounce_ms() abort
  return str2nr(g:vim_ai_autocomplete_debounce_ms)
endfunction
