; ============================================================
; 隐藏窗口（移到屏幕外 + 去掉任务栏按钮）
; ============================================================

; 0，或 {hwnd, x, y, w, h}
global hiddenWin := 0

; 脚本退出 / 重载时把窗口还原，避免窗口永远留在屏幕外
OnExit(RestoreHiddenWindowOnExit)

; --- Ctrl+Alt+Z：隐藏当前窗口 ---
^!z:: {
    global hiddenWin

    if (hiddenWin && WinExist(hiddenWin.hwnd)) {
        MsgBox("当前已有被隐藏的窗口，请先恢复或关闭它。", "提示", "IconI T2")
        return
    }

    ; 不能把桌面 / 任务栏移到屏幕外
    activeID := WinExist("A")
    if (!activeID || IsShellWindow(activeID))
        return

    ; 保存窗口位置大小
    WinGetPos(&x, &y, &w, &h, activeID)
    hiddenWin := {hwnd: activeID, x: x, y: y, w: w, h: h}

    ; 移动到屏幕外；不使用 WinHide，避免 Chromium 失焦
    WinMove(-10000, 0, w, h, activeID)
    RemoveFromTaskbar(activeID)

    ; 保持焦点
    WinActivate(activeID)
}

; --- Ctrl+Alt+X：恢复隐藏窗口 ---
^!x:: {
    if (hwnd := RestoreHiddenWindow())
        WinActivate(hwnd)
    else
        MsgBox("当前没有被隐藏的窗口。", "提示", "IconI T2")
}

; --- Ctrl+Alt+C：关闭隐藏窗口 ---
^!c:: CloseHiddenWindow()

; 把隐藏的窗口移回原位并恢复任务栏按钮；成功返回窗口句柄，否则返回 0
RestoreHiddenWindow() {
    global hiddenWin

    if !(hiddenWin && WinExist(hiddenWin.hwnd)) {
        hiddenWin := 0
        return 0
    }

    hwnd := hiddenWin.hwnd
    AddToTaskbar(hwnd)
    WinMove(hiddenWin.x, hiddenWin.y, hiddenWin.w, hiddenWin.h, hwnd)

    hiddenWin := 0
    return hwnd
}

; 关闭隐藏的窗口。
; 先设为全透明再移回原位，屏幕上不会闪现，程序记住的关闭位置也正常；
; 如果 2 秒后窗口还在（多半弹了"是否保存"），就让它显示出来，免得对话框藏在屏幕外。
CloseHiddenWindow() {
    global hiddenWin

    if !(hiddenWin && WinExist(hiddenWin.hwnd)) {
        hiddenWin := 0
        return
    }

    hwnd := hiddenWin.hwnd
    prevTrans := WinGetTransparent(hwnd)
    try WinSetTransparent(0, hwnd)         ; 管理员权限窗口可能设置失败，不影响关闭
    RestoreHiddenWindow()
    WinClose(hwnd)

    if !WinWaitClose(hwnd, , 2)
        try WinSetTransparent(prevTrans = "" ? "Off" : prevTrans, hwnd)
}

; 注意：OnExit 回调返回非零值会阻止退出，所以这里不 return 任何值
RestoreHiddenWindowOnExit(*) {
    try RestoreHiddenWindow()
}
