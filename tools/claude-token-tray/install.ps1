#Requires -Version 5.1
<#
.SYNOPSIS
    安裝「Claude token 用量」工作列/系統匣顯示工具。

.DESCRIPTION
    從 GitHub 下載 tools/claude-token-tray、安裝相依套件、寫入預設設定,
    並在「啟動」資料夾建立捷徑讓它開機自動執行。可重複執行(會覆蓋舊版檔案,
    等於是順便拿來更新)。

.PARAMETER InstallDir
    安裝目錄。預設 %LOCALAPPDATA%\ClaudeTokenTray

.PARAMETER Budget
    5 小時區塊的 token 預算,系統匣圖示與 tooltip 會依此顯示百分比。
    預設 2000000(2M)。設 0 表示不要預算(圖示只顯示壓縮後的 token 數)。

.PARAMETER Ui
    要開哪種介面:tray(系統匣圖示)、overlay(工作列浮動面板)、both(兩個都開)。
    預設 both。

.PARAMETER Branch
    要抓取的分支。預設 claude/windows-taskbar-token-usage-ghyq4k。

.PARAMETER NoAutostart
    不要建立開機自動啟動的捷徑。

.PARAMETER NoLaunch
    安裝完不要立刻啟動。

.PARAMETER Uninstall
    移除已安裝的工具與開機捷徑(設定檔不會刪)。執行前請先從系統匣/浮動面板的
    右鍵選單按「結束」,不然安裝目錄裡的檔案可能因為程式還在跑而刪不掉。

.EXAMPLE
    irm https://raw.githubusercontent.com/Suchongan/My_first_project/claude/windows-taskbar-token-usage-ghyq4k/tools/claude-token-tray/install.ps1 | iex

.EXAMPLE
    iex "& { $(irm https://raw.githubusercontent.com/Suchongan/My_first_project/claude/windows-taskbar-token-usage-ghyq4k/tools/claude-token-tray/install.ps1) } -Budget 500000 -Ui tray"
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "ClaudeTokenTray"),
    [long]$Budget = 2000000,
    [ValidateSet("tray", "overlay", "both")]
    [string]$Ui = "both",
    [string]$Branch = "claude/windows-taskbar-token-usage-ghyq4k",
    [switch]$NoAutostart,
    [switch]$NoLaunch,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
    # 舊版 .NET 可能沒有 Tls12 這個列舉值,忽略即可,系統通常還是會協商到堪用的版本。
}

$RepoOwner = "Suchongan"
$RepoName = "My_first_project"
$StartupLink = Join-Path ([Environment]::GetFolderPath("Startup")) "ClaudeTokenTray.lnk"

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Warn2 {
    param([string]$Message)
    Write-Host "!! $Message" -ForegroundColor Yellow
}

# --------------------------------------------------------------------------
# 解除安裝
# --------------------------------------------------------------------------
if ($Uninstall) {
    Write-Step "移除 Claude token 用量顯示工具"
    if (Test-Path $StartupLink) {
        Remove-Item $StartupLink -Force
        Write-Host "已移除開機捷徑:$StartupLink"
    } else {
        Write-Host "沒有找到開機捷徑,略過。"
    }
    if (Test-Path $InstallDir) {
        Remove-Item $InstallDir -Recurse -Force
        Write-Host "已移除安裝目錄:$InstallDir"
    } else {
        Write-Host "沒有找到安裝目錄,略過。"
    }
    Write-Host ""
    Write-Host "解除安裝完成。設定檔沒有一併刪除,如果不需要可以手動刪:"
    Write-Host "  $env:USERPROFILE\.claude\token_tray.json"
    return
}

