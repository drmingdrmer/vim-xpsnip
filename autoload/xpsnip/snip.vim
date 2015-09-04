exe xpsnip#once#init

let s:oldcpo = &cpo
set cpo-=< cpo+=B

let s:eof = '(eof)'

fun! xpsnip#snip#Compile(lines) "{{{

    let sess = {
          \ 'l' : 0,
          \ 'c' : -1,
          \ 'lines' : a:lines,
          \ 'buf' : '',
          \ 'status' : 'init',
          \ 'prev_indent' : 0,
          \ 'cur_indent' : 0,
          \ }

    let lines = a:lines
    let buf = ''
    let status = 'init'
    let prev_indent = 0
    let cur_indent = 0

    if len(lines) == 0
        " TODO empy
    endif

    let line = lines[l]

    while 1
        let c += 1
        if c >= strlen(line)
            let l += 1
            if l >= len(lines)
                " TODO handle bytes left in buf
                break
            else
                let line = lines[l]
                let indent_tabs = matchstr(line, '\v^\t*')
                let [prev_indent, cur_indent] = [cur_indent, strlen(indent_tabs)]
                let buf .= indent_tabs
                let c = cur_indent
            endif
        endif

        let chr = line[c]

        if status =='init'

            if chr == '$'
                " TODO flush buf
                let status = 'dollar'
            else
                let buf .= chr
            endif

        elseif status == 'escape'
            let buf .= chr

        elseif status == 'dollar'
            if chr == '{'
                let status = 'quoted_ph'
            elseif chr == '('
                let status = 'include_snip'

            elseif chr =~ '\v\w'
                let varname = matchstr(line, '\v^\w+', c)
                let c += strlen(varname) - 1
                " TODO flush buf
                " TODO add var

                let status = 'init'
            else
                " TODO error invalid char following $
            endif

        elseif status == 'quoted_ph'
            if chr == '}'
                let status = 'init'
                " TODO add var
            elseif chr =~ '\v\w'
                let varname = matchstr(line, '\v^\w+', c)
                let c += strlen(varname) - 1
                let status = 'ph_decor'
            else
                " TODO invalid
            endif
        elseif status == 'ph_decor'
            if chr == '.'
                let status = 'quoted_ph_dot_index'
            elseif chr == '['
                let status = 'quoted_ph_bracket_index'
            elseif chr == ':'
                let status = 'quoted_ph_default_val'
            elseif chr == '/'
                let status = 'quoted_ph_reg_transform'
            elseif chr == '}'
                let status = 'init'
                " TODO handle ph
            else
                " TODO invalid
            endif
        elseif status == 'quoted_ph_dot_index'
            if chr =~ '\v\d'
                let _ph_index = matchstr(line, '\v^\d+', c)
                let c += len(_ph_index) - 1
                let ph_index = _ph_index + 0
                let status = 'ph_decor'
            else
                " TODO invalid index
            endif
        elseif status == 'quoted_ph_bracket_index'
            if chr == '['
                let status = 'quoted_ph_bracket_index'
            else


            endif

        elseif status == 'include_snip'
        endif


    endwhile
endfunction "}}}

fun! xpsnip#snip#CompileExpr(text, c, endchar) abort "{{{

    echom 'compile expr:' a:text string(a:text[ a:c : ])

    let endchar = a:endchar
    if endchar == ''
        let endchar = '\v[]'
    endif

    let status = 'literal_str'

    let [expr, err, mes] = [[], 'Unknown', '']
    let [c, text] = [a:c - 1, a:text]

    let buf = ''

    let chr = 'xx'
    while chr != s:eof
        let c += 1
        if c >= strlen(text)
            let chr = s:eof
        else
            let chr = text[c]
            if chr =~ endchar
                let chr = s:eof
            endif

            " let indent_tabs = matchstr(text, '\v^\t*')
            " let [prev_indent, cur_indent] = [cur_indent, strlen(indent_tabs)]
            " let c = cur_indent
        endif

        echom '    status and chr: ' . status . ' ' . string(chr)

        if status == 'done'
            break
        endif

        if status != 'literal_str'
            if chr == s:eof
                let [err, mes] = s:errExpcet("non-(eof)", c, chr, text)
                break
            endif
        endif

        if status =='literal_str'

            if chr == s:eof || chr == '$'
                if buf != ''
                    let expr += [['text', buf]]
                    let buf = ''
                endif
            endif

            if chr == s:eof
                let status = 'done'
                let err = 'OK'
                continue
            endif

            if chr == '$'
                let status = 'dollar'
            elseif chr == '\'
                let status = 'escape'
            else
                let buf .= chr
            endif

        elseif status == 'escape'
            let buf .= chr
            let status = 'literal_str'

        elseif status == 'dollar'
            if chr == '{' || chr =~ '\v\w'
                let [ph, err, mes, cc] = xpsnip#snip#CompilePlaceHolder(text, c-1)
                if err == 'OK'
                    let expr += [['ph', ph]]
                    let c = cc - 1
                    let status = 'literal_str'
                else
                    break
                endif

            elseif chr == '('
                let [scall, err, mes, cc] = xpsnip#snip#CompileSnippetCall(text, c-1)
                if err == 'OK'
                    let expr += [['snip', scall]]
                    let c = cc - 1
                    let status = 'literal_str'
                else
                    break
                endif
            else
                let [err, mes] = s:errExpcet("{|(|\w", c, chr, text)
                break
            endif
        endif

    endwhile

    if err == 'OK'
        let pos = c
    else
        let expr = []
        let pos = a:c
    endif

    return [expr, err, mes, pos]
