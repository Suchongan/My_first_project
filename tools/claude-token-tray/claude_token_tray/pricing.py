"""模型計價表與費用估算。

價格為 Anthropic 第一方 API 的每百萬 token 費率(USD)。訂閱制方案
(Pro / Max)實際上不是按 token 計費,所以這裡算出來的金額請視為
「等值 API 費用」,只用來當作用量的相對參考。
"""

from __future__ import annotations

from dataclasses import dataclass

MILLION = 1_000_000


@dataclass(frozen=True)
class ModelPrice:
    """每百萬 token 的美元費率。"""

    input: float
    output: float
    # 寫入快取的倍率:5 分鐘 TTL 為 1.25x、1 小時 TTL 為 2x input。
    cache_write_5m_mult: float = 1.25
    cache_write_1h_mult: float = 2.0
    # 讀取快取預設為 input 的 0.1x;少數模型另有固定價,用 cache_read 覆寫。
    cache_read_mult: float = 0.1
    cache_read: float | None = None

    @property
    def cache_write_5m(self) -> float:
        return self.input * self.cache_write_5m_mult

    @property
    def cache_write_1h(self) -> float:
        return self.input * self.cache_write_1h_mult

    @property
    def cache_read_rate(self) -> float:
        if self.cache_read is not None:
            return self.cache_read
        return self.input * self.cache_read_mult


# key 為模型 ID 的前綴,比對時取最長相符的前綴。
PRICES: dict[str, ModelPrice] = {
    "claude-fable-5-1": ModelPrice(10.0, 50.0, cache_read=0.25),
    "claude-mythos-5-1": ModelPrice(10.0, 50.0, cache_read=0.25),
    "claude-fable-5": ModelPrice(10.0, 50.0),
    "claude-mythos-5": ModelPrice(10.0, 50.0),
    "claude-opus-5": ModelPrice(5.0, 25.0),
    "claude-opus-4-8": ModelPrice(5.0, 25.0),
    "claude-opus-4-7": ModelPrice(5.0, 25.0),
    "claude-opus-4-6": ModelPrice(5.0, 25.0),
    "claude-opus-4-5": ModelPrice(5.0, 25.0),
    "claude-sonnet-5": ModelPrice(2.0, 10.0),
    "claude-sonnet-4-6": ModelPrice(3.0, 15.0),
    "claude-sonnet-4-5": ModelPrice(3.0, 15.0),
    "claude-sonnet-4": ModelPrice(3.0, 15.0),
    "claude-haiku-4-5": ModelPrice(1.0, 5.0),
    "claude-3-5-haiku": ModelPrice(0.8, 4.0),
}

# 找不到對應模型時的保底費率(用 Sonnet 級距,避免高估)。
FALLBACK = ModelPrice(3.0, 15.0)


def price_for(model: str | None) -> ModelPrice:
    """依模型 ID 取得費率;未知模型回退到 FALLBACK。"""
    if not model:
        return FALLBACK
    best: ModelPrice | None = None
    best_len = -1
    for prefix, price in PRICES.items():
        if model.startswith(prefix) and len(prefix) > best_len:
            best, best_len = price, len(prefix)
    return best if best is not None else FALLBACK


def cost_usd(
    model: str | None,
    *,
    input_tokens: int = 0,
    output_tokens: int = 0,
    cache_write_5m: int = 0,
    cache_write_1h: int = 0,
    cache_read: int = 0,
) -> float:
    """依各類 token 數量估算美元費用。"""
    p = price_for(model)
    return (
        input_tokens * p.input
        + output_tokens * p.output
        + cache_write_5m * p.cache_write_5m
        + cache_write_1h * p.cache_write_1h
        + cache_read * p.cache_read_rate
    ) / MILLION
