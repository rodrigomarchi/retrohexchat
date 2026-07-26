"""End-to-end pipeline behaviour, driven by scripted translators.

No Argos models are involved: `ScriptedTranslator` replays the exact output
shapes observed in the audit, so the fallbacks are exercised deterministically.
"""

from __future__ import annotations

import unittest

from i18n.pipeline import Pipeline, chunk
from i18n.protection import BATCH_SEPARATOR
from i18n.translator import IdentityTranslator, ScriptedTranslator


def upper(text: str) -> str:
    return text.upper()


class TranslateOneTest(unittest.TestCase):
    def test_translates_and_restores_placeholders(self):
        pipeline = Pipeline(ScriptedTranslator(default=upper))

        self.assertEqual(pipeline.translate_one("Hello %{name}"), "HELLO %{name}")
        self.assertEqual(pipeline.stats.translated, 1)

    def test_skips_strings_with_nothing_to_translate(self):
        pipeline = Pipeline(ScriptedTranslator(default=upper))

        self.assertEqual(pipeline.translate_one("%{a} — %{b}"), "%{a} — %{b}")
        self.assertEqual(pipeline.stats.skipped, 1)
        self.assertEqual(pipeline.stats.translated, 0)

    def test_falls_back_to_source_when_output_is_degenerate(self):
        pipeline = Pipeline(ScriptedTranslator({"Blue": "Azul Azul Azul Azul"}))

        self.assertEqual(pipeline.translate_one("Blue"), "Blue")
        self.assertEqual(pipeline.stats.fell_back, 1)

    def test_falls_back_when_a_placeholder_is_lost(self):
        pipeline = Pipeline(ScriptedTranslator(default=lambda _: "traducao sem token"))

        self.assertEqual(pipeline.translate_one("Hello %{name}"), "Hello %{name}")
        self.assertEqual(pipeline.stats.fell_back, 1)

    def test_falls_back_when_sentinel_survives(self):
        pipeline = Pipeline(ScriptedTranslator(default=lambda text: text + " <ph9></ph9>"))

        self.assertEqual(pipeline.translate_one("Hello %{name}"), "Hello %{name}")
        self.assertEqual(pipeline.stats.fell_back, 1)

    def test_applies_postprocessor(self):
        pipeline = Pipeline(IdentityTranslator(), postprocess=lambda text: f"[{text}]")

        self.assertEqual(pipeline.translate_one("Channel created here"), "[Channel created here]")


class TranslateManyTest(unittest.TestCase):
    def test_splits_a_joined_batch_back_into_strings(self):
        sources = ["Blue is nice", "Green is fine", "Red is bold"]
        translator = ScriptedTranslator(
            default=lambda text: text.replace("is", "e").upper()
            if BATCH_SEPARATOR in text
            else text
        )
        pipeline = Pipeline(translator)

        results = pipeline.translate_many(sources)

        self.assertEqual(len(results), 3)
        self.assertEqual(results["Blue is nice"], "BLUE E NICE")

    def test_recovers_from_a_contaminated_batch(self):
        # The ja failure: joined batch comes back with an invented heading on
        # every segment. The pipeline must notice and redo them individually.
        sources = ["Authentication here", "Back to the list", "Confirm your password"]

        def translate(text: str) -> str:
            if BATCH_SEPARATOR in text:
                segments = text.split(BATCH_SEPARATOR)
                return BATCH_SEPARATOR.join(f"\nの特長\n{segment.strip()}" for segment in segments)

            return f"OK {text}"

        pipeline = Pipeline(ScriptedTranslator(default=translate))
        results = pipeline.translate_many(sources)

        for source in sources:
            self.assertNotIn("の特長", results[source])
            self.assertTrue(results[source].startswith("OK "))

        self.assertEqual(pipeline.stats.retried, 3)

    def test_recovers_when_the_split_count_is_wrong(self):
        sources = ["Blue is nice", "Green is fine", "Red is bold"]
        translator = ScriptedTranslator(
            default=lambda text: "everything merged" if BATCH_SEPARATOR in text else f"OK {text}"
        )
        pipeline = Pipeline(translator)

        results = pipeline.translate_many(sources)

        self.assertTrue(all(value.startswith("OK ") for value in results.values()))

    def test_a_single_bad_string_does_not_poison_the_batch(self):
        sources = ["Blue is nice", "Green is fine", "Red is bold"]

        def translate(text: str) -> str:
            if BATCH_SEPARATOR in text:
                out = []

                for segment in text.split(BATCH_SEPARATOR):
                    segment = segment.strip()
                    out.append(
                        "ruim ruim ruim ruim" if segment.startswith("Green") else f"OK {segment}"
                    )

                return BATCH_SEPARATOR.join(out)

            return "ruim ruim ruim ruim" if text.startswith("Green") else f"OK {text}"

        pipeline = Pipeline(ScriptedTranslator(default=translate))
        results = pipeline.translate_many(sources)

        self.assertEqual(results["Blue is nice"], "OK Blue is nice")
        self.assertEqual(results["Green is fine"], "Green is fine")
        self.assertEqual(pipeline.stats.fell_back, 1)

    def test_deduplicates_repeated_sources(self):
        translator = ScriptedTranslator(default=lambda text: text)
        pipeline = Pipeline(translator)

        results = pipeline.translate_many(["Same string here"] * 5)

        self.assertEqual(len(results), 1)


class ChunkTest(unittest.TestCase):
    def test_splits_on_count(self):
        self.assertEqual(list(chunk(["a", "b", "c"], 2, 1000)), [["a", "b"], ["c"]])

    def test_splits_on_characters(self):
        self.assertEqual(list(chunk(["aaa", "bbb"], 10, 4)), [["aaa"], ["bbb"]])

    def test_empty_input_yields_nothing(self):
        self.assertEqual(list(chunk([], 10, 100)), [])


if __name__ == "__main__":
    unittest.main()
