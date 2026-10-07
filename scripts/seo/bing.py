"""Bing Webmaster Tools, read through its JSON API into the shared report.

    https://ssl.bing.com/webmaster/api.svc/json/<Method>?apikey=…&siteUrl=…

Every response wraps its payload in ``{"d": …}``; a failure is HTTP 400 with
``{"ErrorCode": n, "Message": "…"}``. Dates arrive as ``/Date(ms)/`` and
"never" is .NET's ``DateTime.MinValue``, a large negative timestamp.

The normalisers are pure functions of a response payload; ``build_report`` is
the only code that calls the API, through the client it is handed.
"""

from __future__ import annotations

import json
import re
import time
import urllib.parse
from datetime import datetime, timezone
from typing import Callable

from seo import report as rpt
from seo.transport import Fetch, FetchError

API_BASE = "https://ssl.bing.com/webmaster/api.svc/json/"
SOURCE = "bing"

# GetCrawlIssues.Issues is a bit set.
ISSUE_FLAGS = [
    (1, "redirect_301"),
    (2, "redirect_302"),
    (4, "http_4xx"),
    (8, "http_5xx"),
    (16, "blocked_by_robots"),
    (32, "contains_malware"),
    (64, "important_url_blocked_by_robots"),
    (128, "dns_error"),
    (256, "timeout"),
]

_DATE = re.compile(r"/Date\((-?\d+)(?:[+-]\d{4})?\)/")


# ErrorCode Bing answers with when calls come too fast for it.
THROTTLE_CODE = 5
RETRY_BACKOFF_SECONDS = (5, 15, 30, 60)

_TITLE = re.compile(r"<title>\s*([^<]*?)\s*</title>", re.IGNORECASE)


class BingError(RuntimeError):
    """The API refused a call; the message never contains the API key.

    ``transient`` marks the failures worth retrying: throttling, a 5xx, or an
    HTML error page where JSON was due.
    """

    def __init__(self, message: str, code: int | None = None, transient: bool = False):
        super().__init__(message)
        self.code = code
        self.transient = transient


class Client:
    """One API key against the JSON endpoint; transient failures wait and retry."""

    def __init__(
        self,
        api_key: str,
        fetcher: Fetch,
        sleep: Callable[[float], None] = time.sleep,
        backoff: tuple[float, ...] = RETRY_BACKOFF_SECONDS,
    ):
        self._api_key = api_key
        self._fetch = fetcher
        self._sleep = sleep
        self._backoff = backoff

    def call(self, method: str, **params: str):
        for delay in (*self._backoff, None):
            try:
                return self._call_once(method, params)
            except BingError as error:
                if not error.transient or delay is None:
                    raise
                self._sleep(delay)
        raise AssertionError("unreachable")

    def _call_once(self, method: str, params: dict):
        query = urllib.parse.urlencode({"apikey": self._api_key, **params})
        try:
            raw = self._fetch(f"{API_BASE}{method}?{query}")
        except FetchError as error:
            raise _error(method, error.status, error.body) from None
        try:
            body = json.loads(raw)
        except ValueError:
            raise _error(method, 200, raw.decode("utf-8", "replace")) from None
        if not isinstance(body, dict) or "d" not in body:
            raise BingError(f"{method}: unexpected response {str(body)[:200]}")
        return body["d"]


def _error(method: str, status: int, body: str) -> BingError:
    try:
        parsed = json.loads(body)
    except ValueError:
        title = _TITLE.search(body)
        summary = title.group(1) if title else body[:200]
        return BingError(f"{method}: HTTP {status}, not JSON: {summary}", transient=True)
    code = parsed.get("ErrorCode") if isinstance(parsed, dict) else None
    message = parsed.get("Message") if isinstance(parsed, dict) else parsed
    return BingError(
        f"{method}: HTTP {status}, error {code}: {message}",
        code,
        transient=code == THROTTLE_CODE or status >= 500,
    )


def parse_date(value: str | None) -> str | None:
    """``/Date(ms)/`` → ISO-8601 UTC, or ``None`` for empty and "never"."""
    if not value:
        return None
    match = _DATE.fullmatch(value)
    if not match:
        return None
    millis = int(match.group(1))
    if millis <= 0:
        return None
    return datetime.fromtimestamp(millis / 1000, tz=timezone.utc).replace(microsecond=0).isoformat()


def issue_names(flags: int) -> list[str]:
    names = [name for bit, name in ISSUE_FLAGS if flags & bit]
    return names or ([f"unknown_{flags}"] if flags else [])


def normalize_feeds(feeds: list[dict]) -> list[dict]:
    return [
        {
            "url": f.get("Url"),
            "type": f.get("Type"),
            "status": f.get("Status"),
            "submitted": parse_date(f.get("Submitted")),
            "last_read": parse_date(f.get("LastCrawled")),
            "url_count": f.get("UrlCount"),
            "errors": None,
            "warnings": None,
        }
        for f in feeds
    ]


def normalize_crawl_issues(issues: list[dict]) -> list[dict]:
    return [
        {"url": i.get("Url"), "issues": issue_names(int(i.get("Issues") or 0)), "http_status": i.get("HttpCode") or None}
        for i in issues
    ]


