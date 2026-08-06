# LiveComponent island decomposition

Read when extracting, editing, or debugging a LiveComponent island: ownership, event routing, `send_update` timing, streams, bubbling, modals, async work.

Part of the [Agent Guide](../AGENT-GUIDE.md) (§6). Section numbers there are stable — `§6` still means this file.

---

The single most important architectural pattern: extract stateful UI islands out of a large
orchestrator LiveView (`ChatLive`) into `Phoenix.LiveComponent`s. The parent
becomes a thin orchestrator; each island owns its own state, events, and streams.

### 6.1 Ownership — what migrates, what stays

- **The island owns content/draft state:** query text, inputs, selections, local errors,
  indices, results, local pagination, sub-form flags, view/filter/sort state.
- **The parent owns coordination state** — specifically any assign read *synchronously* by a
  *different* subsystem:
  - `*_visible` / `show_*` flags read by the Escape-dismissal stack in `keyboard_events.ex`
    (`topmost_dismissals`/`secondary_dismissals`). Moving these into an island breaks Escape
    ordering — pass them in as `visible` (passthrough) and let the island own only the draft.
  - Any list/map read mid-flow by tab-complete, pagination, context-menu predicates, the
    connect flow, or a sibling handler.
- **The canonical read-model test:** a key stays on the parent *only* when a synchronous
  reader in a **different** subsystem touches it. A handler that is a sibling of the same
  dialog re-reading its own state is NOT a read-model — convert those events to `@myself`
  and the state migrates with them. Detect sync readers by grepping **both**
  `socket.assigns.key` **and** `Map.get(socket.assigns, :key`.
- **Move only the render-model in practice.** Even on the message hot-path, the parent kept
  all pagination/scroll/reconciliation and the island owned only `stream(:chat_messages)` +
  the row renderer. The isolation win comes from removing the `:for` from the parent
  template, not from relocating intricate read logic.
- **Total extraction is possible** when *every* reader is the template plus event/PubSub
  handlers (no sync cross-subsystem reader): rewrite the PubSub handlers to *drive* the
  island (`send_update {:dismiss_if_nick, nick}`) instead of reading it, moving the
  match/merge logic verbatim into the island. The assign leaves the parent entirely.

### 6.2 Event routing — ADAPTER is the default

- **Default = adapter.** Keep legacy event names firing on the parent; the `*_events.ex`
  module becomes a thin adapter that forwards to the island:
  ```elixir
  send_update(MyComponent, id: MyComponent.id(), action: {:input, value})
  ```
  This preserves every LiveViewTest contract (tests fire on the `view`, not the element),
  `data-testid`s, JS hooks that `pushEvent` to the root LV, external triggers
  (menubar/toolbar/keyboard), and Playwright Page Objects — **zero selector churn**. Expose
  reusable `open/1`, `close/1` helpers on the adapter and have external triggers delegate to
  them.
- **A JS hook's `pushEvent` always targets the ROOT LiveView, never the nested
  LiveComponent** (without `pushEventTo`). So hook *inbound* events stay as parent adapters →
  `send_update`. Only server→client `push_event` leaves the island — `this.handleEvent(...)`
  is global per LiveSocket and catches a push from *any* component (this is how an island can
  drive a hook another island renders). Collapse a large family of inbound hook events into
  one generic host adapter by name-prefix, then dispatch inside the island:
  ```elixir
  def handle_event("ft_" <> _ = name, params, socket) do
    send_update(FileIsland, id: FileIsland.id(), action: {:ft_event, name, params})
    {:noreply, socket}
  end
  ```
