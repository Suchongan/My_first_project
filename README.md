# Verilog 驗證環境

一組自我檢查(self-checking)的 SystemVerilog testbench,使用
[Verilator](https://www.veripool.org/verilator/) 模擬。每個DUT都各自搭配一份獨立推導的黃金參考模型(golden reference model)與一個熟悉管線凍結行為的scoreboard,讓RTL「實作本身」的錯誤(不只是設計意圖上的錯誤)也能被抓出來。

## DUT 列表

### `LSC_Func1`(`rtl/LSC_Func1.v`)

一個4級、同步致能(「凍結式」)管線,計算 `log2(dat_in + 1)` 的定點分段線性近似值,縮放係數為 2^11:

```
dat_out ≈ a_tmp * 2048 + interpolated_fraction(dat_in)
```

所有內部暫存器都由 `pipe_en & RS_LSC_EnH_FB` 統一閘控;為低時,整條管線同步保持不動。從取樣輸入到 `dat_out` 的延遲固定為4個clock edge。

### `JRP_CONV`(`rtl/JRP_CONV.v`)

一個3級、同步致能管線,對5x5像素視窗計算4個對角角點響應量值(`CR1~CR4`,2週期延遲)以及一組梯度/局部結構量(`Gx`、`Gy`、`Gx_abs`、`Gy_abs`、`C1`、`Ls0~Ls8`,3週期延遲)。所有暫存器由單一個 `pipe_en` 閘控。`Pxd_window_5x5_pipe1`/`pipe2` 需要是外部預先延遲好的 `Pxd_window_5x5_pipe0` 副本(分別延遲1、2個**致能週期**),因為設計選擇在後段管線重新讀取原始像素,而不是把整個250-bit視窗一路搬過內部暫存器。

### `JRP_func4`(`rtl/JRP_func4.v`)

一個3級、同步致能管線,結構跟 `LSC_Func1` 同一類型(leading-bit index + 查表的log2近似壓縮電路),但規模小很多:8-bit輸入、7-bit輸出,單一延遲(3週期),只有一張6-bit查表、沒有二次插值乘法器。因為輸入空間只有256種可能值,這個模組的驗證改用**窮舉測試**(每個值都測到一次),而不是隨機抽樣。

## 目錄結構

```
rtl/LSC_Func1.v            DUT 1
rtl/JRP_CONV.v              DUT 2
rtl/JRP_func4.v              DUT 3
rtl/JRP_func1.v ~ JRP_funcR.v  尚未建立驗證環境的其他模組
tb/lsc_func1_ref_pkg.sv     LSC_Func1 的獨立黃金參考模型
tb/lsc_func1_tb.sv          Testbench:激勵、scoreboard、reset/凍結測試
tb/jrp_conv_ref_pkg.sv      JRP_CONV 的獨立黃金參考模型
tb/jrp_conv_tb.sv           Testbench:激勵、scoreboard、reset/凍結測試
tb/jrp_func4_ref_pkg.sv     JRP_func4 的獨立黃金參考模型
tb/jrp_func4_tb.sv          Testbench:256種輸入窮舉測試 + CSV輸出
tb/plot_jrp_func4.py        讀取CSV、畫出 dat_in vs dat_out 轉換曲線
tb/Makefile                 三個DUT共用的 Verilator build/run/wave 指令
requirements.txt            Python 相依套件(matplotlib,畫圖用)
```

## 驗證原理

- **參考模型**:重新推導出跟每個DUT一致的運算結果,但用獨立的方式實作(用變數位移/遮罩/陣列索引取代RTL裡逐一列舉的 `case` 敘述或個別命名的線號,`JRP_func4` 更進一步改用 `unique casez` 優先編碼樣式取代RTL的五層巢狀三元判斷式),這樣RTL單一分支寫錯或某條線接錯都會在比對時現形,而不是被原樣複製一份而恆真。查表係數本身視為設計規格予以沿用,因為那是常數資料,不是「實作邏輯」。
- **Scoreboard**:testbench裡的shadow shift register,用跟DUT完全相同的致能條件閘控,精準重現凍結/延遲行為,不需要額外處理管線填充或bubble追蹤。`JRP_CONV` 的scoreboard從陣列的兩個不同深度取值比對,因為 `CR1~CR4` 跟其餘輸出延遲不同。
- **激勵策略**:
  - `LSC_Func1`、`JRP_CONV`:輸入空間太大(23-bit、250-bit)無法窮舉,改用邊界定向案例 + 致能凍結/管線中途reset情境 + 數千組隨機測試。
  - `JRP_func4`:輸入空間只有8-bit(256種可能值),改用**窮舉測試**——每個值都測到一次,不做隨機抽樣;窮舉過程同時把每組 `(dat_in, dat_out)` 記錄成CSV,`make run-jrp4` 跑完會自動用 `plot_jrp_func4.py` 畫出轉換曲線圖(純觀察用,確認曲線形狀符合log2壓縮特性——小數值時陡峭、大數值時平緩、非線性——不當作pass/fail條件)。

三個環境都用mutation test驗證過:故意在DUT裡注入一個一行的bug(查表係數改錯一筆、像素接線接錯一條、leading-bit門檻寫錯一個),重新跑測試,確認對應的testbench能抓到——而且只影響真正用到那段邏輯的輸出——確認scoreboard真的在檢查數值,而不是恆真通過,測完再還原。

## 執行方式

需要 Verilator(已測試 5.020 版本);看波形需要 GTKWave;`JRP_func4` 的畫圖需要 Python 3 加 `matplotlib`(`pip install -r requirements.txt`)。

```sh
cd tb
make run-lsc     # 建置 + 模擬 LSC_Func1
make run-jrp     # 建置 + 模擬 JRP_CONV
make run-jrp4    # 建置 + 模擬 JRP_func4(窮舉)+ 自動畫轉換曲線圖
make waves-lsc   # 用 GTKWave 開 LSC_Func1 的波形
make waves-jrp   # 用 GTKWave 開 JRP_CONV 的波形
make waves-jrp4  # 用 GTKWave 開 JRP_func4 的波形
make clean       # 清除建置產物(含CSV、PNG)
```

## 如何套用到其他DUT

把Verilog檔案放進 `rtl/`,依照現有的成對範例在 `tb/` 底下寫一份參考模型與testbench,並在 `tb/Makefile` 裡加一個 `run-<name>` 目標。
