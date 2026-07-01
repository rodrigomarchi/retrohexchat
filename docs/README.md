# Documentation Index

Living documentation for retro_hex_chat. Plan/progress files are intentionally
**not** kept here — their durable learnings are crystallized into `AGENT-GUIDE.md`
once implemented, and the plans themselves are removed as noise.

## Guide

- [AGENT-GUIDE.md](AGENT-GUIDE.md) — the durable engineering guide: the 11 governing
  principles plus hard-won rules (state tiers, command/dispatch, LiveComponent island
  decomposition, WebRTC/P2P, JS hook loading standard, i18n/public URLs, testing gotchas).
  Start here.

## Reference

Living catalogs and runbooks kept current with the code:

- [reference/svg-catalog.md](reference/svg-catalog.md) — inventory of every icon
  (`Icons.*` submodules) and diagram. Browse visually at `/showcase/icons` (dev only).
- [reference/i18n-catalogs.md](reference/i18n-catalogs.md) — Gettext catalog conventions,
  the locale roster, and rollout waves (`config/i18n_locales.exs`).
- [reference/server-provision.md](reference/server-provision.md) — production provisioning
  runbook: the Admin Console script that seeds channels, bots, and server settings.

## Conventions

- Add a durable, cross-cutting engineering learning → `AGENT-GUIDE.md`.
- Add a living inventory/runbook → `reference/`, and link it here.
- Finished a plan? Extract any durable learning into `AGENT-GUIDE.md`, then delete the plan —
  implemented plans with no residual learning are just noise.
</content>
