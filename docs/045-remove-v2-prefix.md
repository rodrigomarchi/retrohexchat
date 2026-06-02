# Remove V2 Prefix

## Objective

Remove the old `v2` naming layer now that the migrated app is the only supported app surface.

The cleanup should not keep compatibility aliases, duplicate module names, or duplicate asset entrypoints. There should be one canonical name for each concern.

## Target Names

- `v2_app.js` -> `app.js`
- `retro_hex_chat_web_v2_app_js` -> `retro_hex_chat_web_app_js`
- `chunks/v2-[name]-[hash]` -> `chunks/app-[name]-[hash]`
- `RetroHexChatWeb.V2.*` -> `RetroHexChatWeb.App.*`
- `live/v2/` -> `live/app/`
- `controllers/v2/` -> `controllers/app/`
- `layouts/v2.html.heex` -> `layouts/chat.html.heex`
- router pipeline `:v2_app` -> `:app`
- router live session `:v2_locale` -> `:app_locale`
- `V2Helpers` -> `ChatHelpers`

## Progress

- [x] Rename asset entrypoint, esbuild config, chunk names, and bundle budget.
- [x] Rename app layout and router pipeline/session names.
- [x] Move LiveView and controller modules from `V2` to `App`.
- [x] Rename `V2Helpers` to `ChatHelpers`.
- [x] Update Tailwind scanning, CSS consistency linting, and gettext domainization scripts.
- [x] Update tests, e2e references, analytics fixtures, docs, and comments.
- [x] Run full validation and fix every warning, lint issue, and test failure.

## Validation

- [x] `mix format`
- [x] `mix compile --warnings-as-errors`
- [x] `mix test`
- [x] `npm test`
- [x] `mix assets.build`
- [x] `mix assets.deploy`
- [x] `npm run bundle:budget`
- [x] `make lint`
- [x] `make i18n.gettext.extract`
- [x] `make i18n.gettext.check`
- [x] `git diff --check`
