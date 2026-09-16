' 完全無視窗地啟動 Claude token 用量顯示。
' 把這個檔案的捷徑放進「啟動」資料夾(Win+R 輸入 shell:startup)即可開機自動執行。
Dim shell, fso, here
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
here = fso.GetParentFolderName(WScript.ScriptFullName)
shell.CurrentDirectory = here
shell.Run "pythonw -m claude_token_tray --ui both", 0, False
