"""collector / pricing / formatting 的單元測試(標準函式庫 unittest)。"""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from claude_token_tray import pricing  # noqa: E402
from claude_token_tray.collector import (  # noqa: E402
    UsageCollector,
    parse_line,
)
from claude_token_tray.formatting import compact, duration  # noqa: E402


def make_entry(
    *,
    ts: str,
    msg_id: str = "msg_1",
    request_id: str = "req_1",
    session_id: str = "s1",
    model: str = "claude-opus-5",
    input_tokens: int = 10,
    output_tokens: int = 20,
    cache_5m: int = 0,
    cache_1h: int = 0,
    cache_read: int = 0,
) -> str:
    entry = {
        "type": "assistant",
        "timestamp": ts,
        "sessionId": session_id,
        "requestId": request_id,
        "uuid": f"u-{msg_id}-{request_id}",
        "message": {
            "id": msg_id,
            "model": model,
            "usage": {
                "input_tokens": input_tokens,
                "output_tokens": output_tokens,
                "cache_creation_input_tokens": cache_5m + cache_1h,
                "cache_read_input_tokens": cache_read,
                "cache_creation": {
                    "ephemeral_5m_input_tokens": cache_5m,
                    "ephemeral_1h_input_tokens": cache_1h,
                },
            },
        },
    }
    return json.dumps(entry) + "\n"


class ParseLineTests(unittest.TestCase):
    def test_parses_usage_record(self) -> None:
        parsed = parse_line(
            make_entry(
                ts="2026-09-16T08:38:33.473Z",
                input_tokens=2,
                output_tokens=1964,
                cache_1h=16936,
                cache_read=19972,
            )
        )
        self.assertIsNotNone(parsed)
        key, record = parsed
        self.assertEqual(key, "msg_1:req_1")
        self.assertEqual(record.input_tokens, 2)
        self.assertEqual(record.output_tokens, 1964)
        self.assertEqual(record.cache_write_1h, 16936)
        self.assertEqual(record.cache_write_5m, 0)
        self.assertEqual(record.cache_read, 19972)
        self.assertEqual(record.total, 2 + 1964 + 16936 + 19972)
        self.assertEqual(record.ts.tzinfo, timezone.utc)

    def test_falls_back_to_5m_when_breakdown_missing(self) -> None:
        raw = json.dumps(
            {
                "type": "assistant",
                "timestamp": "2026-09-16T08:00:00.000Z",
                "sessionId": "s",
                "requestId": "r",
                "message": {
                    "id": "m",
                    "model": "claude-sonnet-5",
                    "usage": {
                        "input_tokens": 1,
                        "output_tokens": 2,
                        "cache_creation_input_tokens": 500,
                        "cache_read_input_tokens": 0,
                    },
                },
            }
        )
        key, record = parse_line(raw)
        self.assertEqual(record.cache_write_5m, 500)
        self.assertEqual(record.cache_write_1h, 0)

    def test_ignores_non_usage_lines(self) -> None:
        self.assertIsNone(parse_line(""))
        self.assertIsNone(parse_line("not json"))
        self.assertIsNone(parse_line(json.dumps({"type": "user", "message": {}})))
        self.assertIsNone(
            parse_line(json.dumps({"type": "assistant", "message": {"usage": "nope"}}))
        )

    def test_ignores_assistant_without_timestamp(self) -> None:
        raw = json.dumps(
            {"type": "assistant", "message": {"id": "m", "usage": {"input_tokens": 1}}}
        )
        self.assertIsNone(parse_line(raw))


class CollectorTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name) / "projects" / "proj"
        self.root.mkdir(parents=True)
        self.addCleanup(self._tmp.cleanup)

    def collector(self, **kwargs) -> UsageCollector:
        return UsageCollector(roots=[self.root.parent], **kwargs)

    def test_dedupes_same_message_across_files(self) -> None:
        line = make_entry(ts="2026-09-16T08:00:00Z", input_tokens=100, output_tokens=200)
        (self.root / "a.jsonl").write_text(line, encoding="utf-8")
        (self.root / "b.jsonl").write_text(line, encoding="utf-8")

        col = self.collector()
        added = col.refresh(now=datetime(2026, 9, 16, 9, tzinfo=timezone.utc))
        self.assertEqual(added, 1)

        snap = col.snapshot(now=datetime(2026, 9, 16, 9, tzinfo=timezone.utc))
        self.assertEqual(snap.block.total, 300)
        self.assertEqual(snap.block.messages, 1)

    def test_incremental_refresh_only_reads_new_lines(self) -> None:
        path = self.root / "a.jsonl"
        path.write_text(
            make_entry(ts="2026-09-16T08:00:00Z", msg_id="m1", request_id="r1"),
            encoding="utf-8",
        )
        col = self.collector()
        now = datetime(2026, 9, 16, 9, tzinfo=timezone.utc)
        self.assertEqual(col.refresh(now=now), 1)
        self.assertEqual(col.refresh(now=now), 0)

        with path.open("a", encoding="utf-8") as fh:
            fh.write(make_entry(ts="2026-09-16T08:30:00Z", msg_id="m2", request_id="r2"))
        self.assertEqual(col.refresh(now=now), 1)
        self.assertEqual(col.snapshot(now=now).block.messages, 2)

    def test_partial_trailing_line_is_reread_when_complete(self) -> None:
        path = self.root / "a.jsonl"
        full = make_entry(ts="2026-09-16T08:00:00Z", msg_id="m1", request_id="r1")
        path.write_text(full[: len(full) // 2], encoding="utf-8")  # 尚未寫完的一行

        col = self.collector()
        now = datetime(2026, 9, 16, 9, tzinfo=timezone.utc)
        self.assertEqual(col.refresh(now=now), 0)

        path.write_text(full, encoding="utf-8")
        self.assertEqual(col.refresh(now=now), 1)

    def test_truncated_file_is_reread_from_start(self) -> None:
        path = self.root / "a.jsonl"
        path.write_text(
            make_entry(ts="2026-09-16T08:00:00Z", msg_id="m1", request_id="r1"),
            encoding="utf-8",
        )
        col = self.collector()
        now = datetime(2026, 9, 16, 9, tzinfo=timezone.utc)
        col.refresh(now=now)

        path.write_text(
            make_entry(ts="2026-09-16T08:10:00Z", msg_id="m2", request_id="r2"),
            encoding="utf-8",
        )
        self.assertEqual(col.refresh(now=now), 1)
        self.assertEqual(col.snapshot(now=now).block.messages, 2)

    def test_blocks_split_on_five_hour_window_and_gap(self) -> None:
        lines = [
            make_entry(ts="2026-09-16T08:10:00Z", msg_id="m1", request_id="r1"),
            make_entry(ts="2026-09-16T10:00:00Z", msg_id="m2", request_id="r2"),
            # 距離區塊起點(08:00)已滿 5 小時 -> 開新區塊
            make_entry(ts="2026-09-16T13:30:00Z", msg_id="m3", request_id="r3"),
            # 與前一則間隔超過 5 小時 -> 再開一個新區塊
            make_entry(ts="2026-09-16T23:00:00Z", msg_id="m4", request_id="r4"),
        ]
        (self.root / "a.jsonl").write_text("".join(lines), encoding="utf-8")

        col = self.collector(max_age_days=30)
        now = datetime(2026, 9, 17, 0, tzinfo=timezone.utc)
        col.refresh(now=now)

        blocks = col.blocks()
        self.assertEqual(len(blocks), 3)
        self.assertEqual(blocks[0].start, datetime(2026, 9, 16, 8, tzinfo=timezone.utc))
        self.assertEqual(blocks[0].totals.messages, 2)
        self.assertEqual(blocks[1].start, datetime(2026, 9, 16, 13, tzinfo=timezone.utc))
        self.assertEqual(blocks[2].start, datetime(2026, 9, 16, 23, tzinfo=timezone.utc))
        self.assertEqual(blocks[0].end, datetime(2026, 9, 16, 13, tzinfo=timezone.utc))

    def test_snapshot_block_is_empty_when_no_active_block(self) -> None:
        (self.root / "a.jsonl").write_text(
            make_entry(ts="2026-09-16T08:00:00Z"), encoding="utf-8"
        )
        col = self.collector(max_age_days=30)
        now = datetime(2026, 9, 16, 20, tzinfo=timezone.utc)  # 已超過 08:00 起算的 5 小時
        col.refresh(now=now)
        snap = col.snapshot(now=now)
        self.assertEqual(snap.block.total, 0)
        self.assertIsNone(snap.block_start)
        self.assertIsNone(snap.block_remaining)

    def test_session_totals_follow_latest_session(self) -> None:
        lines = [
            make_entry(ts="2026-09-16T08:00:00Z", msg_id="m1", request_id="r1", session_id="old", output_tokens=1),
            make_entry(ts="2026-09-16T09:00:00Z", msg_id="m2", request_id="r2", session_id="new", output_tokens=5),
            make_entry(ts="2026-09-16T09:30:00Z", msg_id="m3", request_id="r3", session_id="new", output_tokens=7),
        ]
        (self.root / "a.jsonl").write_text("".join(lines), encoding="utf-8")
        col = self.collector(max_age_days=30)
        now = datetime(2026, 9, 16, 10, tzinfo=timezone.utc)
        col.refresh(now=now)
        snap = col.snapshot(now=now)
        self.assertEqual(snap.session_id, "new")
        self.assertEqual(snap.session.messages, 2)
        self.assertEqual(snap.session.output_tokens, 12)

    def test_records_outside_max_age_are_pruned(self) -> None:
        old = (datetime.now(timezone.utc) - timedelta(days=30)).strftime("%Y-%m-%dT%H:%M:%SZ")
        recent = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        (self.root / "a.jsonl").write_text(
            make_entry(ts=old, msg_id="m1", request_id="r1")
            + make_entry(ts=recent, msg_id="m2", request_id="r2"),
            encoding="utf-8",
        )
        col = self.collector(max_age_days=7)
        col.refresh()
        self.assertEqual(col.snapshot().record_count, 1)


class PricingTests(unittest.TestCase):
    def test_longest_prefix_wins(self) -> None:
        self.assertEqual(pricing.price_for("claude-opus-5").output, 25.0)
        self.assertEqual(pricing.price_for("claude-sonnet-4-6").input, 3.0)
        self.assertEqual(pricing.price_for("claude-fable-5-1").cache_read_rate, 0.25)
        self.assertEqual(pricing.price_for("claude-fable-5").cache_read_rate, 1.0)

    def test_unknown_model_uses_fallback(self) -> None:
        self.assertEqual(pricing.price_for("something-else"), pricing.FALLBACK)
        self.assertEqual(pricing.price_for(None), pricing.FALLBACK)

    def test_cost_matches_published_rates(self) -> None:
        # Opus 5:input $5/M、output $25/M、1h 快取寫入 2x input、快取讀取 0.1x input
        cost = pricing.cost_usd(
            "claude-opus-5",
            input_tokens=1_000_000,
            output_tokens=1_000_000,
            cache_write_1h=1_000_000,
            cache_read=1_000_000,
        )
        self.assertAlmostEqual(cost, 5.0 + 25.0 + 10.0 + 0.5, places=6)


class FormattingTests(unittest.TestCase):
    def test_compact(self) -> None:
        self.assertEqual(compact(0), "0")
        self.assertEqual(compact(999), "999")
        self.assertEqual(compact(1234), "1.2k")
        self.assertEqual(compact(9000), "9k")
        self.assertEqual(compact(128_400), "128k")
        self.assertEqual(compact(2_300_000), "2.3M")
        self.assertEqual(compact(24_000_000), "24M")

    def test_duration(self) -> None:
        self.assertEqual(duration(timedelta(minutes=45)), "45 分")
        self.assertEqual(duration(timedelta(hours=2, minutes=5)), "2 小時 5 分")
        self.assertEqual(duration(timedelta(seconds=-10)), "0 分")


if __name__ == "__main__":
    unittest.main()
