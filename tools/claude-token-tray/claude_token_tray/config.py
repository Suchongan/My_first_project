"""設定的讀寫。預設放在 `~/.claude/token_tray.json`。"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

DEFAULTS: dict[str, Any] = {
    "mode": "block",            # block | today | session | week
    "ui": "tray",              # tray | overlay | both
    "refresh_seconds": 5,
    "budget": None,             # 觀察窗的 token 預算,設了才會出現百分比與顏色
    "icon_style": "auto",      # auto | number | percent | gauge
    "max_age_days": 7,
    "overlay": {
        "x": None,
        "y": None,
        "font_size": 12,
        "alpha": 0.88,
        "locked": False,
    },
}


def config_path() -> Path:
    env = os.environ.get("CLAUDE_TOKEN_TRAY_CONFIG", "").strip()
    if env:
        return Path(env).expanduser()
    base = os.environ.get("CLAUDE_CONFIG_DIR", "").strip()
    root = Path(base.split(os.pathsep)[0]).expanduser() if base else Path.home() / ".claude"
    return root / "token_tray.json"


def _merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    out = dict(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            out[key] = _merge(out[key], value)
        else:
            out[key] = value
    return out


def load() -> dict[str, Any]:
    path = config_path()
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError, ValueError):
        return json.loads(json.dumps(DEFAULTS))
    if not isinstance(raw, dict):
        return json.loads(json.dumps(DEFAULTS))
    return _merge(DEFAULTS, raw)


def save(config: dict[str, Any]) -> bool:
    """寫回設定;失敗不拋例外,只回傳 False(UI 不該因為存檔失敗而中斷)。"""
    path = config_path()
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(config, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        return True
    except OSError:
        return False
