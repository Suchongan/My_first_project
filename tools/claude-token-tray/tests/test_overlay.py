"""overlay 面板的煙霧測試。沒有 tkinter 或沒有顯示裝置時自動跳過。"""

from __future__ import annotations

import os
import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from claude_token_tray.collector import Snapshot, Totals, UsageRecord  # noqa: E402

try:
    import tkinter

    _HAS_TK = True
except ImportError:  # pragma: no cover
    _HAS_TK = False

_HAS_DISPLAY = bool(os.environ.get("DISPLAY")) or sys.platform == "win32"


def make_snapshot(total_tokens: int = 1_796_566) -> Snapshot:
    now = datetime(2026, 9, 16, 12, 0, tzinfo=timezone.utc)
    record = UsageRecord(
        ts=now - timedelta(minutes=30),
        model="claude-opus-5",
        session_id="s1",
        input_tokens=32,
        output_tokens=38_706,
        cache_write_5m=0,
        cache_write_1h=117_393,
        cache_read=total_tokens - 32 - 38_706 - 117_393,
    )
    totals = Totals()
    totals.add(record)
    return Snapshot(
        now=now,
        today=totals,
        block=totals,
        session=totals,
        week=totals,
        block_start=now - timedelta(hours=1),
        block_end=now + timedelta(hours=4),
        session_id="s1",
        record_count=1,
        source_files=1,
    )


@unittest.skipUnless(_HAS_TK and _HAS_DISPLAY, "需要 tkinter 與可用的顯示裝置")
class OverlayTests(unittest.TestCase):
    def setUp(self) -> None:
        from claude_token_tray.overlay import Overlay

        self.saved: list[dict] = []
        self.cfg = {
            "mode": "block",
            "budget": 2_000_000,
            "overlay": {"x": None, "y": None, "font_size": 12, "alpha": 0.9, "locked": False},
        }
        self.panel = Overlay(self.cfg, on_config_change=self.saved.append)
        self.addCleanup(self.panel.stop)

    def test_update_renders_tokens_and_detail(self) -> None:
        self.panel.update(make_snapshot())
        self.assertEqual(self.panel.value_var.get(), "1,796,566 tok")
        detail = self.panel.detail_var.get()
        self.assertIn("本 5 小時區塊", detail)
        self.assertIn("90%", detail)
        self.assertIn("剩 4 小時", detail)
        self.assertIn("$", detail)

    def test_mode_switch_updates_label_and_persists(self) -> None:
        self.panel.update(make_snapshot())
        self.panel.set_mode("today")
        self.assertEqual(self.cfg["mode"], "today")
        self.assertIn("今日", self.panel.detail_var.get())
        self.assertTrue(self.saved)

    def test_dot_color_tracks_threshold(self) -> None:
        self.panel.update(make_snapshot(1_796_566))  # 90% -> 紅
        self.assertEqual(self.panel.dot.itemcget(self.panel._dot_id, "fill"), "#c62d2d")
        self.panel.update(make_snapshot(200_000))  # 10% -> 藍
        self.assertEqual(self.panel.dot.itemcget(self.panel._dot_id, "fill"), "#237ade")

    def test_default_position_is_on_screen(self) -> None:
        x, y = self.panel._default_position()
        self.assertGreaterEqual(x, 0)
        self.assertGreaterEqual(y, 0)
        self.assertLess(x, self.panel.root.winfo_screenwidth())
        self.assertLess(y, self.panel.root.winfo_screenheight())


if __name__ == "__main__":
    unittest.main()
