# SEO i18n & Public Pages Plan

**Created**: 2026-06-02  
**Status**: Active  
**Priority**: High  
**Scope**: Public landing pages, help documentation pages, SEO metadata, localized URL discovery, and public-page performance.

## Objective

Make Retro Hex Chat easier to crawl, index, share, and rank by giving public pages stable localized URLs, stronger canonical/hreflang behavior, and a lighter public-page asset path.

Primary target:

- Default locale keeps canonical unprefixed URLs, for example `/features`.
- Non-default locales get clean permanent paths, for example `/pt-BR/features`, `/es/features`, `/zh-Hans/features`.
- Public SEO URLs use only the clean path model. Query-locale public URLs are not supported as an alternate public form.
- Public landing/help pages avoid loading the full app JavaScript bundle when only small progressive behavior is needed.

## Current Baseline

- [x] Public landing and help layouts include canonical URLs, Open Graph, Twitter Card, social preview image metadata, and robots metadata.
- [x] App/session/showcase layouts include `noindex, nofollow, noarchive`.
- [x] `robots.txt` points to `/sitemap.xml` and blocks technical/session areas.
- [x] `sitemap.xml` lists landing/help URLs and includes `xhtml:link` hreflang alternates.
- [x] Social preview image exists at `apps/retro_hex_chat_web/priv/static/images/social/retrohexchat_og.png`.
- [x] Footer exposes visible language links using the existing i18n locale catalog.
- [x] Public secondary landing pages have a page-level `h1`.

## Target URL Model

Use BCP 47 locale segments in public URLs:

| Locale code | URL segment | Example |
|-------------|-------------|---------|
| `en` | none | `/features` |
| `pt_BR` | `pt-BR` | `/pt-BR/features` |
| `pt_PT` | `pt-PT` | `/pt-PT/features` |
| `zh_hans` | `zh-Hans` | `/zh-Hans/features` |
| `zh_hant` | `zh-Hant` | `/zh-Hant/features` |
| `es` | `es` | `/es/features` |

Default English remains unprefixed to avoid moving the main URL set.

## Phase 1: Locale URL Helpers

**Goal**: Centralize conversion between locale codes, URL segments, and canonical paths.

- [x] Add `I18n.locale_url_segment/1` or `SEO.locale_segment/1` using `Locales.bcp47/1`.
- [x] Add `SEO.locale_from_segment/1` to normalize URL segments back to enabled locale codes.
- [x] Replace query-based `SEO.localized_path/2` output with path-prefix output for non-default locales.
- [x] Preserve default locale behavior: `SEO.localized_path("/features", "en") == "/features"`.
- [x] Add unit coverage for locale path generation and segment parsing.

Key files:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/seo.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/i18n.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/i18n/locales.ex`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/i18n_test.exs`

## Phase 2: Localized Public Routes

**Goal**: Serve landing pages at clean localized paths without catching app routes like `/connect`.

- [x] Generate explicit localized scopes for enabled non-default locale segments instead of a catch-all `/:locale` route.
- [x] Add localized landing routes:
  - `/pt-BR`
  - `/pt-BR/how-it-works`
  - `/pt-BR/features`
  - `/pt-BR/privacy`
  - `/pt-BR/install`
  - `/pt-BR/community`
  - `/pt-BR/faq`
- [x] Add localized help routes:
  - `/pt-BR/chat/help`
  - `/pt-BR/chat/help/:topic`
- [x] Ensure `PutLocale` can resolve the locale from route params or assigns before session/Accept-Language fallback.
- [x] Confirm `/connect`, `/chat`, `/p2p/:token`, `/game/:token`, `/solo/:token`, `/arcade/:token/:game_id`, and `/showcase` do not get captured by locale routes.

