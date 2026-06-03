# LiveView JavaScript Hook Loading Standard

## Status

In progress. Phase 1 inventory is complete; Phase 2 central registry is next.

## Goal

Establish one project-wide standard for JavaScript hook registration and lazy loading in the Phoenix LiveView app. The standard must remove local choice from `app.js`, prevent arbitrary lazy loading decisions, and make server/client timing boundaries explicit and testable.

This document is the tracking file for the work. Update the Progress Log as each phase is completed.

## Problem

Phoenix LiveView expects hooks to be registered in the `LiveSocket` hooks namespace and attached through `phx-hook`. Server-to-client events sent with `push_event` are received by active hook instances through `handleEvent`.

Dynamic `import()` is asynchronous. A lazy hook facade can mount before the real implementation is loaded, which means a server event can arrive before the real hook has registered its handlers. This creates timing races such as:

- page renders but navigation or controls are not wired yet;
- server pushes an initial event before the lazy hook is ready;
- a hook receives duplicate start events after a retry;
- AI agents or developers choose eager vs lazy per file without a project rule.

## Non-Goals

- Do not convert all JavaScript to lazy loading.
- Do not introduce a new bundler unless esbuild cannot support a required constraint.
- Do not replace simple `Phoenix.LiveView.JS` interactions with hooks.
- Do not rely on documentation-only rules when a CI guard can enforce the rule.

## Community-Aligned Baseline

The Phoenix-aligned approach is:

- register hooks through the `LiveSocket` hook namespace;
- use `Phoenix.LiveView.JS` for declarative client UI behavior where possible;
- use hooks only for custom JavaScript wiring;
- use asset/code splitting at feature boundaries, not arbitrary files;
- treat lazy loading as an asynchronous feature boundary with an explicit readiness protocol.

References:

- Phoenix LiveView JS interoperability: https://hexdocs.pm/phoenix_live_view/js-interop.html
- Phoenix LiveView JS commands: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.JS.html
- Phoenix asset management: https://hexdocs.pm/phoenix/asset_management.html
- JavaScript dynamic import: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/import

## Target Architecture

There must be exactly one hook registration path:

```txt
assets/js/app.js
  -> imports buildHooks()
  -> hooks/registry.js
  -> critical_hooks.js + lazy_feature_hooks.js
  -> LiveSocket(..., { hooks: buildHooks() })
```

`app.js` must not import individual hook implementations.

### Critical Hooks

Critical hooks are imported eagerly. These are needed for the initial chat shell and basic app operation.

Initial critical category:

- input and keyboard handling;
- chat input character count;
- autocomplete;
- message scrolling;
- menu bar and toolbar behavior;
- conversations/sidebar navigation;
- connection status and lag display;
- title/sound/notification shell behavior that is cheap and always available;
- context menu base behavior used by the chat shell.

Rule: a critical hook must not be lazy.

### Lazy Feature Hooks

Lazy feature hooks are allowed only for heavy or rare feature boundaries.

Initial allowed category:

- P2P WebRTC;
- media/audio/video controls;
- file transfer;
- P2P diagrams;
- game WebRTC;
- game canvas;
- game engines;
- other heavy feature modules only after bundle budget evidence.

Rule: a lazy feature hook must be declared in one central allowlist with metadata.

## Required File Structure

Create or refactor toward:

```txt
apps/retro_hex_chat_web/assets/js/hooks/
  registry.js
  critical_hooks.js
  lazy_feature_hooks.js
  lazy_feature_hook.js
```

### `registry.js`

Responsibilities:

- export `buildHooks()`;
- merge critical hooks and lazy feature hooks;
- be the only module imported by `app.js` for hook registration.

### `critical_hooks.js`

Responsibilities:

- import eager hook implementations;
- export a plain object of hook names to implementations.

No dynamic import is allowed in this file.

### `lazy_feature_hooks.js`

Responsibilities:

- define the full allowlist of lazy hooks;
- provide required metadata for each lazy hook;
- be the only place where lazy feature hooks are declared.

Example:

```js
export const lazyFeatureHooks = {
  GameWebRTCHook: lazyFeatureHook({
    name: "GameWebRTCHook",
    loader: () => import("./games/game_webrtc_hook"),
    serverEvents: ["game_start_offer", "game_start_answer", "game_signal"],
    readyEvent: "game_webrtc_ready",
    reason: "Heavy game WebRTC feature, not needed for the initial chat shell",
  }),
};
```

### `lazy_feature_hook.js`

Responsibilities:

- provide the single lazy hook facade API;
- load the implementation on `mounted`;
- delegate LiveView lifecycle callbacks;
- attach implementation helper methods to the LiveView hook instance before calling implementation `mounted`;
- avoid calling late-loaded implementations after `destroyed`;
- optionally expose debug metadata in development.

Required API:

```js
lazyFeatureHook({
  name,
  loader,
  serverEvents = [],
  readyEvent = null,
  reason,
})
```

Validation rules:

- `name` is required.
- `loader` is required.
- `reason` is required.
- `serverEvents.length > 0` requires either `readyEvent` or an explicit `safeWithoutReady: true` with rationale.
- `safeWithoutReady` should be rare and must be rejected for initial-start server events.

## Server/Client Readiness Protocol

Any lazy hook that receives server-pushed startup events must use this protocol:

```txt
1. LiveView renders DOM with phx-hook.
2. Lazy facade mounts.
3. Real hook implementation loads.
4. Real hook registers all handleEvent callbacks.
5. Client pushes a ready event.
6. Server sends or resends startup state.
7. Client handlers are idempotent.
```

Required server-side behavior:

- `handle_event("*_ready", ...)` sends current startup state if the feature is already active.
- Startup pushes must be safe to resend.
- Duplicate start events must not create duplicate peer connections, media sessions, file sessions, game engines, or timers.

Required client-side behavior:

- register `handleEvent` before `pushEvent("*_ready")`;
- guard duplicate starts;
- queue out-of-order async signals when the protocol requires it;
- clean up timers/listeners on `destroyed`.

## Guardrails

### Guard 1: Hook Registry Contract

Add `apps/retro_hex_chat_web/assets/scripts/enforce_hooks_contract.cjs`.

The script must fail if:

- `lazyHook(` or `lazyFeatureHook(` appears outside the allowed registry/facade files;
- `import(` appears outside approved dynamic import locations;
- `app.js` imports hook implementations directly;
- a `phx-hook="Name"` in HEEx has no matching registry entry;
- a critical hook appears in `lazyFeatureHooks`;
- a lazy hook with `serverEvents` lacks `readyEvent` or explicit approved exception;
- a new hook file exists but is not classified as critical or lazy feature;
- colocated hooks are introduced without an explicit approved exception.

### Guard 2: Bundle Budget

Keep and strengthen the existing bundle budget.

The bundle check must fail if:

- initial `app.js` exceeds the approved budget;
- a known lazy feature module is pulled back into the initial chunk;
- the largest async chunk exceeds the approved budget without an explicit budget update;
- bundle output changes without updating the optimization progress log.

### Guard 3: E2E Coverage

The following e2e tests are required after changes to hook loading:

- public landing page loads and navigates;
- chat shell input/tabs/menu/navigation work;
- Status tab remains selectable during reconnect/rejoin;
- P2P invite/session/file/call flows work;
- game WebRTC startup and state sync work;
- reload/reconnect flows preserve expected shell state.

### Guard 4: Unit Coverage

Add or update JavaScript tests for `lazyFeatureHook`:

- delegates `mounted`, `updated`, `destroyed`, `disconnected`, `reconnected`;
- attaches implementation helper methods before implementation `mounted`;
- does not call implementation `mounted` if destroyed before import resolves;
- validates required metadata;
- rejects server events without a readiness protocol unless explicitly approved.

### Guard 5: Code Review Checklist

Any hook loading change must answer:

- Is this hook critical to first render or chat shell operation?
- Does this hook receive server-pushed events?
- Can the server event arrive before the hook implementation loads?
- Is there a ready event or safe buffer?
- Are duplicate server pushes idempotent?
- Is the hook in the correct registry category?
- Did bundle budget and e2e pass?

