# i18n catalog standard

RetroHexChat uses Gettext with English as the source language and versioned catalogs.
The project standard is to keep catalogs small, one per functional domain,
instead of concentrating everything in `default.po`.

## Locales

Locales are registered in `config/i18n_locales.exs`, with:

- the Gettext directory code, for example `pt_BR` or `zh_hans`;
- the BCP 47 tag for HTML, for example `pt-BR` or `zh-Hans`;
- the Open Graph locale;
- the native name for the language picker;
- the text direction, `ltr` or `rtl`;
- the Gettext `Plural-Forms`;
- the rollout wave and status.

The enabled set is 14 locales, all with `status: :enabled` in the registry:

| Wave | Locales |
| --- | --- |
| 0 | `en`, `pt_BR` |
| 1 | `es`, `fr`, `de`, `ja`, `zh_hans`, `id` |
| 2 | `ru` |
| 3 | `zh_hant`, `pt_PT`, `it`, `pl`, `nl` |

No planned locale exists outside this list. Adding or removing a language is
an edit to a single file, `config/i18n_locales.exs` — the Makefile, the browser
catalogs and the Python checkers derive from it. Never write a list of locales
anywhere else.

All enabled locales are LTR. The RTL path remains in the code
(`dir={RetroHexChatWeb.I18n.html_dir()}` on the `html` element), but today no
locale exercises it; a future RTL language requires a dedicated visual review.

## Domains

`apps/retro_hex_chat`:

- `accounts`, `admin`, `arcade`, `bots`, `channels`, `chat`, `commands`,
  `emoji`, `games`, `group_call`, `help`, `p2p`, `services`
- `default` must stay empty or hold only genuinely cross-cutting strings.

`apps/retro_hex_chat_web`:

- `admin`, `chat`, `connect`, `default`, `diagrams`, `dialogs`, `errors`,
  `games`, `group_call`, `landing`, `p2p`, `showcase`, `system`, `ui`
- Long help is split into `help`, `help_arcade`, `help_bots`,
  `help_channels`, `help_commands`, `help_features`, `help_games`,
  `help_p2p` and `help_ui`.

JavaScript catalogs live in `apps/retro_hex_chat_web/assets/js/lib/i18n_catalogs`,
one file per locale. `i18n_catalog.js` is only the compatibility barrel
that re-exports those files for the runtime and for the tests.

## Rules

- New code must use `dgettext/2`, `dngettext/4` or `dpgettext/3` with the
  right domain. Use `gettext/1` only when the string truly belongs to
  `default`.
- `msgid` stays in English and must be a literal to keep extraction
  automatic.
- Interpolation must use Gettext placeholders, for example
  `dgettext("chat", "Hello, %{name}", name: name)`.
- A `.po` file above 12,000 lines is a regression: create or refine a domain.
- Enabled locales cannot have `msgstr ""`, pending `fuzzy` or lost
  Gettext placeholders.
- Enabled locales also cannot keep an English fallback when the string
  with a placeholder is clearly user-facing text. Technical formats, scores,
  URLs, commands and service envelopes are documented in the allowlist of
  `scripts/i18n_source_fallback_check.py`.
- Machine translation is accepted as a working draft, but human review is still
  required for terminology, tone and feature names.
- Batch writes **match by msgid AND domain**, never by msgid alone. A script
  that swept every `.po` looking for `%{count} minute` overwrote twelve
  entries of `chat.po` that already had their own translation: the same English
  words, another catalog, another person's answer. The prior `tar` plus the diff
  of each `msgstr` is what found it — twice now (once in `accounts`, once
  in these). Limit the write to the domains the extract actually touched.
- Searching for `fuzzy` in a `.po` with `grep` also finds the `msgid`s that talk
  about fuzzy search. The flag is a `#,` line — match on `^#,.*\bfuzzy\b`, or you
  will investigate translations that are correct.
- `fuzzy` **renders**. Gettext serves a translation marked `fuzzy` like
  any other, so it is not "almost done", it is the old text showing on
  screen with the confidence of the new text. Measured on 2026-09-01: `repeat window`
  appeared as "janela limpa", `Sharing a Game` as "Iniciando um jogo solo",
  and the Chinese P2P invite carried `/p2p/ %{token}` — with a space, a dead
  link. Clearing the flag is a per-entry decision, never a batch one.

### The third checker, and the hole it closed

`i18n_po_status` counts entries **present** in the `.po`; `i18n.gettext.check`
asserts the `.pot` is fresh. Neither asks whether every `msgid` in the
`.pot` exists in every `.po` — and an entry that was never merged is not
empty, it does not exist. Measured on 2026-09-01 with both green: **65 `msgid`s**
lived in a `.pot` and in no catalog, and the 13 locales rendered all of them in
English (`help_bots` 29, `accounts` 9, `help_ui` 8, `dialogs` 6, `commands` 5,
`help` 3, `connect` 3, and five more domains with 1 each).

