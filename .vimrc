"
" .vimrc
"
" Source it with ``:so .vimrc''.
"

" Mark angle brackets (which we use as delimiters).
syn match texDelimiter "[<>]"

" Color listings like {verbatim}s.
syn region texZone matchgroup=texSection start="^\\begin{lstlisting}" end="^\\end{lstlisting}$" contains=texStatement,texInputCurlies

" Color \Code, \Var, \Class, \Fun, \Tpl, and \Make like {verbatim}.
syn region texZone matchgroup=texCmdname contains=texInputCurlies start="\\\(Code\|Var\|Class\|Fun\|Tpl\|Make\){"rs=e-1 skip="}{" end="}\+"re=e keepend

" Color \Topic{}.
hi konecTopic ctermfg=white
syn match konecTopic "^\\Topic\({.*}\|\[.*\]\)$" contains=texInputCurlies

" Color environment names lighter.
hi texSection ctermfg=darkcyan

" Bind ``,a'' to :nohl.
nmap ,a :nohlsearch<CR>

" End of .vimrc
