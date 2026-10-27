; ============================================================
; 快速启动
; ============================================================

; Open websites
#g::Run "https://gemini.google.com/app"
#x::Run "https://grok.com/"

; Open local files
#n::Run '"E:\我是一个没有智力的大长椅\Documents\Input Tool\input.exe"'

; --- Ctrl+Alt+J：启动网易云音乐并最小化 ---
^!j:: {
    Run "F:\CloudMusic\cloudmusic.exe"

    ; 最多等约 5 秒，直到窗口真正出现
    if WinWait("ahk_exe cloudmusic.exe", , 5) {
        Sleep 1000             ; 给窗口 1 秒完全初始化
        WinMinimize "ahk_exe cloudmusic.exe"
    }
}
