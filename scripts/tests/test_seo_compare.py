"""The SEO comparison: tags must not change, text must not be lost."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
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
