; ============================================================
; 任务栏图标隐藏 / 恢复
; ============================================================

; 被隐藏任务栏图标的窗口句柄列表
global hiddenTaskbarHWNDs := []

; 脚本退出 / 重载时把图标还原，避免窗口在任务栏上永久"消失"
OnExit(RestoreTaskbarIconsOnExit)

; --- Ctrl+Alt+W：隐藏当前窗口的任务栏图标 ---
^!w:: {
    global hiddenTaskbarHWNDs

    if !(activeID := WinExist("A"))
        return

    ; 已经在列表中就不重复添加
    for hwnd in hiddenTaskbarHWNDs
        if (hwnd = activeID)
            return

    RemoveFromTaskbar(activeID)
    hiddenTaskbarHWNDs.Push(activeID)
    ShowTip("已隐藏图标")
}

; --- Ctrl+Alt+E：恢复所有被隐藏的任务栏图标 ---
^!e:: {
    if (hiddenTaskbarHWNDs.Length = 0) {
        MsgBox("无效操作", "提示", "IconI T2")
        return
    }
    ShowTip("已恢复 " RestoreTaskbarIcons() " 个图标")
}

; 恢复所有被隐藏的任务栏图标，返回实际恢复的数量
RestoreTaskbarIcons() {
    global hiddenTaskbarHWNDs

    restoredCount := 0
    for hwnd in hiddenTaskbarHWNDs {
        if WinExist(hwnd) {
            AddToTaskbar(hwnd)
            restoredCount++
        }
    }
    hiddenTaskbarHWNDs := []
    return restoredCount
}

; 注意：OnExit 回调返回非零值会阻止退出，所以这里不 return 任何值
RestoreTaskbarIconsOnExit(*) {
    try RestoreTaskbarIcons()
}
