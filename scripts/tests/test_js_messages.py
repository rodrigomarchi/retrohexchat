"""What the browser asks to translate, read from the JS that asks it.

The server's strings reach a catalog through `mix gettext.extract`; the
browser's had no extractor, so a new `t("...")` stayed English in every
language and nothing said so. Ninety did, among them the P2P device errors
and the call quality names.
"""

from __future__ import annotations

import unittest

from i18n import js_messages


class ExtractTest(unittest.TestCase):
    def test_reads_a_literal_t_call_in_either_quote(self):
        source = 't("Copied!"); t(\'Got it!\', { n: 1 }); t(  "Spaced"  )'
        self.assertEqual(js_messages.extract(source), {"Copied!", "Got it!", "Spaced"})

    def test_unescapes_what_the_literal_escapes(self):
        source = r't("Don\'t say \"hi\"")'
        self.assertEqual(js_messages.extract(source), {"Don't say \"hi\""})

    def test_turns_a_tagged_template_into_its_numbered_msgid(self):
        # jt joins the parts with %{0}, %{1}... exactly as i18n.js does at run time.
        source = "jt`${name} WINS!`; jt`Round ${round} of ${total}`; jt`Plain`"
        self.assertEqual(
            js_messages.extract(source), {"%{0} WINS!", "Round %{0} of %{1}", "Plain"}
        )

    def test_decodes_a_template_escape_as_the_browser_does(self):
        source = r"jt`${a} \u2014 ${b}`"
        self.assertEqual(js_messages.extract(source), {"%{0} \u2014 %{1}"})

    def test_ignores_a_call_it_cannot_read(self):
        # A variable or a built string names no msgid; it is the caller's to
        # pass something already in the catalog.
        source = 't(label); t("a" + b); format(x); start("Not a t call")'
        self.assertEqual(js_messages.extract(source), set())

    def test_ignores_identifiers_that_end_in_t(self):
        source = 'parseInt("10"); emit("x"); split("a")'
        self.assertEqual(js_messages.extract(source), set())


class MissingTest(unittest.TestCase):
    def test_names_each_locale_missing_a_message(self):
        catalogs = {"PT_BR": {"A": "a"}, "FR": {"A": "a", "B": "b"}}
        missing = js_messages.missing({"A", "B"}, catalogs)
        self.assertEqual(missing, {"PT_BR": ["B"]})


if __name__ == "__main__":
    unittest.main()
