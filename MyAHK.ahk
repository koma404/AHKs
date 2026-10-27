#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
#Include "Lib\TrayIcon.ahk"

; ============================================================
; 全局状态
; ============================================================

; Ctrl+Alt+Z 隐藏的窗口：0，或 {hwnd, x, y, w, h, wasMax}
global hiddenWin := 0

; Ctrl+Alt+W 隐藏了任务栏图标的窗口句柄列表
global hiddenTaskbarHWNDs := []

; Ctrl+Alt+S 标记的窗口，以及切过去之前的原窗口
global pinnedWinID := 0
global prevWinID := 0

; 脚本退出 / 重载时，把隐藏的窗口和任务栏图标都还原，避免窗口"丢失"
OnExit(RestoreAllOnExit)


; ============================================================
; 通用工具函数
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
        Sleep 150              ; 给目标程序足够时间读取剪贴板
    }
    A_Clipboard := saved
}

; 桌面、任务栏这类系统外壳窗口，不应被移动 / 隐藏 / 设透明
IsShellWindow(hwnd) {
    try return WinGetClass(hwnd) ~= "^(Progman|WorkerW|Shell_TrayWnd|Shell_SecondaryTrayWnd)$"
    return true
}


; ============================================================
; 快速启动
; ============================================================

; Open websites
#g::Run "https://gemini.google.com/app"
#x::Run "https://grok.com/"

; Open local files
#n::Run '"E:\我是一个没有智力的大长椅\Documents\Input Tool\input.exe"'


; ============================================================
; 热字串
; ============================================================

; Use "addcode" to add collapsible code block in Luogu
:XC:addcode::{
    Print "::::success[代码]`n``````cpp`n`n```````n::::"
    Send "{UP 2}"
}

:XC:addT:: Print "int T; cin>>T; while(T--) solve();"
:XC:addSol::{
    Print "
    (
        inline void solve(){

        }
    )"
    Send "{UP}{Tab}"
}

:XC:Date:: SendInput A_YYYY A_MM A_DD

^q:: {
    SendText FormatTime(, "yyyy-MM-dd HH:mm:ss")
}


; ============================================================
; 托盘图标测试 (Win+Alt+Space)
; ============================================================

#!Space:: {
    maxShow := 10

    try {
        trayList := TrayIcon_GetInfo()

        if (trayList.Length = 0) {
            ShowTip("未检测到任何托盘图标。请检查是否有图标被隐藏，或尝试以管理员身份运行此脚本。", 3000)
            return
        }

        resultText := "成功检测到 " trayList.Length " 个托盘图标：`n"
        resultText .= "----------------------------------------`n"

        for index, icon in trayList {
            ; 只展示前 maxShow 个，确实还有剩余时才提示
            if (index > maxShow) {
                resultText .= "... 后面还有 " (trayList.Length - maxShow) " 个图标 ...`n"
                break
            }

            sTip := icon.tooltip ? icon.tooltip : "(无文字提示)"
            ; 过滤掉换行符，防止弹窗排版错乱
            sTip := StrReplace(StrReplace(sTip, "`r", " "), "`n", " ")

            resultText .= "[" index "] 进程: " icon.process "`n    提示: " sTip "`n`n"
        }

        MsgBox(resultText, "测试结果 - 成功!", 64)

    } catch Error as err {
        ShowTip("读取托盘时偶发错误: " err.Message, 3000)
    }
}


; ============================================================
; 网易云音乐 / 娱乐程序
; ============================================================

; Ctrl+Alt+J：启动网易云音乐并最小化到任务栏
^!j:: {
    musicPath := "F:\CloudMusic\cloudmusic.exe"

    try Run(musicPath)
    catch {
        ShowTip("无法启动：" musicPath, 3000)
        return
    }

    ; 最多等 5 秒，等窗口真正出现
    if WinWait("ahk_exe cloudmusic.exe", , 5) {
        Sleep 1000             ; 给窗口 1 秒完全初始化
        try WinMinimize("ahk_exe cloudmusic.exe")
    }
}

