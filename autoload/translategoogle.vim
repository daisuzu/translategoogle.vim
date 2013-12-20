" File: translategoogle.vim
" Author: daisuzu <daisuzu@gmail.com>

let s:save_cpo = &cpo
set cpo&vim

" difinitions {{{
let s:V = vital#of('translategoogle.vim')
let s:BufferManager = s:V.import('Vim.BufferManager')
let s:HTTP = s:V.import('Web.HTTP')
let s:HTML = s:V.import('Web.HTML')
let s:Message = s:V.import('Vim.Message')
let s:OptionParser = s:V.import('OptionParser')

augroup TranlateGoogle
    autocmd!
augroup END

let s:url = 'https://translate.google.com/'

let s:params = {
            \   'hl': g:translategoogle_default_hl,
            \   'sl': g:translategoogle_default_sl,
            \   'ie': g:translategoogle_default_ie,
            \   'oe': g:translategoogle_default_oe,
            \ }

let s:bufname_pre = 'translate.google.com'
let s:bufname_before = s:bufname_pre . '- before'
let s:bufname_after = s:bufname_pre . '- after'
let s:bufname_retrans = s:bufname_pre . '- retrans'

let s:parser = s:OptionParser.new()
call s:parser.on('--hl', 'hl')
call s:parser.on('--sl', 'sl')
call s:parser.on('--ie', 'ie')
call s:parser.on('--oe', 'oe')

let s:translategoogle = {
            \   'index': -1,
            \   'buffers': [],
            \   'params': [],
            \   'retranslate': [],
            \ }
" }}}

" interfaces {{{
function! translategoogle#command(args)
    let args = s:parser.parse(a:args)
    let text = iconv(join(get(args, '__unknown_args__', []), "\n"), &encoding, 'utf-8')

    return join(s:get_translated_text(text, args), "\n")
endfunction

function! translategoogle#buffer(bufnr, ...)
    if !a:bufnr
        return []
    endif

    let text = iconv(join(getbufline(a:bufnr, 1, '$'), "\n"), &encoding, 'utf-8')
    let params = get(a:000, 0, {})

    return s:get_translated_text(text, params)
endfunction

function! translategoogle#open()
    call s:open_buffers()
endfunction

" }}}

" internal functions {{{
function! s:define_cmd(idx)
    execute 'command! -buffer TranslateGoogleToggle call s:toggle_language(' . a:idx . ')'
    execute 'command! -buffer TranslateGoogleClose call s:close_buffers(' . a:idx . ')'
    execute 'command! -buffer TranslateGoogleEnableRetranslate call s:enable_retranslate(' . a:idx . ')'
    execute 'command! -buffer TranslateGoogleDisableRetranslate call s:disable_retranslate(' . a:idx . ')'
endfunction

function! s:toggle_language(idx)
    let hl = s:translategoogle.params[a:idx].hl
    let s:translategoogle.params[a:idx].hl = s:translategoogle.params[a:idx].sl
    let s:translategoogle.params[a:idx].sl = hl
    let g:debug_params = s:translategoogle.params[a:idx]

    let bufnr = get(s:translategoogle.buffers[a:idx].before.list(), 0)
    let text = join(getbufline(bufnr, 1))
    if len(text)
        call s:update_buffers(a:idx)
    endif
endfunction

function s:enable_retranslate(idx)
    if !s:translategoogle.retranslate[a:idx]
        let s:translategoogle.retranslate[a:idx] = 1

        call s:translategoogle.buffers[a:idx].after.move()
        call s:translategoogle.buffers[a:idx].retrans.open(s:bufname_retrans,
                    \ {'opener': g:translategoogle_default_opener_retrans})
        call s:define_cmd(a:idx)

        let retrans = translategoogle#buffer(get(s:translategoogle.buffers[a:idx].after.list(), 0),
                    \   {'hl': s:translategoogle.params[a:idx].sl, 'sl': s:translategoogle.params[a:idx].hl}
                    \ )
        call s:rewrite_buffer(retrans)

        call s:translategoogle.buffers[a:idx].before.move()
    else
        s:Message.warn('already enabled')
    endif
endfunction

