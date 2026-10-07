"""Reading the site's sitemap and choosing which URLs to inspect."""

from __future__ import annotations

import unittest

from seo import sitemap

INDEX = b"""<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap><loc>https://example.app/sitemaps/a.xml</loc></sitemap>
  <sitemap><loc>https://example.app/sitemaps/b.xml</loc></sitemap>
</sitemapindex>"""


def urlset(*urls: str) -> bytes:
    body = "".join(f"<url><loc>{u}</loc></url>" for u in urls)
    return f'<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">{body}</urlset>'.encode()


class ParseTest(unittest.TestCase):
    def test_an_index_lists_children(self):
        self.assertEqual(
            sitemap.parse(INDEX),
            (["https://example.app/sitemaps/a.xml", "https://example.app/sitemaps/b.xml"], []),
        )

    def test_a_urlset_lists_pages(self):
        self.assertEqual(sitemap.parse(urlset("https://example.app/", " https://example.app/faq ")),
                         ([], ["https://example.app/", "https://example.app/faq"]))


class CollectTest(unittest.TestCase):
    def test_follows_the_index_in_order_and_drops_duplicates(self):
        pages = {
            "https://example.app/sitemap.xml": INDEX,
            "https://example.app/sitemaps/a.xml": urlset("https://example.app/", "https://example.app/faq"),
            "https://example.app/sitemaps/b.xml": urlset("https://example.app/faq", "https://example.app/games"),
        }
        self.assertEqual(
            sitemap.collect(pages.__getitem__, "https://example.app/sitemap.xml"),
            ["https://example.app/", "https://example.app/faq", "https://example.app/games"],
        )

    def test_a_self_referencing_index_stops_at_max_depth(self):
        loop = b'<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><sitemap><loc>x</loc></sitemap></sitemapindex>'
        calls = []

        def fetch(url):
            calls.append(url)
            return loop

        self.assertEqual(sitemap.collect(fetch, "x", max_depth=2), [])
        self.assertEqual(len(calls), 3)


class SampleTest(unittest.TestCase):
    URLS = [f"/p{i}" for i in range(10)]

    def test_evenly_spaced_after_the_pinned_urls(self):
        self.assertEqual(sitemap.sample(self.URLS, 3, always=["/p0"]), ["/p0", "/p1", "/p5"])

    def test_pinned_urls_are_kept_even_past_the_size(self):
        self.assertEqual(sitemap.sample(self.URLS, 1, always=["/x", "/y"]), ["/x", "/y"])

    def test_asks_for_more_than_exist(self):
        self.assertEqual(sitemap.sample(self.URLS[:2], 10), ["/p0", "/p1"])

    def test_spread_reaches_the_end_of_the_list(self):
        picked = sitemap.sample(self.URLS, 5)
        self.assertEqual(picked, ["/p0", "/p2", "/p4", "/p6", "/p8"])


if __name__ == "__main__":
    unittest.main()
