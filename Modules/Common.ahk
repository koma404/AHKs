; ============================================================
; 通用工具函数（被其他模块共用）
; ============================================================

ShowTip(text, ms := 1500) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -ms)
}

; 通过剪贴板粘贴文本，完成后恢复原剪贴板
Print(text) {
    saved := ClipboardAll()
    A_Clipboard := ""          ; 先清空，ClipWait 才能真正等到新内容
    A_Clipboard := text
    if ClipWait(1) {
        Send "^v"
        Sleep 70
    }
    A_Clipboard := saved       ; 无论粘贴是否成功，都恢复原剪贴板
}

; 桌面、任务栏这类系统外壳窗口
IsShellWindow(hwnd) {
    try return WinGetClass(hwnd) ~= "^(Progman|WorkerW|Shell_TrayWnd|Shell_SecondaryTrayWnd)$"
    return true
}

; --- ITaskbarList COM 接口 ---
; vtable: 3 = HrInit, 4 = AddTab, 5 = DeleteTab
SetTaskbarTab(hwnd, show) {
    static CLSID_TaskbarList := "{56FDF344-FD6D-11d0-958A-006097C9A090}"
    static IID_ITaskbarList  := "{56FDF342-FD6D-11d0-958A-006097C9A090}"

    try {
        tbl := ComObject(CLSID_TaskbarList, IID_ITaskbarList)
        ComCall(3, tbl)                          ; HrInit (必须先初始化)
        ComCall(show ? 4 : 5, tbl, "ptr", hwnd)  ; AddTab / DeleteTab
    }
}

RemoveFromTaskbar(hwnd) => SetTaskbarTab(hwnd, false)
AddToTaskbar(hwnd) => SetTaskbarTab(hwnd, true)
