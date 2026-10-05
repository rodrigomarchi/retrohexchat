"""Turning source strings into shippable translations.

This module owns the batching, the guards and the fallbacks. It holds no I/O
and constructs no engine: callers pass a `Translator`, so the whole flow can be
driven by a scripted fake in tests.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from .protection import BATCH_SEPARATOR, protect, restore, should_machine_translate
from .quality import (
    batch_is_contaminated,
    invented_break,
    is_usable_translation,
    lost_negation,
    meaning_kept,
)
from .terms import foreign_forms, missing_terms
from .translator import Translator

DEFAULT_BATCH_SIZE = 48
DEFAULT_BATCH_CHARS = 8000

# A one-word answer opening a sentence ("No. It works the way IRC does…"). The
# engine reads a bare "No." as an exclamation and answered "C'est pas vrai"
# and "Oh, my God"; the answer is a glossary word, so it is said by the
# glossary and only the sentence after it goes to the engine.
ANSWER_RE = re.compile(r"^(Yes|No)\. (\S.*)$", re.DOTALL)


@dataclass
class TranslationStats:
    translated: int = 0
    skipped: int = 0
    rejected: int = 0
    retried: int = 0
    fell_back: int = 0
    reasons: list[str] = field(default_factory=list)


class Pipeline:
    """Translates strings for one locale, rejecting unusable output.

    Beyond the shape checks every translation gets, three optional ones need
    the locale and are off when it is not given: the chat's vocabulary
    (`terms`), a reading back into English (`back_translator`), and the
    glossary's own word for a leading "Yes." or "No." (`answers`).
    """

    def __init__(
        self,
        translator: Translator,
        postprocess=None,
        batch_size: int = DEFAULT_BATCH_SIZE,
        batch_chars: int = DEFAULT_BATCH_CHARS,
        locale_code: str | None = None,
        back_translator: Translator | None = None,
        answers: dict[str, str] | None = None,
        full_stop: str = ".",
    ):
        self.translator = translator
        self.postprocess = postprocess or (lambda text: text)
        self.batch_size = max(batch_size, 1)
        self.batch_chars = max(batch_chars, 500)
        self.locale_code = locale_code
        self.back_translator = back_translator
        self.answers = answers or {}
        self.full_stop = full_stop
        self.stats = TranslationStats()
        self._fell_back: set[str] = set()

    # ── single strings ────────────────────────────────────────

    def translate_one(self, source: str) -> str:
        """Translate one string, falling back to the source when unusable."""
        return self.translate_many([source])[source]

    def acceptable(self, source: str, translated: str, replacements: dict[str, str]) -> bool:
        """Every check a translation must pass to replace the English source."""
        if not is_usable_translation(source, translated, replacements):
            return False

        if self.locale_code and (
            missing_terms(source, translated, self.locale_code)
            or foreign_forms(translated, self.locale_code)
            or lost_negation(source, translated, self.locale_code)
        ):
            return False

        if self.back_translator is None:
            return True

        masked, back_replacements = protect(translated)
        read_back = restore(self.back_translator.translate(masked).strip(), back_replacements)
        return meaning_kept(source, read_back)

    # ── batches ───────────────────────────────────────────────

    def translate_many(self, sources: list[str]) -> dict[str, str]:
        """Translate many strings, batching for speed but verifying each one."""
        results: dict[str, str] = {}
        bodies: dict[str, tuple[str, str]] = {}
        # What fell back belongs to this call: one pipeline serves every file
        # of a locale, and a body that failed in one file may pass in the next.
        self._fell_back = set()

        for source in sources:
            if source in results or source in bodies:
                continue

            prefix, body = self._split_answer(source)

            if not should_machine_translate(body):
                self.stats.skipped += 1
                results[source] = source
            else:
                bodies[source] = (prefix, body)

        pending = list(dict.fromkeys(body for _prefix, body in bodies.values()))
        translated: dict[str, str] = {}

        for batch in chunk(pending, self.batch_size, self.batch_chars):
            translated.update(self._translate_batch(batch))

        for source, (prefix, body) in bodies.items():
            # A body handed back unchanged is English behind a translated
            # answer word ("Não. It works…"): the whole entry stays English.
            if body in self._fell_back or (prefix and translated[body] == body):
                results[source] = source
            else:
                results[source] = prefix + translated[body]

        return results

    @staticmethod
    def _repair(source: str, translated: str) -> str:
        """Drops a heading the model invented above a one-line source (シリーズ)."""
        return invented_break(source, translated) or translated

    def _split_answer(self, source: str) -> tuple[str, str]:
        """The glossary's answer word, and the rest of the sentence for the engine."""
        match = ANSWER_RE.match(source)

        if not match or match.group(1) not in self.answers:
            return "", source

        # A full-width stop carries its own space.
        space = "" if self.full_stop == "。" else " "
        return f"{self.answers[match.group(1)]}{self.full_stop}{space}", match.group(2)

    def _translate_batch(self, batch: list[str]) -> dict[str, str]:
        masked: list[str] = []
        replacements_by_index: list[dict[str, str]] = []

        for source in batch:
            protected, replacements = protect(source)
            masked.append(protected)
            replacements_by_index.append(replacements)

        joined = f"\n{BATCH_SEPARATOR}\n".join(masked)
        parts = [part.strip() for part in self.translator.translate(joined).split(BATCH_SEPARATOR)]

        if len(parts) != len(batch) or batch_is_contaminated(parts, masked):
            # The join confused the model. Redo the batch one string at a time.
            self.stats.retried += len(batch)
            parts = [self.translator.translate(text).strip() for text in masked]

        results: dict[str, str] = {}

        for source, part, replacements in zip(batch, parts, replacements_by_index):
            translated = self._repair(source, self.postprocess(restore(part, replacements)))

            if self.acceptable(source, translated, replacements):
                self.stats.translated += 1
                results[source] = translated
                continue

            self.stats.rejected += 1
            results[source] = self._retry_alone(source)

        return results

    def _retry_alone(self, source: str) -> str:
        protected, replacements = protect(source)
        translated = self._repair(
            source, self.postprocess(restore(self.translator.translate(protected).strip(), replacements))
        )

        if self.acceptable(source, translated, replacements):
            self.stats.retried += 1
            return translated

        self.stats.fell_back += 1
        self.stats.reasons.append(source)
        self._fell_back.add(source)
        return source


def chunk(values: list[str], size: int, max_chars: int):
    """Group values into batches bounded by count and total characters."""
    batch: list[str] = []
    chars = 0

    for value in values:
        if batch and (len(batch) >= size or chars + len(value) > max_chars):
            yield batch
            batch = []
            chars = 0

        batch.append(value)
        chars += len(value)

    if batch:
        yield batch
