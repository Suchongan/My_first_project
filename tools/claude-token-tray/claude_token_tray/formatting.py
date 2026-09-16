"""數字與文字的顯示格式。"""

from __future__ import annotations

from datetime import timedelta

from .collector import Snapshot, Totals

MODE_LABELS = {
    "block": "本 5 小時區塊",
    "today": "今日",
    "session": "目前 session",
    "week": "近 7 日",
}


def compact(tokens: int) -> str:
    """把 token 數壓成圖示放得下的短字串:1234 -> 1.2k、128400 -> 128k。"""
    n = abs(tokens)
    if n < 1000:
        return str(tokens)
    if n < 10_000:
        return f"{tokens / 1000:.1f}k".replace(".0k", "k")
    if n < 1_000_000:
        return f"{round(tokens / 1000)}k"
    if n < 10_000_000:
        return f"{tokens / 1_000_000:.1f}M"
    return f"{round(tokens / 1_000_000)}M"


def grouped(tokens: int) -> str:
    return f"{tokens:,}"


def duration(delta: timedelta) -> str:
    total_minutes = int(delta.total_seconds() // 60)
    hours, minutes = divmod(max(total_minutes, 0), 60)
    if hours:
        return f"{hours} 小時 {minutes} 分"
    return f"{minutes} 分"


def breakdown_lines(totals: Totals) -> list[str]:
    """輸入/輸出/快取的明細。"""
    return [
        f"輸入(未快取):{grouped(totals.input_tokens)}",
        f"輸出:{grouped(totals.output_tokens)}",
        f"快取寫入:{grouped(totals.cache_write)}",
        f"快取讀取:{grouped(totals.cache_read)}",
        f"訊息數:{totals.messages}",
    ]


def tooltip(snapshot: Snapshot, mode: str, budget: int | None = None) -> str:
    """系統匣圖示的滑鼠提示文字。

    Windows 的 tooltip 長度上限是 128 字元,所以這裡刻意壓縮。
    """
    totals = snapshot.pick(mode)
    lines = [f"{MODE_LABELS.get(mode, mode)}:{grouped(totals.total)} tokens"]

    if budget:
        pct = totals.total / budget * 100
        lines.append(f"用量:{pct:.0f}% / {compact(budget)}")

    remaining = snapshot.block_remaining
    if mode == "block" and remaining is not None:
        lines.append(f"區塊剩餘:{duration(remaining)}")

    lines.append(f"估算費用:${totals.cost_usd:,.2f}")
    if totals.top_model:
        lines.append(totals.top_model)

    text = "\n".join(lines)
    return text[:127]


def report(snapshot: Snapshot, budget: int | None = None) -> str:
    """`--once` / `--watch` 用的純文字報表。"""
    out: list[str] = []
    for mode in ("block", "today", "session", "week"):
        totals = snapshot.pick(mode)
        header = f"{MODE_LABELS[mode]}:{grouped(totals.total)} tokens  (≈ ${totals.cost_usd:,.2f})"
        if mode == "block":
            remaining = snapshot.block_remaining
            if remaining is not None:
                header += f"  剩餘 {duration(remaining)}"
            elif totals.messages == 0:
                header += "  (目前沒有進行中的區塊)"
            if budget:
                header += f"  [{totals.total / budget * 100:.0f}% of {compact(budget)}]"
        out.append(header)
        out.extend("    " + line for line in breakdown_lines(totals))
        out.append("")
    out.append(
        f"已載入 {snapshot.record_count} 筆紀錄,來自 {snapshot.source_files} 個 transcript 檔"
    )
    return "\n".join(out)
