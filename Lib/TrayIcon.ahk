#Requires AutoHotkey v2.0
; ======================================================================================================================
; TrayIcon —— 读取 / 清理通知区域（托盘）图标（AHK v2，兼容 Win7 / Win10）
;
;   TrayIcon_GetInfo([sExeName])   返回数组，每项 {idx, idcmd, pid, uid, msgid, hwnd, process, tooltip, tray}
;   TrayIcon_Clean()               删除所属窗口已不存在的"死图标"
;   TrayIcon_Remove(hWnd, uID)     删除指定图标
;
; 注意：要读取 explorer.exe 的内存，结构体布局取决于 explorer 的位数，
;       所以 64 位系统必须用 64 位 AutoHotkey 运行（32 位 AHK 会直接报错，而不是读出乱码）。
; ======================================================================================================================

TrayIcon_GetInfo(sExeName := "") {
    if (A_Is64bitOS && A_PtrSize = 4)
        throw Error("64 位系统请用 64 位 AutoHotkey 运行，否则无法读取托盘图标。")

    prevDHW := A_DetectHiddenWindows
    DetectHiddenWindows true
    oTrayInfo := []
    try {
        ; 主托盘区域，以及"显示隐藏的图标"弹出的溢出区域
        for sTray in ["Shell_TrayWnd", "NotifyIconOverflowWindow"] {
            if (hwTray := TrayIcon_GetTrayBar(sTray))
                TrayIcon_ReadToolbar(hwTray, sTray, sExeName, oTrayInfo)
        }
    } finally {
        DetectHiddenWindows prevDHW
    }
    return oTrayInfo
}

; 返回托盘图标所在工具栏的句柄，找不到返回 0。
; 不能直接用 ToolbarWindow321：开启"快速启动"等工具栏后编号会变，
; 所以按父窗口判断（SysPager = 主托盘区，NotifyIconOverflowWindow = 溢出区）。
TrayIcon_GetTrayBar(sTray := "Shell_TrayWnd") {
    prevDHW := A_DetectHiddenWindows
    DetectHiddenWindows true
    try {
        for hCtrl in WinGetControlsHwnd("ahk_class " sTray) {
            if (TrayIcon_ClassOf(hCtrl) != "ToolbarWindow32")
                continue
            sParent := TrayIcon_ClassOf(DllCall("GetParent", "Ptr", hCtrl, "Ptr"))
            if (sParent = "SysPager" || sParent = "NotifyIconOverflowWindow")
                return hCtrl
        }
    } catch {
        ; 托盘窗口不存在（例如 Explorer 正在重启）
    } finally {
        DetectHiddenWindows prevDHW
    }
    return 0
}

