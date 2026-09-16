"""貼在工作列上的浮動小面板(tkinter,只用標準函式庫)。

Windows 11 拿掉了第三方工具列(deskband)API,沒有辦法把自訂控制項真的塞進
工作列。這裡的做法是開一個無邊框、永遠置頂的小視窗,預設停在工作列右側的
空白處,視覺上就等同於「工作列上的即時數字」,而且字級夠大、看得清楚。

操作:
    左鍵拖曳     移動位置(位置會存回設定檔)
    左鍵雙擊     切換觀察窗(區塊 / 今日 / session / 近 7 日)
    右鍵         選單
"""

from __future__ import annotations

import ctypes
import tkinter as tk
from typing import Any, Callable

from .collector import Snapshot
from .colors import hex_color, status_color
from .formatting import MODE_LABELS, duration, grouped

MODES = ("block", "today", "session", "week")

MARGIN = 8


def _work_area() -> tuple[int, int, int, int] | None:
    """回傳 Windows 的工作區 (left, top, right, bottom);非 Windows 回傳 None。"""
    try:
        user32 = ctypes.windll.user32  # type: ignore[attr-defined]
    except AttributeError:
        return None

    class RECT(ctypes.Structure):
        _fields_ = [
            ("left", ctypes.c_long),
            ("top", ctypes.c_long),
            ("right", ctypes.c_long),
            ("bottom", ctypes.c_long),
        ]

    rect = RECT()
    SPI_GETWORKAREA = 0x0030
    if not user32.SystemParametersInfoW(SPI_GETWORKAREA, 0, ctypes.byref(rect), 0):
        return None
    return rect.left, rect.top, rect.right, rect.bottom