def normalize_crawl_stats(rows: list[dict]) -> list[dict]:
    out = [
        {
            "date": (parse_date(r.get("Date")) or "")[:10] or None,
            "crawled": r.get("CrawledPages"),
            "errors": r.get("CrawlErrors"),
            "in_index": r.get("InIndex"),
            "blocked_by_robots": r.get("BlockedByRobotsTxt"),
            "http_2xx": r.get("Code2xx"),
            "http_3xx": (r.get("Code301") or 0) + (r.get("Code302") or 0),
            "http_4xx": r.get("Code4xx"),
            "http_5xx": r.get("Code5xx"),
        }
        for r in rows
    ]
    return sorted(out, key=lambda r: r["date"] or "")


def normalize_performance(rows: list[dict]) -> tuple[list[dict], dict | None]:
    """Weekly rows summed per key; position is the impression-weighted average.

    Returns the rows sorted by clicks then impressions, and the period they cover.
    """
    acc: dict[str, list[float]] = {}
    dates: list[str] = []
    for r in rows:
        key = r.get("Query") or ""
        impressions = int(r.get("Impressions") or 0)
        position = r.get("AvgImpressionPosition")
        weighted = position * impressions if position and position > 0 else 0.0
        bucket = acc.setdefault(key, [0, 0, 0.0, 0])
        bucket[0] += int(r.get("Clicks") or 0)
        bucket[1] += impressions
        bucket[2] += weighted
        bucket[3] += impressions if weighted else 0
        if day := parse_date(r.get("Date")):
            dates.append(day[:10])
    out = [
        rpt.perf_row(key, int(c), int(i), (w / n) if n else None) for key, (c, i, w, n) in acc.items()
    ]
    out.sort(key=lambda r: (-r["clicks"], -r["impressions"], r["key"]))
    period = {"start": min(dates), "end": max(dates)} if dates else None
    return out, period


def totals(rows: list[dict]) -> dict:
    clicks = sum(r["clicks"] for r in rows)
    impressions = sum(r["impressions"] for r in rows)
    weighted = [(r["position"], r["impressions"]) for r in rows if r["position"] is not None]
    weight = sum(i for _, i in weighted)
    position = sum(p * i for p, i in weighted) / weight if weight else None
    return rpt.perf_row("total", clicks, impressions, position)


def url_state(info: dict) -> tuple[str, str | None]:
    """The shared inspection state for a ``GetUrlInfo`` payload, with a human detail."""
    status = info.get("HttpStatus") or 0
    crawled = parse_date(info.get("LastCrawledDate"))
    discovered = parse_date(info.get("DiscoveryDate"))
    if status >= 400:
        return "error", f"HTTP {status} on last fetch"
    if crawled:
        # DocumentSize is 0 for most fetched pages, full ones included: it says
        # nothing about the page, so it is not read.
        return "crawled", None
    if discovered:
        return "discovered", "Known to Bing, never fetched"
    return "unknown", "Bing has never seen this URL"


def normalize_url_info(url: str, info: dict) -> dict:
    state, detail = url_state(info)
    return {
        "url": url,
        "state": state,
        "discovered": parse_date(info.get("DiscoveryDate")),
        "last_crawled": parse_date(info.get("LastCrawledDate")),
        "detail": detail,
    }


def build_report(
    client: Client,
    site: str,
    sitemap_urls: list[str],
    inspect: list[str],
    now: datetime,
    progress: Callable[[str], None] = lambda _msg: None,
) -> dict:
    report = rpt.new_report(SOURCE, site, now)

    sites = client.call("GetUserSites")
    match = next((s for s in sites if s.get("Url") == site), None)
    if match is None:
        known = ", ".join(s.get("Url", "?") for s in sites) or "none"
        raise BingError(f"{site} is not a site of this API key (sites: {known})")
    if not match.get("IsVerified"):
        report["notes"].append(f"{site} is not verified in Bing Webmaster Tools.")

    progress("sitemaps, crawl issues, crawl stats")
    report["sitemaps"] = normalize_feeds(client.call("GetFeeds", siteUrl=site))
    report["crawl_issues"] = normalize_crawl_issues(client.call("GetCrawlIssues", siteUrl=site))
    report["crawl_stats"] = normalize_crawl_stats(client.call("GetCrawlStats", siteUrl=site))

    progress("search performance")
    queries, period = normalize_performance(client.call("GetQueryStats", siteUrl=site))
    pages, page_period = normalize_performance(client.call("GetPageStats", siteUrl=site))
    report["performance"] = {"totals": totals(queries), "queries": queries, "pages": pages}
    report["period"] = period or page_period

    rows = []
    for index, url in enumerate(inspect, 1):
        progress(f"inspecting {index}/{len(inspect)} {url}")
        try:
            info = client.call("GetUrlInfo", siteUrl=site, url=url)
        except BingError as error:
            if not error.transient:
                raise
            report["notes"].append(
                f"Bing kept failing URL inspection: {len(inspect) - len(rows)} of {len(inspect)} URL(s) left uninspected."
            )
            break
        rows.append(normalize_url_info(url, info))
    report["inspection"] = {"sitemap_urls": len(sitemap_urls), "urls": rows}

    try:
        quota = client.call("GetUrlSubmissionQuota", siteUrl=site)
        report["notes"].append(
            f"URL submission quota left: {quota.get('DailyQuota')} today, {quota.get('MonthlyQuota')} this month."
        )
    except BingError as error:
        if not error.transient:
            raise
        report["notes"].append(f"URL submission quota unavailable: {error}")
    report["notes"].append(
        "Bing does not give an index verdict per URL: `crawled` means fetched, not necessarily indexed."
    )
    return rpt.finalize(report)
