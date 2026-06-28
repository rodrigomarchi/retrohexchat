# Chat LiveView Migration Progress

Este arquivo e o quadro central de progresso da migracao. Atualize-o em todo loop de implementacao, junto com o arquivo `.md` do plano individual.

## Status Legend

- `pending`: ainda nao iniciado.
- `in_progress`: iniciado, parcial ou aguardando validacao.
- `blocked`: impedimento concreto, com proximo passo registrado.
- `complete`: tasks relevantes concluidas e validacao registrada.

## Loop Rules

- Antes de editar codigo, marque o plano escolhido como `in_progress`.
- Depois de editar, registre evidencia de validacao.
- Nunca marque `complete` sem atualizar o checklist do plano individual.
- Sempre inclua o proximo passo.
- Use a data real do ambiente no momento da execucao.

## Current Focus

- Current plan: `01-chat-live-orchestrator.md`
- Current status: in_progress
- Last updated: 2026-06-27
- Notes: Boundary foundation landed — `ChatLive.Components` namespace + `ChatContext` struct (identity + admin authorization, single source of truth). Orchestrator admin helpers now delegate. No public contract changes.

## Progress Board

| # | Plan | Status | Last updated | Evidence | Next step |
|---|------|--------|--------------|----------|-----------|
| 00 | `00-loop-execution-prompt.md` | complete | 2026-06-27 | Prompt created and per-plan progress logs initialized. | Use this prompt for each loop. |
| 01 | `01-chat-live-orchestrator.md` | in_progress | 2026-06-27 | Namespace `ChatLive.Components` + `ChatContext` struct created; orchestrator admin helpers delegate. compile -W0 clean; chat_context_test 5/0; server_administration_feature_test 25/0; format+credo clean. | Extract first stateful LiveComponent (search bar / connection status) or proceed to plan 02 event-routing map. |
| 02 | `02-chat-event-routing.md` | in_progress | 2026-06-27 | Event-ownership map (`02-event-ownership-map.md`, code-derived) done; dispatcher now logs unrouted events at :debug (was silent). compile -W0 clean; event_routing_test + 22 chat/messaging/keyboard tests 0 fail; format+credo clean. | Introduce `@global_events` in code + migrate hot events to `phx-target={@myself}` once stateful components exist. |
| 03 | `03-hidden-hooks.md` | pending | 2026-06-27 | Not started. | Inventory JS hooks. |
| 04 | `04-shell-header-status.md` | pending | 2026-06-27 | Not started. | Extract shell/status wrapper. |
| 05 | `05-conversations-sidebar.md` | pending | 2026-06-27 | Not started. | Define ConversationsComponent ownership. |
| 06 | `06-irc-tabs.md` | pending | 2026-06-27 | Not started. | Normalize tab data. |
| 07 | `07-topic-bar.md` | pending | 2026-06-27 | Not started. | Isolate topic bar context. |
| 08 | `08-connection-status.md` | pending | 2026-06-27 | Not started. | Move connection hook/component. |
| 09 | `09-search-bar.md` | pending | 2026-06-27 | Not started. | Move search state. |
| 10 | `10-chat-message-viewport.md` | pending | 2026-06-27 | Not started. | Extract message stream owner. |
| 11 | `11-status-message-viewport.md` | pending | 2026-06-27 | Not started. | Extract status stream owner. |
| 12 | `12-message-row-renderer.md` | pending | 2026-06-27 | Not started. | Move row renderer. |
| 13 | `13-nicklist.md` | pending | 2026-06-27 | Not started. | Stream nicklist users. |
| 14 | `14-composer-input.md` | pending | 2026-06-27 | Not started. | Extract composer ownership. |
| 15 | `15-formatting-reply-typing.md` | pending | 2026-06-27 | Not started. | Move lower composer controls. |
| 16 | `16-autocomplete-syntax.md` | pending | 2026-06-27 | Not started. | Move autocomplete/syntax state. |
| 17 | `17-emoji-picker.md` | pending | 2026-06-27 | Not started. | Mount emoji picker on demand. |
| 18 | `18-hover-card.md` | pending | 2026-06-27 | Not started. | Isolate hover card. |
| 19 | `19-chat-context-menu.md` | pending | 2026-06-27 | Not started. | Move chat context menu. |
| 20 | `20-conversations-context-menu.md` | pending | 2026-06-27 | Not started. | Move conversations menu. |
| 21 | `21-nicklist-context-menu.md` | pending | 2026-06-27 | Not started. | Move nicklist context menu. |
| 22 | `22-mute-duration-dialog.md` | pending | 2026-06-27 | Not started. | Migrate mute dialog. |
| 23 | `23-invite-channel-picker-dialog.md` | pending | 2026-06-27 | Not started. | Migrate invite picker. |
| 24 | `24-knock-request-dialog.md` | pending | 2026-06-27 | Not started. | Migrate knock dialog. |
| 25 | `25-about-dialog.md` | pending | 2026-06-27 | Not started. | Decide JS-only about modal. |
| 26 | `26-account-dialog.md` | pending | 2026-06-27 | Not started. | Extract account dialog. |
| 27 | `27-disconnect-confirm-dialog.md` | pending | 2026-06-27 | Not started. | Simplify disconnect confirm. |
| 28 | `28-delete-confirm-dialog.md` | pending | 2026-06-27 | Not started. | Move delete confirm to viewport. |
| 29 | `29-nick-change-dialog.md` | pending | 2026-06-27 | Not started. | Isolate nick change flow. |
| 30 | `30-notify-list-dialog.md` | pending | 2026-06-27 | Not started. | Extract notify list. |
| 31 | `31-address-book-dialog.md` | pending | 2026-06-27 | Not started. | Extract address book mini-app. |
| 32 | `32-channel-list-dialog.md` | pending | 2026-06-27 | Not started. | Async channel list. |
| 33 | `33-flood-protection-dialog.md` | pending | 2026-06-27 | Not started. | Draft local settings. |
| 34 | `34-sound-settings-dialog.md` | pending | 2026-06-27 | Not started. | Draft sound settings. |
| 35 | `35-perform-dialog.md` | pending | 2026-06-27 | Not started. | Extract perform/autojoin. |
| 36 | `36-alias-dialog.md` | pending | 2026-06-27 | Not started. | Extract alias dialog. |
| 37 | `37-custom-menus-dialog.md` | pending | 2026-06-27 | Not started. | Extract custom menus. |
| 38 | `38-auto-respond-dialog.md` | pending | 2026-06-27 | Not started. | Extract auto respond dialog. |
| 39 | `39-timers-dialog.md` | pending | 2026-06-27 | Not started. | Separate timer config/runtime. |
| 40 | `40-channel-central-dialog.md` | pending | 2026-06-27 | Not started. | Extract Channel Central. |
| 41 | `41-highlight-dialog.md` | pending | 2026-06-27 | Not started. | Extract highlight dialog. |
| 42 | `42-url-catcher-dialog.md` | pending | 2026-06-27 | Not started. | Extract URL catcher. |
| 43 | `43-cheatsheet-dialog.md` | pending | 2026-06-27 | Not started. | Decide JS/static strategy. |
| 44 | `44-user-lookup-dialog.md` | pending | 2026-06-27 | Not started. | Async user lookup. |
| 45 | `45-lookup-result-card.md` | pending | 2026-06-27 | Not started. | Move lookup result under lookup flow. |
| 46 | `46-paste-confirm-dialog.md` | pending | 2026-06-27 | Not started. | Move paste confirm to composer. |
| 47 | `47-invite-dialog.md` | pending | 2026-06-27 | Not started. | Queue invite notifications. |
| 48 | `48-kick-dialog.md` | pending | 2026-06-27 | Not started. | Queue kick notifications. |
| 49 | `49-bot-management-dialog.md` | pending | 2026-06-27 | Not started. | Extract bot management. |
| 50 | `50-new-bot-dialog.md` | pending | 2026-06-27 | Not started. | Make child of bot management. |
| 51 | `51-add-command-dialog.md` | pending | 2026-06-27 | Not started. | Make child of bot management. |
| 52 | `52-admin-console-dialog.md` | pending | 2026-06-27 | Not started. | Extract admin console. |
| 53 | `53-unused-dialogs-audit.md` | pending | 2026-06-27 | Not started. | Audit unused dialogs. |
| 54 | `54-chat-unused-components-audit.md` | pending | 2026-06-27 | Not started. | Audit unused chat components. |
| 55 | `55-toast-notifications.md` | pending | 2026-06-27 | Not started. | Isolate toast host. |
| 56 | `56-loading-and-scroll-indicators.md` | pending | 2026-06-27 | Not started. | Move loading state to owners. |
| 57 | `57-testing-strategy.md` | in_progress | 2026-06-27 | E2E harness confirmed runnable on this host (Chromium + node_modules + e2e DB present; config self-boots server on :4003). Documented focused-spec procedure + baseline pre-existing failure (chat-sound-settings U3, Tip popup hides menu item — fails on clean main). | Use focused Playwright as the real gate per migrated component; fix/track U3 when migrating plan 34. |