- **Use `phx-target={@myself}` only** for DOM events on elements the component itself renders
  (its own form's `phx-change`/`phx-submit`/`phx-click`), when no external hook/trigger
  depends on them. Thread a `target` attr through the design-system component. Component-local
  events are also *synchronous* under LiveViewTest (no flush needed) — good for UI-only events
  (cancel, keyup, tab switch).

### 6.3 Async gotchas — `send_update` and form submits

- **`send_update/2` is ASYNC under LiveViewTest.** A `send_update` inside `handle_event` is
  not applied before `render_click`/`render_change`/`render_submit` returns. Read the result
  with a *separate* `render(view)` (mailbox is FIFO):
  ```elixir
  render_click(view, "search_next")
  assert render(view) =~ "2/3"      # NOT: assert render_click(...) =~ "2/3"
  ```
- **This also swallows `assert_push_event`.** Once a list/stream leaves the parent template,
  the parent's post-handler diff is empty (the change went to a child via `send_update`), and
  LiveViewTest only delivers buffered `push_event`s when a diff is actually sent. The push
  (sound, title-flash) is generated but never reaches the test mailbox. Any assertion — DOM,
  text, or `assert_push_event` — right after an event that now routes through a child island
  needs a `render(view)` flush. Fix centrally in shared test helpers (`send_new_message`,
  `send_user_joined`); an extra render is a no-op for passing tests. E2E/Playwright is NOT
  affected — the real client applies child diffs normally.
- **`render_submit` does NOT dispatch a `phx-submit={JS.push("evt", value: %{...})}`** to the
  parent under LiveViewTest — it silently reaches nothing (only the real browser/E2E
  dispatches the `JS.push` value; firing by *name* also works). Robust fix: carry the
  discriminator via a hidden input rendered only when present, plus `phx-value-*` on action
  buttons, and make the mutating event a plain **string** event that bubbles:
  ```elixir
  <input type="hidden" name="selected" :if={@selected} value={@selected}>
  ```
  Render the hidden input only when the value exists so "add" falls back to `params["name"]`
  and never sends an empty-string id (empty string is truthy in Elixir).
- **The `select_item` design-system control forces a string event** — its `on_select` does
  `JS.push(@on_select, value:)`, and `JS.push/2` rejects a `%JS{}` first arg. Anything routed
  through `select_item` must be a string (adapter), not `@myself`. `phx-click={@on_x}` accepts
  `%JS{}` fine. String + `phx-target` beats `JS.push(target:)` when tests select by
  `[phx-click='evt']` (`JS.push` renders that attr as an opaque JSON blob).

### 6.4 Mounting & lifecycle

- **Always mount `<.live_component>` in the template, never inside `:if`.** Gate visibility
  *inside* the component (CSS `hidden`, not `:if`) so `send_update` always finds it and
  streams/hooks are never destroyed on toggle.
- **The `render/1` root must be a single static HTML tag.** Rendering a reused function
  component directly at the root raises `ArgumentError: Stateful components must have a single
  static HTML tag at the root`. Always wrap: `<div id={"#{@id}-mount"}><.some_dialog .../></div>`.
- **Assign `:id` in `mount/1`** (constant id for singletons); the mount `id=` must equal
  `Component.id()` or `send_update` won't find it. If an `update(%{action: a}, socket)` clause
  doesn't re-merge received assigns, `:id` vanishes and action-only `send_update`s crash with
  `KeyError key :id`. Re-apply parent context with defaults:
  ```elixir
  defp assign_context(socket, assigns) do
    assign(socket,
      visible: Map.get(assigns, :visible, socket.assigns.visible),
      active_channel: Map.get(assigns, :active_channel, socket.assigns.active_channel))
  end
  ```
  Clean protocol: `update(%{action: a} = assigns, socket)` applies context + dispatches;
  `update(assigns, socket)` only applies context.
- **The island's root `id` must not collide with any `id=` a nested function component
  renders** (e.g. a `phx-hook` element). A media panel already using `id="lobby-media"` forced
  the island id to `lobby-media-island`. Symptom: "Duplicate id found while testing LiveView"
  at runtime.

### 6.5 Streams (large / hot lists)

- The parent may keep the **materialized list** (read-model for logic) while the island owns
  the **render `stream`**; the parent pushes deltas. This is read-model + render-model, not
  duplication.
- **The dominant win is change-tracking isolation, not the delta itself** — moving the `:for`
  into a component means it re-renders only when one of *its* assigns changes, not on every
  parent re-render. This comes free with the extraction even if every delta is
  `{:reset, list}`.
- Delta protocol (helpers taking/returning socket, calling `send_update`): `{:reset, items}`
  (mass/context change), `{:upsert, item}` (`stream_insert`), `{:remove, key}`
  (`stream_delete_by_dom_id`). Per-row for frequent events; `:reset` for rare/bulk. Pass a
  stable `dom_id: &row_dom_id/1` at mount **and** on every `:reset`.
- **A stream does NOT re-style existing rows on an ordinary re-render.** If a per-item style
  assign changes (e.g. a color-palette edit), re-`stream` (`{:reset, items}`).
- **Stream isn't always right.** For a *small* list whose per-row style churns (unread badges,
  flash), a stream forces a re-push per style change — instead pass raw maps as assigns, derive
  lists/classes *inside* `render/1`, render with a normal `:for`. Isolation still comes free —
  but only if you pass **stable references**: an inline `for` comprehension in the parent
  template makes a new list every render. Move the comprehension into the component.
