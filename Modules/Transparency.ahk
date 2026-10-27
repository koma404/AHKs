; ============================================================
; 窗口透明度 (Win+滚轮)
; ============================================================

#WheelUp:: AdjustTransparency(+15)     ; 增加不透明度
#WheelDown:: AdjustTransparency(-15)   ; 增加透明度

; 不透明度限制在 15~255，防止窗口彻底消失找不到
AdjustTransparency(delta) {
    if !(hwnd := WinExist("A"))
        return

    current := WinGetTransparent(hwnd)
    ; 如果当前没有设置过透明度，默认当作 255 处理
    if (current = "")
        current := 255

    WinSetTransparent(Min(255, Max(15, current + delta)), hwnd)
}
