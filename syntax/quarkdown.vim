if exists("b:current_syntax")
  finish
endif

" Quarkdown extends Markdown, so load the bundled markdown syntax as a base.
runtime! syntax/markdown.vim
unlet! b:current_syntax

" Function call: .name, optionally with chained ::name segments.
syntax match quarkdownFunctionName /\.\@<=\h\w*\%(::\h\w*\)*/ contained
syntax match quarkdownFunctionDot  /\.\ze\h\w*/ contained nextgroup=quarkdownFunctionName
syntax match quarkdownFunctionCall /\.\h\w*\%(::\h\w*\)*/ contains=quarkdownFunctionDot,quarkdownFunctionName

" Named argument: foo:{...} or foo:value (the `name:` portion).
syntax match quarkdownArgumentName /\<\h\w*\ze:\%({\|\S\)/

" Argument blocks { ... } and bracketed content [ ... ].
syntax region quarkdownArgumentBlock matchgroup=quarkdownArgumentDelim start=/{/ end=/}/ contains=@quarkdownInline,quarkdownFunctionCall keepend
syntax region quarkdownBracketBlock  matchgroup=quarkdownArgumentDelim start=/\[/ end=/\]/ contains=@quarkdownInline,quarkdownFunctionCall keepend

" Common inline group reused inside argument blocks.
syntax cluster quarkdownInline contains=quarkdownFunctionCall,quarkdownArgumentName,markdownBold,markdownItalic,markdownCode

highlight default link quarkdownFunctionCall  Function
highlight default link quarkdownFunctionDot   Function
highlight default link quarkdownFunctionName  Function
highlight default link quarkdownArgumentName  Identifier
highlight default link quarkdownArgumentDelim Delimiter

let b:current_syntax = "quarkdown"
