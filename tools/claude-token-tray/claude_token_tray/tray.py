"""系統匣圖示(pystray)。"""

from __future__ import annotations

from typing import Any, Callable

import pystray

from . import icon as icon_mod
from .collector import Snapshot
from .formatting import MODE_LABELS, breakdown_lines, duration, grouped, tooltip

MODES = ("block", "today", "session", "week")


class TrayIcon:
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
        self._snapshot: Snapshot | None = None
        self._refresh_hook: Callable[[], None] | None = None
        self.icon = pystray.Icon(
            "claude-token-tray",
            icon=icon_mod.render(0, budget=cfg.get("budget"), style=cfg.get("icon_style", "auto")),
            title="Claude token 用量(載入中…)",
            menu=self._build_menu(),
        )

    # -- 選單 ---------------------------------------------------------------

    def _detail_text(self) -> str:
        snapshot = self._snapshot
        if snapshot is None:
            return "尚未載入"
        totals = snapshot.pick(self.cfg.get("mode", "block"))
        parts = [f"總計 {grouped(totals.total)} tokens"]
        parts.extend(breakdown_lines(totals))
        parts.append(f"估算費用 ${totals.cost_usd:,.2f}")
        remaining = snapshot.block_remaining
        if remaining is not None:
            parts.append(f"區塊剩餘 {duration(remaining)}")
        return "   |   ".join(parts)

    def _build_menu(self) -> pystray.Menu:
        def mode_item(mode: str) -> pystray.MenuItem:
            return pystray.MenuItem(
                MODE_LABELS[mode],
                lambda _icon, _item: self.set_mode(mode),
                checked=lambda _item, m=mode: self.cfg.get("mode", "block") == m,
                radio=True,
            )

        return pystray.Menu(
            pystray.MenuItem(lambda _item: self._detail_text(), None, enabled=False),
            pystray.Menu.SEPARATOR,
            *(mode_item(mode) for mode in MODES),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("立即重新整理", lambda _icon, _item: self.request_refresh()),
            pystray.MenuItem("結束", lambda _icon, _item: self.stop()),
        )

    def set_mode(self, mode: str) -> None:
        self.cfg["mode"] = mode
        if self.on_config_change:
            self.on_config_change(self.cfg)
        if self._snapshot is not None:
            self.update(self._snapshot)

    # -- 更新 ---------------------------------------------------------------

    def update(self, snapshot: Snapshot) -> None:
        self._snapshot = snapshot
        mode = self.cfg.get("mode", "block")
        totals = snapshot.pick(mode)
        budget = self.cfg.get("budget")
        self.icon.icon = icon_mod.render(
            totals.total, budget=budget, style=self.cfg.get("icon_style", "auto")
        )
        self.icon.title = tooltip(snapshot, mode, budget)
        if self.icon.visible:
            self.icon.update_menu()

    # -- 生命週期 -----------------------------------------------------------

    def request_refresh(self) -> None:
        if self._refresh_hook:
            self._refresh_hook()

    def set_refresh_hook(self, hook: Callable[[], None]) -> None:
        self._refresh_hook = hook

    def run(self) -> None:
        self.icon.run()

    def stop(self) -> None:
        if self.on_quit:
            self.on_quit()
        self.icon.stop()
