# Claude token 用量:Windows 工作列即時顯示

在 Windows 工作列上即時看到目前的 Claude Code token 用量,不用切回終端機按 `/status`。

```
  [●] 1,796,566 tok   本 5 小時區塊 · 90% · 剩 4 小時 14 分 · $2.96
```

## 先講清楚兩件事

**一、Windows 11 的工作列不開放第三方塞東西。** 舊版的 deskband(工作列工具列)API
從 Windows 11 起被移除,任何工具都沒辦法真的把自訂控制項嵌進工作列。所以這裡提供
兩種介面,可以單獨用也可以一起開:

| 介面 | 位置 | 可讀性 | 相依套件 |
| --- | --- | --- | --- |
| `--ui tray` | 工作列右側的**通知區域(系統匣)** | 圖示只有 16~24 px,適合顯示百分比 | `pystray`、`Pillow` |
| `--ui overlay` | **貼在工作列上的無邊框置頂小面板**,可拖曳 | 字級正常,完整數字一眼看得到 | 無(標準函式庫 tkinter) |
| `--ui both` | 兩個都開 | — | 同上 |

系統匣圖示可以在「工作列設定 → 其他系統匣圖示」裡打開,讓它永遠顯示而不是收在
展開選單裡。

至於圖示上要放什麼:16 px 下 `128k` 這種四字元實測幾乎讀不出來,兩位數的百分比
才清楚,所以只要設了 `--budget`,圖示預設就改顯示百分比(`--icon-style auto`)。
精確數字一律可以從 tooltip、右鍵選單或 overlay 面板取得。

**二、數字來自本機的 Claude Code transcript。** Claude Code 每一輪對話都會寫進
`%USERPROFILE%\.claude\projects\<專案>\<session>.jsonl`,其中 `type == "assistant"`
的紀錄帶著 `message.usage`。這支工具就是增量讀這些檔案來聚合。

也就是說:

* 你必須在**這台 Windows 上跑 Claude Code**,數字才會動;
* 只用 claude.ai 網頁版、或在遠端容器/另一台機器上跑的 session,本機沒有 transcript,
  這裡就看不到(遠端 session 的 transcript 在遠端機器上)。

## 安裝

需要 Python 3.10 以上(沒有的話,`install.ps1` 會告訴你怎麼裝)。

### 一鍵安裝(推薦)

在**目標這台 Windows** 上開一個 PowerShell,貼上執行:

```powershell
irm https://raw.githubusercontent.com/Suchongan/My_first_project/claude/windows-taskbar-token-usage-ghyq4k/tools/claude-token-tray/install.ps1 | iex
```

這行會自動:下載這個資料夾 → 裝 `pystray`/`Pillow` → 把預算/介面偏好寫進設定檔
→ 在「啟動」資料夾建立捷徑(開機自動執行)→ 立刻啟動一次。裝到
`%LOCALAPPDATA%\ClaudeTokenTray`,重複執行等於順便更新。

預設值是 `--budget 2M --ui both`。想自訂,用「帶參數版」:

```powershell
iex "& { $(irm https://raw.githubusercontent.com/Suchongan/My_first_project/claude/windows-taskbar-token-usage-ghyq4k/tools/claude-token-tray/install.ps1) } -Budget 500000 -Ui tray"
```

可用參數:`-InstallDir`、`-Budget`(0 表示不設預算)、`-Ui tray|overlay|both`、
`-NoAutostart`(不要開機自動啟動)、`-NoLaunch`(裝完不要立刻開)。細節見腳本開頭的
註解說明(`Get-Help .\install.ps1 -Full`,或直接開檔案看)。

解除安裝:

```powershell
iex "& { $(irm https://raw.githubusercontent.com/Suchongan/My_first_project/claude/windows-taskbar-token-usage-ghyq4k/tools/claude-token-tray/install.ps1) } -Uninstall"
```

會移除安裝目錄與開機捷徑;設定檔(`token_tray.json`)不會動,懶得留著也沒關係。

> 這個 repo 是 public 的,所以 `irm` 不需要登入。如果之後轉成 private,匿名下載會
> 失敗——改用瀏覽器登入 GitHub 後,到這個分支用 `Code → Download ZIP` 下載,
> 解壓縮後把 `tools\claude-token-tray` 複製出來,手動執行 `pip install -r requirements.txt`。

### 手動安裝

如果你已經把整個 repo clone 到這台電腦(或就是想自己手動控制每一步):

```powershell
cd tools\claude-token-tray
pip install -r requirements.txt   # 只想用 overlay 的話可以跳過
```

## 執行

```powershell
# 工作列浮動面板 + 系統匣圖示,以 5 小時區塊 200 萬 token 為預算
python -m claude_token_tray --ui both --budget 2M

# 只要系統匣圖示
python -m claude_token_tray --ui tray

# 不開 GUI,直接在終端機看一次
python -m claude_token_tray --once

# 在終端機持續刷新(適合放在第二個視窗或 tmux 窗格)
python -m claude_token_tray --watch
```

雙擊 `start_tray.bat` 會用 `pythonw` 啟動、不留主控台視窗;`start_tray.vbs` 則是連
一閃而過的視窗都沒有,適合放捷徑到啟動資料夾。

### 參數

