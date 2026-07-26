"""Turning source strings into shippable translations.

This module owns the batching, the guards and the fallbacks. It holds no I/O
and constructs no engine: callers pass a `Translator`, so the whole flow can be
driven by a scripted fake in tests.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from .protection import BATCH_SEPARATOR, protect, restore, should_machine_translate
from .quality import batch_is_contaminated, is_usable_translation
from .translator import Translator

DEFAULT_BATCH_SIZE = 48
DEFAULT_BATCH_CHARS = 8000


@dataclass
class TranslationStats:
    translated: int = 0
    skipped: int = 0
    rejected: int = 0
    retried: int = 0
    fell_back: int = 0
    reasons: list[str] = field(default_factory=list)


class Pipeline:
    """Translates strings for one locale, rejecting unusable output."""

    def __init__(
        self,
        translator: Translator,
        postprocess=None,
        batch_size: int = DEFAULT_BATCH_SIZE,
        batch_chars: int = DEFAULT_BATCH_CHARS,
    ):
        self.translator = translator
        self.postprocess = postprocess or (lambda text: text)
        self.batch_size = max(batch_size, 1)
        self.batch_chars = max(batch_chars, 500)
        self.stats = TranslationStats()

    # ── single strings ────────────────────────────────────────

    def translate_one(self, source: str) -> str:
        """Translate one string, falling back to the source when unusable."""
        if not should_machine_translate(source):
            self.stats.skipped += 1
            return source

        protected, replacements = protect(source)
        translated = self.postprocess(restore(self.translator.translate(protected).strip(), replacements))

        if is_usable_translation(source, translated, replacements):
            self.stats.translated += 1
            return translated

        self.stats.rejected += 1
        self.stats.fell_back += 1
        self.stats.reasons.append(source)
        return source

    # ── batches ───────────────────────────────────────────────

    def translate_many(self, sources: list[str]) -> dict[str, str]:
        """Translate many strings, batching for speed but verifying each one."""
        results: dict[str, str] = {}
        pending: list[str] = []

        for source in sources:
            if source in results:
                continue

            if not should_machine_translate(source):
                self.stats.skipped += 1
                results[source] = source
            else:
                pending.append(source)

        for batch in chunk(pending, self.batch_size, self.batch_chars):
            results.update(self._translate_batch(batch))

        return results

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
            translated = self.postprocess(restore(part, replacements))

            if is_usable_translation(source, translated, replacements):
                self.stats.translated += 1
                results[source] = translated
                continue

            self.stats.rejected += 1
            results[source] = self._retry_alone(source)

        return results

    def _retry_alone(self, source: str) -> str:
        protected, replacements = protect(source)
        translated = self.postprocess(restore(self.translator.translate(protected).strip(), replacements))

        if is_usable_translation(source, translated, replacements):
            self.stats.retried += 1
            return translated

        self.stats.fell_back += 1
        self.stats.reasons.append(source)
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
