"""The one report shape every search-engine source fills, and its rendering.

A report is a plain dict, so it serialises to JSON as is:

    schema        SCHEMA_VERSION
    source        "bing" | "google"
    site          the property URL, e.g. "https://retrohexchat.app/"
    generated_at  ISO-8601 UTC
    period        {"start": date, "end": date} of the performance data, or None
    sitemaps      [{url, type, status, submitted, last_read, url_count, errors, warnings}]
    crawl_issues  [{url, issues: [str], http_status}]
    crawl_stats   [{date, crawled, errors, in_index, blocked_by_robots,
                    http_2xx, http_3xx, http_4xx, http_5xx}]
    inspection    {"sitemap_urls": int, "urls": [{url, state, discovered,
                    last_crawled, detail}]}; a source that knows more adds
                    canonical_declared, canonical_chosen (the page's own
                    canonical and the one the engine picked) and blocked
                    ("robots_txt" | "noindex" | None)
    performance   {"totals": row, "queries": [row], "pages": [row]} where a row
                  is {key, clicks, impressions, ctr, position}
    web_vitals    [{target, scope: "origin" | "page", form_factor, period,
                    metrics: {name: {p75, rating}}}] from real visitors; [] when
                  the engine has too little traffic to say
    notes         [str]: source-specific facts worth reading (quotas, caveats)
    problems      derived by ``derive_problems`` — never filled by a source

A section is ``None`` when the source cannot provide it and ``[]`` when it can
but reported nothing; the Markdown says which, so an empty table is never
mistaken for a clean bill of health.

Inspection states, ordered from healthy to absent:

    indexed        the engine says the URL is in its index
    crawled        fetched, no index verdict available
    not_indexed    fetched and deliberately left out of the index
    error          the fetch failed
    discovered     known to the engine, never fetched
    unknown        the engine has never seen the URL
"""

from __future__ import annotations

import json
from collections import Counter
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

SCHEMA_VERSION = 2

STATES = ["indexed", "crawled", "not_indexed", "error", "discovered", "unknown"]
HEALTHY_STATES = {"indexed", "crawled"}

STALE_CRAWL_DAYS = 60
LOW_CTR = 0.01
LOW_CTR_MIN_IMPRESSIONS = 100
# Ranking 8th to 20th is the end of page one or the top of page two: the
# queries where a better title or more content moves the most clicks.
STRIKING_DISTANCE = (8.0, 20.0)
STRIKING_MIN_IMPRESSIONS = 20

# Core Web Vitals thresholds at the 75th percentile: (good up to, poor above).
VITALS = {
    "largest_contentful_paint": ("LCP", 2500, 4000, "ms"),
    "interaction_to_next_paint": ("INP", 200, 500, "ms"),
    "cumulative_layout_shift": ("CLS", 0.1, 0.25, ""),
    "first_contentful_paint": ("FCP", 1800, 3000, "ms"),
    "experimental_time_to_first_byte": ("TTFB", 800, 1800, "ms"),
}
URLS_PER_PROBLEM = 10
TOP_ROWS = 15

SEVERITY_ORDER = {"error": 0, "warning": 1, "info": 2}


def new_report(source: str, site: str, now: datetime) -> dict:
    """An empty report: every section ``None`` until the source fills it."""
    return {
        "schema": SCHEMA_VERSION,
        "source": source,
        "site": site,
        "generated_at": now.astimezone(timezone.utc).replace(microsecond=0).isoformat(),
        "period": None,
        "sitemaps": None,
        "crawl_issues": None,
        "crawl_stats": None,
        "inspection": None,
        "performance": None,
        "web_vitals": None,
        "notes": [],
        "problems": [],
    }


def perf_row(key: str, clicks: int, impressions: int, position: float | None) -> dict:
    ctr = clicks / impressions if impressions else 0.0
    return {
        "key": key,
        "clicks": clicks,
        "impressions": impressions,
        "ctr": round(ctr, 4),
        "position": None if position is None else round(position, 1),
    }