## Global Progress Log

### 2026-06-27

- Created migration plan set in `docs/plans/`.
- Added Playwright-aware testing strategy in `57-testing-strategy.md`.
- Added this central progress board.
- Added loop prompt in `00-loop-execution-prompt.md`.
- Added `## Progress Log` to every numbered plan so each loop records local and central progress.
- Plan 01 boundary slice: created `RetroHexChatWeb.ChatLive.Components` namespace anchor and `RetroHexChatWeb.ChatLive.ChatContext` struct (identity + `admin?/admin_only?/root_admin?` as single source of truth). Orchestrator private admin helpers now delegate to `ChatContext`; removed now-unused `ServerRoles` alias. Added `chat_context_test.exs` (unit). Validation: compile `-W0` clean, 5/0 unit + 25/0 admin feature tests, format+credo clean. No public contract/`data-testid`/event changes — Playwright not impacted this slice.
- **Menubar (2026-06-27) — diagnostico corrigido 2x; mudanca REVERTIDA.** (1) A menubar NAO esta quebrada (o "hook nao monta" foi probe bugado). (2) Tentei corrigir O6/O7 adicionando "Find" ao menu View, MAS `make ci` pegou regressao: o teste autoritativo `window_display_edit_menu_feature_test` exige Find **so no Edit** (refuta no View) e passa no main. Os 7 specs `openSearchFromViewMenu` e que estao **stale** (ja falhavam no baseline). **Revertido** menu_bar_app.ex + ChatPage.ts. Resolucao correta = repontar esses specs E2E para o menu Edit (`openSearchFromEditMenu`), cleanup separado do refactor / decisao de produto. **Licao:** E2E por-feature nao pega regressao de LiveViewTest — `make ci` e o gate de completude. U3 (first-click race, plano 04/08) e O12 (nicklist, plano 13/21) seguem abertos. Detalhes em `57-testing-strategy.md`.
- Per-feature E2E audit (2026-06-27): ran 14 feature specs focados (nunca a suite inteira). **Zero regressoes** das foundations 01/02 — todos os specs verdes seguem verdes; todas as falhas (chat-context-menus O12, chat-sound-settings U3, chat-search O6/O7, chat-perform-dialog U6) reproduzem identicas em `main` limpo (provado via stash baseline). chat-send é flaky (timing). Matriz completa + IDs das falhas em `57-testing-strategy.md`. Foundations auditadas: code-vs-claim OK (namespace, ChatContext struct+delegacao, ownership map, unrouted-event log todos presentes e corretos).
- E2E gate confirmed: Playwright runs on this host. Validated harness by running `chat-sound-settings.spec.ts` (1 pass / 1 fail). Isolated the failure (U3) as **pre-existing on clean `main`** via stash baseline — not caused by the migration. Recorded run procedure + baseline failure in `57-testing-strategy.md`. Going forward, focused specs are the real gate before any plan is marked `complete`.
- Plan 02 mapping slice: added code-derived `02-event-ownership-map.md` (every event → final owner, global/adapter classification, regen command). Made the dispatcher fall-through observable — unrouted events now `Logger.debug` instead of being silently swallowed; socket returned untouched (never crashes the session). Added `event_routing_test.exs`. Validation: compile `-W0` clean, 22/0 across chat_live/messaging/keyboard suites, format+credo clean. No public contract changes — v1 adapters preserved, Playwright not impacted.
