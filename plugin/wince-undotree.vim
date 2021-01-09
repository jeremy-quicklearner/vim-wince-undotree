" Wince group type that integrates mbbill/undotree as an afterimaging subwin

" Dependency on Wince, and implicitly on vim-jersuite-core
JerCheckDep wince_undotree
\           wince
\           github.com/jeremy-quicklearner/vim-wince
\           0.2.0
\           1.0.0
let g:wince_undotree_version = '0.0.0'
call jer_log#LogFunctions('jersuite').CFG('wince-undotree version ',
                                        \ g:wince_undotree_version)
" Dependency on mbbill/undotree
if !exists('g:loaded_undotree') || !g:loaded_undotree
    echom 'Jersuite plugin wince_undotree requires undotree (github.com/mbbill/undotree) to be installed before it'
    exit
endif

