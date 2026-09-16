"""背景輪詢執行緒:定時重新掃描 transcript,並把新的 Snapshot 推給訂閱者。"""

from __future__ import annotations

import threading
from typing import Callable

from .collector import Snapshot, UsageCollector

Subscriber = Callable[[Snapshot], None]


class UsageMonitor:
    def __init__(self, collector: UsageCollector, interval: float = 5.0) -> None:
        self.collector = collector
        self.interval = max(float(interval), 1.0)
        self._subscribers: list[Subscriber] = []
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._latest: Snapshot | None = None
        self._lock = threading.Lock()

    @property
    def latest(self) -> Snapshot | None:
        with self._lock:
            return self._latest

    def subscribe(self, callback: Subscriber) -> None:
        self._subscribers.append(callback)

    def poll_once(self) -> Snapshot:
        self.collector.refresh()
        snapshot = self.collector.snapshot()
        with self._lock:
            self._latest = snapshot
        for callback in list(self._subscribers):
            try:
                callback(snapshot)
            except Exception:  # UI 的錯誤不該讓輪詢停掉
                pass
        return snapshot

    def _loop(self) -> None:
        while not self._stop.is_set():
            try:
                self.poll_once()
            except Exception:
                pass
            self._stop.wait(self.interval)

    def start(self) -> None:
        if self._thread is not None:
            return
        self.poll_once()
        self._thread = threading.Thread(target=self._loop, name="usage-monitor", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        thread = self._thread
        if thread is not None:
            thread.join(timeout=2.0)
        self._thread = None
