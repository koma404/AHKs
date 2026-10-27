; ============================================================
; 热字串 / 文本输入
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

; --- Ctrl+Q：输入当前日期时间 ---
^q:: SendText FormatTime(, "yyyy-MM-dd HH:mm:ss")
