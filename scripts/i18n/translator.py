"""Translation engines behind one small interface.

The pipeline only ever calls `translate(text) -> str`, so tests inject a fake
and never need Argos models installed. Engine construction is lazy for the
same reason: importing this module must not require the translation venv.
"""

from __future__ import annotations

from typing import Protocol


class Translator(Protocol):
    def translate(self, text: str) -> str:  # pragma: no cover - interface
        ...


class IdentityTranslator:
    """Returns text unchanged. Used for the source locale."""

    def translate(self, text: str) -> str:
        return text


class ScriptedTranslator:
    """A deterministic translator for tests.

    Looks up exact matches in `responses`; anything unknown falls back to
    `default`, which receives the input text.
    """

    def __init__(self, responses: dict[str, str] | None = None, default=None):
        self.responses = responses or {}
        self.default = default or (lambda text: text)
        self.calls: list[str] = []

    def translate(self, text: str) -> str:
        self.calls.append(text)

        if text in self.responses:
            return self.responses[text]

        return self.default(text)


class ArgosTranslator:
    """Offline NMT via Argos Translate."""

    def __init__(self, to_code: str, from_code: str = "en"):
        from argostranslate import translate as argos

        installed = argos.get_installed_languages()

        try:
            source = next(language for language in installed if language.code == from_code)
            target = next(language for language in installed if language.code == to_code)
            translation = source.get_translation(target)
        except StopIteration:
            translation = None

        if translation is None:
            raise SystemExit(
                f"No Argos model installed for {from_code} -> {to_code}. "
                "Run make i18n.venv to install it."
            )

        self._translation = translation

    def translate(self, text: str) -> str:
        return self._translation.translate(text)


def build(locale_code: str, argos_code: str) -> Translator:
    if locale_code == "en" or argos_code == "en":
        return IdentityTranslator()

    return ArgosTranslator(argos_code)


def build_back(locale_code: str, argos_code: str) -> Translator | None:
    """The engine that reads a translation back into English, or None for `en`.

    Traditional Chinese is read back through the Simplified model, which is the
    one Argos has, after converting the text to the script that model reads.
    """
    if locale_code == "en" or argos_code == "en":
        return None

    back = ArgosTranslator("en", from_code=argos_code)

    if locale_code == "zh_hant":
        return SimplifiedChineseReader(back)

    return back


class SimplifiedChineseReader:
    """Converts Traditional input to Simplified before the zh -> en model."""

    def __init__(self, inner: Translator):
        self.inner = inner
        self._converter = None

    def translate(self, text: str) -> str:
        if self._converter is None:
            from opencc import OpenCC

            self._converter = OpenCC("t2s")

        return self.inner.translate(self._converter.convert(text))


class TraditionalChinesePostprocessor:
    """Converts Simplified output to Traditional for zh_hant.

    Argos has no direct en -> zh_hant model, so zh output is converted.
    """

    def __init__(self, inner: Translator):
        self.inner = inner
        self._converter = None

    def translate(self, text: str) -> str:
        return self.convert(self.inner.translate(text))

    def convert(self, text: str) -> str:
        if self._converter is None:
            try:
                from opencc import OpenCC
            except ImportError as error:
                raise SystemExit(
                    "zh_hant needs opencc-python-reimplemented in the translation venv"
                ) from error

            self._converter = OpenCC("s2t")

        return self._converter.convert(text)
