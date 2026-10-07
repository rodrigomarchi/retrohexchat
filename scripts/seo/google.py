"""Google Search Console, read through its API into the shared report.

    GET  webmasters/v3/sites                                  properties of the account
    GET  webmasters/v3/sites/<site>/sitemaps                  sitemaps, errors, warnings
    POST webmasters/v3/sites/<site>/searchAnalytics/query     clicks, impressions, position
    POST searchconsole/v1/urlInspection/index:inspect         one URL's index verdict

Access is a service account added as a user of the property. Its token is a
JWT signed with the account's RSA key; the standard library has no RSA, so the
signature comes from ``openssl``, the one external tool this needs. Google has
no crawl-issue list or crawl stats in the API, so those sections stay ``None``.

The normalisers are pure functions of a response payload; ``build_report`` is
the only code that calls the API, through the client it is handed.
"""

from __future__ import annotations

import base64
import json
import os
import subprocess
import tempfile
import time
import urllib.parse
from datetime import date, datetime, timedelta, timezone
from typing import Callable

from seo import report as rpt
from seo.transport import Request

SOURCE = "google"
SCOPE = "https://www.googleapis.com/auth/webmasters.readonly"
WEBMASTERS = "https://www.googleapis.com/webmasters/v3"
INSPECT = "https://searchconsole.googleapis.com/v1/urlInspection/index:inspect"
RETRY_BACKOFF_SECONDS = (5, 15, 30)
TOKEN_LIFETIME_SECONDS = 3600
PERFORMANCE_DAYS = 28
# Search data settles about three days after the fact; a window ending today
# would always show its last days short.
PERFORMANCE_LAG_DAYS = 3
ROW_LIMIT = 1000

# pageFetchState values that mean the fetch itself failed.
FETCH_ERRORS = {
    "SOFT_404",
    "NOT_FOUND",
    "ACCESS_DENIED",
    "ACCESS_FORBIDDEN",
    "SERVER_ERROR",
    "REDIRECT_ERROR",
    "BLOCKED_4XX",
    "INTERNAL_CRAWL_ERROR",
    "INVALID_URL",
}

Sign = Callable[[str, bytes], bytes]


class GoogleError(RuntimeError):
    """A refused or failed call; the message never carries a token or key."""

    def __init__(self, message: str, status: int | None = None, transient: bool = False):
        super().__init__(message)
        self.status = status
        self.transient = transient


# --- Service account token ----------------------------------------------------


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def jwt_assertion(account: dict, now: int, sign: Sign) -> str:
    """The signed JWT a service account trades for an access token."""
    header = {"alg": "RS256", "typ": "JWT"}
    claims = {
        "iss": account["client_email"],
        "scope": SCOPE,
        "aud": account["token_uri"],
        "iat": now,
        "exp": now + TOKEN_LIFETIME_SECONDS,
    }
    signing_input = f"{_b64url(json.dumps(header).encode())}.{_b64url(json.dumps(claims).encode())}"
    return f"{signing_input}.{_b64url(sign(account['private_key'], signing_input.encode()))}"


def openssl_sign(private_key_pem: str, data: bytes) -> bytes:
    """RS256 over ``data``; the key is written only to a private, deleted temp file."""
    with tempfile.TemporaryDirectory() as directory:
        key_path = os.path.join(directory, "key.pem")
        descriptor = os.open(key_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w") as handle:
            handle.write(private_key_pem)
        result = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", key_path],
            input=data,
            capture_output=True,
            check=False,
        )
    if result.returncode != 0:
        raise GoogleError(f"openssl could not sign the token: {result.stderr.decode(errors='replace')[:200]}")
    return result.stdout


class ServiceAccountToken:
    """An access token for the account, fetched once and reused until it is about to expire."""

    def __init__(self, account: dict, request: Request, sign: Sign = openssl_sign, clock: Callable[[], float] = time.time):
        for field in ("client_email", "private_key", "token_uri"):
            if not account.get(field):
                raise GoogleError(f"the service account file has no {field}")
        self._account = account
        self._request = request
        self._sign = sign
        self._clock = clock
        self._token: str | None = None
        self._expires_at = 0.0

    def __call__(self) -> str:
        now = self._clock()
        if self._token and now < self._expires_at - 60:
            return self._token
        body = urllib.parse.urlencode(
            {
                "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                "assertion": jwt_assertion(self._account, int(now), self._sign),
            }
        ).encode()
        status, raw = self._request(
            "POST", self._account["token_uri"], body, {"Content-Type": "application/x-www-form-urlencoded"}
        )
        payload = _json(raw)
        if status != 200 or "access_token" not in payload:
            raise GoogleError(f"token: HTTP {status}, {_error_text(payload, raw)}", status)
        self._token = payload["access_token"]
        self._expires_at = now + int(payload.get("expires_in", TOKEN_LIFETIME_SECONDS))
        return self._token


