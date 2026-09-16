"""狀態顏色。獨立成一個模組,讓 overlay 不必為了取色而相依 Pillow。"""

from __future__ import annotations

# (門檻百分比, 顏色)。由低到高比對。
THRESHOLDS = (
    (60, (35, 122, 222)),   # 藍:正常
    (85, (214, 148, 0)),    # 琥珀:接近上限
    (101, (198, 45, 45)),   # 紅:超過 85%
)
NEUTRAL = (35, 122, 222)
OVER = (198, 45, 45)


def status_color(pct: float | None) -> tuple[int, int, int]:
    """依用量百分比取狀態色;沒有預算(pct 為 None)時回傳中性色。"""
    if pct is None:
        return NEUTRAL
    for limit, color in THRESHOLDS:
        if pct < limit:
            return color
    return OVER


def hex_color(rgb: tuple[int, int, int]) -> str:
    r, g, b = rgb
    return f"#{r:02x}{g:02x}{b:02x}"
