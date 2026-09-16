"""進入點:`python -m claude_token_tray`。"""

from __future__ import annotations

import argparse
import sys
import threading
import time
from pathlib import Path

from . import config as config_mod
from .collector import UsageCollector
from .formatting import report
from .monitor import UsageMonitor

MODES = ("block", "today", "session", "week")


def parse_budget(text: str | None) -> int | None:
    """接受 `500000`、`500k`、`1.5M` 這幾種寫法。"""
    if text is None:
        return None
    raw = text.strip().replace(",", "").replace("_", "")
    if not raw:
        return None
    multiplier = 1
    if raw[-1] in "kK":
        multiplier, raw = 1_000, raw[:-1]
    elif raw[-1] in "mM":
        multiplier, raw = 1_000_000, raw[:-1]
    try:
        return int(float(raw) * multiplier)
    except ValueError:
        raise argparse.ArgumentTypeError(f"看不懂的預算值:{text}") from None


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="claude-token-tray",
        description="在 Windows 工作列/系統匣即時顯示 Claude Code 的 token 用量。",
    )
    parser.add_argument("--ui", choices=("tray", "overlay", "both"), help="要顯示哪一種介面")
    parser.add_argument("--mode", choices=MODES, help="預設觀察窗")
    parser.add_argument("--budget", type=parse_budget, help="觀察窗的 token 預算,例如 500k")
    parser.add_argument("--interval", type=float, help="重新掃描的秒數(預設 5)")
    parser.add_argument(
        "--icon-style",
        choices=("auto", "number", "percent", "gauge"),
        help="系統匣圖示樣式(預設 auto:有預算顯示百分比,沒有則顯示 token 數)",
    )
    parser.add_argument("--max-age-days", type=int, help="往回讀幾天的 transcript(預設 7)")
    parser.add_argument(
        "--root",
        action="append",
        type=Path,
        help="自訂 transcript 目錄(即 .claude/projects),可重複指定",
    )
    parser.add_argument("--once", action="store_true", help="輸出一次文字報表後結束")
    parser.add_argument("--watch", action="store_true", help="持續在終端機輸出文字報表")
    parser.add_argument("--no-save", action="store_true", help="不要把介面上的變更寫回設定檔")
    return parser


def apply_args(cfg: dict, args: argparse.Namespace) -> dict:
    if args.ui:
        cfg["ui"] = args.ui
    if args.mode:
        cfg["mode"] = args.mode
    if args.budget is not None:
        cfg["budget"] = args.budget
    if args.interval:
        cfg["refresh_seconds"] = args.interval
    if args.icon_style:
        cfg["icon_style"] = args.icon_style
    if args.max_age_days:
        cfg["max_age_days"] = args.max_age_days
    return cfg


def run_text(monitor: UsageMonitor, cfg: dict, *, watch: bool) -> int:
    budget = cfg.get("budget")
    if not watch:
        snapshot = monitor.poll_once()
        print(report(snapshot, budget))
        return 0
    try:
        while True:
            snapshot = monitor.poll_once()
            print("\033[2J\033[H", end="")
            print(report(snapshot, budget))
            time.sleep(monitor.interval)
    except KeyboardInterrupt:
        return 0


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    cfg = apply_args(config_mod.load(), args)

    collector = UsageCollector(roots=args.root, max_age_days=int(cfg.get("max_age_days", 7)))
    if not collector.roots:
        print(
            "找不到 Claude Code 的 transcript 目錄。\n"
            "預期位置:%USERPROFILE%\\.claude\\projects\n"
            "若設定檔放在別處,請設 CLAUDE_CONFIG_DIR 或用 --root 指定。",
            file=sys.stderr,
        )
        return 2

    monitor = UsageMonitor(collector, interval=float(cfg.get("refresh_seconds", 5)))

    if args.once or args.watch:
        return run_text(monitor, cfg, watch=args.watch)

    def persist(updated: dict) -> None:
        if not args.no_save:
            config_mod.save(updated)

    ui = cfg.get("ui", "tray")
    stopping = threading.Event()

    tray = None
    panel = None

    if ui in ("tray", "both"):
        try:
            from .tray import TrayIcon
        except ImportError:
            print(
                "系統匣模式需要 pystray 與 Pillow:pip install pystray Pillow\n"
                "(或改用 --ui overlay,只靠標準函式庫的 tkinter)",
                file=sys.stderr,
            )
            return 2
        tray = TrayIcon(cfg, on_quit=stopping.set, on_config_change=persist)
        tray.set_refresh_hook(monitor.poll_once)
        monitor.subscribe(tray.update)

    if ui in ("overlay", "both"):
        try:
            from .overlay import Overlay
        except ImportError:
            print(
                "工作列浮動面板需要 tkinter。Windows 官方版 Python 預設就有;"
                "若是自行編譯或用 Linux 套件版,請補裝 tk 支援(例如 apt install python3-tk),"
                "或改用 --ui tray。",
                file=sys.stderr,
            )
            return 2
        panel = Overlay(cfg, on_quit=stopping.set, on_config_change=persist)
        monitor.subscribe(panel.schedule_update)

    monitor.start()

    try:
        if tray is not None and panel is not None:
            # tkinter 必須待在主執行緒,pystray 在 Windows 可以自己開訊息迴圈。
            thread = threading.Thread(target=tray.run, name="tray", daemon=True)
            thread.start()
            panel.run()
        elif panel is not None:
            panel.run()
        elif tray is not None:
            tray.run()
    except KeyboardInterrupt:
        pass
    finally:
        monitor.stop()
        if tray is not None:
            try:
                tray.icon.stop()
            except Exception:
                pass
        if panel is not None:
            panel.stop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
