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

function! s:throw(string) abort
  let v:errmsg = 'phabricator: ' . a:string
  throw v:errmsg
endfunction

function! s:remote_url() abort
  " Arcanist workflows use temporary files outside of the repository's
  " directory hierarchy so we need to explicitly look below the current
  " working directory instead of relying on the current buffer's path.
  return FugitiveRemoteUrl('', FugitiveExtractGitDir(getcwd()))
endfunction

function! s:diffusion_root_for_remote(url) abort
  " Start by assuming the Phabricator hostname starts with 'phabricator', and
  " then add any additional patterns from the 'g:phabricator_hosts' list.
  let host_pattern = 'phabricator.*'
  let hosts = get(g:, 'phabricator_hosts', [])
  call map(copy(hosts), 'substitute(v:val, "/$", "", "")')
  for host in hosts
    let host_pattern .= '\|' . escape(split(host, '://')[-1], '.')
  endfor
  let base = matchstr(a:url, '^\%(https\=://\|git://\|git@\|ssh://code@\|ssh://git@\)\=\zs\('.host_pattern.'\)\%(:\d\{1,5}\)\=\/diffusion[/:][^/]\{-\}\ze[/:].\{-\}\%(\.git\)\=$')
  if !empty(base)
    " Remove the port component of the hostname.
    let base = substitute(base, '[^/]*\zs:\d\{1,5}', '', '')
    return 'https://' . tr(base, ':', '/')
  endif
  return ''
endfunction

function! s:api_root() abort
  if exists('b:phabricator_api_root')
    return b:phabricator_api_root
  endif
  let remote = s:remote_url()
  let diffusion_root = s:diffusion_root_for_remote(remote)
  let api_root = substitute(diffusion_root, '/diffusion/.*', '/api/', '')
  if empty(api_root)
    call s:throw((!empty(remote) ? remote : 'origin') .
          \ ' is not a Phabricator repository')
  endif
  let b:phabricator_api_root = api_root
  return api_root
endfunction

function! s:api_token(api_root) abort
  if exists('b:phabricator_api_token')
    return b:phabricator_api_token
  endif
  try
    let json = json_decode(join(readfile(expand('~/.arcrc')), ' '))
    let host = get(get(json, 'hosts', {}), a:api_root, {})
    let token = get(host, 'token', get(g:, 'phabricator_api_token'))
  catch
    let token = get(g:, 'phabricator_api_token')
  endtry
  let b:phabricator_api_token = token
  return token
endfunction

function! s:request(method, order, query) abort
  if !executable('curl')
    call s:throw('cURL is required')
  endif
  if !exists('*json_decode')
    call s:throw('json_decode() is required')
  endif

  let api_root = s:api_root()
  if empty(api_root)
    call s:throw('could not determine Conduit (API) URL')
  endif
  let token = s:api_token(api_root)
  if empty(token)
    call s:throw('missing API token')
  endif

  " curl arguments
  let args = ['-q', '--silent']
  call extend(args, ['-H', 'Accept: application/json'])
  call extend(args, ['-A', 'vim-phabricator'])
  call extend(args, ['-d', shellescape('api.token=' . token)])
  call extend(args, ['-d', 'queryKey=active'])
  call extend(args, ['-d', shellescape('order[0]=' . a:order)])
  if !empty(a:query)
    call extend(args, ['-d', shellescape('constraints[query]=core%3A~"' . a:query . '"')])
  endif
  call add(args, api_root . a:method)

  let data = system('curl ' . join(args))

  let json = json_decode(data)
  if type(json) != type({})
    call s:throw('bad API response')
  elseif !empty(get(json, 'error_info'))
    call s:throw(get(json, 'error_info'))
  endif

  let result = get(json, 'result', {})
  return map(get(result, 'data', []), 'get(v:val, "fields", {})')
endfunction

function! phabricator#query_projects(query) abort
  return s:request('project.search', 'name', a:query)
endfunction

function! phabricator#query_users(query) abort
  return s:request('user.search', 'username', a:query)
endfunction

function! phabricator#complete(findstart, base) abort
  if a:findstart 
    let line = getline('.')
    if line !~# '^\%(Reviewers\|Subscribers\):'
      return -2 " cancel silently and stay in completion mode
    endif
    let start = col('.') - 1
    while start > 0 && line[0:start - 1] !~# '[:,]\s*$'
      let start -= 1
    endwhile
    return start
  endif
  try
    if a:base =~# '^#'
      let results = phabricator#query_projects(a:base[1:])
      return map(results, 
            \ '{"word": "#".v:val.slug, "menu": v:val.name, '.
            \ '"info": !empty(v:val.description) ? v:val.description : ""}')
    else
      let results = phabricator#query_users(a:base)
      return map(results, '{"word": v:val.username, "menu": v:val.realName}')
    endif
  catch /^phabricator:.*is not a Phabricator repository/
    return []
  catch /^\%(fugitive\|phabricator\):/
    echoerr v:errmsg
  endtry
endfunction

function! phabricator#fugitive_url(...) abort
  if a:0 == 1 || type(a:1) == type({})
    let opts = a:1
    let root = s:diffusion_root_for_remote(get(opts, 'remote', ''))
  else
    return ''
  endif
  if empty(root)
    return ''
  endif
  let path = substitute(opts.path, '^/', '', '')
  if path =~# '^\.git/refs/heads/'
    return root . '/history/' . path[16:-1]
  elseif path =~# '^\.git/refs/tags/'
    return root . '/history/;' . path[15:-1]
  elseif path =~# '^\.git/'
    return root
  endif
  let branch = substitute(FugitiveHead(), '/', '%252F7', 'g')
  if empty(branch)
    return ''
  endif
  let commit = opts.commit
  if commit =~# '^\d\=$'
    return ''
  endif
  if get(opts, 'type', '') ==# 'tree' || opts.path =~# '/$'
    let url = substitute(root . '/browse/' . branch . '/' . path, '/$', '', '')
  elseif get(opts, 'type', '') ==# 'blob' || opts.path =~# '[^/]$'
    let url = root . '/browse/' . branch . '/' . path . ';' . commit
    if get(opts, 'line2') && opts.line1 == opts.line2
      let url .= '$' . opts.line1
    elseif get(opts, 'line2')
      let url .= '$' . opts.line1 . '-' . opts.line2
    endif
  else
    let url = substitute(root, '/diffusion/', '/r', '') . commit
  endif
  return url
endfunction
