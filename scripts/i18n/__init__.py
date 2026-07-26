"""Shared building blocks for the i18n tooling.

Layered so each piece is usable and testable on its own:

- `locales`    the supported set, parsed from config/i18n_locales.exs
- `protection` masking fragments a translator must not touch
- `quality`    guards deciding whether output is fit to ship
- `translator` engines behind one interface, injectable in tests
- `pipeline`   batching and fallbacks, pure of I/O and engine choice
- `catalogs`   all catalog filesystem access
"""
