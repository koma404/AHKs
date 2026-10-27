; ============================================================
; Win+Alt+Space：列出托盘图标（测试 TrayIcon 库）
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

            ; 格式化输出：[序号] 进程名 - 提示文本
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