endfunction "}}}

fun! xpsnip#snip#CompilePlaceHolder(text, c) abort "{{{

    let status = 'init'
    let [ph, err, mes] = [{}, 'Unknown', '']
    let [c, text] = [a:c - 1, a:text]

    let chr = 'xx'
    while chr != s:eof
        let c += 1
        if c >= strlen(text)
            let chr = s:eof
        else
            let chr = text[c]

            " let indent_tabs = matchstr(text, '\v^\t*')
            " let [prev_indent, cur_indent] = [cur_indent, strlen(indent_tabs)]
            " let c = cur_indent
        endif

        " echom 'status and chr: ' . status . ' ' . chr

        if status == 'done'
            break
        endif

        if status != 'init'
            if chr == s:eof
                let [err, mes] = s:errExpcet("non-(eof)", c, chr, text)
                break
            endif
        endif

        if status =='init'
            if chr == '$'
                let status = 'dollar'
            else
                let [err, mes] = s:errExpcet("'", c, chr, text)
                break
            endif

        elseif status == 'dollar'
            if chr == '{'
                let status = 'quoted_ph'

            elseif chr =~ '\v\w'
                let phname = matchstr(text, '\v^\w+', c)
                let c += strlen(phname) - 1
                let ph = { 'name' : phname, }
                let err = 'OK'
                let status = 'done'

            else
                let [err, mes] = s:errExpcet("{|\w", c, chr, text)
                break
            endif

        elseif status == 'quoted_ph'
            if chr == '}'
                let ph = { 'name' : '' }
                let err = 'OK'
                let status = 'done'

            elseif chr =~ '\v\w'
                let phname = matchstr(text, '\v^\w+', c)
                let c += strlen(phname) - 1
                let ph = { 'name' : phname, }
                let status = 'ph_decor'
            else
                let [err, mes] = s:errExpcet("}|\w", c, chr, text)
                break
            endif

        elseif status == 'ph_decor'
            if chr == '.'
                let status = 'quoted_ph_dot_index'
            elseif chr == '['
                let status = 'quoted_ph_bracket_index'
            elseif chr == ':'
                let status = 'quoted_ph_default_val'
            elseif chr == '/'
                let status = 'quoted_ph_reg_transform'
            elseif chr == '}'
                let err = 'OK'
                let status = 'done'
            else
                let [err, mes] = s:errExpcet("[.\[:/}]", c, chr, text)
                break
            endif

        elseif status == 'quoted_ph_dot_index'
            let [ok, cc] = s:readIndex(text, c, ph)
            if ok
                let [c, status] = [cc, 'ph_decor']
            else
                let [err, mes] = ['InvalidPHIndex', s:errmes("[0-9]", c, chr, text)]
                break
            endif

        elseif status == 'quoted_ph_bracket_index'
            let [ok, cc] = s:readIndex(text, c, ph)
            if ok
                let [c, status] = [cc, 'quoted_ph_bracket_right']
            else
                let [err, mes] = ['InvalidPHIndex', s:errmes("[0-9]", c, chr, text)]
                break
            endif

        elseif status == 'quoted_ph_bracket_right'
            if chr == ']'
                let status = 'ph_decor'
            else
                let [err, mes] = ['NeedRightBracket', s:errmes(']', c, chr, text)]
                break
            endif

        elseif status == 'quoted_ph_default_val'

            let status = 'ph_decor'

            " TODO 
        elseif status == 'quoted_ph_reg_transform'
            " TODO
        endif

    endwhile

    if err == 'OK'
        let pos = c
    else
        let ph = {}
        let pos = a:c
    endif

    return [ph, err, mes, pos]

endfunction "}}}

