# Chat Desktop Migration — Progress & Learnings

## Status

| Phase | Status | Notes |
|-------|--------|-------|
| 1 — Desktop shell | not started | |
| 2 — Pilot + recipe | not started | |
| 3 — Tools/Settings batch | not started | |
| 4 — View/Account batch | not started | |
| 5 — Admin batch | not started | |
| 6 — Unify + cleanup | not started | |

## Per-dialog migration recipe

(Established in Phase 2. Until then, this section is empty — do not improvise a
recipe in Phase 3+ without it.)

## Learnings

Record durable gotchas here as they are discovered (short, imperative, one bullet
each). At the end of Phase 6 these get crystallized into `docs/AGENT-GUIDE.md` and
this plan directory is deleted.

Seed gotchas imported from AGENT-GUIDE §6/§7 and lobby experience — verify they
hold for the chat and extend:

- Closing a window only hides it; `managed` windows are the exception (unmounted
  server-side). Choose `managed` per dialog ONLY if the component holds no
  long-lived state that must survive while closed and receives no `send_update`
  while closed — otherwise keep it always-mounted with `open={false}`.
- When the host opens a managed window and updates its island in the same event:
  `open_window(socket, id)` BEFORE `send_update` (island must exist in the patch).
- `push_event("window_command", %{action:, id:})` works from island `update/2`,
  not just `handle_event` (hook's handleEvent is global).
- Island root wrapper needs `class="h-full"` (or `"contents"`) to preserve the
  window-body flex chain.
- Island/window DOM ids must not collide with panel-internal ids.
- `persist_key` must be unique per LiveView ("chat"; lobby="lobby", showcase="showcase").
- The `#{id}-show-trigger` marker is the modal-dialog test contract; migrated
  windows lose it — use `data-window-id` visibility, `render_hook(view,
  "window_open"/"window_closed")`, and `assert_push_event(view, "window_command", ...)`
  instead (see `lobby_live_test.exs` for the patterns).

## Decision log

- 2026-07-02 — Design locked with Rodrigo (see PROMPT.md "Locked design decisions"):
  chat = single pinned maximized-by-default window; confirmations stay modal;
  sub-forms modal scoped to parent window; menu bar + start menu coexist; persist
  to localStorage; taskbar = windows + tray clock; header in desktop `:header`
  slot; mobile inherits WM stacked mode untouched.
