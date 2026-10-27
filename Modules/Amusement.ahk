; ============================================================
; 一键关闭娱乐程序
; ============================================================

CloseAmusement() {
    ; 使用系统 taskkill 强制结束所有名称匹配的进程（/F 为强制，/IM 指定映像名称）
    for exe in ["cloudmusic.exe", "Reader.exe", "cloudmusic_reporter.exe"]
        RunWait("taskkill /F /IM " exe, , "Hide")

    Sleep 300

    ; 清理被强杀进程残留的托盘图标
    TrayIcon_Clean()
}

; --- Ctrl+Alt+Q：关闭娱乐程序 ---
^!q:: CloseAmusement()

; --- 按住左右键再按中键：关闭娱乐程序和隐藏窗口 ---
~MButton:: {
    if GetKeyState("LButton", "P") && GetKeyState("RButton", "P") {
        CloseAmusement()
        CloseHiddenWindow()
    }
}
