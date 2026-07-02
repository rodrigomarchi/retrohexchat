# Chat Desktop Migration — Progress & Learnings

## Status

| Phase | Status | Notes |
|-------|--------|-------|
| 1 — Desktop shell | **complete** (2026-07-02) | Full `make ci` 9/9 green; browser smoke done (only <720px stacked check pending — needs devtools responsive mode; untouched generic WM code) |
| 2 — Pilot + recipe | **complete** (2026-07-02) | Recipe final; dialyzer runs with the Phase 3 batch gate |
| 3 — Tools/Settings batch | **complete** (2026-07-02) | All 8 migrated (all managed); full `make ci` 9/9 incl. dialyzer |
| 4 — View/Account batch | not started | |
| 5 — Admin batch | not started | |
| 6 — Unify + cleanup | not started | |

## Per-dialog migration recipe

FINAL (validated by all three pilots: UrlCatcher = always-mounted, Timers =
managed, Highlight = managed + sub-forms). Phases 3–5 apply these steps
mechanically; when a dialog doesn't fit a step, record why here.

1. **Mounting decision.** Always-mounted (`open={false}`, client owns
   open/close) when the island holds view state that must survive closes OR
   receives passthrough data while closed (UrlCatcher: both). `managed` when
   neither holds — closing must be a clean reset (Timers). For managed: add the
   id to `ChatLive.Windows` `@managed`, render the window `:if={"<id>" in
   @open_windows}` with the `managed` attr, and make its taskbar button
   conditional too.
2. **Split the UI layer.** Extract a bare `<feature>_panel/1` (content only,
   root: `id="#{id}-content"` + hooks + stable `data-testid`, class
   `flex h-full min-h-0 flex-col`) from the dialog wrapper. Keep the dialog
   wrapper only if the showcase (or another consumer) still uses it; give the
   panel a `table_class`-style knob where the dialog needs a height cap.
3. **Window in `chat_live.html.heex`** (inside `<.desktop>`, after the chat
   window): `<.desktop_window id="<feature>" open={false} title icon
   default_x/y width/height min_* body_class="flex min-h-0 flex-col p-2"
   data-testid="<feature>-window">` wrapping the island `live_component`
   (island root gets `class="contents"`). Managed variant instead uses
   `:if={"<id>" in @open_windows}` + `managed` (no `open` attr). Add a
   `<.taskbar_button window="<feature>">` (conditional for managed). Stagger
   `default_x/y` a bit per window so restored windows don't stack exactly.
4. **Openers.** Every server entry point (menu bar / toolbar / keyboard
   `dispatch_action` / commands) calls `ChatLive.Windows.open(socket, "<id>")`
   — it mounts the island when managed and pushes `window_command open` either
   way (open/focus, never toggle). Start menu: switch the item to
   `<.window_item window="<id>">` (client-side `data-window-open`; for an
   unmounted managed window the hook round-trips through `"window_open"`).
5. **Delete the server open-state.** Remove the `show_*` assign from
   `assign_defaults`, the `visible` passthrough, the Escape entry in
   `keyboard_events.ex` dismissals (+ its `close_*` helper), and any
   `close_*` event handler nothing references anymore.
6. **Tests.** Component test: panel renders bare (no `phx-show-modal`), events
   still routed. New `<feature>_window_test.exs`: window present +
   `data-window-open="false"` + taskbar button; opener event →
   `assert_push_event(view, "window_command", %{action: "open", id: ...})`;
   start-menu `[data-window-open=...]` present; `show_*` assign gone.
   E2E: keep `data-testid`s stable and menu-open specs pass unchanged —
   verify with a TARGETED run of the affected spec only.
7. **Sub-forms.** Convert bespoke `fixed inset-0` overlays to
   `<.dialog scope={@sub_scope}>` (island passes `:window`; a showcase dialog
   wrapper passes `:viewport`). Close paths route to the island via
   `JS.push(event, target: @target)` in `on_cancel`/`on_close` — no dialog.ex
   changes needed. The dialog primitive's `data-state` makes the WM Escape
   defer while a sub-form is open (Escape ladder: sub-form → window).
8. **Help.** Update the feature topic: it is a window now (drag/resize/
   minimize/taskbar/Escape; Start menu path).

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
- `default_maximized` needs no restore-geometry special case: `registerWindow`
  always seeds `default_x/y/w/h` into state, so restoring from a default-maximized
  window falls back to them naturally. Only the initial `maximized` flag changes;
  `applySavedState` overwrites it unconditionally, which is exactly "storage wins".