| 參數 | 說明 |
| --- | --- |
| `--ui tray\|overlay\|both` | 要開哪種介面(預設 `tray`) |
| `--mode block\|today\|session\|week` | 預設觀察窗(預設 `block`) |
| `--budget 500k` | 觀察窗的 token 預算;設了才會有百分比與顏色警示。接受 `500000`、`500k`、`1.5M` |
| `--interval 5` | 幾秒重新掃描一次(預設 5) |
| `--icon-style auto\|number\|percent\|gauge` | 系統匣圖示樣式 |
| `--max-age-days 7` | 往回讀幾天的 transcript(預設 7) |
| `--root <路徑>` | 自訂 `projects` 目錄,可重複指定 |
| `--once` / `--watch` | 輸出文字報表(不開 GUI) |
| `--no-save` | 介面上的變更不寫回設定檔 |

## 四種觀察窗

| 模式 | 意義 |
| --- | --- |
| `block` | **目前的 5 小時區塊**。Claude Code 的用量上限以 5 小時為一個視窗,這通常是你最在意的數字。區塊起點是該區塊第一則訊息往下對齊到整點;超過 5 小時、或與前一則訊息間隔超過 5 小時,就會開新區塊 |
| `today` | 今天(本機時區)的總量 |
| `session` | 最近有活動的那個 session 的總量 |
| `week` | 近 7 日總量 |

系統匣右鍵選單、或 overlay 面板上左鍵雙擊,都可以切換模式。

## 操作方式

**系統匣圖示**:滑鼠停留看摘要;右鍵有明細、模式切換、立即重新整理、結束。

**工作列浮動面板**:

| 動作 | 效果 |
| --- | --- |
| 左鍵拖曳 | 移動位置(位置會記到設定檔) |
| 左鍵雙擊 | 切換觀察窗 |
| 右鍵 | 選單(切換模式、重設位置、結束) |

預設會停在工作列右側、系統匣左邊的空白處。位置是用 `SystemParametersInfo(SPI_GETWORKAREA)`
算出工作列高度後對齊的,所以工作列在上下左右哪一邊、有沒有自動隱藏,都可以自己拖到想要的位置。

## 設定檔

`%USERPROFILE%\.claude\token_tray.json`(可用 `CLAUDE_TOKEN_TRAY_CONFIG` 改位置):

```json
{
  "mode": "block",
  "ui": "both",
  "refresh_seconds": 5,
  "budget": 2000000,
  "icon_style": "auto",
  "max_age_days": 7,
  "overlay": { "x": 1480, "y": 1052, "font_size": 12, "alpha": 0.88, "locked": false }
}
```

介面上改的東西(模式、位置)會自動寫回這裡。`overlay.locked` 設 `true` 可以鎖住位置
避免誤拖。

## 開機自動啟動

按 <kbd>Win</kbd>+<kbd>R</kbd> 輸入 `shell:startup`,把 `start_tray.vbs` 的捷徑丟進去即可。

## 費用估算怎麼算的

`pricing.py` 內建各模型每百萬 token 的第一方 API 費率,快取寫入以 input 的 1.25x
(5 分鐘 TTL)/ 2x(1 小時 TTL)計、快取讀取以 0.1x 計,再依每筆紀錄的模型分別加總。

**訂閱制(Pro / Max)實際上不是按 token 計費**,所以這個金額請當成「等值 API 費用」,
只用來衡量用量的相對大小,不是你的帳單。未知的模型會退回 Sonnet 級距的費率計算。

## 效能

第一次啟動會掃過 `max_age_days` 內的 transcript,之後只從上次讀到的位移繼續往下讀,
所以每次刷新幾乎沒有成本(以 5 秒為週期不會有感)。同一則回覆若因為 resume / fork
被寫進多個檔案,會用 `message.id` + `requestId` 去重。

## 測試

```powershell
python -m unittest discover -s tests -v
```

21 個測試,涵蓋 JSONL 解析、跨檔去重、增量讀取(含寫到一半的行、被截斷/改寫的檔案)、
5 小時區塊切割、費率計算與數字格式,以及 overlay 面板的渲染與模式切換。全部只用標準
函式庫,不需要 Windows;其中 4 個 overlay 測試在沒有 tkinter 或沒有顯示裝置時會自動跳過。

## 目錄結構

```
install.ps1         一鍵安裝/更新/解除安裝腳本(見上方「一鍵安裝」)
start_tray.bat      雙擊啟動,不留主控台視窗
start_tray.vbs      雙擊啟動,連一閃而過的視窗都沒有;適合放進「啟動」資料夾
claude_token_tray/
    collector.py   讀 transcript、增量掃描、聚合成 Snapshot
    pricing.py     模型費率表與費用估算
    formatting.py  數字/時間格式、tooltip 與文字報表
    colors.py      狀態色(獨立出來,overlay 才不用相依 Pillow)
    icon.py        用 Pillow 動態產生系統匣圖示
    tray.py        pystray 系統匣圖示
    overlay.py     tkinter 工作列浮動面板
    monitor.py     背景輪詢執行緒
    config.py      設定檔讀寫
    __main__.py    CLI 與組裝
tests/
    test_collector.py   解析、聚合、費率、格式
    test_overlay.py     overlay 面板(需要顯示裝置,否則跳過)
```
