"""The SEO comparison: tags must not change, text must not be lost."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
import unittest.mock
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "seo_compare.py"
_spec = importlib.util.spec_from_file_location("seo_compare", SCRIPT)
seo_compare = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(seo_compare)

PAGE = """<html><head><title>Games</title>
<meta name="description" content="Play in the browser">
<link rel="canonical" href="https://example.app/games">
<script type="application/ld+json">{"a": 1}</script></head>
<body><h1>Retro games</h1><p>Every game.</p><p>{extra}</p></body></html>"""


def page(extra: str) -> str:
    return PAGE.replace("{extra}", extra)


class SeoCompareTest(unittest.TestCase):
    def run_compare(self, before_html, after_html):
        before, after = Path(tempfile.mkdtemp()), Path(tempfile.mkdtemp())
        (before / "games.html").write_text(before_html)
        (after / "games.html").write_text(after_html)

        with redirect_stdout(StringIO()) as out:
            code = seo_compare.compare(before, after)

        return code, out.getvalue()

    def test_added_text_passes(self):
        code, out = self.run_compare(page(""), page("A new link"))

        self.assertEqual(code, 0)
        self.assertIn("+ A new link", out)

    def test_lost_text_fails(self):
        code, out = self.run_compare(page("Kept"), page(""))

        self.assertEqual(code, 1)
        self.assertIn("text lost:   Kept", out)

    def test_a_changed_tag_fails(self):
        code, out = self.run_compare(
            page(""), page("").replace("Play in the browser", "Play")
        )

        self.assertEqual(code, 1)
        self.assertIn("seo changed", out)

    def test_an_empty_snapshot_fails(self):
        with redirect_stdout(StringIO()):
            code = seo_compare.compare(Path(tempfile.mkdtemp()), Path(tempfile.mkdtemp()))

        self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()


class ChromeTest(unittest.TestCase):
    def test_the_desktop_furniture_is_not_the_page_text(self):
        html = """<body><h1>Games</h1><p>Every game.</p>
        <div data-window-start-menu><a>Arcade...</a><div><span>Tools</span></div></div>
        <button class="desktop-shortcut"><span>Account</span></button>
        <footer class="desktop-taskbar"><span data-clock>--:--</span></footer>
        <p>After the chrome.</p></body>"""

        text = seo_compare.parse(html).text

        self.assertEqual(text, ["Games", "Every game.", "After the chrome."])

    def test_a_page_losing_only_furniture_passes(self):
        before = page("<nav data-window-start-menu><a>Arcade...</a></nav>")
        code, _out = SeoCompareTest().run_compare(before, page(""))
        self.assertEqual(code, 0)


class SitemapPathsTest(unittest.TestCase):
    INDEX = b"""<?xml version="1.0"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap><loc>https://example.app/sitemaps/public-1.xml</loc></sitemap>
</sitemapindex>"""
    CHUNK = b"""<?xml version="1.0"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://example.app/</loc></url>
  <url><loc>https://example.app/pt-BR/features</loc></url>
  <url><loc>https://example.app/archive/retro/2026-10-01?before=9</loc></url>
  <url><loc>https://example.app/</loc></url>
</urlset>"""

    def test_follows_the_index_and_keeps_paths_on_the_local_base(self):
        fetched = []

        def fetch(url):
            fetched.append(url)
            return self.INDEX if url.endswith("/sitemap.xml") else self.CHUNK

        paths = seo_compare.sitemap_paths("http://localhost:4003/", fetch)

        self.assertEqual(paths, ["/", "/pt-BR/features", "/archive/retro/2026-10-01?before=9"])
        self.assertEqual(
            fetched,
            ["http://localhost:4003/sitemap.xml", "http://localhost:4003/sitemaps/public-1.xml"],
        )

    def test_a_query_gets_a_file_name_of_its_own(self):
        self.assertNotEqual(
            seo_compare.file_name("/archive/retro/2026-10-01"),
            seo_compare.file_name("/archive/retro/2026-10-01?before=9"),
        )



class SnapshotTest(unittest.TestCase):
    def quietly(self, *args, **kwargs):
        with redirect_stdout(StringIO()):
            return seo_compare.snapshot(*args, **kwargs)

    def test_a_timeout_is_asked_again(self):
        out = Path(tempfile.mkdtemp())
        answers = [TimeoutError("slow"), b"<html>ok</html>"]

        def fetch(_url):
            answer = answers.pop(0)
            if isinstance(answer, Exception):
                raise answer
            return answer

        with redirect_stdout(StringIO()), unittest.mock.patch("sys.stderr", StringIO()):
            self.assertEqual(seo_compare.snapshot("http://x", out, ["/"], fetch=fetch, sleep=lambda _s: None), 0)

        self.assertEqual((out / seo_compare.file_name("/")).read_bytes(), b"<html>ok</html>")

    def test_a_missing_page_is_an_answer_not_a_retry(self):
        calls = []

        def fetch(url):
            calls.append(url)
            raise seo_compare.urllib.error.HTTPError(url, 404, "Not Found", {}, None)

        with self.assertRaises(seo_compare.urllib.error.HTTPError):
            self.quietly("http://x", Path(tempfile.mkdtemp()), ["/gone"], fetch=fetch, sleep=lambda _s: None)

        self.assertEqual(len(calls), 1)

    def test_resume_keeps_what_was_saved(self):
        out = Path(tempfile.mkdtemp())
        (out / seo_compare.file_name("/")).write_bytes(b"saved")
        fetched = []

        def fetch(url):
            fetched.append(url)
            return b"fresh"

        self.quietly("http://x", out, ["/", "/faq"], resume=True, fetch=fetch, sleep=lambda _s: None)

        self.assertEqual(fetched, ["http://x/faq"])
        self.assertEqual((out / seo_compare.file_name("/")).read_bytes(), b"saved")