## Migration Plan

### Phase 1: Inventory

- List every `phx-hook` in HEEx and components.
- List every hook registered in `app.js`.
- List every dynamic `import()` in `assets/js`.
- Classify each hook as `critical` or `lazyFeature`.
- Identify server events sent to lazy hooks.

Completion criteria:

- [x] Inventory table added to this document.
- [x] Every current main-app hook has exactly one classification.
- [x] Entrypoint-scoped hook exceptions are recorded.
- [x] Dynamic import categories are recorded.

### Phase 2: Central Registry

- Create `registry.js`.
- Create `critical_hooks.js`.
- Create `lazy_feature_hooks.js`.
- Move current hook registration out of `app.js`.
- Make `app.js` import only `buildHooks`.

Completion criteria:

- App boots.
- `app.js` no longer imports hook implementations directly.
- E2E chat shell smoke tests pass.

### Phase 3: Lazy Facade API

- Replace the generic lazy hook facade with `lazyFeatureHook`.
- Add metadata validation.
- Port current lazy hooks to the new allowlist.
- Keep helper-method attachment and lifecycle delegation.

Completion criteria:

- Current lazy features still work.
- Unit tests cover facade behavior.
- No direct lazy wrapper use outside the allowlist.

### Phase 4: Readiness Protocol Audit

- Audit each lazy hook with `serverEvents`.
- Add or verify `*_ready` events.
- Make server startup pushes idempotent.
- Queue out-of-order async signals where needed.

Completion criteria:

- Each lazy hook with server events has a readiness entry in the inventory.
- P2P and game e2e pass under normal timing.
- No startup flow relies on import timing.

### Phase 5: CI Enforcement

- Add `enforce_hooks_contract.cjs`.
- Add `npm run lint:hooks`.
- Wire `lint.hooks` into `make lint`.
- Add failure messages that point to this document.

Completion criteria:

- CI fails on unauthorized lazy hook usage.
- CI fails on unclassified new hooks.
- CI fails on direct hook imports from `app.js`.

### Phase 6: Bundle Budget Verification

- Confirm current app and chunk budgets.
- Ensure lazy feature chunks remain async chunks.
- Update budget report in this document.

Completion criteria:

- `npm run bundle:budget --prefix apps/retro_hex_chat_web/assets` passes.
- Budget report recorded in Progress Log.

### Phase 7: Full Validation

Run:

```sh
rtk env MIX_ENV=e2e mix compile
rtk npm test --prefix apps/retro_hex_chat_web/assets
rtk npm run lint --prefix apps/retro_hex_chat_web/assets
rtk npm run bundle:budget --prefix apps/retro_hex_chat_web/assets
rtk npx playwright test --project=chromium --reporter=line
```

Completion criteria:

- All commands pass.
- Full e2e passes with zero failures.
- Progress Log updated with results and durations.

## Hook Inventory

Phase 1 inventory completed on 2026-06-03.

### Main App Hook Registry

These hooks are currently registered in `assets/js/app.js`.