function s:disable_retranslate(idx)
    if s:translategoogle.retranslate[a:idx]
        let s:translategoogle.retranslate[a:idx] = 0
        call s:translategoogle.buffers[a:idx].retrans.close()
        call s:translategoogle.buffers[a:idx].before.move()
    else
        s:Message.warn('already disabled')
    endif
endfunction

function! s:create_buffers()
    let s:translategoogle.index += 1
    call add(s:translategoogle.buffers,
                \   {
                \       'before': s:BufferManager.new(),
                \       'after': s:BufferManager.new(),
                \       'retrans': s:BufferManager.new(),
                \   }
                \ )
    call add(s:translategoogle.params,
                \   {
                \       'hl': g:translategoogle_default_hl,
                \       'sl': g:translategoogle_default_sl,
                \       'ie': g:translategoogle_default_ie,
                \       'oe': g:translategoogle_default_oe,
                \   }
                \ )
    call add(s:translategoogle.retranslate,
                \   g:translategoogle_enable_retranslate
                \ )
endfunction

function! s:open_buffers(...)
    if !a:0
        if s:translategoogle.index < 0
            call s:create_buffers()
        endif

        let idx = 0
    else
        let idx = a:1
    endif

    call s:translategoogle.buffers[idx].before.open(s:bufname_before,
                \ {'opener': g:translategoogle_default_opener_before})
    setlocal buftype=nofile
    call s:define_cmd(idx)
    autocmd! TranlateGoogle * <buffer>
    execute 'autocmd TranlateGoogle InsertLeave,TextChanged <buffer> call s:update_buffers(' . idx . ')'

    call s:translategoogle.buffers[idx].after.open(s:bufname_after,
                \ {'opener': g:translategoogle_default_opener_after})
    call s:define_cmd(idx)

    if s:translategoogle.retranslate[idx]
        call s:translategoogle.buffers[idx].retrans.open(s:bufname_retrans,
                    \ {'opener': g:translategoogle_default_opener_retrans})
        call s:define_cmd(idx)
    endif

    call s:translategoogle.buffers[idx].before.move()
endfunction

function! s:close_buffers(idx)
    call s:translategoogle.buffers[a:idx].before.close()
    call s:translategoogle.buffers[a:idx].after.close()
    if s:translategoogle.retranslate[a:idx]
        call s:translategoogle.buffers[a:idx].retrans.close()
    endif
endfunction

function! s:update_buffers(idx)
    let after = translategoogle#buffer(get(s:translategoogle.buffers[a:idx].before.list(), 0),
                \   {'hl': s:translategoogle.params[a:idx].hl, 'sl': s:translategoogle.params[a:idx].sl}
                \ )
    call s:translategoogle.buffers[a:idx].after.move()
    call s:rewrite_buffer(after)

    if s:translategoogle.retranslate[a:idx]
        let retrans = translategoogle#buffer(get(s:translategoogle.buffers[a:idx].after.list(), 0),
                    \   {'hl': s:translategoogle.params[a:idx].sl, 'sl': s:translategoogle.params[a:idx].hl}
                    \ )
        call s:translategoogle.buffers[a:idx].retrans.move()
        call s:rewrite_buffer(retrans)
    endif

    call s:translategoogle.buffers[a:idx].before.move()
endfunction

function! s:rewrite_buffer(text)
    setlocal modified
    % delete _
    call append(0, a:text)
    setlocal nomodified
endfunction

function! s:get_translated_text(text, ...)
    let getdata = {
                \     'hl': get(a:1, 'hl', s:params.hl),
                \     'sl': get(a:1, 'sl', s:params.sl),
                \     'ie': get(a:1, 'il', s:params.ie),
                \     'oe': get(a:1, 'ol', s:params.oe),
                \     'text': a:text
                \ }
    let headdata = {'User-Agent': 'w3m/0.5.3'}

    let response = s:HTTP.get(s:url, getdata, headdata)

    if response.status != 200
        s:Message.error(response.statusText)
        return ''
    endif

    let html = s:HTML.parse(response.content)
    let result = html.find({'id': 'result_box'}).childNodes()
    let text = map(copy(result), 'v:val.child[0]')
    return text
endfunction
" }}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