class Overlay:
    """工作列浮動面板。"""

    def __init__(
        self,
        cfg: dict[str, Any],
        *,
        on_quit: Callable[[], None] | None = None,
        on_config_change: Callable[[dict[str, Any]], None] | None = None,
    ) -> None:
        self.cfg = cfg
        self.on_quit = on_quit
        self.on_config_change = on_config_change
        self._drag_origin: tuple[int, int] | None = None
        self._snapshot: Snapshot | None = None

        overlay_cfg = cfg.get("overlay", {})
        self.root = tk.Tk()
        self.root.title("Claude token 用量")
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", True)
        try:
            self.root.attributes("-alpha", float(overlay_cfg.get("alpha", 0.88)))
        except tk.TclError:
            pass
        self.root.configure(bg="#111418")

        font_size = int(overlay_cfg.get("font_size", 12))
        frame = tk.Frame(self.root, bg="#111418", padx=10, pady=4)
        frame.pack(fill="both", expand=True)

        self.dot = tk.Canvas(
            frame, width=10, height=10, bg="#111418", highlightthickness=0
        )
        self.dot.pack(side="left", padx=(0, 7))
        self._dot_id = self.dot.create_oval(1, 1, 9, 9, fill="#237ade", outline="")

        self.value_var = tk.StringVar(value="—")
        self.value = tk.Label(
            frame,
            textvariable=self.value_var,
            fg="#f2f4f7",
            bg="#111418",
            font=("Segoe UI Semibold", font_size),
        )
        self.value.pack(side="left")

        self.detail_var = tk.StringVar(value="")
        self.detail = tk.Label(
            frame,
            textvariable=self.detail_var,
            fg="#9aa4b2",
            bg="#111418",
            font=("Segoe UI", max(font_size - 3, 7)),
        )
        self.detail.pack(side="left", padx=(8, 0))

        for widget in (self.root, frame, self.value, self.detail, self.dot):
            widget.bind("<Button-1>", self._drag_start)
            widget.bind("<B1-Motion>", self._drag_move)
            widget.bind("<ButtonRelease-1>", self._drag_end)
            widget.bind("<Double-Button-1>", self._cycle_mode)
            widget.bind("<Button-3>", self._popup)

        self.menu = tk.Menu(self.root, tearoff=0)
        for mode in MODES:
            self.menu.add_command(
                label=MODE_LABELS[mode],
                command=lambda m=mode: self.set_mode(m),
            )
        self.menu.add_separator()
        self.menu.add_command(label="重設位置", command=self.reset_position)
        self.menu.add_command(label="結束", command=self._quit)

        self.root.update_idletasks()
        self._place(overlay_cfg.get("x"), overlay_cfg.get("y"))

    # -- 位置 ---------------------------------------------------------------

    def _default_position(self) -> tuple[int, int]:
        """預設停在工作列右側(系統匣左邊)的空白處。"""
        self.root.update_idletasks()
        w = self.root.winfo_width()
        h = self.root.winfo_height()
        screen_w = self.root.winfo_screenwidth()
        screen_h = self.root.winfo_screenheight()

        area = _work_area()
        if area:
            _, _, work_right, work_bottom = area
            taskbar_h = screen_h - work_bottom
            if taskbar_h > 0:
                # 工作列在下方:垂直置中對齊工作列,水平靠右但留出系統匣的位置。
                y = work_bottom + max((taskbar_h - h) // 2, 0)
                return max(work_right - w - 220, 0), y
        return max(screen_w - w - 240, 0), max(screen_h - h - MARGIN, 0)

    def _place(self, x: object, y: object) -> None:
        if isinstance(x, int) and isinstance(y, int):
            self.root.geometry(f"+{x}+{y}")
            return
        px, py = self._default_position()
        self.root.geometry(f"+{px}+{py}")

    def reset_position(self) -> None:
        self.cfg.setdefault("overlay", {})["x"] = None
        self.cfg["overlay"]["y"] = None
        self._place(None, None)
        self._persist()

    def _drag_start(self, event: "tk.Event[Any]") -> None:
        if self.cfg.get("overlay", {}).get("locked"):
            return
        self._drag_origin = (event.x_root, event.y_root)
        self._window_origin = (self.root.winfo_x(), self.root.winfo_y())

    def _drag_move(self, event: "tk.Event[Any]") -> None:
        if self._drag_origin is None:
            return
        dx = event.x_root - self._drag_origin[0]
        dy = event.y_root - self._drag_origin[1]
        x = self._window_origin[0] + dx
        y = self._window_origin[1] + dy
        self.root.geometry(f"+{x}+{y}")

    def _drag_end(self, _event: "tk.Event[Any]") -> None:
        if self._drag_origin is None:
            return
        self._drag_origin = None
        self.cfg.setdefault("overlay", {})["x"] = self.root.winfo_x()
        self.cfg["overlay"]["y"] = self.root.winfo_y()
        self._persist()

    def _popup(self, event: "tk.Event[Any]") -> None:
        try:
            self.menu.tk_popup(event.x_root, event.y_root)
        finally:
            self.menu.grab_release()

    # -- 狀態 ---------------------------------------------------------------

    def set_mode(self, mode: str) -> None:
        self.cfg["mode"] = mode
        self._persist()
        if self._snapshot is not None:
            self.update(self._snapshot)

    def _cycle_mode(self, _event: "tk.Event[Any]") -> None:
        current = self.cfg.get("mode", "block")
        idx = MODES.index(current) if current in MODES else 0
        self.set_mode(MODES[(idx + 1) % len(MODES)])

    def _persist(self) -> None:
        if self.on_config_change:
            self.on_config_change(self.cfg)

    def update(self, snapshot: Snapshot) -> None:
        """由背景執行緒以外的地方呼叫(透過 root.after 排進主迴圈)。"""
        self._snapshot = snapshot
        mode = self.cfg.get("mode", "block")
        totals = snapshot.pick(mode)
        budget = self.cfg.get("budget")
        pct = (totals.total / budget * 100) if budget else None

        self.value_var.set(f"{grouped(totals.total)} tok")

        bits = [MODE_LABELS.get(mode, mode)]
        if pct is not None:
            bits.append(f"{pct:.0f}%")
        if mode == "block":
            remaining = snapshot.block_remaining
            if remaining is not None:
                bits.append(f"剩 {duration(remaining)}")
        bits.append(f"${totals.cost_usd:,.2f}")
        self.detail_var.set(" · ".join(bits))

        self.dot.itemconfigure(self._dot_id, fill=hex_color(status_color(pct)))

    def schedule_update(self, snapshot: Snapshot) -> None:
        """執行緒安全:把更新排進 tkinter 的事件迴圈。"""
        try:
            self.root.after(0, self.update, snapshot)
        except RuntimeError:
            pass

    # -- 生命週期 -----------------------------------------------------------

    def _quit(self) -> None:
        if self.on_quit:
            self.on_quit()
        self.stop()

    def stop(self) -> None:
        try:
            self.root.quit()
            self.root.destroy()
        except tk.TclError:
            pass

    def run(self) -> None:
        self.root.mainloop()
