#!/usr/bin/env python3
"""Refresh docs/data/prices.json for the Phantom price catalog.

Reads the current file + the parent commit's version. For any price that
changed (priceMonthly differs), sets prevPrice to the old value and stamps
hikedAt = today. Always bumps updatedAt to today so the iOS PriceMonitor
sees a fresh catalog every day.

Usage:
    refresh_prices.py <current_path> <previous_path>
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone


def main(current_path: str, previous_path: str) -> None:
    with open(current_path, encoding="utf-8") as fh:
        current = json.load(fh)
    try:
        with open(previous_path, encoding="utf-8") as fh:
            previous = json.load(fh)
    except FileNotFoundError:
        previous = {"prices": []}

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    prev_by_id = {p["id"]: p for p in previous.get("prices", [])}

    for price in current.get("prices", []):
        prior = prev_by_id.get(price["id"])
        if not prior:
            continue
        old = prior.get("priceMonthly")
        new = price.get("priceMonthly")
        if old is None or new is None:
            continue
        if abs(float(old) - float(new)) >= 0.01:
            price["prevPrice"] = float(old)
            price["hikedAt"] = today
        else:
            # Drop stale prevPrice/hikedAt if the price has now stabilised
            # for 30 days (so old alerts age out of the feed).
            hiked = price.get("hikedAt")
            if hiked:
                hiked_dt = datetime.strptime(hiked, "%Y-%m-%d").replace(
                    tzinfo=timezone.utc
                )
                age_days = (datetime.now(timezone.utc) - hiked_dt).days
                if age_days >= 30:
                    price.pop("prevPrice", None)
                    price.pop("hikedAt", None)

    current["updatedAt"] = today

    with open(current_path, "w", encoding="utf-8") as fh:
        json.dump(current, fh, indent=2, ensure_ascii=False)
        fh.write("\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1], sys.argv[2])