Key files:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/router.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/plugs/put_locale.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/put_locale.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/landing_live/*.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/help_live/index.ex`

## Phase 3: Single Public URL Model & Canonical Behavior

**Goal**: Enforce one public URL shape for each public localized page.

- [x] Remove public SEO dependence on `?locale=`.
- [x] Treat `/features?locale=pt_BR` as non-canonical and not advertised anywhere.
- [x] Treat `/?locale=pt_BR` as non-canonical and not advertised anywhere.
- [x] Treat `/chat/help/cmd-join?locale=pt_BR` as non-canonical and not advertised anywhere.
- [x] Keep `/locale/:locale?return_to=...` only for user-initiated language switching inside the app flow.
- [x] Ensure canonical URLs on localized pages are self-referencing clean paths.
- [x] Ensure public language links, sitemap entries, and head alternates never emit query-locale URLs.

Key tests:

- English public URLs keep unprefixed canonical URLs.
- Localized public URLs return localized content and self-canonical clean URLs.
- Query-locale public URLs are not emitted in head, footer, or sitemap.
- App/session URLs do not redirect unexpectedly.

## Phase 4: Sitemap, hreflang, and Footer Links

**Goal**: Make every localized URL discoverable and reciprocal.

- [x] Update sitemap entries from `?locale=` URLs to clean path URLs.
- [x] Keep `xhtml:link` alternates reciprocal for every locale version.
- [x] Keep `x-default` pointing at the English unprefixed URL.
- [x] Update `<head>` alternate links to clean paths.
- [x] Update landing footer language links to clean paths.
- [x] Verify XML escaping still handles query and path variants correctly.

Key files:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/sitemap_controller.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/layouts/landing_live.html.heex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/layouts/help_live.html.heex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/landing_live/landing_helpers.ex`

## Phase 5: Public Page JavaScript Diet

**Goal**: Stop loading the full LiveView/app bundle on public pages when only small behavior is needed.

- [x] Audit `retrohex_content.js` usage on landing/help pages.
- [x] Identify which interactions require LiveView:
  - mobile navigation toggle
  - README/trash popups on home
  - help topic navigation
- [x] Prefer server-rendered static behavior where possible.
- [x] Create a small public bundle only if necessary, for example `public_pages.js`.
- [x] Use CSS/HTML-first interactions where feasible.
- [x] Keep full `v2_app.js` only for the actual app pages.
- [x] Measure final JS payload for public routes.

Key files:

- `apps/retro_hex_chat_web/assets/js/retrohex_content.js`
- `apps/retro_hex_chat_web/assets/js/v2_app.js`
- `apps/retro_hex_chat_web/assets/package.json`
- `apps/retro_hex_chat_web/mix.exs`
- `config/config.exs`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/layouts/landing_live.html.heex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/layouts/help_live.html.heex`

## Phase 6: Landing Content & Semantics Polish

**Goal**: Improve indexable page structure without adding spammy hidden text.

- [x] Ensure every public page has exactly one page-level `h1`.
- [x] Ensure visible or accessible headings are specific enough to match page intent.
- [x] Add concise intro copy to secondary pages where current content begins too abruptly.
- [x] Keep page titles unique and under practical search-result length.
- [x] Keep descriptions unique and human-readable.
- [x] Add image `width`/`height` where static images are rendered, especially the wordmark.
- [x] Avoid FAQ JSON-LD unless policy changes or the site qualifies for FAQ rich results.

Key files:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/landing_live/*.html.heex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/landing_live/*.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/layouts/landing_live.html.heex`

## Phase 7: Tests & Verification

**Goal**: Keep the SEO implementation regression-resistant.

- [x] Add route tests for localized landing pages.
- [x] Add route tests for localized help pages.
- [x] Add tests that query-locale public URLs are not emitted in public SEO surfaces.
- [x] Add sitemap assertions for clean localized paths.
- [x] Add alternate-link assertions for localized clean paths.
- [x] Add tests confirming app/session routes remain `noindex`.
- [x] Run focused tests:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/controllers/landing_controller_test.exs`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/help_live_test.exs`
  - `rtk mix test --only liveview_feature apps/retro_hex_chat_web/test/retro_hex_chat_web/live/help_system_feature_test.exs`
- [x] Run full validation:
  - `rtk mix test`
  - `rtk mix compile --warnings-as-errors`
  - `rtk git diff --check`

## Risks & Decisions

- Dynamic `/:locale` routes can accidentally catch `/connect` or other app paths. Prefer explicit generated locale scopes for enabled non-default locales.
- Query-param localized URLs are crawlable, but this project intentionally avoids them for public SEO to keep one canonical URL shape.
- Removing LiveView from public pages may require replacing `phx-click` interactions with small JS or CSS-only patterns.
- Help pages may still need LiveView for topic navigation; if public bundle removal is too invasive, keep help separate from landing and optimize landing first.
- Existing session language selection must continue to work for the app experience.

## Progress Log

- 2026-06-02: Plan created after SEO metadata, sitemap, robots, social image, and visible language links baseline was implemented.
- 2026-06-02: Implemented clean path-based public locale URLs, explicit localized landing/help route scopes, query-free sitemap/hreflang/footer links, and focused regression tests.
- 2026-06-02: Split public JavaScript into a static landing bundle, a help-only LiveView bundle, and the existing showcase bundle with syntax highlighting. Measured esbuild output: landing `public_pages.js` 5.5 KB, help `help_live.js` 323.0 KB, showcase `retrohex_content.js` 389.5 KB.
- 2026-06-02: Polished public-page semantics with visible secondary-page intros, one `h1` per landing/help page, concise title/description regression tests, and intrinsic wordmark dimensions.
- 2026-06-02: Expanded final SEO helper coverage for canonical origin handling, clean hreflang alternates, localized URL generation, shared noindex content, social image metadata, and SoftwareApplication JSON-LD.
