"""Translating a count as a number, so each plural form gets its own grammar.

`%{count} game` reaches the model with the placeholder masked as a sentinel,
and the model has no way to know a number goes there. It treated the sentinel
as a name: French came back "Jeu %{count}" ("Game 18"), Dutch "%{count}-spel",
and Polish gave all three of its forms the same word, though one game, three
games and five games are three different words there.

So a plural entry is translated through an example: each slot's source is sent
with a number that falls in that slot — "1 game", "3 games", "5 games" for
Polish — and the number is turned back into `%{count}` afterwards. The number
for each slot comes from the locale's own Gettext plural rule, evaluated here,
so a language added to the registry needs no table in this file.

When the translation does not carry the number back exactly once (a model that
spelled "1" as "one" has nowhere to put the placeholder), the caller falls back
to the ordinary masked path.
"""

from __future__ import annotations

import re
from collections.abc import Callable
from functools import lru_cache

COUNT = "%{count}"

# How far to look for a number that lands in each slot. Every rule we ship
# reaches all of its slots well inside this.
_SEARCH_LIMIT = 200

# The number a one-form language is shown: any plural number, never 1, whose
# translation would be the singular and then be used for every count.
_ONE_FORM_SAMPLE = 5


def sample_number(plural_forms: str, index: int) -> int:
    """The count that reads most naturally in `index`: for the singular slot
    the smallest count the rule puts there, for every other slot the smallest
    above 1 — falling back to 1, then 0, for a slot only those reach (Latvian
    gives 0 a slot of its own)."""
    nplurals, rule = parse_plural_forms(plural_forms)

    if nplurals == 1:
        return _ONE_FORM_SAMPLE

    candidates = [n for n in range(0, _SEARCH_LIMIT) if rule(n) == index]

    if not candidates:
        raise ValueError(f"no count in 0..{_SEARCH_LIMIT} reaches slot {index} of {plural_forms!r}")

    if index == 0:
        positive = [n for n in candidates if n > 0]
        return positive[0] if positive else candidates[0]

    for preferred in ([n for n in candidates if n > 1], [n for n in candidates if n == 1], candidates):
        if preferred:
            return preferred[0]

    return candidates[0]


def as_numeral(source: str, number: int) -> str | None:
    """`source` with its one `%{count}` written as `number`, or None if it has none or several."""
    if source.count(COUNT) != 1:
        return None

    return source.replace(COUNT, str(number))


def from_numeral(translated: str, number: int) -> str | None:
    """`translated` with `number` turned back into `%{count}`.

    None unless the number appears exactly once as a whole number: a model that
    dropped it, spelled it out or repeated it leaves no single place for the
    placeholder to go.
    """
    pattern = re.compile(rf"(?<![\d.,]){number}(?!\d|[.,]\d)")
    matches = pattern.findall(translated)

    if len(matches) != 1:
        return None

    return pattern.sub(COUNT, translated, count=1)


@lru_cache(maxsize=None)
def parse_plural_forms(plural_forms: str) -> tuple[int, Callable[[int], int]]:
    """(nplurals, rule) from a Gettext header such as "nplurals=2; plural=(n != 1);"."""
    match = re.search(r"nplurals\s*=\s*(\d+)\s*;\s*plural\s*=\s*(.+?);?\s*$", plural_forms.strip())

    if not match:
        raise ValueError(f"not a Gettext plural rule: {plural_forms!r}")

    nplurals = int(match.group(1))
    expression = _Parser(match.group(2).rstrip(";")).parse()
    return nplurals, lambda n: int(expression(n))