- `classes/1` is TwMerge, so `body_class` on `desktop_window` cleanly overrides the
  body defaults (`p-0` beats `p-2`, `overflow-hidden` beats `overflow-auto`) — use
  `body_class="flex flex-col min-h-0 p-0 overflow-hidden"` for windows whose body
  is a flex layout that must fill.
- The chat tab strip has no stable id/testid — select it with `[role="tablist"]`
  in tests.
- An empty `@managed_windows` list in a guard (`when id in @managed_windows`)
  compiles to `when false` → dead-clause warnings. Use a `MapSet` attribute +
  runtime `MapSet.member?/2` until the set is non-empty.
- Start-menu items that fire server actions (`phx-click` + `phx-value-action`)
  need no extra close wiring — the WM hook closes the menu on any in-menu click
  that isn't a `data-window-open` opener.
- Escape ownership is layered client-side: WM menus → modal/`data-escape-guard`
  overlays → topmost unpinned window (opt-in per desktop via
  `escape_closes_windows`); a consumed press is stopPropagation'd so the server
  `dismiss_topmost` ladder never sees it. New Escape-owning overlays must carry
  `data-escape-guard` (hidden state must be `u-hidden` or absence from the DOM).
- Window-scoped modals (`dialog scope={:window}`): the dialog root must NOT be
  `relative` in that scope — its absolute children would anchor to the zero-size
  root instead of the desktop window. Don't assert exact class-string order in
  tests (`classes/1` reorders); match with a regex.
- `hook.command` takes `(action, id)` — only the `handleEvent` callback takes the
  `{action, id}` object. Passing the object to `command` silently no-ops (it
  pushes `window_open` for id `undefined`) — easy test bug.
- PROCESS: fix tests PROACTIVELY, not reactively. Before migrating dialog X,
  one sweep finds every affected test:
  `grep -rn "<id>-show-trigger\|<id>-dialog \[role\|<X>Dialog.getByRole" test/ e2e/`
  plus the page-object helpers (`open<X>FromMenu`, `close<X>`). Fix them WITH
  the code change; run each test layer ONCE. The run-fail-fix loop across three
  layers is where iterations bleed time.
- KNOWN BROKEN SPEC (pre-existing, Phase 6 candidate): chat-address-book-contacts
  U12 expects `----- Whois: -----` TEXT output but `whois_output_mode` defaults
  to `:card` — fails at HEAD, unrelated to the migration.
- KNOWN FLAKE (pre-existing, Phase 6 candidate): channel_moderation_context_menu
  and channel_central feature tests race the second user's /join against channel
  membership ("user not in channel" / "no process") — nondeterministic across
  identical runs. Don't burn a bisect on it again; rerun the file to confirm.
- "Receives updates while closed" only forces always-mounted when the updates
  target the ISLAND (send_update). If they mutate the parent's session
  read-model, a managed island gets fresh state at mount — NotifyList is
  managed despite live buddy-status updates.
- Open-on-tab for a managed window: `Windows.open(socket, id)` FIRST, then
  `send_update(island, open: tab)` — confirms the seed gotcha (island must exist
  in the patch for the directive to land).
- The Playwright suite is NOT in `make ci` — expect to find pre-existing broken
  specs when touching an area (parity spec clicked the View menu for Find, which
  lives in Edit). Fix them in passing; they are ours.
- Managed windows survive a transient offline/online blip: the LV process (and
  `open_windows` + island drafts) outlives a short socket drop, so the
  reconnect-dialog-state E2E contract holds without extra work. A full remount
  (reload/takeover) still resets them — that matches modal behavior.
- E2E page-object locators must target the WINDOW testid (`<id>-window`), not
  the panel testid — the title-bar X lives outside the panel.
- Batch migrations: the per-dialog diff is nearly identical, so migrating 2–3
  same-shape dialogs per commit halves CI wall-clock with no extra risk (each
  dialog has its own tests to bisect failures).
- Browser-smoke gotcha: don't verify WM behavior by mutating inline styles on
  server-rendered elements — the next LiveView patch (e.g. a bot message) wipes
  them and invalidates the test. Use real window/geometry changes.
- Help content: topic metadata lives in `HelpTopics.*` (domain app); the body is
  a `ui_<id>.html.heex` template under `controllers/help_content/` auto-embedded
  by glob — no registration step beyond the metadata entry.
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
