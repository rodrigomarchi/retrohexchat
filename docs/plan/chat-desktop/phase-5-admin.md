# Phase 5 — Admin Batch

## Objective

Apply the recipe to the two permission-gated admin mini-apps and finish the start
menu's Admin group.

## Prerequisite

Phase 4 complete.

## Windows to migrate

- [ ] AdminConsole (8 tabs: users, channels, MOTD, broadcast, settings, TURN,
      audit, danger zone). Danger-zone confirmations stay modal (locked decision
      #2), scoped to the console window.
- [ ] BotManagement (+ BotForm sub-dialogs — new/edit stay modal scoped to the
      window).

## Batch-specific watchpoints

- Both are admin-gated: the windows, their taskbar buttons, and the start menu
  Admin group must only render for admins — and the `managed` open events
  (`window_open`) must be authorized server-side, not just hidden client-side
  (a non-admin sending `window_open: admin-console` must be a no-op; add a test).
- These are strong `managed` candidates (heavy, rarely open, no state needed while
  closed) — confirm against the recipe rule.

## Completion criteria

- [ ] Both open as windows for admins from menu bar and start menu Admin group.
- [ ] Non-admins: no taskbar/start-menu traces, and server-side rejection test for
      forged `window_open`.
- [ ] All 18 planned windows are now windows; the modal-only survivors are exactly
      the locked-decision-#2 list.

## Verification

- `make ci` fully green.
- Manual smoke as admin AND as regular user (gating), broadcast tab opens, bot
  form sub-dialog scoping.

## Execution map (researched 2026-07-02 — turnkey)

Both dialogs are ALREADY fully-extracted stateful islands owning their own `show`
flag via `send_update(open:/close:)`. There is NO `show_*` parent assign in
`assign_defaults` to remove (step 5 of the recipe is a no-op here). Migration =
managed-window wrap + opener rewrite + panel extraction + contract updates.

### Managed candidates — confirmed
Both heavy, rarely open, hold no state needed while closed → `managed`. Add both
ids to `ChatLive.Windows` `@managed` (windows.ex L34-36):
`admin-console-dialog`, `bot-management-dialog`. (Keep the existing dialog ids as
the window ids to avoid re-plumbing the island `@id`/testids.)

### AdminConsole
- Panel extract: `components/ui/dialogs/admin_console_dialog.ex` — the `<.tabs>`
  block is L112-326 inside `<.dialog>` (L107-343). Add `admin_console_panel/1`
  (root `<div id={"#{@id}-content"} data-testid="admin-console-panel"
  class="flex h-full min-h-0 flex-col">` wrapping the tabs) and make
  `admin_console_dialog/1` render `<.admin_console_panel {assigns}/>` inside
  `<.dialog>` (showcase keeps the dialog). ~90 attrs — pass through with
  `{assigns}` (names already match). Drop the `phx-window-keydown` Escape div
  (the WM owns Escape for windows).
- Island `components/chat_live/components/admin_console_dialog.ex` render tail
  (L1350) renders `<.admin_console_dialog show={@show} on_close=...>`; switch to
  `<.admin_console_panel ...>` (no show/on_close — the window chrome owns close).
  Keep `@reset`/`@owned_defaults` but `show` becomes irrelevant (window mount ==
  open); safe to leave it set true in `@reset`.
- Window in heex `chat_live.html.heex`: replace the always-mounted
  `<.live_component>` at L774-779 with a `<.desktop_window :if={"admin-console-dialog"
  in @open_windows} id="admin-console-dialog" managed title="Admin Console"
  icon=icon_dialog_admin_console default_x/y width~640 height~560
  body_class="flex min-h-0 flex-col p-2" data-testid="admin-console-window">`
  wrapping the island. Gate the whole window `:if={admin?(@session) and ...}`.
- Opener `admin_console_events.ex` open_admin_console L22: replace
  `send_update(open: true)` with `ChatLive.Windows.open(socket, "admin-console-dialog")`
  (keep the admin gate L42-47 — this IS the server-side authz for forged
  `window_open`). Drop close_admin_console send_update (window close is client
  WM); keep the handler only if a test still fires it.
- Taskbar button + start-menu: add conditional `<.taskbar_button :if={"admin-console-dialog"
  in @open_windows} window="admin-console-dialog">`; the start-menu `app_item
  action="open_admin_console"` (start_menu_app.ex L109) stays server-side (opening
  loads nothing lazily, but the opener is gated server-side — keep app_item, not
  window_item, so a non-admin's forged client open still hits the server gate).

### BotManagement
- Island `components/chat_live/components/bot_management_dialog.ex` (L56-84)
  renders 3 UI dialogs. Panel-extract only the MAIN one:
  `components/ui/dialogs/bot_management_dialog.ex` `bot_management_dialog/1`
  (L32, `<.dialog max-w-2xl>` L34) → add `bot_management_panel/1`. The two
  sub-forms (`new_bot_dialog`/`add_command_dialog`, bot_form_dialog.ex) STAY as
  `<.dialog>` (locked decision #3, window-scoped) — pass `scope={:window}` if they
  must anchor to the window.
- Window in heex L767-772 → `<.desktop_window :if={"bot-management-dialog" in
  @open_windows} managed ... data-testid="bot-management-window">` gated
  `:if={admin?(@session)}`.
- Opener `bot_events.ex` open_bot_dialog L20: `put_bot(show_bot: true, bots:)` →
  load bots + `ChatLive.Windows.open_with(socket, "bot-management-dialog",
  BotManagementDialog, ...)` (bots must ride the mount — use open_with so the
  data reaches a fresh managed island one hop later; see the REVERSED gotcha).
  Keep the admin gate as server-side authz.
- Legacy `ui_actions/bots.ex` handle_ui_action(:open_bot_dialog) L18 sets a STALE
  `show_bot_dialog` assign nothing reads — verify dead and remove it +
  `@bot_actions` route (ui_action_handlers.ex L61/L98) if unused.

### Test-contract migration (the choke point)
- ExUnit `-show-trigger` contract in `bot_management_entry_points_feature_test.exs`
  (L62/64/66/107) and `server_administration_feature_test.exs` (opens via
  `render_click "toolbar_action" open_admin_console` L1054): the migrated window
  loses `#<id>-show-trigger`. Replace with `render_hook(view, "window_open"/
  "window_closed")` + `assert_push_event(view, "window_command", %{action:
  "open", id: ...})` and `data-window-id` visibility (see `lobby_live_test.exs`).
- Component tests `admin_console_dialog_test.exs`/`bot_management_dialog_test.exs`
  drive via `show:`/`show_bot:` and assert bare content — repoint to
  `admin_console_panel`/`bot_management_panel` (no `phx-show-modal`).
- Add: non-admin forged `window_open`/opener event is a server-side no-op
  (assert no `window_command` push, window stays out of `@open_windows`).
- e2e ChatPage.ts is the single choke point: `adminConsoleDialog`
  (`#admin-console-dialog [role=dialog]` L572) and `botManagementDialog` (L569)
  → repoint to `[data-testid="admin-console-window"]` / `bot-management-window`;
  `openAdminConsoleFromMenu` L1153 / `openBotManagementFromToolsMenu` L1255 /
  `closeBotManagementDialog` L1180 → open via start menu/taskbar, close via window
  title-bar X (outside the panel). ~20 admin/bot specs flow through these helpers,
  so fixing the helpers fixes the suite; run each touched spec file:line ONCE.

### Do AdminConsole and BotManagement as SEPARATE commits (batch rule: each has
its own tests to bisect). AdminConsole first (bigger, sets the pattern).
