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

let s:has_textprops = !s:is_nvim && has('patch-9.0.0178') && exists('*prop_add') && exists('*prop_remove')

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
let s:log_error = ''
let s:log_initialized = 0

function! s:LogEnabled() abort
  return exists('g:vim_ai_autocomplete_logs') && type(g:vim_ai_autocomplete_logs) == v:t_string && g:vim_ai_autocomplete_logs !=# ''
endfunction

function! s:MaybeInitLog() abort
  if s:log_initialized || !s:LogEnabled()
    return
  endif
  let s:log_initialized = 1
  let l:timestamp = strftime('%Y-%m-%d %H:%M:%S')
  let l:message = printf('vim_ai_autocomplete logging initialised is_nvim=%s has_textprops=%s setup_done=%s',
        \ string(s:is_nvim), string(s:has_textprops), string(s:setup_done))
  try
    call writefile([printf('[%s] %s', l:timestamp, l:message)], g:vim_ai_autocomplete_logs, 'a')
  catch /^Vim\%((\a\+)\)\=:/
    let s:log_error = v:exception
  endtry
endfunction

function! s:Log(message, ...) abort
  call s:MaybeInitLog()
  if !s:LogEnabled()
    return
  endif
  if type(a:message) == v:t_string
    let l:payload = a:message
  else
    let l:payload = string(a:message)
  endif
  if a:0 > 0
    let l:segments = map(copy(a:000), 'string(v:val)')
    if l:payload !=# ''
      let l:payload .= ' '
    endif
    let l:payload .= join(l:segments, ' ')
  endif
  let l:lines = split(l:payload, "\n", 1)
  let l:timestamp = strftime('%Y-%m-%d %H:%M:%S')
  let l:entries = map(l:lines, {_, line -> printf('[%s] %s', l:timestamp, line)})
  try
    call writefile(l:entries, g:vim_ai_autocomplete_logs, 'a')
  catch /^Vim\%((\a\+)\)\=:/
    let s:log_error = v:exception
  endtry
endfunction

function! s:EnsurePythonModules() abort
  call s:Log('EnsurePythonModules invoked')
  if !has('python3')
    call s:Log('EnsurePythonModules skipped: python3 not available')
    return
  endif
  let l:py_root = s:plugin_root . '/py'
  let l:py_root_repr = string(l:py_root)
  execute 'py3 import sys'
  execute 'py3 import importlib'
  execute 'py3 py_root = ' . l:py_root_repr
  if !py3eval('py_root in sys.path')
    call s:Log('EnsurePythonModules adding to sys.path', l:py_root)
    execute 'py3 sys.path.insert(0, py_root)'
  else
    call s:Log('EnsurePythonModules sys.path already contains', l:py_root)
  endif
  for py_module in ['types', 'utils', 'context', 'complete', 'autocomplete']
    let l:module_repr = string(py_module)
    if py3eval('sys.modules.get(' . l:module_repr . ', None) is not None')
      call s:Log('EnsurePythonModules module already in sys.modules', py_module)
      if !py3eval("globals().get('" . py_module . "', None) is not None")
        call s:Log('EnsurePythonModules binding existing module to globals', py_module)
        try
          execute printf("py3 globals()['%s'] = sys.modules[%s]", py_module, l:module_repr)
        catch /^Vim\%((\a\+)\)\=:/
          call s:Log('EnsurePythonModules binding failed', py_module, v:exception)
          throw v:exception
        endtry
      endif
      continue
    endif
    call s:Log('EnsurePythonModules importing module', py_module)
    let l:cmd = printf("py3 globals()['%s'] = importlib.import_module(%s)", py_module, l:module_repr)
    try
      execute l:cmd
      call s:Log('EnsurePythonModules module available', py_module)
    catch /^Vim\%((\a\+)\)\=:/
      call s:Log('EnsurePythonModules module load failed', py_module, v:exception)
      throw v:exception
    endtry
  endfor
  if py3eval("globals().get('utils', None) is not None")
    call s:Log('EnsurePythonModules exposing helpers from utils')
    try
      execute "py3 globals()['unwrap'] = globals()['utils'].unwrap"
    catch /^Vim\%((\a\+)\)\=:/
      call s:Log('EnsurePythonModules failed to expose unwrap', v:exception)
    endtry
  endif