; 读取一个托盘工具栏中的所有图标，结果追加到 oTrayInfo
TrayIcon_ReadToolbar(hwTray, sTray, sExeName, oTrayInfo) {
    static TB_GETBUTTON := 0x417, TB_BUTTONCOUNT := 0x418
    ; TBBUTTON: iBitmap(0) idCommand(4) fsState(8) fsStyle(9) bReserved[] dwData iString
    static szBtn     := A_PtrSize = 8 ? 32 : 20
    static offData   := A_PtrSize = 8 ? 16 : 12
    static offString := A_PtrSize = 8 ? 24 : 16
    ; TRAYDATA: hwnd(0) uID uCallbackMessage Reserved[2] hIcon
    static szData    := A_PtrSize = 8 ? 32 : 24
    static offUID    := A_PtrSize = 8 ? 8 : 4
    static offMsg    := A_PtrSize = 8 ? 12 : 8

    pidTaskbar := 0
    DllCall("GetWindowThreadProcessId", "Ptr", hwTray, "UInt*", &pidTaskbar)

    ; PROCESS_VM_OPERATION | PROCESS_VM_READ | PROCESS_VM_WRITE
    if !(hProc := DllCall("OpenProcess", "UInt", 0x38, "Int", false, "UInt", pidTaskbar, "Ptr"))
        return
    ; 在 explorer 进程里分配一块内存，用来接收 TB_GETBUTTON 的结果（MEM_COMMIT, PAGE_READWRITE）
    if !(pRB := DllCall("VirtualAllocEx", "Ptr", hProc, "Ptr", 0, "UPtr", szBtn, "UInt", 0x1000, "UInt", 0x4, "Ptr")) {
        DllCall("CloseHandle", "Ptr", hProc)
        return
    }

    btn    := Buffer(szBtn, 0)
    data   := Buffer(szData, 0)
    tipBuf := Buffer(256, 0)      ; szTip 最多 128 个 WCHAR

    try {
        bCount := DllCall("SendMessage", "Ptr", hwTray, "UInt", TB_BUTTONCOUNT, "Ptr", 0, "Ptr", 0, "Ptr")
        Loop bCount {
            idx := A_Index - 1
            if !DllCall("SendMessage", "Ptr", hwTray, "UInt", TB_GETBUTTON, "Ptr", idx, "Ptr", pRB, "Ptr")
                continue
            if !TrayIcon_ReadMem(hProc, pRB, btn)
                continue

            idCmd   := NumGet(btn, 4, "Int")
            dwData  := NumGet(btn, offData, "UPtr")
            iString := NumGet(btn, offString, "Ptr")

            ; 读不到 TRAYDATA 的按钮直接跳过，避免产生 hwnd = 0 的垃圾条目
            if !(dwData && TrayIcon_ReadMem(hProc, dwData, data))
                continue

            hWnd_Icon := NumGet(data, 0, "UPtr")
            uID       := NumGet(data, offUID, "UInt")
            msgID     := NumGet(data, offMsg, "UInt")

            ; 所属窗口已不存在时，进程名为空、PID 为 0
            try sProcess := WinGetProcessName("ahk_id " hWnd_Icon)
            catch
                sProcess := ""

            if (sExeName != "" && sProcess != sExeName)
                continue

            try nPID := WinGetPID("ahk_id " hWnd_Icon)
            catch
                nPID := 0

            sTooltip := ""
            if (iString && iString != -1 && TrayIcon_ReadMem(hProc, iString, tipBuf))
                sTooltip := StrGet(tipBuf, "UTF-16")

            oTrayInfo.Push({
                idx: idx,
                idcmd: idCmd,
                pid: nPID,
                uid: uID,
                msgid: msgID,
                hwnd: hWnd_Icon,
                process: sProcess,
                tooltip: sTooltip,
                tray: sTray
            })
        }
    } finally {
        DllCall("VirtualFreeEx", "Ptr", hProc, "Ptr", pRB, "UPtr", 0, "UInt", 0x8000)  ; MEM_RELEASE
        DllCall("CloseHandle", "Ptr", hProc)
    }
}

; 从 explorer 进程读取 buf.Size 字节到 buf，成功返回 true
TrayIcon_ReadMem(hProc, pRemote, buf) {
    return DllCall("ReadProcessMemory", "Ptr", hProc, "Ptr", pRemote, "Ptr", buf, "UPtr", buf.Size, "Ptr", 0)
}

TrayIcon_ClassOf(hwnd) {
    buf := Buffer(512, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", buf, "Int", 256)
    return StrGet(buf)
}

; ======================================================================================================================
; 移除无用的死图标（进程被强制结束后残留在托盘里的图标）
; ======================================================================================================================
TrayIcon_Clean() {
    for item in TrayIcon_GetInfo() {
        ; 图标所属的窗口已经不存在
        if (item.hwnd && !DllCall("IsWindow", "Ptr", item.hwnd))
            TrayIcon_Remove(item.hwnd, item.uid)
    }
}

; sTray 参数仅为兼容旧调用保留，未使用
TrayIcon_Remove(hWnd, uID, sTray := "Shell_TrayWnd") {
    ; NOTIFYICONDATAW（Vista+ 完整大小）：cbSize(0) hWnd uID ...
    NID := Buffer(A_PtrSize = 8 ? 976 : 956, 0)
    NumPut("UInt", NID.Size, NID, 0)
    NumPut("Ptr", hWnd, NID, A_PtrSize = 8 ? 8 : 4)
    NumPut("UInt", uID, NID, A_PtrSize = 8 ? 16 : 8)
    return DllCall("shell32\Shell_NotifyIconW", "UInt", 0x2, "Ptr", NID, "Int")  ; NIM_DELETE
}
