"""動態產生系統匣圖示。

Windows 的系統匣圖示只有 16~24 px,能塞的字非常少,所以:

* 圖示上畫「壓縮後的數值」(例如 128k)或「佔用百分比」,底部再加一條進度條;
* 精確數字放在 tooltip 與右鍵選單裡。

背景會填上狀態色(未設定預算時為中性藍),文字用白色,這樣在淺色與深色
工作列上都看得清楚。
"""

from __future__ import annotations

from PIL import Image, ImageDraw, ImageFont

from .colors import status_color
from .formatting import compact

__all__ = ["render", "status_color", "CANVAS"]

#: 渲染尺寸。畫得比實際顯示大,交給 Windows 縮圖,邊緣比較平滑。
CANVAS = 64

FONT_CANDIDATES = (
    "seguisb.ttf",  # Segoe UI Semibold (Windows)
    "segoeuib.ttf",  # Segoe UI Bold
    "arialbd.ttf",
    "tahomabd.ttf",
    "DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
)

def _load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for name in FONT_CANDIDATES:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _fit_font(draw: ImageDraw.ImageDraw, text: str, max_w: int, max_h: int):
    """由大往小找出塞得進 (max_w, max_h) 的最大字級。"""
    size = max_h
    while size > 6:
        font = _load_font(size)
        left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
        if (right - left) <= max_w and (bottom - top) <= max_h:
            return font, (right - left, bottom - top), (left, top)
        size -= 2
    font = _load_font(6)
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    return font, (right - left, bottom - top), (left, top)


def render(
    tokens: int,
    *,
    budget: int | None = None,
    style: str = "number",
) -> Image.Image:
    """畫出圖示。

    style:
        auto     有設預算就用 percent、沒有就用 number(預設)
        number   顯示壓縮後的 token 數(128k)
        percent  顯示佔預算的百分比(需要 budget)
        gauge    只畫進度條,不顯示文字

    提醒:系統匣圖示只有 16~24 px。實測下來 "128k" 這種四字元在 16 px 幾乎讀不出來,
    兩位數的百分比才清楚,所以有設預算時預設改用 percent。要看完整數字請用 overlay
    面板或 tooltip。
    """
    pct = (tokens / budget * 100) if budget else None
    color = status_color(pct)

    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((0, 0, CANVAS - 1, CANVAS - 1), radius=12, fill=color + (255,))

    has_bar = budget is not None
    bar_h = 8 if has_bar else 0
    text_area = CANVAS - bar_h

    if style == "auto":
        style = "percent" if pct is not None else "number"

    if style == "gauge":
        text = ""
    elif style == "percent" and pct is not None:
        text = f"{min(int(pct), 999)}"
    else:
        text = compact(tokens)

    if text:
        font, (tw, th), (ox, oy) = _fit_font(draw, text, CANVAS - 4, text_area - 4)
        x = (CANVAS - tw) / 2 - ox
        y = (text_area - th) / 2 - oy
        draw.text((x, y), text, font=font, fill=(255, 255, 255, 255))

    if has_bar:
        top = CANVAS - bar_h
        draw.rectangle((5, top, CANVAS - 6, top + 3), fill=(255, 255, 255, 80))
        filled = max(0.0, min(1.0, tokens / budget))
        if filled > 0:
            right = 5 + (CANVAS - 11) * filled
            draw.rectangle((5, top, right, top + 3), fill=(255, 255, 255, 240))

    return image
