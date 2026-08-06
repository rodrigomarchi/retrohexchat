# Windowed desktop UI (Win98 desktop)

Read when adding or changing a window, dialog, taskbar entry, or Start menu item in the Win98 desktop shell.

Part of the [Agent Guide](../AGENT-GUIDE.md) (§7). Section numbers there are stable — `§7` still means this file.

---

- Each feature lives in a `desktop_window` — client-side chrome owned by a
  `WindowManagerHook` (position/size/z-order/min-max/open persisted to localStorage) wrapping a
  **stateless panel** fed by assigns. The island is only the window **body** — mount the
  `live_component` inside the `desktop_window` slot. `cid` and change-tracking work through the
  function-component slot; you do NOT hoist the wrapper into a LiveView.
- **An island drives its own window** via
  `push_event("window_command", %{action: "open"|"close"|"flash", id})`, which works from
  inside `update/2` (not just `handle_event`) because the hook's `this.handleEvent` is global,
  not element-scoped. A window's `on_close` event becomes a thin host adapter that
  `send_update`s the island (preserves the testid + Playwright contract).
- **Closing a window only hides it** (visibility class); it must NOT unmount the island or its
  hook — critical for features whose hook/data channel must stay alive the whole connection
  (WebRTC/file/game). Islands with a live hook are **always mounted**. Add a test asserting the
  hook (`phx-hook="…"`) is still in the DOM after close.
- Preserve the `h-full` chain: the island root wrapper needs `class="h-full"` (or `"contents"`)
  so the panel's `flex-1`/`h-full` layout survives inside `window_body`.
- **Taskbar badges and any cross-cutting aggregator window stay on the host.** The island
  mirrors a minimal summary up via `send(self(), {:feature_summary, key, summary})`; the host
  stores it. The summary shape is the **union of what every host reader needs** (badge + status
  strip), mirrored via `Map.take/2` — check all host template readers first, not just the badge.
  The `handle_info({:feature_summary, ...})` clause must sit above the catch-all (see [`liveview-islands.md` §6.6](liveview-islands.md)); a
  badge-glyph test is the canary. PubSub subscriptions stay on the host; feature `handle_info`s
  become thin adapters → `send_update`.
- **Don't extract a small, churny cross-cutting aggregator** (a connection/stats window that
  reads a bit of every feature). Keep it in the host and feed it via summaries — moving it just
  relocates the coupling. There is a menu-bar top chrome (Session/Call/Window/Help) + status
  bar built from the shared `menu_bar` primitive + a desktop `:header` slot.

### 7.1 Chat: managed windows (server-owned lifecycle)

The chat's P2P session windows keep their islands **always mounted** (rule above) because their
hooks/data channels must outlive a close. A second kind — **`managed` windows** — coexists.
The chat is one `pinned default_maximized` window (never closable); ~18 former modals are windows;
confirmations/transient prompts stay modal `UI.Dialog`; persistence is ON (`persist_key="chat"`,
unique per LiveView).

- **Managed vs always-mounted — the decision.** `managed` = the host mounts/unmounts the island
  (`ChatLive.Windows` `@managed` set + an `open_windows` MapSet assign; render the window
  `:if={"<id>" in @open_windows}` with the `managed` attr). Choose `managed` ONLY when the island
  holds no state that must survive a close AND receives no `send_update` while closed — closing is
  then a clean reset. Otherwise keep it **always-mounted** (`open={false}`, client owns
  visibility): the island accumulates state while hidden (UrlCatcher) or receives passthrough data
  while closed. "Receives updates while closed" forces always-mounted only when the updates target
  the ISLAND; if they mutate the host read-model, a managed island gets fresh state at mount
  (NotifyList is managed despite live buddy updates).
- **One opener: `Windows.open/2`.** Every server entry point (menu bar / toolbar / keyboard
  `dispatch_action` / commands) calls it — it adds the id to `open_windows` when managed and pushes
  `window_command open` either way (open/focus, never toggle, never duplicate). Start-menu items are
  `window_item` (client `data-window-open`) EXCEPT when opening implies a data load — then keep a
  server `app_item` so the fresh data is fetched (ChannelList).
