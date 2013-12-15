" File: translategoogle.vim
" Author: daisuzu <daisuzu@gmail.com>

let s:save_cpo = &cpo
set cpo&vim

" vital {{{
let s:V = vital#of('translategoogle.vim')
let s:BufferManager = s:V.import('Vim.BufferManager')
let s:HTTP = s:V.import('Web.HTTP')
let s:HTML = s:V.import('Web.HTML')
let s:Message = s:V.import('Vim.Message')
let s:OptionParser = s:V.import('OptionParser')
" }}}

" augroup {{{
augroup TranlateGoogle
    autocmd!
augroup END
" }}}

" variables {{{
let s:url = 'https://translate.google.com/'

let s:params = {
            \   'hl': g:translategoogle_default_hl,
            \   'sl': g:translategoogle_default_sl,
            \   'ie': g:translategoogle_default_ie,
            \   'oe': g:translategoogle_default_oe,
            \ }

let s:buffers = {
            \   'before': s:BufferManager.new(),
            \   'after': s:BufferManager.new(),
            \   'retrans': s:BufferManager.new(),
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
" }}}

" interfaces {{{
function! translategoogle#start()
    " if s:buffers.before.opend(s:bufname_before)
    if empty(s:buffers.before.list())
        call s:buffers.before.open(s:bufname_before,
                    \ {'opener': g:translategoogle_default_opener_before})
        setlocal buftype=nofile
        command! -buffer TranslateGoogleToggle call translategoogle#toggle()
        autocmd TranlateGoogle InsertLeave,TextChanged <buffer> call s:update_buffers()
    endif

    " if s:buffers.after.opend(s:bufname_after)
    if empty(s:buffers.after.list())
        call s:buffers.after.open(s:bufname_after,
                    \ {'opener': g:translategoogle_default_opener_after})
        command! -buffer TranslateGoogleToggle call translategoogle#toggle()
    endif

    if g:translategoogle_enable_retranslate
        echomsg 'retranslate is enable'
        " if s:buffers.after.opend(s:bufname_after)
        if empty(s:buffers.retrans.list())
            call s:buffers.retrans.open(s:bufname_retrans,
                        \ {'opener': g:translategoogle_default_opener_retrans})
            command! -buffer TranslateGoogleToggle call translategoogle#toggle()
        endif
    endif

    call s:buffers.before.move()
endfunction

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

function! translategoogle#toggle()
    let tmp_hl = s:params.hl
    let s:params.hl = s:params.sl
    let s:params.sl = tmp_hl
endfunction
" }}}

" internal functions {{{
function! s:rewrite_buffer(text)
    setlocal modified
    % delete _
    call append(0, a:text)
    setlocal nomodified
endfunction

function! s:update_buffers()
    call s:buffers.after.move()
    let after = translategoogle#buffer(get(s:buffers.before.list(), 0))
    call s:rewrite_buffer(after)

    if g:translategoogle_enable_retranslate
        call s:buffers.retrans.move()
        let retrans = translategoogle#buffer(get(s:buffers.after.list(), 0),
                    \   {'hl': s:params.sl, 'sl': s:params.hl}
                    \ )
        call s:rewrite_buffer(retrans)
    endif

    call s:buffers.before.move()
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