- **A DOM `limit` caps the end the reader can come back to, never the end they cannot.**
  LiveView prunes a *negative* limit from the **front** of the list and a positive one from the
  back — and a prepend (`at: 0`) lands at the front, so `stream_insert(…, at: 0, limit: -150)`
  deletes the page in the same patch that inserted it. The chat scrollback shipped that way:
  paging back died at 150 rows while the cursor kept advancing, so 700 fetched messages became
  unreachable for the session. Cap the live tail; leave scrollback uncapped
  (`MessageViewport`, `scrollback?`).
- **`Phoenix.LiveViewTest` applies no stream limit at all.** Every assertion about *which* rows
  a stream holds is a claim about the server's intent, never about the browser's list — a
  capped list is only observable in a real browser (`e2e/tests/chat-scrollback-audit.spec.ts`).
- **An infinite-scroll hook must hold a `pending` flag and re-arm on the server's *reply*.**
  Scroll fires once per frame, so an unguarded handler asks for a page per frame — measured at
  two pages per gesture in a test, and a real wheel flick emits dozens of events. Re-arm on the
  reply, never on the next patch: an empty page produces no patch and paging would wedge.
- **A missed stream callsite is a runtime error, not a compile error** —
  `stream_insert(socket, :chat_messages, …)` still compiles. The completeness gate for a
  stream refactor is `grep -rn ":chat_messages"`, not the compiler; then drop
  `import Phoenix.LiveView, only: [stream*]` and let `-W0` flag orphaned imports.
- A pure per-row renderer must be a **function component**, never a LiveComponent-per-row
  (thousands of rows). Use `use RetroHexChatWeb, :html` for a raw-HEEx module (provides `raw/1`
  and `~p`, which `RetroHexChatWeb.Component` does not).

### 6.6 Child → parent bubbling & the silent-swallow bug

- **A component never mutates the parent.** When privileged work lives on the parent
  (session-mutating context calls, `CommandDispatch`, persistence), the island does its own
  local/optimistic work and bubbles a semantic message:
  `send(self(), {:composer_dispatch, text, reply_to})` — inside a LiveComponent, `self()` is
  the parent's pid. The parent's `handle_info` does the privileged work.