# --- API client ---------------------------------------------------------------


class Client:
    """JSON calls with the account's token; throttling and server errors wait and retry."""

    def __init__(
        self,
        token: Callable[[], str],
        request: Request,
        sleep: Callable[[float], None] = time.sleep,
        backoff: tuple[float, ...] = RETRY_BACKOFF_SECONDS,
    ):
        self._token = token
        self._request = request
        self._sleep = sleep
        self._backoff = backoff

    def get(self, url: str) -> dict:
        return self._call("GET", url, None)

    def post(self, url: str, payload: dict) -> dict:
        return self._call("POST", url, payload)

    def _call(self, method: str, url: str, payload: dict | None) -> dict:
        for delay in (*self._backoff, None):
            try:
                return self._call_once(method, url, payload)
            except GoogleError as error:
                if not error.transient or delay is None:
                    raise
                self._sleep(delay)
        raise AssertionError("unreachable")

    def _call_once(self, method: str, url: str, payload: dict | None) -> dict:
        headers = {"Authorization": f"Bearer {self._token()}", "Accept": "application/json"}
        body = None
        if payload is not None:
            body = json.dumps(payload).encode()
            headers["Content-Type"] = "application/json; charset=utf-8"
        status, raw = self._request(method, url, body, headers)
        parsed = _json(raw)
        if status == 200:
            return parsed
        endpoint = urllib.parse.urlsplit(url).path.rsplit("/", 1)[-1]
        raise GoogleError(
            f"{endpoint}: HTTP {status}, {_error_text(parsed, raw)}",
            status,
            transient=status == 429 or status >= 500,
        )


def _json(raw: bytes) -> dict:
    try:
        parsed = json.loads(raw or b"{}")
    except ValueError:
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _error_text(parsed: dict, raw: bytes) -> str:
    error = parsed.get("error")
    if isinstance(error, dict):
        return f"{error.get('status', '')} {error.get('message', '')}".strip()
    if isinstance(error, str):
        return f"{error} {parsed.get('error_description', '')}".strip()
    return raw[:200].decode("utf-8", "replace")


# --- Normalisers --------------------------------------------------------------


def property_for(sites: list[dict], site: str) -> str | None:
    """The property covering ``site``: the Domain property if there is one, else the URL prefix."""
    usable = {s.get("siteUrl") for s in sites if s.get("permissionLevel") != "siteUnverifiedUser"}
    host = urllib.parse.urlsplit(site).hostname or ""
    for candidate in (f"sc-domain:{host}", site, site.rstrip("/") + "/"):
        if candidate in usable:
            return candidate
    return None


def _iso(timestamp: str | None) -> str | None:
    if not timestamp:
        return None
    parsed = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    return parsed.astimezone(timezone.utc).replace(microsecond=0).isoformat()


def _int(value) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def normalize_sitemaps(items: list[dict]) -> list[dict]:
    return [
        {
            "url": s.get("path"),
            "type": "Sitemap Index" if s.get("isSitemapsIndex") else (s.get("type") or "sitemap").capitalize(),
            "status": "Pending" if s.get("isPending") else "Success",
            "submitted": _iso(s.get("lastSubmitted")),
            "last_read": _iso(s.get("lastDownloaded")),
            "url_count": sum(_int(c.get("submitted")) or 0 for c in s.get("contents", [])) or None,
            "errors": _int(s.get("errors")),
            "warnings": _int(s.get("warnings")),
        }
        for s in items
    ]


def inspection_state(result: dict) -> tuple[str, str | None]:
    """The shared state for an ``indexStatusResult``, with Google's own words as the detail."""
    coverage = result.get("coverageState") or None
    fetch = result.get("pageFetchState")
    if result.get("verdict") == "PASS":
        return "indexed", None
    if fetch in FETCH_ERRORS:
        return "error", f"{coverage or 'Fetch failed'} ({fetch.lower()})"
    if coverage and "unknown to Google" in coverage:
        return "unknown", coverage
    if coverage and coverage.startswith("Discovered"):
        return "discovered", coverage
    return "not_indexed", coverage


