#Requires AutoHotkey v2.0
#NoTrayIcon

; 第三方库：托盘图标读取 / 清理（TrayIcon_GetInfo、TrayIcon_Clean）
#Include "Lib\TrayIcon.ahk"

; 各功能模块（模块顶层的全局变量和 OnExit 会在启动时按顺序执行）
#Include "Modules\Common.ahk"
#Include "Modules\Launchers.ahk"
#Include "Modules\Hotstrings.ahk"
#Include "Modules\TrayTest.ahk"
#Include "Modules\Amusement.ahk"
#Include "Modules\Browser.ahk"
#Include "Modules\HiddenWindow.ahk"
#Include "Modules\Transparency.ahk"
#Include "Modules\TaskbarIcons.ahk"
#Include "Modules\PinnedWindow.ahk"
