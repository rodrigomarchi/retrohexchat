# App Bundle Optimization Plan

## Goal

Reduce the initial app JavaScript cost without hiding warnings or weakening the build. The target architecture follows the common Phoenix/esbuild pattern: a small route entry point, dynamic imports at feature boundaries, hashed chunks, and an automated bundle budget so regressions fail early.

## Current Baseline

- Previous cleanup split arcade engines out of `app.js`.
- `app.js` development build dropped from `1.6mb` with an esbuild size warning to `493.9kb`.
- `app.js` production/minified build is `232.0kb`.
- Remaining candidates:
  - JavaScript i18n catalogs are imported eagerly through `js/lib/i18n_catalog.js`.
  - Heavy hooks for P2P/media/file transfer/game WebRTC still sit in the initial hook registry.
  - Bundle size is measured manually; there is no CI budget yet.

## Tasks

- [x] Establish bundle optimization plan and progress log.
- [x] Generate and record a fresh esbuild metafile baseline.
- [x] Lazy-load the active JavaScript i18n catalog while keeping `t()`/`jt()` synchronous for call sites.
- [x] Replace heavyweight hook imports with lightweight LiveView hook facades that load implementations on mount.
- [x] Add an automated bundle budget script for initial assets and chunks.
- [x] Wire the bundle budget into the existing lint/build flow.
- [x] Run full validation: Elixir compile/tests, JS tests, lint, assets build/deploy.
- [x] Commit the completed optimization pass.

## Decisions

- Keep English source strings as the synchronous fallback for i18n. Dynamic locale catalogs can hydrate after boot, but call sites should not become async.
- Keep esbuild as the bundler. The repo already uses Phoenix/esbuild successfully; Vite/Rollup is not justified until the module graph needs features esbuild cannot provide cleanly.
- Prefer feature-boundary chunks over arbitrary micro-chunks. Games, P2P/media and locale catalogs are valid boundaries.
- Do not silence bundle warnings with ignore flags. Either reduce initial payload, document an explicit budget, or fail the check.

## Progress Log

- 2026-06-02: Created this plan after the first code-splitting pass. Starting from clean git state at commit `5b624a8`.
- 2026-06-02: Fresh esbuild metafile baseline: `app.js` is `493.9kb`; shared app chunk is `191.2kb` and is dominated by eager JS i18n catalogs. Top remaining initial modules after Phoenix/LiveView are P2P/file-transfer/media hooks.
- 2026-06-02: Lazy-loaded JS i18n catalogs. `app.js` development build is now `438.0kb`; locale catalogs are emitted as per-locale chunks and only the active locale is awaited before LiveSocket connects.
- 2026-06-02: Added lazy LiveView hook facades for heavy P2P/media/file-transfer/game hooks. `app.js` development build is now `377.9kb`; file transfer and media hooks are emitted as feature chunks.
- 2026-06-02: Added `npm run bundle:budget` and `make lint.bundle`. Current budget report: `app.js` `377.9kb` raw / `85.4kb` gzip, top async engine chunk `74.7kb` raw.
- 2026-06-02: Validation passed: `npm test --prefix apps/retro_hex_chat_web/assets`, `mix assets.build`, `mix assets.deploy`, `mix compile --warnings-as-errors`, `mix test`, `make lint`, and `git diff --check`.