endfunction

function! s:ResetGhostState() abort
  call s:Log('ResetGhostState invoked with state=' . string(s:ghost_state))
  let s:ghost_state = {
        \ 'bufnr': -1,
        \ 'id': -1,
        \ 'text': '',
        \ 'request_id': 0,
        \ }
  call s:Log('ResetGhostState completed')
endfunction

function! s:EnsureGhostResources() abort
  call s:Log('EnsureGhostResources invoked ready=' . string(s:ghost_resources_ready) . ' has_textprops=' . string(s:has_textprops))
  if s:ghost_resources_ready
    call s:Log('EnsureGhostResources skipped: already ready')
    return
  endif
  let s:ghost_resources_ready = 1
  if !hlexists('VimAIAutocompleteGhostText')
    call s:Log('EnsureGhostResources defining highlight VimAIAutocompleteGhostText')
    silent! execute 'highlight default link VimAIAutocompleteGhostText Comment'
  else
    call s:Log('EnsureGhostResources highlight already defined')
  endif
  if s:has_textprops && exists('*prop_type_add')
    if exists('*prop_type_get')
      let l:type_info = prop_type_get(s:ghost_prop_type)
    else
      let l:type_info = {}
    endif
    if empty(l:type_info)
      call s:Log('EnsureGhostResources registering text prop type')
      call prop_type_add(s:ghost_prop_type, {
            \ 'highlight': 'VimAIAutocompleteGhostText',
            \ 'combine': 1,
            \ 'priority': 99,
            \ })
    else
      call s:Log('EnsureGhostResources text prop type already exists')
    endif
  else
    call s:Log('EnsureGhostResources text props unavailable, skipping registration')
  endif
endfunction

function! vim_ai_autocomplete#ClearGhostText() abort
  call s:Log('ClearGhostText invoked state=' . string(s:ghost_state))
  if s:ghost_state['bufnr'] == -1
    call s:Log('ClearGhostText skipped: no active ghost state')
    return
  endif
  if s:is_nvim
    call s:Log('ClearGhostText clearing nvim namespace bufnr=' . string(s:ghost_state['bufnr']))
    if bufexists(s:ghost_state['bufnr'])
      call nvim_buf_clear_namespace(s:ghost_state['bufnr'], s:ns_id, 0, -1)
    endif
  elseif s:has_textprops && bufexists(s:ghost_state['bufnr'])
    call s:Log('ClearGhostText removing text property bufnr=' . string(s:ghost_state['bufnr']))
    call prop_remove(s:ghost_prop_type, 1, -1, {'bufnr': s:ghost_state['bufnr']})
  else
    call s:Log('ClearGhostText no removal method available')
  endif
  call s:ResetGhostState()
endfunction

function! vim_ai_autocomplete#HasGhostText() abort
  let l:has = s:ghost_state['bufnr'] != -1 && s:ghost_state['text'] !=# ''
  call s:Log('HasGhostText evaluated result=' . string(l:has))
  return l:has
endfunction

function! s:ShowGhostText(text, request_id) abort
  call s:Log('ShowGhostText invoked text=' . string(a:text) . ' request_id=' . string(a:request_id))
  call vim_ai_autocomplete#ClearGhostText()
  if a:text ==# ''
    call s:Log('ShowGhostText aborted: empty text')
    return
  endif
  call s:EnsureGhostResources()
  let l:lines = split(a:text, "\n", 1)
  let l:first_line = get(l:lines, 0, '')
  let s:ghost_state['text'] = a:text
  let s:ghost_state['bufnr'] = bufnr('%')
  let s:ghost_state['request_id'] = a:request_id
  call s:Log('ShowGhostText processed first_line=' . string(l:first_line) . ' total_lines=' . string(len(l:lines)))
  if s:is_nvim
    let l:display = l:first_line
    let l:chunks = [[l:display, 'VimAIAutocompleteGhostText']]
    if len(l:lines) > 1
      let l:display .= ' …'
      let l:chunks = [[l:display, 'VimAIAutocompleteGhostText']]
    endif
    let l:opts = {
          \ 'virt_text_pos': 'overlay',
          \ 'hl_mode': 'combine',
          \ 'col': col('.') - 1,
          \ }
    let l:id = nvim_buf_set_virtual_text(0, s:ns_id, line('.') - 1, l:chunks, l:opts)
    let s:ghost_state['id'] = l:id
    call s:Log('ShowGhostText set virtual text id=' . string(l:id) . ' display=' . string(l:display))
  elseif s:has_textprops
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
      call s:Log('ShowGhostText added text property id=' . string(l:prop_id) . ' display=' . string(l:display))
    catch /^Vim\%((\a\+)\)\=:/
      call s:Log('ShowGhostText exception=' . string(v:exception))
      call s:ResetGhostState()
    endtry
  else
    call s:Log('ShowGhostText no rendering method available')
  endif
