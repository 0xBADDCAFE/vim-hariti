" The MIT License (MIT)
"
" Copyright (c) 2015 kamichidu
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
" THE SOFTWARE.
let s:save_cpo= &cpo
set cpo&vim

function! hariti#parser#parse() dict abort
    let in= {
    \   'text': self.__input,
    \   'pos': 0,
    \   'length': strlen(self.__input),
    \}

    let context= s:file(in)
    if in.pos < in.length
        let [lnum, col]= s:where_is(in)
        throw printf("hariti: Couldn't consume whole file. (line %d, column %d)", lnum, col)
    endif
    return context
endfunction

function! s:where_is(in) abort
    let lines= split(a:in.text[ : a:in.pos], '\%(\r\n\|\r\|\n\)')
    let lnum= len(lines)
    let col= strlen(lines[-1])

    return [lnum, col]
endfunction

function! s:match(in, pat) abort
    call s:skip(a:in)
    let end= matchend(a:in.text, '^' . a:pat, a:in.pos)
    if end == -1
        let [lnum, col]= s:where_is(a:in)
        throw printf('hariti: Expects %s. (line %d, column %d)', a:pat, lnum, col)
    endif

    let start= a:in.pos
    let a:in.pos= end

    return strpart(a:in.text, start, end - start)
endfunction

function! s:expect(in, pat) abort
    call s:skip(a:in)
    let end= matchend(a:in.text, '^' . a:pat, a:in.pos)
    if end == -1
        let [lnum, col]= s:where_is(a:in)
        throw printf('hariti: Expects %s. (line %d, column %d)', a:pat, lnum, col)
    endif

    let a:in.pos= end
endfunction

function! s:lookahead(in, pat) abort
    call s:skip(a:in)
    return match(a:in.text, '^' . a:pat, a:in.pos) != -1
endfunction

function! s:skip(in) abort
    while match(a:in.text, '^\%(\_s\|#\)', a:in.pos) != -1
        let a:in.pos= matchend(a:in.text, '^\%(\_s\+\|#[^\r\n]*\)', a:in.pos)
    endwhile
endfunction

function! s:file(in) abort
    let context= {}
    let context.bundle= []
    while s:lookahead(a:in, 'use')
        let context.bundle+= [s:bundle(a:in)]
    endwhile
    return context
endfunction

function! s:bundle(in) abort
    let context= {}
    call s:expect(a:in, 'use')
    let context.repository= s:repository(a:in)
    if s:lookahead(a:in, 'as')
        call s:expect(a:in, 'as')
        let context.alias= []
        let context.alias+= [s:alias(a:in)]
        while s:lookahead(a:in, ',')
            call s:expect(a:in, ',')
            let context.alias+= [s:alias(a:in)]
        endwhile
    endif
    if s:lookahead(a:in, 'enable_if')
        call s:expect(a:in, 'enable_if')
        let context.enable_if= {'String': s:String(a:in)}
    endif
    if s:lookahead(a:in, 'depends')
        call s:expect(a:in, 'depends')
        call s:expect(a:in, '(')
        let context.dependency= []
        while s:lookahead(a:in, '[^)]')
            let context.dependency+= [s:dependency(a:in)]
        endwhile
        call s:expect(a:in, ')')
    endif
    return context
endfunction

function! s:repository(in) abort
    let context= {}
    let context.Identifier= []
    let context.Identifier+= [s:Identifier(a:in)]
    if s:lookahead(a:in, '/')
        call s:expect(a:in, '/')
        let context.Identifier+= [s:Identifier(a:in)]
    endif

    return context
endfunction

function! s:alias(in) abort
    let context= {}
    let context.Identifier= s:Identifier(a:in)
    return context
endfunction

function! s:dependency(in) abort
    let context= {}
    let context.repository= s:repository(a:in)
    return context
endfunction

function! s:Identifier(in) abort
    return s:match(a:in, '[a-zA-Z0-9.$_-]\+')
endfunction

function! s:String(in) abort
    return s:match(a:in, '\%(''\%([^'']\|\\''\)*''\|"\%([^"]\|\\"\)*"\)')
endfunction

function! hariti#parser#new(input, ...) abort
    let parser= {
    \   'parse': function('hariti#parser#parse'),
    \}

    if type(a:input) == type('')
        let parser.__input= a:input
    elseif type(a:input) == type([])
        let parser.__input= join(a:input, "\n")
    else
        throw 'hariti: Unsupported input type.'
    endif

    return parser
endfunction

let &cpo= s:save_cpo
unlet s:save_cpo