# --------------------------------------------------------------------------
# 主流程
# --------------------------------------------------------------------------
try {

    # -- 1. 找 Python -------------------------------------------------------
    Write-Step "檢查 Python"
    $PythonExe = $null
    $PythonArgsPrefix = @()

    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCmd) {
        $PythonExe = $pythonCmd.Source
    } else {
        $pyCmd = Get-Command py -ErrorAction SilentlyContinue
        if ($pyCmd) {
            $PythonExe = $pyCmd.Source
            $PythonArgsPrefix = @("-3")
        }
    }

    if (-not $PythonExe) {
        Write-Warn2 "找不到 Python。請先安裝 Python 3.10 以上,例如:"
        Write-Host "    winget install Python.Python.3.12"
        Write-Host "或到 https://www.python.org/downloads/ 下載安裝,記得勾選 'Add python.exe to PATH'。"
        Write-Host "裝完後重新開一個 PowerShell 視窗,再執行一次這個安裝指令。"
        return
    }

    function Invoke-Python {
        & $PythonExe @PythonArgsPrefix @args
    }

    $verText = (Invoke-Python "--version") 2>&1
    Write-Host "找到:$verText ($PythonExe)"

    # -- 2. 下載程式碼 --------------------------------------------------------
    Write-Step "下載 tools/claude-token-tray(分支:$Branch)"
    $stamp = [Guid]::NewGuid().ToString("N")
    $tempZip = Join-Path $env:TEMP "claude-token-tray-$stamp.zip"
    $tempDir = Join-Path $env:TEMP "claude-token-tray-$stamp"
    $archiveUrl = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/$Branch.zip"

    try {
        Invoke-WebRequest -Uri $archiveUrl -OutFile $tempZip -UseBasicParsing
    } catch {
        Write-Warn2 "下載失敗:$($_.Exception.Message)"
        Write-Host "如果這個 repository 是 private,匿名下載會被拒絕。請改用已登入 GitHub 的瀏覽器,"
        Write-Host "到 https://github.com/$RepoOwner/$RepoName/tree/$Branch 用 Code -> Download ZIP,"
        Write-Host "解壓縮後把裡面的 tools\claude-token-tray 資料夾複製到 $InstallDir,"
        Write-Host "再到該目錄執行:$PythonExe -m pip install --user -r requirements.txt"
        return
    }

    Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force
    $extractedRoot = Get-ChildItem $tempDir -Directory | Select-Object -First 1
    if (-not $extractedRoot) {
        Write-Warn2 "下載的壓縮檔是空的,安裝中止。"
        return
    }
    $sourceDir = Join-Path $extractedRoot.FullName "tools\claude-token-tray"
    if (-not (Test-Path $sourceDir)) {
        Write-Warn2 "下載內容裡找不到 tools\claude-token-tray,分支名稱可能不對:$Branch"
        return
    }

    if (Test-Path $InstallDir) {
        Remove-Item $InstallDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Copy-Item (Join-Path $sourceDir "*") -Destination $InstallDir -Recurse -Force

    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "已安裝到:$InstallDir"

    # -- 3. 安裝相依套件 ------------------------------------------------------
    Write-Step "安裝相依套件(pystray、Pillow;工作列浮動面板不需要它們)"
    Invoke-Python "-m" "pip" "install" "--user" "-r" (Join-Path $InstallDir "requirements.txt")
    if ($LASTEXITCODE -ne 0) {
        Write-Warn2 "pip install 失敗(exit code $LASTEXITCODE)。系統匣圖示(--ui tray)可能無法使用,"
        Write-Warn2 "但工作列浮動面板(--ui overlay)只靠標準函式庫,不受影響。"
    }

    # -- 4. 寫入預設設定 ------------------------------------------------------
    Write-Step "寫入預設設定(Budget=$Budget, Ui=$Ui)"
    Push-Location $InstallDir
    try {
        $budgetExpr = "None"
        if ($Budget -gt 0) {
            $budgetExpr = "$Budget"
        }
        $pyCode = "from claude_token_tray import config; c = config.load(); c['ui'] = '$Ui'; c['budget'] = $budgetExpr; config.save(c); print('config saved:', config.config_path())"
        Invoke-Python "-c" $pyCode
    } finally {
        Pop-Location
    }

    # -- 5. 開機自動啟動 ------------------------------------------------------
    if (-not $NoAutostart) {
        Write-Step "建立開機自動啟動捷徑"
        $vbsPath = Join-Path $InstallDir "start_tray.vbs"
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($StartupLink)
        $shortcut.TargetPath = Join-Path $env:WINDIR "System32\wscript.exe"
        $shortcut.Arguments = "`"$vbsPath`""
        $shortcut.WorkingDirectory = $InstallDir
        $shortcut.Description = "Claude token 用量顯示"
        $shortcut.Save()
        Write-Host "已建立:$StartupLink"
    } else {
        Write-Host "略過開機自動啟動(-NoAutostart)。"
    }

    # -- 6. 立即啟動 ----------------------------------------------------------
    if (-not $NoLaunch) {
        Write-Step "啟動"
        $vbsPath = Join-Path $InstallDir "start_tray.vbs"
        Start-Process -FilePath "wscript.exe" -ArgumentList "`"$vbsPath`"" -WorkingDirectory $InstallDir
        Write-Host "已啟動,工作列附近應該幾秒內就會看到浮動面板/系統匣圖示。"
    } else {
        Write-Host "略過立即啟動(-NoLaunch)。"
    }

    Write-Host ""
    Write-Host "安裝完成!" -ForegroundColor Green
    Write-Host "安裝目錄:$InstallDir"
    Write-Host "設定檔:  $env:USERPROFILE\.claude\token_tray.json"
    Write-Host "手動調整,例如(在安裝目錄下執行):"
    Write-Host "  $PythonExe -m claude_token_tray --ui tray --budget 500k"
    Write-Host "解除安裝:重新下載這支腳本並加上 -Uninstall 執行"

} catch {
    Write-Host ""
    Write-Warn2 "安裝失敗:$($_.Exception.Message)"
    Write-Host $_.ScriptStackTrace
    return
}
