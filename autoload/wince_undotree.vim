" Wince undotree plugin - autoloaded portion
let s:Log = jer_log#LogFunctions('wince-undotree-subwin')
let s:Win = jer_win#WinFunctions()

" Callback that opens the undotree windows for the current window
function! wince_undotree#ToOpen()
    call s:Log.INF('wince_undotree#ToOpen')
    if (exists('t:undotree') && t:undotree.IsVisible())
        throw 'Undotree window is already open'
    endif

    " Before opening the tree window, make sure there's enough room.
    " We need at least <undotree_width + 2> columns - <undotree_width> for the tree
    " content, one for the vertical divider, and one for the supwin.
    " We also need enough room to then open the diff window. We need
    " at least <undodiff_height + 2> rows. <undodiff_height> for the diff content,
    " one for the tree statusline, and at least one for the tree content
    if winwidth(0) <# g:wince_undotree_width + 2 || winheight(0) <# g:wince_undodiff_height + 2
        throw 'Not enough room'
    endif

    let jtarget = s:Win.getid()

    UndotreeShow

    " UndotreeShow does not directly cause the undotree to be drawn. Instead,
    " it registers an autocmd that draws the tree when one of a set of events
    " fires. The direct call to undotree#UndotreeUpdate() here makes sure that
    " the undotree is drawn before wince_undotree#ToOpen returns, which is required
    " for signs and folds to be properly restored when the undotree window is
    " closed and reopened.
    noautocmd call s:Win.gotoid(jtarget)
    call undotree#UndotreeUpdate()

    let treeid = -1
    let diffid = -1

    " The Undotree plugin has a troublesome feature - you can switch the
    " diffpanel window on and off. I deal with this by defining the Undotree subwin
    " group as having either one subwin or two subwins, so
    " wince_undotree#ToOpen may return either one winid or two winids. Unfortunately
    " this means the diffpanel can't be toggled during a session
    let diffon = (exists('g:undotree_DiffAutoOpen') && g:undotree_DiffAutoOpen == 0)

    let treebufname = t:undotree.bufname
    let diffbufname = t:diffpanel.bufname

    for winnr in range(1,winnr('$'))
        if treeid >=# 0 && (diffon || diffid >=# 0)
            break
        endif

        let curbufname = bufname(winbufnr(winnr))
        if treebufname ==# curbufname
            let treeid = s:Win.getid(winnr)
            continue
        endif
        
        if diffbufname ==# curbufname
            let diffid = s:Win.getid(winnr)
            continue
        endif
    endfor

    let treenr = s:Win.id2win(treeid)
    call setwinvar(treenr, '&number', 1)
    call setwinvar(treenr, 'j_undotree_target', jtarget)

    if !diffon
        let diffnr = s:Win.id2win(diffid)
        call setwinvar(diffnr, '&number', 1)
        call setwinvar(diffnr, 'j_undotree_target', jtarget)
    endif

    if !diffon
        return [treeid, diffid]
    else
        return [treeid]
    endif
endfunction

" Callback that closes the undotree windows for the current window
function! wince_undotree#ToClose()
    call s:Log.INF('wince_undotree#ToClose')
    if (!exists('t:undotree') || !t:undotree.IsVisible())
        throw 'Undotree window is not open'
    endif

    " When closing the undotree, we want its supwin to fill the
    " space left. If there is also a supwin on the other side of the undotree
    " window, Vim may choose to fill the space with that one instead. Setting
    " splitright causes Vim to always pick the supwin to the left via some undocumented
    " behaviour. Conversely, resetting splitbelow causes Vim to always pick
    " the supwin to the right.
    let oldsr = &splitright
    if g:wince_undotree_right
        let &splitright = 1
    else
        let &splitright = 0
    endif

    UndotreeHide

    " Restore splitright
    let &splitright = oldsr
endfunction