| Hook | Current Source | Classification | Server Events | Ready Event | Notes |
| --- | --- | --- | --- | --- | --- |
| AutoFocusHook | inline in `app.js` | critical | none found | none | Small utility hook. |
| CharCounterHook | `hooks/ui/char_counter_hook` | critical | none found | none | Chat input shell behavior. |
| ClockHook | `hooks/connection/clock_hook` | critical | none found | none | Status bar shell behavior. |
| ConnectFormHook | `hooks/connection/connect_form_hook` | critical | `submit_connect` | none | Connect-route shell hook; not lazy. |
| ConnectionStatusHook | `hooks/connection/connection_status_hook` | critical | none found | none | Chat shell connectivity UI. |
| ContextMenuHook | `hooks/ui/context_menu_hook` | critical | none found | none | Base UI behavior. |
| ContextualTipsHook | `hooks/ui/contextual_tips_hook` | critical | `tip_trigger` | none | Small chat shell helper. |
| AutocompleteHook | `hooks/chat/autocomplete_hook` | critical | `autocomplete_closed`, `set_input`, `tab_matches` | none | Critical input behavior. |
| EmojiPickerHook | `hooks/chat/emoji_picker_hook` | critical | `insert_emoji` | none | Chat input behavior. |
| FileTransferHook | `lazyHook(() => import("./hooks/p2p/file_transfer_hook"))` | lazyFeature | `ft_channel_ready`, `ft_config`, `ft_accept`, `ft_reject`, `ft_cancel`, `ft_retry` | none | Existing lazy feature. Must keep dataset fallback or add ready protocol for server config. |
| FocusChatInputOnClickHook | inline in `app.js` | critical | none found | none | Small shell utility. |
| ArcadeIframe | `hooks/games/arcade_iframe_hook` | critical | `arcade_close_tab`, `open_game_window` | none | Route-specific but currently eager and small. |
| ArcadeSession | `hooks/games/arcade_iframe_hook` | critical | `arcade_close_tab` | none | Route-specific but currently eager and small. |
| ArcadeGame | `hooks/games/arcade_game_hook` | critical | `arcade_close_tab` | none | Route-specific but currently eager and small. |
| ArcadeTimer | `hooks/games/arcade_timer_hook` | critical | none found | none | Route-specific but currently eager and small. |
| GameCanvasHook | `lazyHook(() => import("./hooks/games/game_canvas_hook"))` | lazyFeature | `game_start`, `game_end` | none | Existing lazy feature. Reads initial state from dataset to tolerate missed `game_start`. |
| GameSessionHook | `hooks/games/game_session_hook` | critical | `game_close_tab` | none | Game session shell/navigation hook. |
| GameWebRTCHook | `lazyHook(() => import("./hooks/games/game_webrtc_hook"))` | lazyFeature | `game_start_offer`, `game_start_answer`, `game_signal` | `game_webrtc_ready` | Existing lazy feature with ready protocol. |
| FormatToolbarHook | `hooks/chat/format_toolbar_hook` | critical | none found | none | Chat input shell behavior. |
| KeyboardHook | `hooks/input/keyboard_hook` | critical | `focus_input`, `clear_input`, `set_input`, `update_bindings` | none | Critical input behavior. |
| LagHook | `hooks/connection/lag_hook` | critical | `pong` | none | Status bar shell behavior. |
| MediaHook | `lazyHook(() => import("./hooks/p2p/media_hook"))` | lazyFeature | `media_start_audio`, `media_start_video`, `media_end_call`, `media_peer_muted`, `media_peer_camera`, `media_upgrade_accepted`, `media_upgrade_rejected`, `media_set_preset` | none | Existing lazy feature. Needs explicit readiness assessment before stricter guard. |
| MessageInteractionsHook | `hooks/chat/message_interactions_hook` | critical | `enter_edit_mode`, `exit_edit_mode` | none | Chat message interaction behavior. |
| NickChangeFormHook | `hooks/chat/nick_change_form_hook` | critical | `submit_nick_change` | none | Nick change dialog behavior. |
| P2PCapabilityHook | `hooks/p2p/p2p_capability_hook` | critical | `p2p_request_permission` | none | P2P route setup; currently eager and small. |
| P2PChatFormHook | `hooks/p2p/p2p_chat_form_hook` | critical | `p2p_lobby_message_sent` | none | Small form reset hook. |
| P2PDiagramHook | `lazyHook(() => import("./hooks/p2p/p2p_diagram_hook"))` | lazyFeature | none found | none | Existing lazy visual-only feature. |
| P2PSessionHook | `hooks/p2p/p2p_session_hook` | critical | `p2p_close_tab` | none | P2P session shell/navigation hook. |
| NotifyListHook | `hooks/notifications/notify_list_hook` | critical | none found | none | Dialog/helper hook, currently eager and small. |
| PasteHook | `hooks/chat/paste_hook` | critical | none found | none | Critical input behavior. |
| ScrollHook | `hooks/chat/scroll_hook` | critical | `scroll_to_bottom`, `clear_chat_messages`, `scroll_to_message`, `enter_edit_mode`, `exit_edit_mode`, `link_preview`, `dismiss_hover_card`, `clipboard_copy`, `clipboard_copy_selection`, `open_url`, `message_confirmed`, `message_failed`, `prepend_start` | none | Critical chat shell behavior. |
| SearchHighlightHook | `hooks/chat/search_highlight_hook` | critical | `search_clear_highlights`, `search_highlight`, `search_scroll_to` | none | Chat search behavior. |
| ShortcutDispatcherHook | `hooks/input/shortcut_dispatcher_hook` | critical | none found | none | Critical keyboard behavior. |
| SoundHook | `hooks/input/sound_hook` | critical | `play_sound`, `toggle_mute` | none | Notification shell behavior. |
| TitleFlashHook | `hooks/notifications/title_flash_hook` | critical | `title_flash_start`, `title_flash_stop` | none | Notification shell behavior. |
| MenuBarHook | `hooks/ui/menu_bar_hook` | critical | none found | none | Navigation shell behavior. |
| ToolbarGroupHook | `hooks/ui/toolbar_group_hook` | critical | none found | none | Shell UI behavior. |
| ConversationsHook | `hooks/ui/conversations_hook` | critical | `channel_joined_flash` | none | Critical navigation/sidebar behavior. |
| NicklistHook | `hooks/ui/nicklist_hook` | critical | none found | none | Chat shell behavior. |
| URLCatcherHook | `hooks/ui/url_catcher_hook` | critical | none found | none | Dialog/helper hook, currently eager and small. |
| ViewportDetectHook | `hooks/ui/viewport_detect_hook` | critical | none found | none | Shell responsive behavior. |