fun! xpsnip#snip#CompileSnippetCall(text, c) abort "{{{

    let status = 'init'
    let [scall, err, mes] = [{}, 'Unknown', '']
    let [c, text] = [a:c - 1, a:text]

    let chr = 'xx'
    while chr != s:eof
        let c += 1
        if c >= strlen(text)
            let chr = s:eof
        else
            let chr = text[c]

            " let indent_tabs = matchstr(text, '\v^\t*')
            " let [prev_indent, cur_indent] = [cur_indent, strlen(indent_tabs)]
            " let c = cur_indent
        endif

        echom 'status and chr: ' . status . ' ' . chr

        if status == 'done'
            break
        endif

        if status != 'init'
            if chr == s:eof
                let [err, mes] = s:errExpcet("non-(eof)", c, chr, text)
                break
            endif
        endif

        if status =='init'
            if chr == '$'
                let status = 'dollar'
            else
                let [err, mes] = s:errExpcet("'", c, chr, text)
                break
            endif

        elseif status == 'dollar'
            if chr == '('
                let status = 'left_parentheses'
            else
                let [err, mes] = s:errExpcet("(", c, chr, text)
                break
            endif

        elseif status == 'left_parentheses'

            if chr =~ '\v^\s*$'
                continue

            elseif chr =~ '\v\w'
                let n = matchstr(text, '\v^\w+', c)
                let scall = { 'snipname' : n, 'param' : [] }
                let c += strlen(n) - 1
                let status = 'space_before_param'

            elseif chr == ')'
                let scall = {}
                let err = 'OK'
                let status = 'done'
            else
                let [err, mes] = s:errExpcet('\w', c, chr, text)
                break
            endif

        elseif status == 'space_before_param'

            if chr =~ '\v^\s$'
                let sp = matchstr(text, '\v^\s*', c)
                let c += strlen(sp) - 1
                let status = 'param'
            elseif chr == ')'
                let err = 'OK'
                let status = 'done'
            else
                let [err, mes] = s:errExpcet('\s', c, chr, text)
                break
            endif

        elseif status == 'param'

            if chr == ')'
                let err = 'OK'
                let status = 'done'

            elseif chr == "'"
                let [str, err, mes, cc] = xpsnip#snip#CompileLiteralString(text, c)
                if err == 'OK'
                    let scall.param += [[['text', str]]]
                    let c = cc - 1
                    let status = 'space_before_param'
                else
                    break
                endif

            elseif chr == '"'
                let [expr, err, mes, cc] = xpsnip#snip#CompileExpr(text, c+1, '\v["]')
                if err == 'OK'
                    let scall.param += [expr]
                    " skip the quote
                    let c = cc
                    let status = 'space_before_param'
                else
                    break
                endif

            else
                let [expr, err, mes, cc] = xpsnip#snip#CompileExpr(text, c, '\v[ \t)]')
                if err == 'OK'
                    let scall.param += [expr]
                    let c = cc - 1
                    let status = 'space_before_param'
                else
                    break
                endif

            endif
        endif

    endwhile

    if err == 'OK'
        let pos = c
    else
        let scall = {}
        let pos = a:c
    endif

    return [scall, err, mes, pos]

endfunction "}}}

fun! xpsnip#snip#CompileLiteralString(text, c) abort "{{{

    let status = 'init'

    let [buf, err, mes] = ['', 'Unknown', '']
    let [c, text] = [a:c - 1, a:text]

    let chr = 'xx'
    while chr != s:eof
        let c += 1
        if c >= strlen(text)
            let chr = s:eof
        else
            let chr = text[c]

            " let indent_tabs = matchstr(text, '\v^\t*')
            " let [prev_indent, cur_indent] = [cur_indent, strlen(indent_tabs)]
            " let c = cur_indent
        endif

        if status =='init'
            if chr == "'"
                let status = 'literal'
            else
                let [err, mes] = s:errExpcet("'", c, chr, text)
                break
            endif

        elseif status == 'literal'
            if chr == "'"
                let status = 'quote_1'
            elseif chr == s:eof
                let [err, mes] = s:errExpcet("non-(eof)", c, chr, text)
                break
            else
                let cc = matchstr(text, '\v^[^'']*', c)
                let c += strlen(cc) - 1
                let buf .= cc
            endif

        elseif status == 'quote_1'
            if chr == "'"
                let buf .= "'"
                let status = 'literal'
            else
                let err = 'OK'
                break
            endif
        endif
    endwhile

    if err == 'OK'
        let pos = c
    else
        let buf = ''
        let pos = a:c
    endif

    return [buf, err, mes, pos]
endfunction "}}}

fun! s:readIndex(line, c, ph) abort "{{{
    let [line, c] = [a:line, a:c]

    let chr = line[c]

    if chr =~ '\v\d'
        let _ph_index = matchstr(line, '\v^\d+', c)
        let c += len(_ph_index) - 1
        let a:ph.index = _ph_index + 0
        return [1, c]
    else
        return [0, 0]
    endif

endfunction "}}}

fun! s:errExpcet(expect, c, chr, text) abort "{{{
    if a:chr == s:eof
        let err = 'EOF'
    else
        let err = 'InvalidInput'
    endif
    return [err, s:errmes(a:expect, a:c, a:chr, a:text)]
endfunction "}}}

fun! s:errmes(expect, c, chr, text) abort "{{{
    return printf('expect %s at %d but it is %s; text=%s',
          \ a:expect, a:c, a:chr, a:text)
endfunction "}}}

let &cpo = s:oldcpo