CloseAmusement() {
    ; 使用系统 taskkill 强制结束所有名称匹配的进程（/F 为强制，/IM 指定映像名称）
    for exe in ["cloudmusic.exe", "Reader.exe", "cloudmusic_reporter.exe"]
        RunWait("taskkill /F /IM " exe, , "Hide")

    Sleep 300

    ; Clean TrayIcon
    TrayIcon_Clean()
}

^!q:: CloseAmusement()

; 按住左右键再按中键：紧急关闭娱乐程序和隐藏窗口
~MButton:: {
    if GetKeyState("LButton", "P") && GetKeyState("RButton", "P") {
        CloseAmusement()
        CloseHiddenWindow()
    }
}


; ============================================================
; Chrome / Supermium：F4 清除浏览数据
; ============================================================

#HotIf WinActive("ahk_exe chrome.exe") || WinActive("ahk_exe supermium.exe")
F4::{
    Send "^+{Del}"
    Sleep 700
    Send "{Tab}{Enter}"
    Sleep 300
    Send "^w"
}
#HotIf


; ============================================================
; 隐藏窗口（移到屏幕外 + 去掉任务栏按钮）
; ============================================================

; --- Ctrl+Alt+Z：隐藏当前窗口 ---
^!z:: {
    global hiddenWin

    if (hiddenWin && WinExist(hiddenWin.hwnd)) {
        MsgBox("当前已有被隐藏的窗口，请先恢复或关闭它。", "提示", "IconI T2")
        return
    }

    activeID := WinExist("A")
    if (!activeID || IsShellWindow(activeID))
        return

    ; 最大化窗口先还原，记录的是还原后的位置，恢复时再重新最大化
    wasMax := WinGetMinMax(activeID) = 1
    if (wasMax)
        WinRestore(activeID)

    WinGetPos(&x, &y, &w, &h, activeID)
    hiddenWin := {hwnd: activeID, x: x, y: y, w: w, h: h, wasMax: wasMax}

    ; 移动到屏幕外；不使用 WinHide，避免 Chromium 失焦
    WinMove(-10000, 0, , , activeID)
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
    if (hiddenWin.wasMax)
        WinMaximize(hwnd)

    hiddenWin := 0
    return hwnd
}

; 先移回屏幕内再关闭：程序记住的关闭位置正常，"是否保存"之类的对话框也看得见
CloseHiddenWindow() {
    if (hwnd := RestoreHiddenWindow())
        WinClose(hwnd)
}


; ============================================================
; 窗口透明度 (Win+滚轮)
; ============================================================

#WheelUp:: AdjustTransparency(+15)     ; 增加不透明度
#WheelDown:: AdjustTransparency(-15)   ; 增加透明度

; 不透明度限制在 15~255（防止窗口彻底消失找不到）；回到 255 时关闭透明效果
AdjustTransparency(delta) {
    if !(hwnd := WinExist("A")) || IsShellWindow(hwnd)
        return

    current := WinGetTransparent(hwnd)
    ; 没有设置过透明度时，当作 255 处理
    if (current = "")
        current := 255

    newTrans := Min(255, Max(15, current + delta))
    if (newTrans = current)
        return

    WinSetTransparent(newTrans = 255 ? "Off" : newTrans, hwnd)
}


; ============================================================
; 任务栏图标隐藏 / 恢复
; ============================================================

; --- Ctrl+Alt+W：隐藏当前窗口的任务栏图标 ---
^!w:: {
    global hiddenTaskbarHWNDs

    activeID := WinExist("A")
    if (!activeID || IsShellWindow(activeID))
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


; ============================================================
; 标记窗口快速切换
; ============================================================

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
        ShowTip("还没有标记窗口（Ctrl+Alt+S 标记）")
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


; ============================================================
; 退出清理
; ============================================================

; 注意：OnExit 回调返回非零值会阻止退出，所以这里不 return 任何值
RestoreAllOnExit(*) {
    RestoreHiddenWindow()
    RestoreTaskbarIcons()
}
