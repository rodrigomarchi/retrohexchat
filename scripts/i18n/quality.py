"""Deciding whether a machine translation is fit to ship.

The guards here encode failure modes observed in real catalogs. They are pure
functions over strings so they can be exercised without a translation engine,
and they are shared by the translation pipeline (which rejects bad output at
write time) and the CI gate (which rejects it at review time).
"""

from __future__ import annotations

import re
from collections import defaultdict

from .protection import has_sentinel_residue

# A token repeated this many times in a row is an NMT decoding loop, e.g.
# "permanently" -> "Sürekli kalıcı kalıcı kalıcı kalıcı kalıcı".
DEGENERATE_RUN = 4
# A long run of one character, e.g. a backslash explosion.
DEGENERATE_CHAR_RUN = re.compile(r"(\S)\1{7,}")
# One translation serving at least this many distinct sources means the model
# collapsed unrelated strings onto a single output.
COLLAPSE_THRESHOLD = 5


def is_degenerate(text: str) -> bool:
    """True when the output shows a decoding loop."""
    tokens = text.split()
    run = 1

    for index in range(1, len(tokens)):
        if tokens[index] == tokens[index - 1] and len(tokens[index]) > 1:
            run += 1

            if run >= DEGENERATE_RUN:
                return True
        else:
            run = 1

    return bool(DEGENERATE_CHAR_RUN.search(text))


def introduced_degeneration(source: str, translated: str) -> bool:
    """True when the repetition is the model's doing, not the source's.

    Some sources repeat on purpose (a scroll-area demo string), and echoing
    that faithfully is correct.
    """
    return is_degenerate(translated) and not is_degenerate(source)


def is_usable_translation(source: str, translated: str, replacements: dict[str, str]) -> bool:
    """Reject output we would rather not ship at all.

    A translation that lost a placeholder, kept a raw sentinel, looped, or came
    back empty is worse than leaving the English source in place: the source
    stays readable and the fallback check flags it for a human.
    """
    if not translated.strip():
        return False

    if has_sentinel_residue(translated):
        return False

    if introduced_degeneration(source, translated):
        return False

    return all(value in translated for value in replacements.values())


def batch_is_contaminated(parts: list[str], sources: list[str]) -> bool:
    """Detect a model treating a joined batch as a single document.

    Chaining unrelated UI strings makes some models emit a running heading in
    front of the segments. It shows up as one extra leading line that several
    parts share and their sources do not. The first segment usually escapes it
    (the model only starts the heading after the first separator), so a
    majority rule is used rather than requiring every part to carry it.
    """
    if len(parts) < 3 or len(parts) != len(sources):
        return False

    spurious: dict[str, int] = defaultdict(int)

    for part, source in zip(parts, sources):
        # A single-line result has no extra heading: the line is the answer.
        if "\n" not in part:
            continue

        head = part.split("\n", 1)[0].strip()

        if not head:
            continue

        # A first line mirroring the source's own first line is legitimate.
        if head == source.split("\n", 1)[0].strip():
            continue

        spurious[head] += 1

    return any(count >= 2 for count in spurious.values())


def find_shared_headings(
    entries: list[tuple[str, str]], threshold: int = COLLAPSE_THRESHOLD
) -> dict[str, set[str]]:
    """Leading lines many translations share but their sources do not.

    This is `batch_is_contaminated` applied to a whole catalog: it catches a
    heading the model injected during batching that was then written to disk,
    which no per-string check can see.
    """
    headings: dict[str, set[str]] = defaultdict(set)

    for source, translated in entries:
        if "\n" not in translated:
            continue

        head = translated.split("\n", 1)[0].strip()

        if not head or head == source.split("\n", 1)[0].strip():
            continue

        headings[head].add(source.strip())

    return {head: sources for head, sources in headings.items() if len(sources) >= threshold}


def find_collapses(
    entries: list[tuple[str, str]], threshold: int = COLLAPSE_THRESHOLD
) -> dict[str, set[str]]:
    """Group sources that share one translation.

    `entries` is a list of (source, translated) pairs. The result maps each
    over-reused translation to the distinct sources that produced it.
    """
    by_translation: dict[str, set[str]] = defaultdict(set)

    for source, translated in entries:
        stripped = translated.strip()

        if stripped:
            by_translation[stripped].add(source.strip())

    return {
        translated: sources
        for translated, sources in by_translation.items()
        if len(sources) >= threshold
    }