endfunction

function! s:OnUserActivity(event) abort
  call s:Log('OnUserActivity event=' . string(a:event) . ' is_active=' . string(s:is_active))
  call vim_ai_autocomplete#ClearGhostText()
  if s:is_active && (a:event ==# 'text' || a:event ==# 'cursor')
    let s:active_cancelled = 1
    call s:Log('OnUserActivity cancelled active request')
  endif
endfunction

function! s:KeyAsTermcodes(key) abort
  call s:Log('KeyAsTermcodes input=' . string(a:key))
  if a:key ==# ''
    call s:Log('KeyAsTermcodes returning empty string')
    return ''
  endif
  let l:escaped = substitute(a:key, '\\', '\\\\', 'g')
  let l:escaped = substitute(l:escaped, '"', '\\"', 'g')
  let l:result = eval('"' . l:escaped . '"')
  call s:Log('KeyAsTermcodes output=' . string(l:result))
  return l:result
endfunction

function! s:CommitCompletion() abort
  call s:Log('CommitCompletion invoked')
  if !vim_ai_autocomplete#HasGhostText()
    call s:Log('CommitCompletion aborted: no ghost text')
    return ''
  endif
  let l:text = s:ghost_state['text']
  call s:Log('CommitCompletion committing text=' . string(l:text))
  call vim_ai_autocomplete#ClearGhostText()
  if exists('g:vim_ai_autocomplete_state') && type(g:vim_ai_autocomplete_state) == v:t_dict
    let g:vim_ai_autocomplete_state['completion'] = ''
    call s:Log('CommitCompletion cleared g:vim_ai_autocomplete_state completion')
  endif
  let l:result = "\<C-g>u" . l:text . "\<C-g>u"
  call s:Log('CommitCompletion returning keys=' . string(l:result))
  return l:result
endfunction

function! vim_ai_autocomplete#AcceptMapping() abort
  call s:Log('AcceptMapping invoked')
  if vim_ai_autocomplete#HasGhostText()
    call s:Log('AcceptMapping committing ghost text')
    return s:CommitCompletion()
  endif
  let l:key = get(g:, 'vim_ai_autocomplete_accept_key', '<Tab>')
  call s:Log('AcceptMapping delegating to original key=' . string(l:key))
  return s:KeyAsTermcodes(l:key)
endfunction

function! vim_ai_autocomplete#DismissMapping() abort
  call s:Log('DismissMapping invoked')
  if vim_ai_autocomplete#HasGhostText()
    call s:Log('DismissMapping clearing ghost text')
    call vim_ai_autocomplete#ClearGhostText()
    if exists('g:vim_ai_autocomplete_state') && type(g:vim_ai_autocomplete_state) == v:t_dict
      let g:vim_ai_autocomplete_state['completion'] = ''
      call s:Log('DismissMapping cleared g:vim_ai_autocomplete_state completion')
    endif
    return ''
  endif
  let l:key = get(g:, 'vim_ai_autocomplete_dismiss_key', '<C-]>')
  call s:Log('DismissMapping delegating to original key=' . string(l:key))
  return s:KeyAsTermcodes(l:key)
endfunction

function! s:MapInsertKey(key, plug_mapping) abort
  call s:Log('MapInsertKey key=' . string(a:key) . ' plug=' . string(a:plug_mapping))
  if a:key ==# ''
    call s:Log('MapInsertKey skipped: empty key')
    return
  endif
  let l:info = maparg(a:key, 'i', 0, 1)
  if !empty(l:info) && get(l:info, 'rhs', '') !~ a:plug_mapping
    call s:Log('MapInsertKey existing mapping incompatible, skipping')
    return
  endif
  if !empty(l:info)
    call s:Log('MapInsertKey removing existing mapping for key=' . string(a:key))
    execute 'silent! iunmap ' . a:key
  endif
  execute 'inoremap <silent> ' . a:key . ' ' . a:plug_mapping
  call s:Log('MapInsertKey applied mapping for key=' . string(a:key))
endfunction

function! s:EnsurePlugMappings() abort
  call s:Log('EnsurePlugMappings resetting plug mappings')
  silent! iunmap <Plug>(VimAIAutocompleteAccept)
  silent! iunmap <Plug>(VimAIAutocompleteDismiss)
  inoremap <silent><expr> <Plug>(VimAIAutocompleteAccept) vim_ai_autocomplete#AcceptMapping()
  inoremap <silent><expr> <Plug>(VimAIAutocompleteDismiss) vim_ai_autocomplete#DismissMapping()
endfunction

function! s:ApplyMappings() abort
  call s:Log('ApplyMappings invoked applied=' . string(s:mappings_applied))
  if s:mappings_applied
    call s:Log('ApplyMappings skipped: already applied')
    return
  endif
  let s:mappings_applied = 1
  if !exists('g:vim_ai_autocomplete_accept_key')
    let g:vim_ai_autocomplete_accept_key = '<Tab>'
    call s:Log('ApplyMappings set default accept key <Tab>')
  endif
  if !exists('g:vim_ai_autocomplete_dismiss_key')
    let g:vim_ai_autocomplete_dismiss_key = '<C-]>'
    call s:Log('ApplyMappings set default dismiss key <C-]>')
  endif
  call s:EnsurePlugMappings()
  call s:MapInsertKey(g:vim_ai_autocomplete_accept_key, '<Plug>(VimAIAutocompleteAccept)')
  call s:MapInsertKey(g:vim_ai_autocomplete_dismiss_key, '<Plug>(VimAIAutocompleteDismiss)')
  call s:Log('ApplyMappings completed')
endfunction

function! vim_ai_autocomplete#Setup() abort
  call s:Log('Setup invoked setup_done=' . string(s:setup_done))
  if s:setup_done
    call s:Log('Setup skipped: already done')
    return
  endif
  let s:setup_done = 1
  if !has('timers') || !has('python3')
    call s:Log('Setup aborted: timers=' . string(has('timers')) . ' python3=' . string(has('python3')))
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
  call s:Log('Setup completed')
endfunction

function! vim_ai_autocomplete#HandleEvent(event) abort
  call s:Log('HandleEvent received event=' . string(a:event))
  call s:OnUserActivity(a:event)
  let l:should = vim_ai_autocomplete#ShouldTrigger()
  call s:Log('HandleEvent should_trigger=' . string(l:should) . ' is_active=' . string(s:is_active) . ' needs_reschedule=' . string(s:needs_reschedule))
  if !l:should
    call vim_ai_autocomplete#CancelTimer()
    let s:needs_reschedule = 0
    call s:Log('HandleEvent exit: trigger declined, timer cancelled')
    return
  endif
  if s:is_active
    let s:needs_reschedule = 1
    call s:Log('HandleEvent exit: pipeline active, reschedule flagged')
    return
  endif
  call vim_ai_autocomplete#Schedule()
  call s:Log('HandleEvent scheduled pipeline')
endfunction

function! vim_ai_autocomplete#Schedule() abort
  call s:Log('Schedule invoked timer_id=' . string(s:timer_id))
  call vim_ai_autocomplete#CancelTimer()
  let s:needs_reschedule = 0
  let l:delay = vim_ai_autocomplete#get_debounce_ms()
  call s:Log('Schedule debounce delay=' . string(l:delay))
  if l:delay <= 0
    call s:Log('Schedule running pipeline immediately')
    call vim_ai_autocomplete#RunPipeline()
    return
  endif
  let s:timer_id = timer_start(l:delay, function('vim_ai_autocomplete#OnTimer'))
  call s:Log('Schedule set timer timer_id=' . string(s:timer_id))
endfunction

function! vim_ai_autocomplete#CancelTimer() abort
  call s:Log('CancelTimer invoked timer_id=' . string(s:timer_id))
  if s:timer_id != -1
    call timer_stop(s:timer_id)
    call s:Log('CancelTimer stopped timer')
    let s:timer_id = -1
  endif
  call vim_ai_autocomplete#ClearGhostText()
endfunction

function! vim_ai_autocomplete#OnTimer(timer) abort
  call s:Log('OnTimer fired timer=' . string(a:timer))
  let s:timer_id = -1
  if !vim_ai_autocomplete#ShouldTrigger()
    call s:Log('OnTimer aborting: ShouldTrigger returned false')
    return
  endif
  call vim_ai_autocomplete#RunPipeline()
endfunction

function! vim_ai_autocomplete#RunPipeline() abort
  call s:Log('RunPipeline invoked is_active=' . string(s:is_active) . ' active_request_id=' . string(s:active_request_id))
  if s:is_active
    call s:Log('RunPipeline aborted: another request in flight')
    return
  endif
  let s:is_active = 1
  let s:active_cancelled = 0
  let s:active_request_id += 1
  let l:request_id = s:active_request_id
  call s:Log('RunPipeline starting request_id=' . string(l:request_id))
  try
    call s:EnsurePythonModules()
    let l:config = { 'context_lines': g:vim_ai_autocomplete_context_lines }
    call s:Log('RunPipeline config=' . string(l:config))
    let l:result = py3eval("autocomplete.request_autocomplete(unwrap('l:config'))")
    call s:Log('RunPipeline result=' . string(l:result))
    let l:completion = get(l:result, 'completion', '')
    let g:vim_ai_autocomplete_state = {
          \ 'completion': l:completion,
          \ 'prompt': get(l:result, 'prompt', ''),
          \ 'metadata': get(l:result, 'metadata', {}),
          \ 'request_id': l:request_id,
          \ }
    call s:Log('RunPipeline state updated completion_length=' . string(len(l:completion)))
    if l:completion ==# '' || s:active_cancelled || !vim_ai_autocomplete#ShouldTrigger()
      call s:Log('RunPipeline clearing ghost text completion_empty=' . string(l:completion ==# '') . ' active_cancelled=' . string(s:active_cancelled))
      call vim_ai_autocomplete#ClearGhostText()
    else
      call s:Log('RunPipeline showing ghost text request_id=' . string(l:request_id))
      call s:ShowGhostText(l:completion, l:request_id)
    endif
  catch
    call s:Log('RunPipeline exception=' . string(v:exception) . ' throwpoint=' . string(v:throwpoint))
  finally
    let l:reschedule = s:needs_reschedule
    let s:needs_reschedule = 0
    let s:is_active = 0
    call s:Log('RunPipeline completed reschedule=' . string(l:reschedule))
    if l:reschedule && vim_ai_autocomplete#ShouldTrigger()
      call s:Log('RunPipeline scheduling follow-up request')
      call vim_ai_autocomplete#Schedule()
    endif
  endtry
endfunction

function! vim_ai_autocomplete#ShouldTrigger() abort
  if !exists('g:vim_ai_autocomplete_enabled') || !g:vim_ai_autocomplete_enabled
    call s:Log('ShouldTrigger disabled via g:vim_ai_autocomplete_enabled')
    return 0
  endif
  if !has('timers') || !has('python3')
    call s:Log('ShouldTrigger false: timers=' . string(has('timers')) . ' python3=' . string(has('python3')))
    return 0
  endif
  call s:EnsurePythonModules()
  let l:value = py3eval("bool(autocomplete.should_trigger())") ? 1 : 0
  call s:Log('ShouldTrigger python result=' . string(l:value))
  return l:value
endfunction

function! vim_ai_autocomplete#get_debounce_ms() abort
  let l:value = str2nr(g:vim_ai_autocomplete_debounce_ms)
  call s:Log('get_debounce_ms value=' . string(l:value))
  return l:value
endfunction

function! vim_ai_autocomplete#PrimeLogging() abort
  call s:MaybeInitLog()
  if s:LogEnabled()
    call s:Log('PrimeLogging invoked is_nvim=' . string(s:is_nvim))
  endif
endfunction

call s:MaybeInitLog()