" Callback that returns {'typename':'tree','supwin':<id>} or
" {'typename':'diff','supwin':<id>} if the supplied winid is for an undotree
" window
function! wince_undotree#ToIdentify(winid)
    call s:Log.DBG('wince_undotree#ToIdentify ', a:winid)
    if (!exists('t:undotree') || !t:undotree.IsVisible())
        return {}
    endif

    let curbufname = bufname(winbufnr(a:winid))
    if t:undotree.bufname ==# curbufname
        let typename = 'tree'
    elseif t:diffpanel.bufname ==# curbufname
        let typename = 'diff'
    else
        return {}
    endif

    let jtarget = getwinvar(s:Win.id2win(a:winid), 'j_undotree_target', 0)
    if jtarget
        let supwinid = jtarget
    else
        let supwinid = -1
        let targetid = t:undotree.targetid
        for winnr in range(1, winnr('$'))
            if getwinvar(winnr, 'undotree_id') == targetid
                let supwinid = s:Win.getid(winnr)
                call setwinvar(s:Win.id2win(a:winid), 'j_undotree_target', supwinid)
                break
            endif
        endfor
    endif
    return {'typename':typename,'supwin':supwinid}
endfunction

" Returns the statusline of the undotree window
function! wince_undotree#TreeStatusLine()
    call s:Log.DBG('UndotreeStatusLine')
    let statusline = ''

    " 'Undotree' string
    let statusline .= '%5*[Undotree]'

    " Start truncating
    let statusline .= '%1*%<'

    " Right-justify from now on
    let statusline .= '%=%<'

    " [Current line/Total lines][% of buffer]
    let statusline .= '%5*[%l/%L][%p%%]'

    return statusline
endfunction

" Returns the statusline of the undodiff window
function! wince_undotree#DiffStatusLine()
    call s:Log.DBG('UndodiffStatusLine')
    let statusline = ''

    " 'Undodiff' string
    let statusline .= '%5*[Undodiff]'

    " Start truncating
    let statusline .= '%1*%<'

    " Right-justify from now on
    let statusline .= '%=%<'

    " [Current line/Total lines][% of buffer]
    let statusline .= '%5*[%l/%L][%p%%]'

    return statusline
endfunction

" For each supwin, make sure the undotree subwin group exists if and only if
" that supwin has undo history
function! wince_undotree#Update()
    call s:Log.DBG('wince_undotree#Update')
    " Make sure scrollbind and cursorbind are off. For reasons I don't
    " understand, moving from window to window when there are
    " scrollbound/cursorbound windows can change those windows' cursor
    " positions
    let opts = {'s':&l:scrollbind,'c':&l:cursorbind}
    let &l:scrollbind = 0
    let &l:cursorbind = 0

    let info = wince_common#GetCursorPosition()
    try
        for supwinid in wince_model#SupwinIds()
            let undotreewinsexist = wince_model#SubwinGroupExists(supwinid, 'undotree')

            " Special case: Terminal windows should never have undotrees
            if undotreewinsexist && wince_state#WinIsTerminal(supwinid)
                call s:Log.INF('Removing undotree subwin group from terminal supwin ', supwinid)
                call wince_user#RemoveSubwinGroup(supwinid, 'undotree')
                continue
            endif

            noautocmd silent call wince_state#MoveCursorToWinid(supwinid)
            let undotreeexists = !empty(undotree().entries)

            if undotreewinsexist && !undotreeexists
                call s:Log.INF('Removing undotree subwin group from supwin ', supwinid, ' because its buffer has no undotree')
                call wince_user#RemoveSubwinGroup(supwinid, 'undotree')
                continue
            endif

            if !undotreewinsexist && undotreeexists
                call s:Log.INF('Adding undotree subwin group to supwin ', supwinid, ' because its buffer has an undotree')
                call wince_user#AddSubwinGroup(supwinid, 'undotree', 1, 0)
                continue
            endif
        endfor
    finally
        call wince_common#RestoreCursorPosition(info)
        let &l:scrollbind = opts.s
        let &l:cursorbind = opts.c
    endtry
endfunction

function! wince_undotree#CloseDangling()
    for winnr in range(1, winnr('$'))
        let statusline = getwinvar(winnr, '&statusline', '')
        if statusline ==# g:wince_undotree_subwin_statusline || statusline ==# g:wince_undodiff_subwin_statusline
            let winid = s:Win.getid(winnr)
            call s:Log.INF('Closing dangling window with winnr ', winid)
            call wince_state#CloseWindow(winid, g:wince_undotree_right)
        endif
    endfor
endfunction

