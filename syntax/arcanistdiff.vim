" Copyright (c) 2019-2020 Jon Parise
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to
" deal in the Software without restriction, including without limitation the
" rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
" sell copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
" FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
" IN THE SOFTWARE.

if exists('b:current_syntax')
  finish
endif

if has('spell')
  syn spell toplevel
endif

syn match arcanistdiffTitle "^.*\%<51v."
  \ contained containedin=arcanistdiffSummary
  \ nextgroup=arcanistdiffOverflow
  \ contains=@Spell

syn match arcanistdiffSummary   "\%^[^#].*" nextgroup=arcanistdiffBlank skipnl
syn match arcanistdiffBlank     "^[^#].*" contained contains=@Spell
syn match arcanistdiffOverflow  ".*" contained contains=@Spell
syn match arcanistdiffHeading   "^\(\u\S\+\s*\)\+:" display
syn match arcanistdiffComment   "^#.*"

hi def link arcanistdiffTitle     Keyword
hi def link arcanistdiffBlank     Error
hi def link arcanistdiffHeading   Special
hi def link arcanistdiffComment   Comment