- **Mount-state rides `mount/3`, never a post-mount `send_update`.** A managed island loads its
  initial data in its own `mount/3` (`assign(:bots, Queries.list_bots())`) so it travels in the
  mount's main diff — always DOM-safe. Delivering initial data via a post-mount `send_update` (even
  deferred) RACES the managed-window mount patch client-side: the component-only diff merges into
  the virtual tree but never mutates the DOM, so the data silently never appears. `Windows.open_with/4`
  (defer one hop) is for a DIRECTIVE to an island that owns the data lifecycle (which tab to select,
  an auth mode) — not for initial data. This class is invisible to ExUnit; **only E2E catches it.**
- **Optimistic stream rows: key by the id the echo will carry.** Seed an optimistic channel row
  with the persisted DB id (`Server.send_message` returns `{:ok, id}`), never a temp id you swap on
  the echo. Phoenix `stream_insert` UPDATES an existing id in place; a fresh id APPENDS at the tail,
  so a temp→real swap reorders/duplicates under rapid sends (paste). Same rule kills the
  pending-reconciliation bookkeeping entirely.
- **Panel extraction for a big dialog.** Add a `windowed` flag to the design-system `*_dialog/1`:
  windowed → a bare `<div id="#{@id}-content" data-testid="…-panel">`; else → the `<.dialog>`
  wrapper (showcase keeps it). Move the shared body into a private no-attr `*_body/1`/`*_tabs/1`
  that both branches render via `{assigns}` spread — no re-declaring ~90 attrs. The island passes
  `windowed`; the window chrome (title bar / close X) replaces the modal header/footer.
- **Admin-gated windows.** The opener event's admin check IS the server-side authorization for a
  forged `window_open` (the generic `window_open` handler adds any managed id to `open_windows`
  without gating). The window's `:if={admin?(@session) and …}` render guard is defense-in-depth —
  no admin content in a non-admin's DOM. Test both.
- **Island → host command dispatch is always delegated.** Never call a host-level function that
  reads host assigns (`CommandDispatch.dispatch_command_*`, which touches `show_status_tab`) on the
  island's component socket — KeyError crash. `send(self(), {:admin_console_command, name, args})`;
  the host runs it on its full socket and reflects the result back via `send_update`.
- **Escape is layered client-side** (WM menus → `data-escape-guard` overlays → topmost unpinned
  window), stopPropagation'd when consumed. The server `dismiss_topmost` ladder therefore only ever
  sees the non-window overlays (modal survivors + search/notice). New Escape-owning overlays carry
  `data-escape-guard`.
- **Test contract shift.** A migrated window has no `#<id>-show-trigger`; assert with the window
  `data-testid`, `has_element?(view, "#<id>-content")`, `render_hook(view, "window_open"/
  "window_closed")`, and `assert_push_event(view, "window_command", %{action: "open", id})`. E2E
  page objects target the window testid + `[data-window-control="close"]` (the X lives outside the
  panel). And: the Playwright config uses `reuseExistingServer` — after an Elixir change, kill the
  stale server on its port (`lsof -ti:<port> | xargs kill -9`) or you validate old code.
- **A popup anchored inside a scroller is `fixed`, never `absolute`.** A scroll container clips on
  *both* axes — `overflow-y: visible` is not honoured when the other axis is `auto` — so an
  `absolute bottom-full` flyout out of the `overflow-x-auto` taskbar is cut off and its clicks land
  on whatever is behind it. Playwright reports this as `subtree intercepts pointer events` on an
  element it also calls "visible, enabled and stable". Follow the taskbar context menus: a `fixed`
  panel positioned by the hook from the trigger's `getBoundingClientRect()`, clamped to the viewport.
- **Every popup root owns its own data attribute.** `data-taskbar-group` is not `data-start-submenu`
  is not the menu bar's submenu attribute. Different roots, different hooks — sharing the attribute
  makes one panel close the other. This has bitten three times.
- **Merge instead of extracting when tabs are one surface with a discriminator.** List each assign
  and assign it to a tab: nothing shared → independent features, extract; shared snapshot but
  divergent content → leave them as separate tabs; same surface with a discriminator → merge. The
  merge signature is mechanical — tabs already share a render function, near-identical
  sub-forms, assigns in parallel triples (`*_selected` ×3), handler families in parallel, derived
  getters differing only by key. Three or more signals and the merge is safe; one or two, stop —
  that's coincidence of shape, not of meaning. Merging is **not** a cheap way to cut tab count: if
  the lists came from different services or had different permission gates, the selector would hide
  a real difference. Unlike extraction, nothing is created before deleting — collapse in place, from
  the innermost sub-form outward, and let the discriminator dictate the whole vocabulary (one
  testid, not N; the dispatch table in the island, the labels in the presentational component).
