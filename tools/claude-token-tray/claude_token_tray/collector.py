"""從 Claude Code 的本機 transcript(JSONL)增量讀出 token 用量。

Claude Code 會把每一輪對話寫進 `~/.claude/projects/<專案>/<session>.jsonl`,
其中 `type == "assistant"` 的紀錄帶有 `message.usage`,欄位如下:

    input_tokens                 未命中快取的輸入 token
    output_tokens                輸出 token(含 thinking)
    cache_creation_input_tokens  寫入快取的 token
    cache_read_input_tokens      從快取讀回的 token
    cache_creation               再細分 ephemeral_5m / ephemeral_1h

這支模組只做「讀檔 + 聚合」,不碰 UI,方便單獨測試。
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable, Iterator

from . import pricing

#: 速率限制視窗長度(小時)。Claude Code 的用量以 5 小時為一個區塊。
BLOCK_HOURS = 5


# --------------------------------------------------------------------------
# 資料結構
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class UsageRecord:
    """單一則 assistant 回覆的用量。"""

    ts: datetime  # 一律為 timezone-aware 的 UTC 時間
    model: str
    session_id: str
    input_tokens: int
    output_tokens: int
    cache_write_5m: int
    cache_write_1h: int
    cache_read: int

    @property
    def total(self) -> int:
        """所有 token 的總和(含快取讀取)。"""
        return (
            self.input_tokens
            + self.output_tokens
            + self.cache_write_5m
            + self.cache_write_1h
            + self.cache_read
        )

    @property
    def cost_usd(self) -> float:
        return pricing.cost_usd(
            self.model,
            input_tokens=self.input_tokens,
            output_tokens=self.output_tokens,
            cache_write_5m=self.cache_write_5m,
            cache_write_1h=self.cache_write_1h,
            cache_read=self.cache_read,
        )


@dataclass
class Totals:
    """一段區間內的聚合結果。"""

    input_tokens: int = 0
    output_tokens: int = 0
    cache_write_5m: int = 0
    cache_write_1h: int = 0
    cache_read: int = 0
    messages: int = 0
    cost_usd: float = 0.0
    first_ts: datetime | None = None
    last_ts: datetime | None = None
    models: dict[str, int] = field(default_factory=dict)

    @property
    def total(self) -> int:
        return (
            self.input_tokens
            + self.output_tokens
            + self.cache_write_5m
            + self.cache_write_1h
            + self.cache_read
        )

    @property
    def cache_write(self) -> int:
        return self.cache_write_5m + self.cache_write_1h

    def add(self, rec: UsageRecord) -> None:
        self.input_tokens += rec.input_tokens
        self.output_tokens += rec.output_tokens
        self.cache_write_5m += rec.cache_write_5m
        self.cache_write_1h += rec.cache_write_1h
        self.cache_read += rec.cache_read
        self.messages += 1
        self.cost_usd += rec.cost_usd
        if self.first_ts is None or rec.ts < self.first_ts:
            self.first_ts = rec.ts
        if self.last_ts is None or rec.ts > self.last_ts:
            self.last_ts = rec.ts
        if rec.model:
            self.models[rec.model] = self.models.get(rec.model, 0) + rec.total

    @property
    def top_model(self) -> str | None:
        if not self.models:
            return None
        return max(self.models.items(), key=lambda kv: kv[1])[0]


@dataclass
class Block:
    """一個 5 小時的用量區塊。"""

    start: datetime  # 對齊到整點的區塊起始(UTC)
    totals: Totals

    @property
    def end(self) -> datetime:
        return self.start + timedelta(hours=BLOCK_HOURS)

    def is_active(self, now: datetime) -> bool:
        return self.start <= now < self.end

    def remaining(self, now: datetime) -> timedelta:
        return max(self.end - now, timedelta(0))


@dataclass
class Snapshot:
    """單次取樣的完整結果,供 UI 直接顯示。"""

    now: datetime
    today: Totals
    block: Totals
    session: Totals
    week: Totals
    block_start: datetime | None = None
    block_end: datetime | None = None
    session_id: str | None = None
    record_count: int = 0
    source_files: int = 0

    def pick(self, mode: str) -> Totals:
        return {
            "today": self.today,
            "block": self.block,
            "session": self.session,
            "week": self.week,
        }.get(mode, self.block)

    @property
    def block_remaining(self) -> timedelta | None:
        if self.block_end is None:
            return None
        return max(self.block_end - self.now, timedelta(0))


# --------------------------------------------------------------------------
# 解析
# --------------------------------------------------------------------------


def _parse_ts(value: object) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    text = value.replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(text)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _as_int(value: object) -> int:
    return value if isinstance(value, int) and not isinstance(value, bool) else 0


def parse_line(raw: str) -> tuple[str, UsageRecord] | None:
    """把一行 JSONL 轉成 (去重用的 key, UsageRecord);不是用量紀錄則回傳 None。"""
    raw = raw.strip()
    if not raw or '"usage"' not in raw:
        return None
    try:
        entry = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        return None
    if not isinstance(entry, dict) or entry.get("type") != "assistant":
        return None

    message = entry.get("message")
    if not isinstance(message, dict):
        return None
    usage = message.get("usage")
    if not isinstance(usage, dict):
        return None

    ts = _parse_ts(entry.get("timestamp"))
    if ts is None:
        return None

    cache_detail = usage.get("cache_creation")
    if isinstance(cache_detail, dict):
        write_5m = _as_int(cache_detail.get("ephemeral_5m_input_tokens"))
        write_1h = _as_int(cache_detail.get("ephemeral_1h_input_tokens"))
    else:
        write_5m, write_1h = 0, 0
    # 沒有細分欄位(舊版)時,整批當成 5 分鐘 TTL。
    total_write = _as_int(usage.get("cache_creation_input_tokens"))
    if write_5m + write_1h == 0:
        write_5m = total_write

    record = UsageRecord(
        ts=ts,
        model=message.get("model") or "",
        session_id=entry.get("sessionId") or "",
        input_tokens=_as_int(usage.get("input_tokens")),
        output_tokens=_as_int(usage.get("output_tokens")),
        cache_write_5m=write_5m,
        cache_write_1h=write_1h,
        cache_read=_as_int(usage.get("cache_read_input_tokens")),
    )

    # 同一則回覆可能因為 resume / fork 被寫進多個檔案,用 message id + request id 去重。
    message_id = message.get("id") or ""
    request_id = entry.get("requestId") or ""
    key = f"{message_id}:{request_id}" if (message_id or request_id) else str(entry.get("uuid") or "")
    if not key:
        return None
    return key, record


# --------------------------------------------------------------------------
# 掃描
# --------------------------------------------------------------------------


def default_roots() -> list[Path]:
    """回傳所有可能的 `projects` 目錄。

    支援 `CLAUDE_CONFIG_DIR`(可用 os.pathsep 分隔多個路徑),
    否則使用 `~/.claude` 與 XDG 的 `~/.config/claude`。
    """
    candidates: list[Path] = []
    env = os.environ.get("CLAUDE_CONFIG_DIR", "").strip()
    if env:
        candidates.extend(Path(p).expanduser() for p in env.split(os.pathsep) if p.strip())
    else:
        home = Path.home()
        candidates.append(home / ".claude")
        xdg = os.environ.get("XDG_CONFIG_HOME", "").strip()
        candidates.append(Path(xdg).expanduser() / "claude" if xdg else home / ".config" / "claude")

    roots: list[Path] = []
    for base in candidates:
        projects = base / "projects"
        if projects.is_dir() and projects not in roots:
            roots.append(projects)
    return roots


class UsageCollector:
    """增量掃描 transcript,並在記憶體中保留最近 N 天的用量紀錄。"""

    def __init__(
        self,
        roots: Iterable[Path] | None = None,
        *,
        max_age_days: int = 7,
    ) -> None:
        self._explicit_roots = [Path(r) for r in roots] if roots is not None else None
        self.max_age_days = max_age_days
        # path -> (已讀到的 offset, 上次看到的檔案大小, 上次看到的 mtime_ns)
        self._offsets: dict[str, tuple[int, int, int]] = {}
        self._seen: set[str] = set()
        self._records: list[UsageRecord] = []
        self.source_files = 0
        self.last_error: str | None = None

    @property
    def roots(self) -> list[Path]:
        if self._explicit_roots is not None:
            return [r for r in self._explicit_roots if r.is_dir()]
        return default_roots()

    # -- 掃描 ---------------------------------------------------------------

    def _iter_files(self, cutoff: datetime) -> Iterator[Path]:
        cutoff_epoch = cutoff.timestamp()
        for root in self.roots:
            for path in root.rglob("*.jsonl"):
                try:
                    st = path.stat()
                except OSError:
                    continue
                # 舊到不可能落在觀察窗內的檔案直接跳過,首次掃描才不會太慢。
                if st.st_mtime < cutoff_epoch and str(path) not in self._offsets:
                    continue
                yield path

    def refresh(self, now: datetime | None = None) -> int:
        """讀取所有新增的行,回傳這次新增的紀錄數。"""
        now = now or datetime.now(timezone.utc)
        cutoff = now - timedelta(days=self.max_age_days)
        added = 0
        files = 0
        self.last_error = None

        for path in self._iter_files(cutoff):
            files += 1
            key = str(path)
            try:
                st = path.stat()
            except OSError:
                continue
            size, mtime = st.st_size, st.st_mtime_ns
            offset, last_size, last_mtime = self._offsets.get(key, (0, -1, -1))
            if size < last_size:
                # 檔案被截斷,整份重讀。
                offset = 0
            elif size == last_size and mtime == last_mtime:
                # 大小與 mtime 都沒變,略過。
                continue
            elif size == last_size and last_size >= 0:
                # 大小一樣但內容被改寫過,整份重讀(重複的紀錄由 _seen 擋掉)。
                offset = 0
            try:
                with open(path, "r", encoding="utf-8", errors="replace") as fh:
                    fh.seek(offset)
                    for line in fh:
                        if not line.endswith("\n"):
                            # 最後一行還沒寫完,下次從這一行的開頭重讀。
                            break
                        offset += len(line.encode("utf-8", errors="replace"))
                        parsed = parse_line(line)
                        if parsed is None:
                            continue
                        dedupe_key, record = parsed
                        if dedupe_key in self._seen:
                            continue
                        self._seen.add(dedupe_key)
                        self._records.append(record)
                        added += 1
            except OSError as exc:
                self.last_error = f"{path.name}: {exc}"
                continue
            self._offsets[key] = (offset, size, mtime)

        self.source_files = files
        if added:
            self._records.sort(key=lambda r: r.ts)
        self._prune(cutoff)
        return added

    def _prune(self, cutoff: datetime) -> None:
        if not self._records or self._records[0].ts >= cutoff:
            return
        keep = [r for r in self._records if r.ts >= cutoff]
        self._records = keep

    # -- 聚合 ---------------------------------------------------------------

    def blocks(self) -> list[Block]:
        """把紀錄切成 5 小時區塊。

        規則與 Claude Code 的速率限制視窗一致:第一則訊息的時間往下對齊到整點
        當作區塊起點;超過 5 小時、或與前一則訊息間隔超過 5 小時就開新區塊。
        """
        result: list[Block] = []
        start: datetime | None = None
        prev: datetime | None = None
        current = Totals()

        for rec in self._records:
            gap = prev is not None and (rec.ts - prev) >= timedelta(hours=BLOCK_HOURS)
            overflow = start is not None and (rec.ts - start) >= timedelta(hours=BLOCK_HOURS)
            if start is None or gap or overflow:
                if start is not None:
                    result.append(Block(start, current))
                start = rec.ts.replace(minute=0, second=0, microsecond=0)
                current = Totals()
            current.add(rec)
            prev = rec.ts

        if start is not None:
            result.append(Block(start, current))
        return result

    def snapshot(self, now: datetime | None = None) -> Snapshot:
        now = now or datetime.now(timezone.utc)
        local_today = now.astimezone().date()
        week_cutoff = now - timedelta(days=7)

        today = Totals()
        week = Totals()
        for rec in self._records:
            if rec.ts >= week_cutoff:
                week.add(rec)
            if rec.ts.astimezone().date() == local_today:
                today.add(rec)

        blocks = self.blocks()
        block_totals = Totals()
        block_start = block_end = None
        if blocks and blocks[-1].is_active(now):
            active = blocks[-1]
            block_totals = active.totals
            block_start, block_end = active.start, active.end

        session_totals = Totals()
        session_id = self._records[-1].session_id if self._records else None
        if session_id:
            for rec in self._records:
                if rec.session_id == session_id:
                    session_totals.add(rec)

        return Snapshot(
            now=now,
            today=today,
            block=block_totals,
            session=session_totals,
            week=week,
            block_start=block_start,
            block_end=block_end,
            session_id=session_id,
            record_count=len(self._records),
            source_files=self.source_files,
        )