Closed the same day: the 65 are translated by hand and
`scripts/i18n_catalog_completeness_check.exs` joined
`make i18n.catalog.check`, which is already in `make ci`. Its question is
presence, not content — whether the entry says something useful is what the other two
check.

**Measurement trap, an expensive one:** the first count used `pt_BR` as the probe and
found 48. Nine `msgid`s from `accounts` existed in `pt_BR` and were missing from the other
twelve locales, and three from `connect` were missing only from `en` — invisible to a
single-locale probe. Count against **all** locales, which is what the checker
does.

## Workflow

After changing translatable strings:

```sh
make i18n.gettext.extract
make i18n.gettext.merge DOMAINS=landing
make i18n.catalog.check
make i18n.gettext.check
```

`i18n.gettext.extract` follows the standard Gettext flow and updates only the
`.pot` templates. `i18n.gettext.merge` calls `mix gettext.merge` file by
file for the selected domains, preserving translations and marking fuzzy
when Gettext finds an approximate match. Use `APP=web` or
`APP=domain` to limit the app, and `LOCALES=pt_BR,es` to limit locales.

To translate the new and fuzzy entries of a domain, use the targets: they
scope the paths, reject a `DOMAINS` that matches no catalog and apply the
glossary after the machine:

```sh
make i18n.venv                                # once: polib, Argos and one model per locale
make i18n.translate DOMAINS=landing APP=web
```

To add a wave:

```sh
make i18n.locales.add WAVE=2
```

To add specific locales:

```sh
make i18n.locales.add LOCALES=es,fr,de
```

For JavaScript catalogs, run `scripts/i18n_machine_translate_js.py` only
when the change actually touches the browser catalogs in
`apps/retro_hex_chat_web/assets/js/lib/i18n_catalogs`.

`scripts/i18n_machine_translate_js.py`, `scripts/i18n_apply_translation_overrides.py`,
`scripts/i18n_repair_js_catalog_placeholders.py` and
`scripts/i18n_source_fallback_check.py` use `scripts/i18n_js_catalogs.py` to
preserve that split layout.

The scripts protect placeholders with alphanumeric sentinels (`XPH0X`), never
with tags: the models treat `<ph0></ph0>` as markup and mangle it. The exception is
`%{count}` in plurals, translated as a number ("1 game", "2 games", "5 games",
chosen by the locale's own `Plural-Forms` rule) and turned back into a
placeholder afterwards — see `scripts/i18n/numerals.py`.

Every script writes catalogs through `catalogs.save_po`, which rewrites only the
changed entries; polib's `po.save()` reflows msgstrs nobody touched, and
`mix gettext.merge` does not undo it.

Repairs to existing catalogs:

- `make i18n.repair` — re-translates unusable entries.
- `make i18n.repair.plurals` — short `%{count} <noun>` plurals with the
  number after the noun or with the "few"/"many" forms collapsed;
  applies the result only if it removes a defect.
- `--msgid "<text>"` in `i18n_machine_translate_po.py` — re-translates a msgid
  known to be bad, through the pipeline, instead of editing the catalog by hand.

After any pass, validate the same set of files:

```sh
mix run --no-start scripts/i18n_placeholder_check.exs --fail-on-findings \
  apps/retro_hex_chat_web/priv/gettext/*/LC_MESSAGES/landing.po
make i18n.quality.check
make i18n.catalog.check
```

`make i18n.catalog.check` stays global on purpose: it is the final barrier
against any pending entry in an enabled locale. The previous commands should be
scoped to the domain/feature being worked on.

`scripts/i18n_apply_translation_overrides.py` holds old curated phrases and
takes no new phrases. New human text that comes out wrong or stays in English is
a pipeline defect: fix the rule that let it through (`scripts/i18n/terms.py`
for chat vocabulary, `quality.py` for the gates, `protection.py` for what
is not translated), with a test in `scripts/tests/`, and re-translate with
`i18n_machine_translate_po.py --msgid`. Never edit the catalog by hand.

For large refactors:

```sh
elixir scripts/i18n_domainize_gettext_calls.exs
elixir scripts/i18n_split_help_domains.exs
make i18n.gettext.rebuild CONFIRM_GLOBAL_REBUILD=1
```

`scripts/i18n_rehydrate_domain_translations.exs` rebuilds the `.po` files from
the current `.pot` files and copies existing translations by `msgid`. This avoids
losing translations when a text only changes domain, but it should be reserved
for broad refactors because it rewrites entire catalogs.
