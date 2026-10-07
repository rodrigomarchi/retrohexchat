"""Read the site's own sitemap: the list of URLs it asks engines to index."""

from __future__ import annotations

import xml.etree.ElementTree as ET

from seo.transport import Fetch

NS = "{http://www.sitemaps.org/schemas/sitemap/0.9}"


def parse(xml: bytes) -> tuple[list[str], list[str]]:
    """``(child sitemaps, page URLs)`` — an index has the first, a urlset the second."""
    root = ET.fromstring(xml)
    locs = [el.text.strip() for el in root.iter(f"{NS}loc") if el.text]
    if root.tag == f"{NS}sitemapindex":
        return locs, []
    return [], locs


def collect(fetcher: Fetch, sitemap_url: str, max_depth: int = 3) -> list[str]:
    """Every page URL reachable from ``sitemap_url``, in sitemap order, without duplicates."""
    seen: dict[str, None] = {}
    pending = [(sitemap_url, 0)]
    while pending:
        url, depth = pending.pop(0)
        children, pages = parse(fetcher(url))
        for page in pages:
            seen.setdefault(page, None)
        if depth < max_depth:
            pending += [(child, depth + 1) for child in children]
    return list(seen)


def sample(urls: list[str], size: int, always: list[str] | None = None) -> list[str]:
    """``always`` first, then evenly spaced picks so every sitemap section is represented."""
    picked = list(dict.fromkeys(always or []))
    rest = [u for u in urls if u not in picked]
    room = size - len(picked)
    if room <= 0 or not rest:
        return picked
    if room >= len(rest):
        return picked + rest
    step = len(rest) / room
    return picked + [rest[int(i * step)] for i in range(room)]