def vital_rating(metric: str, p75: float) -> str:
    _label, good, poor, _unit = VITALS[metric]
    if p75 <= good:
        return "good"
    return "poor" if p75 > poor else "needs_improvement"


def _problem(severity: str, kind: str, message: str, urls: list[str] | None = None) -> dict:
    return {"severity": severity, "kind": kind, "message": message, "urls": urls or []}


def derive_problems(report: dict) -> list[dict]:
    """Every finding comes from the normalised sections, so both sources share them.

    "Today" is the report's own ``generated_at``, so a saved report re-derives
    the same problems whenever it is read.
    """
    today = datetime.fromisoformat(report["generated_at"]).date()
    problems: list[dict] = []

    for sm in report["sitemaps"] or []:
        if sm["status"] and sm["status"].lower() not in ("success", "ok"):
            problems.append(_problem("error", "sitemap_status", f"Sitemap {sm['url']} reports status {sm['status']}."))
        if sm.get("errors"):
            problems.append(_problem("error", "sitemap_errors", f"Sitemap {sm['url']} has {sm['errors']} error(s)."))
        if sm.get("warnings"):
            problems.append(_problem("warning", "sitemap_warnings", f"Sitemap {sm['url']} has {sm['warnings']} warning(s)."))
    if report["sitemaps"] == []:
        problems.append(_problem("error", "no_sitemap", "No sitemap is submitted to this engine."))

    by_issue: dict[str, list[str]] = {}
    for issue in report["crawl_issues"] or []:
        for name in issue["issues"]:
            by_issue.setdefault(name, []).append(issue["url"])
    for name, urls in sorted(by_issue.items()):
        severity = "warning" if name in ("redirect_301", "redirect_302", "blocked_by_robots") else "error"
        problems.append(_problem(severity, f"crawl_{name}", f"{len(urls)} URL(s) with crawl issue {name}.", urls))

    inspection = report["inspection"]
    if inspection:
        urls = inspection["urls"]
        grouped: dict[str, list[str]] = {}
        for row in urls:
            grouped.setdefault(row["state"], []).append(row["url"])
        severities = {
            "error": "error",
            "not_indexed": "warning",
            "discovered": "warning",
            "unknown": "warning",
        }
        for state in STATES:
            if state in severities and state in grouped:
                hit = grouped[state]
                problems.append(
                    _problem(
                        severities[state],
                        f"inspection_{state}",
                        f"{len(hit)} of {len(urls)} inspected URL(s) are {state}.",
                        hit,
                    )
                )
        mismatched = [
            row["url"]
            for row in urls
            if row.get("canonical_chosen")
            and row.get("canonical_declared")
            and row["canonical_chosen"] != row["canonical_declared"]
        ]
        if mismatched:
            problems.append(
                _problem(
                    "warning",
                    "canonical_mismatch",
                    f"{len(mismatched)} inspected URL(s) where the engine chose another canonical than the page declares.",
                    mismatched,
                )
            )
        blocked = [row["url"] for row in urls if row.get("blocked")]
        if blocked:
            problems.append(
                _problem("error", "blocked_in_sitemap", f"{len(blocked)} sitemap URL(s) are blocked by robots.txt or noindex.", blocked)
            )
        cutoff = today - timedelta(days=STALE_CRAWL_DAYS)
        stale = [
            row["url"]
            for row in urls
            if row["last_crawled"] and date.fromisoformat(row["last_crawled"][:10]) < cutoff
        ]
        if stale:
            problems.append(
                _problem(
                    "info",
                    "stale_crawl",
                    f"{len(stale)} inspected URL(s) were last crawled more than {STALE_CRAWL_DAYS} days ago.",
                    stale,
                )
            )

    perf = report["performance"]
    if perf is not None:
        if not perf["totals"]["impressions"]:
            problems.append(_problem("info", "no_traffic", "No search impressions in the reported period."))
        low = [
            row["key"]
            for row in perf["queries"]
            if row["impressions"] >= LOW_CTR_MIN_IMPRESSIONS and row["ctr"] < LOW_CTR
        ]
        if low:
            problems.append(
                _problem(
                    "info",
                    "low_ctr_query",
                    f"{len(low)} query(ies) with at least {LOW_CTR_MIN_IMPRESSIONS} impressions and CTR under {LOW_CTR:.0%}.",
                    low,
                )
            )

        low_lo, low_hi = STRIKING_DISTANCE
        striking = [
            row["key"]
            for row in perf["queries"]
            if row["position"] is not None
            and low_lo <= row["position"] <= low_hi
            and row["impressions"] >= STRIKING_MIN_IMPRESSIONS
        ]
        if striking:
            problems.append(
                _problem(
                    "info",
                    "striking_distance",
                    f"{len(striking)} query(ies) ranking {low_lo:.0f}–{low_hi:.0f} with at least {STRIKING_MIN_IMPRESSIONS} impressions: the cheapest clicks to win.",
                    striking,
                )
            )

    for vital in report.get("web_vitals") or []:
        for metric, value in vital["metrics"].items():
            if value["rating"] == "good":
                continue
            label = VITALS[metric][0]
            severity = "warning" if value["rating"] == "poor" else "info"
            problems.append(
                _problem(
                    severity,
                    f"web_vitals_{label.lower()}",
                    f"{label} is {value['rating'].replace('_', ' ')} at p75 ({value['p75']}{VITALS[metric][3]}) for {vital['form_factor'].lower()} visitors of {vital['target']}.",
                )
            )

    problems.sort(key=lambda p: (SEVERITY_ORDER[p["severity"]], p["kind"]))
    return problems


