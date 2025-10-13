let s:plugin_root = expand('<sfile>:p:h:h')
let s:timer_id = -1
let s:is_active = 0
let s:needs_reschedule = 0
let s:setup_done = 0

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

function! vim_ai_autocomplete#Setup() abort
  if s:setup_done
    return
  endif
  let s:setup_done = 1
  if !has('timers') || !has('python3')
    return
  endif
  call s:EnsurePythonModules()
  augroup VimAIAutocomplete
    autocmd!
    autocmd TextChanged,TextChangedI * call vim_ai_autocomplete#HandleEvent('text')
    autocmd CursorMoved,CursorMovedI * call vim_ai_autocomplete#HandleEvent('cursor')
    autocmd BufLeave,BufUnload * call vim_ai_autocomplete#CancelTimer()
    autocmd OptionSet buftype call vim_ai_autocomplete#CancelTimer()
    autocmd OptionSet modifiable call vim_ai_autocomplete#CancelTimer()
  augroup END
endfunction

function! vim_ai_autocomplete#HandleEvent(event) abort
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
  try
    call s:EnsurePythonModules()
    let l:config = { 'context_lines': g:vim_ai_autocomplete_context_lines }
    let l:result = py3eval("autocomplete.request_autocomplete(unwrap('l:config'))")
    let g:vim_ai_autocomplete_state = {
          \ 'completion': get(l:result, 'completion', ''),
          \ 'prompt': get(l:result, 'prompt', ''),
          \ 'metadata': get(l:result, 'metadata', {}),
          \ }
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
