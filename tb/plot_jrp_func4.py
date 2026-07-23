#!/usr/bin/env python3
"""Plot the JRP_func4 dat_in -> dat_out transfer curve from an exhaustive sweep.

Reads tb/jrp_func4_sweep.csv (produced by `make run-jrp4`) and writes
tb/jrp_func4_transfer.png. Purely observational: lets you eyeball the
curve's shape (it should look like a log2-style compression curve, not a
straight line) -- it is not a pass/fail check.
"""
import csv
import sys
from pathlib import Path

import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
CSV_PATH = HERE / "jrp_func4_sweep.csv"
PNG_PATH = HERE / "jrp_func4_transfer.png"


def main() -> int:
    if not CSV_PATH.exists():
        print(f"error: {CSV_PATH} not found -- run `make run-jrp4` first", file=sys.stderr)
        return 1

    dat_in, dat_out = [], []
    with CSV_PATH.open(newline="") as f:
        for row in csv.DictReader(f):
            dat_in.append(int(row["dat_in"]))
            dat_out.append(int(row["dat_out"]))

    fig, ax = plt.subplots(figsize=(7, 4.5))
    ax.plot(dat_in, dat_out, marker=".", markersize=3, linewidth=1)
    ax.set_xlabel("dat_in")
    ax.set_ylabel("dat_out")
    ax.set_title("JRP_func4 transfer curve (exhaustive sweep, %d points)" % len(dat_in))
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(PNG_PATH, dpi=150)
    print(f"wrote {PNG_PATH} ({len(dat_in)} points)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
