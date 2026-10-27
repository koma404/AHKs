#Requires AutoHotkey v2.0
; ======================================================================================================================
; 函数名称 ......: TrayIcon_GetInfo
; 描述 ..........: 获取托盘图标的详细信息（完美兼容 Win7 x64 / Win10，使用 AHK v2 语法）
; ======================================================================================================================
TrayIcon_GetInfo(sExeName := "") {
    Setting_A_DetectHiddenWindows := A_DetectHiddenWindows
    DetectHiddenWindows true
    oTrayInfo := []

    ; Windows 7 / 10 的托盘和溢出区域类名
    for key, sTray in ["Shell_TrayWnd", "NotifyIconOverflowWindow"] {
        ; 获取托盘工具栏的专用句柄
        idxTB := TrayIcon_GetTrayBar(sTray)
        if (!idxTB)
            continue

        try hwTray := ControlGetHwnd("ToolbarWindow32" idxTB, "ahk_class " sTray)
        if (!hwTray)
            continue

        pidTaskbar := WinGetPID("ahk_class " sTray)

        ; 关键点：针对 64 位系统进行结构体指针和尺寸的精确计算
        hProc := DllCall("OpenProcess", "UInt", 0x38, "Int", 0, "UInt", pidTaskbar, "Ptr")
        if (!hProc)
            continue

        ; 核心：在 64 位 Windows 下，指针大小（A_PtrSize）为 8，结构体对齐完全不同
        bCount := DllCall("User32.dll\SendMessage", "Ptr", hwTray, "UInt", 0x418, "Ptr", 0, "Ptr", 0, "Ptr") ; TB_BUTTONCOUNT

        pRB := DllCall("VirtualAllocEx", "Ptr", hProc, "Ptr", 0, "Ptr", A_PtrSize == 8 ? 32 : 20, "UInt", 0x1000, "UInt", 0x4, "Ptr")
        btn := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
        nRead := Buffer(A_PtrSize == 8 ? 8 : 4, 0)

        Loop bCount {
            DllCall("User32.dll\SendMessage", "Ptr", hwTray, "UInt", 0x417, "Ptr", A_Index - 1, "Ptr", pRB, "Ptr") ; TB_GETBUTTON
            DllCall("ReadProcessMemory", "Ptr", hProc, "Ptr", pRB, "Ptr", btn.Ptr, "Ptr", btn.Size, "Ptr", nRead.Ptr)

            iBitmap := NumGet(btn, 0, "Int")
            idCmd   := NumGet(btn, 4, "Int")
            fsState := NumGet(btn, 8, "UChar")
            fsStyle := NumGet(btn, 9, "UChar")

            ; 64 位系统的偏移地址调整
            dwData  := NumGet(btn, A_PtrSize == 8 ? 16 : 12, "Ptr")
            iString := NumGet(btn, A_PtrSize == 8 ? 24 : 16, "Ptr")

            ; 再次读取远程进程内存获取 TRAYDATA
            data := Buffer(A_PtrSize == 8 ? 32 : 24, 0)
            DllCall("ReadProcessMemory", "Ptr", hProc, "Ptr", dwData, "Ptr", data.Ptr, "Ptr", data.Size, "Ptr", nRead.Ptr)

            hWnd_Icon := NumGet(data, 0, "Ptr")
            uID       := NumGet(data, A_PtrSize == 8 ? 8 : 4, "UInt")
            msgID     := NumGet(data, A_PtrSize == 8 ? 12 : 8, "UInt")

            try sProcess := WinGetProcessName("ahk_id " hWnd_Icon)
            catch
                sProcess := ""

            if (sExeName != "" && sProcess != sExeName)
                continue

            ; 读取 Tooltip 文本
            sTooltip := ""
            if (iString != -1) {
                tipBuf := Buffer(512, 0)
                DllCall("ReadProcessMemory", "Ptr", hProc, "Ptr", iString, "Ptr", tipBuf.Ptr, "Ptr", tipBuf.Size, "Ptr", nRead.Ptr)
                sTooltip := StrGet(tipBuf.Ptr, "UTF-16")
            }

            ; --- 修复后的代码段 ---
            try hWnd_Icon := NumGet(data, 0, "Ptr")
            catch
                hWnd_Icon := 0

            ; 1. 安全获取进程名，失败则为空
            try sProcess := WinGetProcessName("ahk_id " hWnd_Icon)
            catch
                sProcess := ""

            if (sExeName != "" && sProcess != sExeName)
                continue

            ; 2. 【核心修复】安全获取 PID，如果窗口不存在了，直接给 0，避免崩溃
            try nPID := WinGetPID("ahk_id " hWnd_Icon)
            catch
                nPID := 0

            ; 读取 Tooltip 文本
            sTooltip := ""
            if (iString != -1) {
                tipBuf := Buffer(512, 0)
                DllCall("ReadProcessMemory", "Ptr", hProc, "Ptr", iString, "Ptr", tipBuf.Ptr, "Ptr", tipBuf.Size, "Ptr", nRead.Ptr)
                sTooltip := StrGet(tipBuf.Ptr, "UTF-16")
            }

            ; 3. 推入数组（使用上面安全获取到的 nPID）
            oTrayInfo.Push({
                idx: A_Index - 1,
                idcmd: idCmd,
                pid: nPID,
                uid: uID,
                msgid: msgID,
                hwnd: hWnd_Icon,
                process: sProcess,
                tooltip: sTooltip,
                tray: sTray
            })
            ; --- 修复结束 ---
        }
        DllCall("VirtualFreeEx", "Ptr", hProc, "Ptr", pRB, "Ptr", 0, "UInt", 0x8000)
        DllCall("CloseHandle", "Ptr", hProc)
    }

    DetectHiddenWindows Setting_A_DetectHiddenWindows
    return oTrayInfo
}

TrayIcon_GetTrayBar(sTray := "Shell_TrayWnd") {
    try {
        hwTray := WinGetID("ahk_class " sTray)
        hwControl := ControlGetHwnd("ToolbarWindow321", "ahk_id " hwTray)
        return 1
    } catch {
        ; 如果找不到 ToolbarWindow321，循环探测
        Loop {
            try {
                hWnd := ControlGetHwnd("ToolbarWindow32" A_Index, "ahk_class " sTray)
                if (hWnd)
                    return A_Index
            } catch {
                break
            }
        }
    }
    return 0
}

; ======================================================================================================================
; 示例：移除无用的死图标（Orphaned Icons）
; ======================================================================================================================
TrayIcon_Clean() {
    info := TrayIcon_GetInfo()
    for item in info {
        ; 如果图标所属的进程已经不存在，向托盘发送删除消息
        if (item.process == "") {
            TrayIcon_Remove(item.hwnd, item.uid, item.tray)
        }
    }
}

TrayIcon_Remove(hWnd, uID, sTray := "Shell_TrayWnd") {
    ; 创建 NOTIFYICONDATA 结构体以通知系统删除图标
    NID := Buffer(A_PtrSize == 8 ? 936 : 528, 0)
    NumPut("UInt", NID.Size, NID, 0)
    NumPut("Ptr", hWnd, NID, A_PtrSize == 8 ? 8 : 4)
    NumPut("UInt", uID, NID, A_PtrSize == 8 ? 16 : 8)
    return DllCall("shell32\Shell_NotifyIcon", "UInt", 0x2, "Ptr", NID.Ptr) ; NIM_DELETE = 0x2
}