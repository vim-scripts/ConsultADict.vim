"
" ConsultADict.vim
"
" ============================================================================
" Last Change:  2014 Mar 10
"
" Author:       Dmitry Ivanov <Dmitry.Bob.Ivanov at gmail dot com>
"
" Copyright:    Copyright (C) 2013 Dmitry Ivanov
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               ConsultADict.vim is provided *as is* and comes with no
"               warranty of any kind, either expressed or implied. In no
"               event will the copyright holder be liable for any damages
"               resulting from the use of this software.
"
" Description:  Vim plugin that provides easy way to consult a dictinary
"               (for example for translate words).
"
" Help:         g:loaded_ConsultADict - turns off the script.
"
"               g:ConsultADict_cmd - list of commands to show dictionary
"               entries.
"                 Example:
"                  let g:ConsultADict_cmd=["r!/usr/bin/sdcv -n $$$_words",
"                       \ "source ~/.vim/plugin/mydict.vim"]
"
"               $$$_words will be changed to the word (phrase) to translate
"               (the given word or phrase or the word under the cursor or the current
"               selection in visual mode).
"
"               b:ConsultADict_words - word or phrase to look it up in
"               dictionaries. It is for your dictionary vim-files.
"                 Example:
"                 ~/.vim/plugin/mydict.vim:
"                      if !exists("b:ConsultADict_words")
"                          finish
"                      endif
"                      execute "r!/usr/bin/sdcv -n " . shellescape(b:ConsultADict_words)
"
"               :ConsultADict <words> - shows dictionary entries for <words>.
"
"               :ConsultADict - shows dictionary entries for the word under
"               the cursor or the current selection in visual mode.
"               
"               :ConsultADictHistory - shows search history buffer.
"
"               :ConsultADictToggle - switchs plugin window on/off. Shows
"               dictionary entries for the word under the cursor or the
"               current selection in visual mode when switchs plugin window
"               on.
"
"               :ConsultADictClose - closes plugin window.
" ============================================================================


if exists("g:loaded_ConsultADict")
    finish
endif
let g:loaded_ConsultADict = 1

" Version:
" ============================================================================
    let s:version = "0.801"
" ============================================================================

" b:header_len - numter of lines of the header of current plugin buffer
" s:main_title - title of the dictionary entry buffer
" s:history_title - title of the search history buffer
" s:entry_help - determines if Quick Help is shown in the dictionary entry buffer. Nonzero for Quick Help.
" s:history_help - as s:entry_help for search history buffer 

let s:main_title = "[ConsultADict]"
let s:history_title = s:main_title . "-[History]"

let s:entry_help = 0
let s:history_help = 0

" It gets current selection in visual mode.
" Thank Peter Odding (xolox) for http://stackoverflow.com/a/6271254
function! s:get_visual_selection()
    " Why is this not a built-in Vim script function?!
    let [lnum1, col1] = getpos("'<")[1:2]
    let [lnum2, col2] = getpos("'>")[1:2]
    let lines = getline(lnum1, lnum2)
    let lines[-1] = lines[-1][: col2 - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][col1 - 1:]
    return join(lines, "\n")
endfunction

" It returns header for the dictionary entry buffer.
function! s:GetEntryHeader()
    let l:header = []
    if s:entry_help
        call add(l:header, '" Consult A Dictionary ('.s:version.') quickhelp')
        call add(l:header, '" ==============================================')
        call add(l:header, '" <F1>: toggle this Help')
        call add(l:header, '" f: show dictionary entries for the word under the cursor or')
        call add(l:header, '"      the current selection in visual mode')
        call add(l:header, '" s: show search history')
        call add(l:header, '" q: close the ConsultADict window')
        call add(l:header, '')
    else
        call add(l:header, '" Press <F1> for Help')
        call add(l:header, '')
    endif
    return l:header
endfunction

" It returns header for the search history buffer.
function! s:GetHistoryHeader()
    let l:header = []
    if s:history_help
        call add(l:header, '" Consult A Dictionary ('.s:version.') quickhelp')
        call add(l:header, '" ==============================================')
        call add(l:header, '" <F1>: toggle this Help')
        call add(l:header, '" <enter> or f or double-click: show dictionary entries for the word under')
        call add(l:header, '"     the cursor or the current selection in visual mode')
        call add(l:header, '" q: close the ConsultADict window')
        call add(l:header, '')
    else
        call add(l:header, '" Press <F1> for Help')
        call add(l:header, '')
    endif
    return l:header
endfunction

" It sets header for current plugin buffer.
" a:header defines header lines,
" a:cur_on_top determines if the cursor will be set to position under the header or retains its position.
function! s:SetHeader(header, cur_on_top)
    if exists("b:header_len")
        let l:cur_pos = a:cur_on_top ? 1 : line(".") - b:header_len
        if l:cur_pos < 1
            let l:cur_pos = 1
        endif
        silent execute "1," . b:header_len . "d"
    else
        let l:cur_pos = 1
    endif
    call append(0, a:header)
    let b:header_len = len(a:header)
    call cursor(1, 0)
    call cursor((l:cur_pos + b:header_len), 0)
endfunction

fun! s:SetSyntax()
    if has("syntax")
        syn match consultToDictHelp "^\".*" contains=consultToDictMapping
        syn match consultToDictMapping "\" \zs.\+\ze:" contained
        hi def link consultToDictHelp Special
        hi def link consultToDictMapping NonText
    endif
endfun

" It toggles Quick Help in search history buffer
function! s:ToggleHistoryHelp()
    let s:history_help = !s:history_help
    setlocal modifiable
    call s:SetHeader(s:GetHistoryHeader(), s:history_help)
    setlocal nomodifiable