def finalize(report: dict) -> dict:
    report["problems"] = derive_problems(report)
    return report


# --- Markdown -----------------------------------------------------------------


def _cell(value) -> str:
    if value is None:
        return "—"
    return str(value).replace("|", "\\|")


def _table(headers: list[str], rows: list[list]) -> list[str]:
    out = ["| " + " | ".join(headers) + " |", "|" + "---|" * len(headers)]
    out += ["| " + " | ".join(_cell(v) for v in row) + " |" for row in rows]
    return out


def _absent(report: dict, what: str, value) -> str | None:
    if value is None:
        return f"_Not available from {report['source']}._"
    if not value:
        return f"_No {what} reported._"
    return None


def render_markdown(report: dict) -> str:
    lines = [f"# SEO report — {report['source']} — {report['site']}", ""]
    period = report["period"]
    lines.append(f"Generated {report['generated_at']}" + (f" · period {period['start']} → {period['end']}" if period else ""))
    lines.append("")

    counts = Counter(p["severity"] for p in report["problems"])
    lines.append(f"## Problems ({counts['error']} error, {counts['warning']} warning, {counts['info']} info)")
    lines.append("")
    if not report["problems"]:
        lines.append("_None found._")
    for p in report["problems"]:
        lines.append(f"- **{p['severity']}** `{p['kind']}` — {p['message']}")
        for url in p["urls"][:URLS_PER_PROBLEM]:
            lines.append(f"  - {url}")
        if len(p["urls"]) > URLS_PER_PROBLEM:
            lines.append(f"  - … and {len(p['urls']) - URLS_PER_PROBLEM} more (see the JSON)")
    lines.append("")

    lines += ["## Sitemaps", ""]
    lines.append(
        _absent(report, "sitemaps", report["sitemaps"])
        or "\n".join(
            _table(
                ["URL", "Type", "Status", "Last read", "URLs", "Errors", "Warnings"],
                [
                    [s["url"], s["type"], s["status"], s["last_read"], s["url_count"], s["errors"], s["warnings"]]
                    for s in report["sitemaps"]
                ],
            )
        )
    )
    lines.append("")

    lines += ["## Crawl issues", ""]
    lines.append(
        _absent(report, "crawl issues", report["crawl_issues"])
        or "\n".join(
            _table(
                ["URL", "Issues", "HTTP"],
                [[i["url"], ", ".join(i["issues"]), i["http_status"]] for i in report["crawl_issues"]],
            )
        )
    )
    lines.append("")

    lines += ["## Crawl stats", ""]
    stats = report["crawl_stats"]
    absent = _absent(report, "crawl stats", stats)
    if absent:
        lines.append(absent)
    else:
        keys = ["date", "crawled", "errors", "in_index", "blocked_by_robots", "http_2xx", "http_3xx", "http_4xx", "http_5xx"]
        lines += _table(keys, [[row[k] for k in keys] for row in stats[-TOP_ROWS:]])
    lines.append("")

    lines += ["## Index inspection", ""]
    inspection = report["inspection"]
    absent = _absent(report, "inspected URLs", inspection and inspection["urls"])
    if inspection is None or absent:
        lines.append(absent)
    else:
        urls = inspection["urls"]
        states = Counter(row["state"] for row in urls)
        lines.append(f"{len(urls)} URL(s) inspected of {inspection['sitemap_urls']} in the sitemap.")
        lines.append("")
        lines += _table(["State", "URLs"], [[s, states[s]] for s in STATES if states[s]])
        lines.append("")
        lines += _table(
            ["URL", "State", "Discovered", "Last crawled", "Detail", "Engine's canonical"],
            [
                [r["url"], r["state"], r["discovered"], r["last_crawled"], r["detail"], _chosen_canonical(r)]
                for r in urls
            ],
        )
    lines.append("")

    lines += ["## Performance", ""]
    perf = report["performance"]
    if perf is None:
        lines.append(f"_Not available from {report['source']}._")
    else:
        t = perf["totals"]
        lines.append(f"Clicks {t['clicks']} · impressions {t['impressions']} · CTR {t['ctr']:.2%} · position {_cell(t['position'])}")
        for title, rows in (("Top queries", perf["queries"]), ("Top pages", perf["pages"])):
            lines += ["", f"### {title}", ""]
            if not rows:
                lines.append("_None reported._")
                continue
            lines += _table(
                ["Key", "Clicks", "Impressions", "CTR", "Position"],
                [[r["key"], r["clicks"], r["impressions"], f"{r['ctr']:.2%}", r["position"]] for r in rows[:TOP_ROWS]],
            )
    lines.append("")

    lines += ["## Web Vitals", ""]
    vitals = report.get("web_vitals")
    absent = _absent(report, "field data (too little real traffic)", vitals)
    if absent:
        lines.append(absent)
    else:
        names = list(VITALS)
        lines += _table(
            ["Target", "Device", "Period"] + [VITALS[n][0] for n in names],
            [
                [v["target"], v["form_factor"], v["period"]]
                + [_vital_cell(n, v["metrics"].get(n)) for n in names]
                for v in vitals
            ],
        )
    lines.append("")

    if report["notes"]:
        lines += ["## Source notes", ""]
        lines += [f"- {note}" for note in report["notes"]]
        lines.append("")

    return "\n".join(lines)


def _chosen_canonical(row: dict) -> str | None:
    chosen = row.get("canonical_chosen")
    if chosen and chosen != row.get("canonical_declared"):
        return chosen
    return None


def _vital_cell(metric: str, value: dict | None) -> str | None:
    if not value:
        return None
    return f"{value['p75']}{VITALS[metric][3]} ({value['rating'].replace('_', ' ')})"


def file_stem(report: dict) -> str:
    """``20261007T143000Z-bing``: sorts by generation time, never overwrites a past run."""
    stamp = datetime.fromisoformat(report["generated_at"]).strftime("%Y%m%dT%H%M%SZ")
    return f"{stamp}-{report['source']}"


def write(report: dict, out_dir: Path) -> tuple[Path, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    json_path = out_dir / f"{file_stem(report)}.json"
    md_path = out_dir / f"{file_stem(report)}.md"
    json_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    md_path.write_text(render_markdown(report))
    return json_path, md_path