class _Parser:
    """The C subset Gettext plural rules are written in: `n`, integers, `% == != < <= > >=`,
    `&& || !`, parentheses and the `?:` conditional. Each rule compiles to a function of n."""

    _TOKEN = re.compile(r"\s*(\d+|n|==|!=|<=|>=|&&|\|\||[%<>!?:()])")

    def __init__(self, text: str):
        self.tokens = []
        position = 0
        text = text.strip()

        while position < len(text):
            match = self._TOKEN.match(text, position)

            if not match:
                raise ValueError(f"unexpected input in plural rule at {text[position:]!r}")

            self.tokens.append(match.group(1))
            position = match.end()

        self.position = 0

    def parse(self):
        expression = self._conditional()

        if self.position != len(self.tokens):
            raise ValueError(f"trailing tokens in plural rule: {self.tokens[self.position:]}")

        return expression

    def _peek(self):
        return self.tokens[self.position] if self.position < len(self.tokens) else None

    def _take(self, expected=None):
        token = self._peek()

        if expected is not None and token != expected:
            raise ValueError(f"expected {expected!r} in plural rule, found {token!r}")

        self.position += 1
        return token

    def _conditional(self):
        condition = self._or()

        if self._peek() != "?":
            return condition

        self._take("?")
        then = self._conditional()
        self._take(":")
        otherwise = self._conditional()
        return lambda n: then(n) if condition(n) else otherwise(n)

    def _or(self):
        left = self._and()

        while self._peek() == "||":
            self._take()
            right = self._and()
            left = (lambda a, b: lambda n: bool(a(n)) or bool(b(n)))(left, right)

        return left

    def _and(self):
        left = self._equality()

        while self._peek() == "&&":
            self._take()
            right = self._equality()
            left = (lambda a, b: lambda n: bool(a(n)) and bool(b(n)))(left, right)

        return left

    _EQUALITY = {"==": lambda a, b: a == b, "!=": lambda a, b: a != b}
    _RELATIONAL = {
        "<": lambda a, b: a < b,
        "<=": lambda a, b: a <= b,
        ">": lambda a, b: a > b,
        ">=": lambda a, b: a >= b,
    }

    # C binds relational operators tighter than equality: `n == 1 < 2` is
    # `n == (1 < 2)`.
    def _equality(self):
        left = self._relational()

        while self._peek() in self._EQUALITY:
            compare = self._EQUALITY[self._take()]
            right = self._relational()
            left = (lambda c, a, b: lambda n: c(a(n), b(n)))(compare, left, right)

        return left

    def _relational(self):
        left = self._modulo()

        while self._peek() in self._RELATIONAL:
            compare = self._RELATIONAL[self._take()]
            right = self._modulo()
            left = (lambda c, a, b: lambda n: c(a(n), b(n)))(compare, left, right)

        return left

    def _modulo(self):
        left = self._unary()

        while self._peek() == "%":
            self._take()
            right = self._unary()
            left = (lambda a, b: lambda n: a(n) % b(n))(left, right)

        return left

    def _unary(self):
        token = self._take()

        if token == "!":
            operand = self._unary()
            return lambda n: not operand(n)

        if token == "(":
            inner = self._conditional()
            self._take(")")
            return inner

        if token == "n":
            return lambda n: n

        if token is not None and token.isdigit():
            value = int(token)
            return lambda _n: value

        raise ValueError(f"unexpected {token!r} in plural rule")


def plural_defects(forms: list[str], msgid: str, nplurals: int) -> set[str]:
    """What is mechanically wrong with a plural entry's translated forms.

    - "order": the source begins with the count and a form does not. Every
      language here that has plural forms at all writes the number before
      the noun, so "Heures %{count}" is the masked-sentinel failure, not a
      choice. One-form languages (Japanese, Chinese, Indonesian) place it
      freely and are never flagged.
    - "collapsed": a three-form language gave its "few" and "many" slots the
      same text. Sometimes that is right (Polish: 2 dni, 5 dni), which is why
      a repair only lands when it removes a defect — see `repair_wins/3`.

    Judged on the forms alone, so the check needs no model and runs anywhere.
    """
    defects = set()
    present = [form for form in forms if form]

    if nplurals > 1 and msgid.startswith(COUNT) and any(not form.startswith(COUNT) for form in present):
        defects.add("order")

    if nplurals == 3 and len(forms) == 3 and forms[1] and forms[1] == forms[2]:
        defects.add("collapsed")

    return defects


# What a repair may retranslate: a count and the noun it counts, nothing
# around them. Retranslating a sentence rewrote words that were right —
# "Ouvrir le fil" became "Thème ouvert", Polish "muted" became "damaged" —
# so a sentence keeps its text even when its plural forms are imperfect.
SHORT_COUNT_PHRASE = re.compile(r"^%\{count\} [^%{}.!?:;()]{1,40}$")

def repairable(msgid: str) -> bool:
    """Whether `msgid` is a count and the noun it counts, which a repair may retranslate."""
    return bool(SHORT_COUNT_PHRASE.match(msgid))


def forms_agree(forms: list[str]) -> bool:
    """Whether every form counts the same word.

    Compared on the first letter only, case and all: the forms of one Slavic
    noun share little more ("gra", "gry", "gier"; "dzień", "dni"), while the
    failures to catch differ there already — a different word for one slot
    ("entrée", "rubriques") or one slot capitalised ("в пространстве",
    "В космосе").
    """
    if not all(form.startswith(COUNT) for form in forms if form):
        return False

    initials = {form[len(COUNT) :].strip()[:1] for form in forms if form}
    return len(initials) == 1


def repair_wins(
    old: list[str], new: list[str], msgid: str, nplurals: int, msgid_plural: str = ""
) -> bool:
    """Whether retranslated forms replace the current ones: only for a short
    count phrase, only when they fix a defect and introduce none, only when
    every new form counts the same word, and never when a form is the English
    source — the pipeline keeps the source when a model fails, and "%{count}
    hours" has no defect a French "Heures %{count}" has, yet is worse. Anything
    less keeps the current text, because a repair that might be worse is not a
    repair."""
    sources = {msgid, msgid_plural} - {""}

    if not repairable(msgid) or not forms_agree(new) or any(form in sources for form in new):
        return False

    before = plural_defects(old, msgid, nplurals)
    after = plural_defects(new, msgid, nplurals)
    return after < before
