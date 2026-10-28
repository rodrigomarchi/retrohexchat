"""Which browser messages a run of `i18n_js_translate.py` sends to the engine."""

import importlib.util
import pathlib
import unittest

_SPEC = importlib.util.spec_from_file_location(
    "i18n_js_translate", pathlib.Path(__file__).resolve().parents[1] / "i18n_js_translate.py"
)
js_translate = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(js_translate)


class PendingTest(unittest.TestCase):
    def test_a_message_the_catalog_lacks_is_always_sent(self):
        self.assertEqual(js_translate.pending(["Fill", "Undo"], {"Undo": "Desfazer"}, {}), ["Fill"])

    def test_one_left_in_english_is_sent_again_only_when_asked(self):
        catalog = {"Fill": "Fill"}
        self.assertEqual(js_translate.pending(["Fill"], catalog, {}), [])
        self.assertEqual(js_translate.pending(["Fill"], catalog, {}, retry_english=True), ["Fill"])

    def test_the_glossary_word_is_owed_but_a_label_it_keeps_literal_is_not(self):
        # "Fill" stayed English in Japanese although the glossary words it.
        catalog = {"Fill": "Fill", "OK": "OK"}
        curated = {"Fill": "塗りつぶし", "OK": "OK"}
        self.assertEqual(
            js_translate.pending(["Fill", "OK"], catalog, curated, retry_english=True), ["Fill"]
        )


if __name__ == "__main__":
    unittest.main()