def blocked_by(result: dict) -> str | None:
    if result.get("robotsTxtState") == "DISALLOWED" or result.get("indexingState") == "BLOCKED_BY_ROBOTS_TXT":
        return "robots_txt"
    if result.get("indexingState") in ("BLOCKED_BY_META_TAG", "BLOCKED_BY_HTTP_HEADER"):
        return "noindex"
    return None


def normalize_inspection(url: str, payload: dict) -> dict:
    result = payload.get("inspectionResult", {}).get("indexStatusResult", {})
    state, detail = inspection_state(result)
    return {
        "url": url,
        "state": state,
        "discovered": None,
        "last_crawled": _iso(result.get("lastCrawlTime")),
        "detail": detail,
        "canonical_declared": result.get("userCanonical"),
        "canonical_chosen": result.get("googleCanonical"),
        "blocked": blocked_by(result),
    }


def normalize_rows(payload: dict) -> list[dict]:
    rows = [
        rpt.perf_row(
            (r.get("keys") or ["total"])[0],
            int(r.get("clicks", 0)),
            int(r.get("impressions", 0)),
            r.get("position"),
        )
        for r in payload.get("rows", [])
    ]
    rows.sort(key=lambda r: (-r["clicks"], -r["impressions"], r["key"]))
    return rows


def performance_window(today: date) -> tuple[date, date]:
    end = today - timedelta(days=PERFORMANCE_LAG_DAYS)
    return end - timedelta(days=PERFORMANCE_DAYS - 1), end


# --- The report ---------------------------------------------------------------


def _site_path(prop: str) -> str:
    return urllib.parse.quote(prop, safe="")


def build_report(
    client: Client,
    site: str,
    sitemap_urls: list[str],
    inspect: list[str],
    now: datetime,
    web_vitals: Callable[[list[dict]], list[dict] | None] | None = None,
    progress: Callable[[str], None] = lambda _msg: None,
) -> dict:
    report = rpt.new_report(SOURCE, site, now)

    sites = client.get(f"{WEBMASTERS}/sites").get("siteEntry", [])
    prop = property_for(sites, site)
    if prop is None:
        known = ", ".join(s.get("siteUrl", "?") for s in sites) or "none"
        raise GoogleError(f"{site} is not a property this service account can read (properties: {known})")
    report["notes"].append(f"Search Console property: {prop}.")
    base = f"{WEBMASTERS}/sites/{_site_path(prop)}"

    progress("sitemaps")
    report["sitemaps"] = normalize_sitemaps(client.get(f"{base}/sitemaps").get("sitemap", []))

    progress("search performance")
    start, end = performance_window(now.date())
    window = {"startDate": start.isoformat(), "endDate": end.isoformat(), "rowLimit": ROW_LIMIT}
    totals = normalize_rows(client.post(f"{base}/searchAnalytics/query", window))
    report["performance"] = {
        "totals": totals[0] if totals else rpt.perf_row("total", 0, 0, None),
        "queries": normalize_rows(client.post(f"{base}/searchAnalytics/query", {**window, "dimensions": ["query"]})),
        "pages": normalize_rows(client.post(f"{base}/searchAnalytics/query", {**window, "dimensions": ["page"]})),
    }
    report["period"] = {"start": start.isoformat(), "end": end.isoformat()}

    rows = []
    for index, url in enumerate(inspect, 1):
        progress(f"inspecting {index}/{len(inspect)} {url}")
        try:
            payload = client.post(INSPECT, {"inspectionUrl": url, "siteUrl": prop})
        except GoogleError as error:
            if error.status != 429:
                raise
            report["notes"].append(
                f"URL inspection quota reached: {len(inspect) - len(rows)} of {len(inspect)} URL(s) left uninspected."
            )
            break
        rows.append(normalize_inspection(url, payload))
    report["inspection"] = {"sitemap_urls": len(sitemap_urls), "urls": rows}
    report["notes"].append("URL inspection quota: 2,000 per property per day.")

    if web_vitals is not None:
        progress("web vitals")
        report["web_vitals"] = web_vitals(report["performance"]["pages"])

    return rpt.finalize(report)
