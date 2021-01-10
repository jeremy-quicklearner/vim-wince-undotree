" Wince group type that integrates mbbill/undotree as an afterimaging subwin

" Avoid loading twice
if exists('s:loaded')
    finish
endif
let s:loaded = 0

" Dependency on Wince, and implicitly on vim-jersuite-core
JerCheckDep wince_undotree
\           wince
\           github.com/jeremy-quicklearner/vim-wince
\           0.2.0
\           1.0.0
" Dependency on mbbill/undotree
if !exists('g:loaded_undotree') || !g:loaded_undotree
    echom 'Jersuite plugin wince_undotree requires undotree (github.com/mbbill/undotree) to be installed before it'
    exit
endif
" Dependencies satisfied
let g:wince_undotree_version = '0.2.1'
call jer_log#LogFunctions('jersuite').CFG('wince-undotree version ',
                                        \ g:wince_undotree_version)

call jer_log#SetLevel('wince-undotree-subwin', 'WRN', 'WRN')
let s:Log = jer_log#LogFunctions('wince-undotree-subwin')

if !exists('g:wince_undotree_width')
    let g:wince_undotree_width = 25
endif

if !exists('g:wince_undotree_right')
    let g:wince_undotree_right = 0
endif

if !exists('g:wince_undodiff_top')
    let g:wince_undodiff_top = 0
endif

if !exists('g:wince_undodiff_height')
    let g:wince_undodiff_height = 10
endif

if !exists('g:wince_undotree_subwin_statusline')
    let g:wince_undotree_subwin_statusline = '%!wince_undotree#TreeStatusLine()'
endif

if !exists('g:wince_undodiff_subwin_statusline')
    let g:wince_undodiff_subwin_statusline = '%!wince_undotree#DiffStatusLine()'
endif

" Cause UndotreeShow to open the undotree windows relative to the current
" window, instead of relative to the whole tab
if g:wince_undotree_right
    let g:undotree_CustomUndotreeCmd = 'belowright vertical ' . g:wince_undotree_width . ' new'
else
    let g:undotree_CustomUndotreeCmd = 'aboveleft vertical ' . g:wince_undotree_width . ' new'
endif
if g:wince_undodiff_top
    let g:undotree_CustomDiffpanelCmd = 'aboveleft ' . g:wince_undodiff_height . ' new'
else
    let g:undotree_CustomDiffpanelCmd = 'belowright ' . g:wince_undodiff_height . ' new'
endif

" Don't highlight anything in the target windows
let g:undotree_HighlightChangedText = 0

" Don't put signs in target windows to indicate which lines have changes
let g:undotree_HighlightChangedWithSign = 0

" The undotree and diffpanel are a subwin group. If g:undotree_DiffAutoOpen is
" falsey, don't expect the diffpanel
if !exists('g:undotree_DiffAutoOpen') || g:undotree_DiffAutoOpen == 1
    call wince_user#AddSubwinGroupType('undotree', ['tree', 'diff'],
                              \[
                              \    g:wince_undotree_subwin_statusline,
                              \    g:wince_undodiff_subwin_statusline
                              \],
                              \'U', 'u', 5,
                              \40, [1, 1], [0, 0], g:wince_undotree_right,
                              \[g:wince_undotree_width, g:wince_undotree_width], [-1, g:wince_undodiff_height],
                              \function('wince_undotree#ToOpen'),
                              \function('wince_undotree#ToClose'),
                              \function('wince_undotree#ToIdentify'))
else
    call wince_user#AddSubwinGroupType('undotree', ['tree'],
                              \[g:wince_undotree_subwin_statusline],
                              \'U', 'u', 5,
                              \40, [1], [0], g:wince_undotree_right,
                              \[g:wince_undotree_width], [-1],
                              \function('wince_undotree#ToOpen'),
                              \function('wince_undotree#ToClose'),
                              \function('wince_undotree#ToIdentify'))
endif

" Update the undotree subwins after each resolver run, when the state and
" model are certain to be consistent
if !exists('g:wince_undotree_chc')
    let g:wince_undotree_chc = 1
    call jer_chc#Register(function('wince_undotree#Update'), [], 0, 10, 1, 0, 1)
    call wince_user#AddPostUserOperationCallback(function('wince_undotree#Update'))
endif

augroup WinceUndotree
    autocmd!

    " If there are undotree subwins open when mksession is invoked, their
    " contents do not persist. When the session is reloaded, the undotree
    " windows are opened without content or window-local variables and are
    " therefore not compliant with toIdentify. The first resolver run will
    " notice this and relist the windows as supwins - so now there are a bunch
    " of extra supwins with the undotree filetype and no content. I see no
    " reason why the user would ever want to keep these windows around, so
    " they are removed here
    autocmd SessionLoadPost * call jer_util#TabDo('', 'call jer_chc#Register(function("wince_undotree#CloseDangling"), [], 1, -100, 0, 0, 0)')
augroup END

" Mappings
" No explicit mappings to add or remove. Those operations are done by
" wince_undotree#Update.
if exists('g:wince_undotree_disable_mappings') && g:wince_undotree_disable_mappings
    call s:Log.CFG('Undotree uberwin mappings disabled')
else
    call wince_map#MapUserOp('<leader>us', 'call wince_user#ShowSubwinGroup(0, "undotree", 1)')
    call wince_map#MapUserOp('<leader>uh', 'call wince_user#HideSubwinGroup(0, "undotree")')
    call wince_map#MapUserOp('<leader>uu', 'let g:wince_map_mode = wince_user#GotoSubwin(0, "undotree", "tree", g:wince_map_mode, 1)')
    if !exists('g:undotree_DiffAutoOpen') || g:undotree_DiffAutoOpen == 1
        call wince_map#MapUserOp('<leader>ud', 'let g:wince_map_mode = wince_user#GotoSubwin(0, "undotree", "diff", g:wince_map_mode, 1)')
    endif
endif
