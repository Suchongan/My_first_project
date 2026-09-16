@echo off
REM 啟動 Claude token 用量顯示(不開主控台視窗)。
REM 參數會原樣傳給程式,例如:start_tray.bat --ui both --budget 500k
cd /d "%~dp0"
start "" pythonw -m claude_token_tray %*
