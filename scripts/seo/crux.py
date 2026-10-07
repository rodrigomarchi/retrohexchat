"""Core Web Vitals from real Chrome visitors (Chrome UX Report API).

    POST https://chromeuxreport.googleapis.com/v1/records:queryRecord?key=…

One record per origin or page and device, the 75th percentile of each metric
over the last 28 days. A target with too few visitors answers 404: that is an
answer ("not enough traffic"), not a failure, and is left out of the list.
"""

from __future__ import annotations

import json
import urllib.parse

from seo import report as rpt
from seo.transport import Post

ENDPOINT = "https://chromeuxreport.googleapis.com/v1/records:queryRecord"
FORM_FACTORS = ("PHONE", "DESKTOP")
TOP_PAGES = 5


class CruxError(RuntimeError):
    pass


def _date(value: dict) -> str:
    return f"{value['year']:04d}-{value['month']:02d}-{value['day']:02d}"


def normalize(record: dict, scope: str) -> dict:
    key = record["key"]
    period = record.get("collectionPeriod")
    metrics = {}
    for name, value in record.get("metrics", {}).items():
        p75 = (value.get("percentiles") or {}).get("p75")
        if name not in rpt.VITALS or p75 is None:
            continue
        p75 = float(p75) if isinstance(p75, str) else p75
        metrics[name] = {"p75": p75, "rating": rpt.vital_rating(name, p75)}
    return {
        "target": key.get("origin") or key.get("url"),
        "scope": scope,
        "form_factor": key.get("formFactor", "ALL"),
        "period": f"{_date(period['firstDate'])} → {_date(period['lastDate'])}" if period else None,
        "metrics": metrics,
    }


def query(post: Post, api_key: str, target: str, scope: str, form_factor: str) -> dict | None:
    field = "origin" if scope == "origin" else "url"
    status, body = post(
        f"{ENDPOINT}?{urllib.parse.urlencode({'key': api_key})}",
        {field: target, "formFactor": form_factor, "metrics": list(rpt.VITALS)},
    )
    if status == 404:
        return None
    if status != 200:
        raise CruxError(f"queryRecord: HTTP {status}, {body[:200]}")
    return normalize(json.loads(body)["record"], scope)


def collect(post: Post, api_key: str, origin: str, pages: list[dict]) -> list[dict]:
    """The origin, then the pages with the most clicks, on phone and desktop; those with data."""
    targets = [("origin", origin)] + [("page", row["key"]) for row in pages[:TOP_PAGES]]
    found = []
    for scope, target in targets:
        for form_factor in FORM_FACTORS:
            record = query(post, api_key, target, scope, form_factor)
            if record is not None:
                found.append(record)
    return found