### Other LiveSocket Entrypoints

These hooks are not part of the main chat `app.js` hook registry and must be handled as entrypoint-scoped exceptions by the future contract script.

| Entrypoint | Hook | Source | Notes |
| --- | --- | --- | --- |
| `assets/js/help_live.js` | `MenuBarHook` | help LiveSocket hooks namespace | Help route has a minimal LiveSocket separate from `app.js`. |
| `assets/js/retrohex_content.js` | `Highlight` | showcase LiveSocket hooks namespace | Showcase syntax/content highlighting hook, separate from `app.js`. |

### Dynamic Import Inventory

Allowed existing dynamic import categories:

| Category | Location | Current Status | Future Guard |
| --- | --- | --- | --- |
| Lazy feature hooks | `assets/js/app.js` lines declaring `lazyHook(() => import(...))` | Allowed temporarily | Must move to `lazy_feature_hooks.js`; direct use in `app.js` must become forbidden. |
| JavaScript i18n catalogs | `assets/js/lib/i18n.js` | Allowed | Guard as approved locale-catalog boundary. |
| Game engines | `assets/js/hooks/games/game_canvas_hook.js` | Allowed | Guard as approved game-engine boundary. |

Unauthorized future dynamic imports must fail the hooks contract script unless the import is added to an explicit allowlist with rationale.

## Definition Of Done

- There is one hook registration path.
- There is one lazy hook facade API.
- Every hook is classified as critical or lazyFeature.
- Lazy hooks exist only in the allowlist.
- Critical hooks cannot be lazy.
- `app.js` imports no hook implementation directly.
- Every lazy hook with server events has a readiness protocol or approved explicit exception.
- CI enforces the registry contract.
- Bundle budget enforces feature chunks.
- Full e2e passes.
- This document contains final inventory, validation results, and progress log.

## Progress Log

- 2026-06-03: Created tracking plan after lazy loading regressions were fixed and full e2e passed with `PASS (331) FAIL (0)`. Next step is Phase 1 inventory.
- 2026-06-03: Committed all pending lazy-loading/e2e/landing fixes in `fcda6c8` before starting the standardization work.
- 2026-06-03: Completed Phase 1 inventory. Recorded all main `app.js` hooks, current lazy feature hooks, server event exposure, separate LiveSocket entrypoint exceptions, and dynamic import categories. Next step is Phase 2 central registry.
