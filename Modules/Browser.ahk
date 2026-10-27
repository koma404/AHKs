; ============================================================
; Chrome / Supermium：F4 清除浏览数据并关闭设置页
; ============================================================

#HotIf WinActive("ahk_exe chrome.exe") || WinActive("ahk_exe supermium.exe")
F4:: {
    Send "^+{Del}"
    Sleep 700
    Send "{Tab}{Enter}"
    Sleep 300
    Send "^w"
}
#HotIf
