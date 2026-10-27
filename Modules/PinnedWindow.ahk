; ============================================================
; 标记窗口快速切换
; ============================================================

global pinnedWinID := 0
global prevWinID := 0

; --- Ctrl+Alt+S：标记当前窗口 ---
^!s:: {
    global pinnedWinID

    if (activeID := WinExist("A")) {
        pinnedWinID := activeID
        ShowTip("已标记")
    }
}

; --- Ctrl+Alt+A：在标记窗口和原窗口之间切换 ---
^!a:: {
    global pinnedWinID, prevWinID

    if !(pinnedWinID && WinExist(pinnedWinID)) {
        pinnedWinID := 0
        prevWinID := 0
        return
    }

    currentActive := WinExist("A")

    if (currentActive = pinnedWinID) {
        ; 当前就是标记窗口：置底并切回原窗口
        WinMoveBottom(pinnedWinID)
        if (prevWinID && WinExist(prevWinID))
            WinActivate(prevWinID)
    } else {
        ; 当前在其他窗口：记录原窗口，然后切到标记窗口
        prevWinID := currentActive
        if (WinGetMinMax(pinnedWinID) = -1)
            WinRestore(pinnedWinID)
        WinActivate(pinnedWinID)
    }
}