- **⚠️ The most dangerous bug in the whole effort: a 2-tuple `send(self(), {atom, payload})`
  bubble is silently swallowed** if a `handle_info` hook has a generic `Task`-result catcher
  like `handle_info({_ref, _result}, socket), do: {:halt, socket}` — it matches *any* 2-tuple
  and halts the bubble. Symptom is treacherous: the UI looks right (island updated
  optimistically) but the **parent never updates**, so persistence and any other subsystem
  reading the state never see the change.
  - Fix at the root: guard the swallower with `when is_reference(ref)` (real Task results are
    `{reference(), result}`).
  - Rules: prefer a **3-tuple** for island→parent bubbles (or ensure the guard exists). Put an
    explicit `handle_info({:feature_summary, ...})` clause **above** any catch-all
    `handle_info(_msg, socket)`. And **always verify the parent, not just the UI**, in a test
    (`:sys.get_state(view.pid).socket.assigns`) when the bubbled state has a reader in another
    subsystem. `send_update` does NOT hit this trap (it's not a bare message) — only the tuple
    bubble does.
- **Committing a draft *struct*** (too big for `phx-value`): bubble it via
  `send(self(), {:commit, draft, mode})` and handle it in an `info_hook` (returns
  `{:halt|:cont, socket}`; include a catch-all `{:cont, socket}`).
- **Shared mutation logic used by two islands → a pure module** (`session in → {:ok, session,
  status} | {:error, status}`, no socket), not duplication and not a parent adapter. Each
  island calls it and does its own bubble + socket effects.

### 6.7 Shared list / message sink ownership

- One island owns a list that **multiple producers** append to (a system-message sink). Every
  other producer (host or sibling island) enqueues with a one-line `send_update`; only the
  owner mutates the list:
  ```elixir
  send_update(P2PFileIsland, id: P2PFileIsland.id(), action: {:ft_event, name, params})
  # owner builds the map itself:
  def update(%{system_message: txt}, socket),
    do: {:ok, update(socket, :messages, &(&1 ++ [system_msg(txt)]))}
  ```
- Small, churny lists use passthrough + append, NOT a stream.

### 6.8 Modal-in-modal (the clobber anti-pattern)

- **Symptom:** a typed input in a `fixed inset-0` sub-form loses its value on a re-render
  triggered by another event, so submit sends empty and `required` blocks the close.
  **Cause:** the sub-form submits to the *parent* but lives in the *component's* DOM → cid
  mismatch breaks LiveView's uncontrolled-input value preservation. Detect with
  `grep -c "fixed inset-0"` plus `<.input>` without `value=`.
- **Canonical fix — total ownership + target threading:** make the whole dialog `@myself`. Add
  one `attr :target` to the design-system component and apply `phx-target={@target}` on every
  `phx-click`/`phx-submit`, threading `target` through all sub-components; the LiveComponent
  passes `target={@myself}`. Now each sub-form submits to the component that owns its DOM.
- **If the re-render comes from *within the same component*** (e.g. a `color_picker` swatch
  click), `phx-target` alone is not enough — add `phx-update="ignore"` on the uncontrolled
  input (keep a hidden controlled field for the derived value).

### 6.9 The CSS-lint boundary for wrappers

- `lint.css_consistency` scans `live/chat_live/components/` but SKIPS `components/ui/`,
  `live/app/`. Raw Tailwind (`ml-auto`, `flex-1`, `hidden`) in a `chat_live/components/`
  module fails with "Missing CSS classes". **Fix (don't weaken the linter):** move the chrome
  (markup + layout classes) into a function component in `components/ui/` that takes primitives
  + event names and zero domain; leave only domain derivation + delegation in the scanned glue
  module. Rule: `components/ui/` = pure presentation (no `RetroHexChat.*`, no `live/`); domain +
  glue = `chat_live/components/` (no raw Tailwind). A hook-anchor
  `<div phx-hook=... class="hidden">` trips the same linter — wrap it in a `components/ui/`
  function component.
- Presentational wrappers give ~0 assign reduction; their value is removing
  computation/import/DOM from the parent plus function-component memoization (pass scoped
  *primitives*, not whole structs). Don't invent wrappers to hit an assign-reduction goal.

### 6.10 Async work in components

- Heavy queries → `start_async/3` **in the component**. **Never capture `socket` in the task**
  — pass pure data. **Always stale-guard:** tag the result with its input and discard if state
  moved on:
  ```elixir
  start_async(socket, :history_count, fn -> {query, Search.count_matches(channel, query, opts)} end)

  def handle_async(:history_count, {:ok, {query, count}}, socket) do
    socket = if socket.assigns.query == query and socket.assigns.history,
      do: assign(socket, history_count: count), else: socket
    {:noreply, socket}
  end
  def handle_async(:history_count, {:exit, _}, socket), do: {:noreply, socket}
  ```
- Test derived state with `render_async(view)`. **Don't trust an "async" label — verify in
  code.** Several "async lookup" paths were actually synchronous.
