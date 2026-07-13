# Language Menu I18n Progress

## Decisions

- Public pages without a locale prefix should detect `Accept-Language` on first visit.
- If browser detection resolves to a non-default locale, public pages should redirect to the clean localized URL.
- Visiting a localized public URL should save that locale preference in the Phoenix session cookie.
- Language changes may reload the page and may lose transient drafts/window state.
- The connect screen language selector should move to the menu bar; the old in-window selector should be removed.
- Showcase is out of scope for the product-facing rollout.
- The menu label should be translated.
- Locale preference remains cookie/session based; no database/profile persistence in this change.

## TDD Checklist

- [x] Public first visit detects browser locale and redirects to a clean localized URL.
- [x] Public default URLs do not erase an existing session locale.
- [x] Localized public URLs save the selected locale preference.
- [x] `MenuBarApp` renders an always-enabled language menu for connect and chat.
- [x] Connect no longer renders the old in-window locale switcher.
- [x] Help menu bar renders language links that preserve the current help topic.
- [x] RTL locale switching still updates `html dir`.
- [x] Focused Elixir, JS, and e2e validations pass.

## Progress Log

### 2026-07-13

- Synced `main` with `origin/main` using fast-forward pull before implementation.
- Starting from commit `fb86a671`.
- Added failing tests for browser-locale redirects, public preference persistence,
  connect/chat/help language menu contracts, and removal of the old connect-body
  locale switcher.
- Implemented shared `LanguageMenu` for app/public menu bars.
- Integrated language menu into connect/chat (`MenuBarApp`), help (`HelpMenuBar`),
  and landing public menu.
- Public unprefixed pages now redirect to the saved/browser non-default locale;
  localized public URLs save the locale preference.
- Removed the old connect-window locale switcher and its link-building helper.
- Added `Language` to the `ui` Gettext domain for all enabled locales.
- Updated i18n e2e tests to use the menu bar and added chat menu switching coverage.
- Rebuilt Gettext catalogs for both apps with the project rebuild script.
- Fixed existing catalog drift across required locales: empty/fuzzy entries,
  source fallbacks, placeholder mismatches, and stale POT files now pass the
  official i18n checks.
- Switched machine-assisted catalog repair to per-locale batches with isolated
  validation. A single global run was too slow and made placeholder issues
  harder to isolate.
- Added curated overrides and technical allowlist entries for residual i18n
  strings that machine translation either left in English or should not
  translate literally.

## Validation

- `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/controllers/landing_controller_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/connect_desktop_shell_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_desktop_shell_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/help_live_test.exs` — 117 tests, 0 failures.
- `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/i18n_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/controllers/locale_controller_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/i18n_live_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/controllers/session_controller_test.exs` — 34 tests, 0 failures.
- `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/window_display_edit_menu_feature_test.exs --include liveview_feature` — 4 tests, 0 failures.
- `npm test -- test/lib/i18n.test.js` in `apps/retro_hex_chat_web/assets` — 14 tests, 0 failures.
- `npx tsc --noEmit` in `e2e` — no TypeScript errors.
- `npm test -- tests/i18n.spec.ts` in `e2e` — 5 tests, 0 failures.
- `mix test` — `retro_hex_chat`: 2707 tests + 15 properties, 0 failures; `retro_hex_chat_web`: 762 tests, 0 failures, 254 excluded.
- `make i18n.gettext.check` — passed.
- `make i18n.catalog.check` — passed.

## Known Validation Gaps

- None currently known for the i18n checks covered by this change.

## Learnings

- Current app preference lives in the Phoenix encrypted session cookie under `:locale`.
- Current public page pipeline forces `en` for unprefixed public paths and writes it to session; this is the main preference-loss risk to fix.
- `MenuBarApp`, `HelpMenuBar`, and landing menu use the same menu/context primitives, but they are separate concrete menu bars.
- The menu bar trigger label is translated, so e2e should not locate it by text;
  `data-testid="language-menu-trigger"` is the stable interaction contract.
- `/sitemap.xml` shares the public pipeline but must not redirect by browser
  locale.
- For catalog repair, run translation per locale and validate after each batch.
  Global machine-translation runs can take too long and can cache unsafe
  placeholder-stripped translations.
- Always run `i18n_repair_placeholder_mismatches.py` or the placeholder check
  after machine-assisted PO work before trusting source-fallback results.