endfunction

" It toggles Quick Help in dictionary entry buffer
function! s:ToggleEntryHelp()
    let s:entry_help = !s:entry_help
    setlocal modifiable
    call s:SetHeader(s:GetEntryHeader(), s:entry_help)
    setlocal nomodifiable
endfunction

" It creates (if not exists) plugin window, and move cursor to it.
" Then it switchs to (or create) search history buffer, reset parameters of
" that one. Also it sets 'modifiable' on for editing search history in
" s:ShowDictEntry 
function! s:ShowPluginWindow()
    let l:win_num = bufwinnr(s:main_title)
    if l:win_num == -1
        execute "to split"
    else
        execute l:win_num . "wincmd w"
    endif
    silent execute "buffer! " . bufnr(s:history_title, 1)
    setlocal modifiable
    setlocal hidden
    setlocal noswapfile
    setlocal cursorline
    setlocal nonumber
    setlocal buftype=nofile
    setlocal nowrap
    setlocal nobuflisted
    setlocal nospell
    setlocal noshowcmd
    call s:SetHeader(s:GetHistoryHeader(), 1)
endfunction

" It shows dictionary entries in plugin window.
" If a:words is not empty then a:words will be taken to look it up in
" dictionaries.
" If a:words is empty then a:source determines source of word (phrase) to
" look it up in dictionaries:
"   0   - word under the cursor;
"   > 0 - current selection;
"   < 0 - current line.
" The word (phrase) adds to search history.
function! s:ShowDictEntry(source, words)
    if strlen(a:words)
        let l:words = a:words
    elseif a:source == 0
        let l:words = expand('<cword>')
    elseif a:source > 0
        let l:words = s:get_visual_selection()
    else 
        let l:words = getline(".")
    endif
    call s:ShowPluginWindow()
    let l:old_cpo = &cpo
    set cpo&vim
    if !(exists("g:ConsultADict_cmd") && len(g:ConsultADict_cmd))
        setlocal nomodifiable
        silent execute "edit " . s:main_title
        silent 1,$d
        call append(line('$'), "List of commands to show dictionary entries requires configuration.")
        call append(line('$'), "See :help ConsultADict_cmd")
        call append(line('$'), "Press 'q' to quit.")
        call cursor(1, 1)
    else
        if l:words =~ '\S\+'
            let l:words = substitute(l:words, '\n', ' ', 'g')
            silent execute "g\/\\c\^" . l:words . "\$\/d"
            call append(b:header_len, l:words)
            setlocal nomodifiable
            silent execute "edit " . s:main_title
            silent 1,$d
            let b:ConsultADict_words = l:words
            let l:words = shellescape(l:words)
            for s:dictcommand in g:ConsultADict_cmd
                silent execute substitute(s:dictcommand, '$$$_words', l:words, 'g')
            endfor
        else
            setlocal nomodifiable
            silent execute "edit " . s:main_title
            silent 1,$d
            call append(0, "There are no words to consult a dictionary")
        endif
        call s:SetHeader(s:GetEntryHeader(), 1)
        noremap <buffer> <silent> f :ConsultADict<cr>
        noremap <buffer> <silent> s :call <SID>ShowHistory()<cr>
        noremap <buffer> <silent> <F1> :call <SID>ToggleEntryHelp()<cr>
    endif
    noremap <buffer> <silent> q :close<CR>
    let l:old_cpo = &cpo
    setlocal nomodifiable
    setlocal noswapfile
    setlocal nonumber
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal nowrap
    setlocal nobuflisted
    setlocal nospell
    setlocal noshowcmd
    call s:SetSyntax()
endfunction

" It shows search history in plugin window.
function! s:ShowHistory()
    call s:ShowPluginWindow()
    setlocal nomodifiable
    if !exists(":ConsultADictLine")
        command -nargs=? -buffer -count ConsultADictLine :call <sid>ShowDictEntry(line(".") > b:header_len ? -1 : <count>, <q-args>)
    endif
    let l:old_cpo = &cpo
    set cpo&vim
    noremap <buffer> <silent> <cr> :ConsultADictLine<cr>
    noremap <buffer> <silent> f :ConsultADictLine<cr>
    noremap <buffer> <silent> <F1> :call <SID>ToggleHistoryHelp()<cr>
    noremap <buffer> <silent> q :close<CR>
    noremap <buffer> <silent> <2-leftmouse> :ConsultADictLine<cr>
    let &cpo = l:old_cpo
    call s:SetSyntax()
endfunction

" It toggles plugin window on/off.
" a:source determine source of word (phrase) to look it up in dictionaries
" (see s:ShowDictEntry).
function! s:TogglePluginWindow(source)
    let l:win_num = bufwinnr(s:main_title)
    if l:win_num == -1
        call s:ShowDictEntry(a:source, "")
    else
        execute l:win_num . "wincmd w"
        close
    endif
endfunction

function! s:ClosePluginWindow()
    let l:win_num = bufwinnr(s:main_title)
    if l:win_num != -1
        execute l:win_num . "wincmd w"
        close
    endif
endfunction

if !exists(":ConsultADict")
    command -nargs=? -count ConsultADict :call <sid>ShowDictEntry(<count>, <q-args>)
endif

if !exists(":ConsultADictHistory")
    command -nargs=0 ConsultADictHistory :call <sid>ShowHistory()
endif

if !exists(":ConsultADictToggle")
    command -nargs=0 -count ConsultADictToggle :call <sid>TogglePluginWindow(<count>)
endif

if !exists(":ConsultADictClose")
    command -nargs=0 ConsultADictClose :call <sid>ClosePluginWindow()
endif

