# Agent Guide — retro_hex_chat

Durable engineering guidance for anyone (human or agent) working in this codebase.
It consolidates the governing principles and the hard-won learnings from the major
build-outs (feature suite, ChatLive → LiveComponent island migration, P2P/WebRTC
lobby). Read `CLAUDE.md` for commands and day-to-day workflow; this file explains the
*why* and the non-obvious rules that keep the system coherent.

Rules are stated as imperatives. When a rule cites a symptom ("this broke"), treat it
as a landmine map — the failure mode is real and has bitten before.

---

## 1. Governing Principles (non-negotiable)

These 11 principles are the supreme constraints. Any change that violates one is wrong
until the principle itself is amended.

1. **Elixir & Phoenix exclusive stack.** Backend is Elixir/OTP only. All reactive UI is
   Phoenix LiveView — zero JS UI frameworks (no React/Vue/Svelte/Angular). PostgreSQL is
   the sole relational store; no NoSQL as primary store. The retro CSS design system is
   the aesthetic base.
2. **Umbrella with bounded contexts.** `apps/retro_hex_chat` is pure domain (zero Phoenix
   deps); `apps/retro_hex_chat_web` is the web layer. The domain contexts are: `Accounts`,
   `Admin`, `Bots`, `Channels`, `Chat`, `Commands`, `Config`, `P2P`, `Presence`,
   `RateLimit`, `Services` (NickServ/ChanServ), plus game sessions. Each context layers
   internally: Schema, Queries, Service/UseCase, Policy, Events.
3. **OTP process architecture from day zero.** Process-per-entity: a `DynamicSupervisor`
   + `Registry` (`via_tuple`) + one GenServer per active channel / P2P session / game
   session / bot. Dedicated GenServers back NickServ and ChanServ. Copy the existing
   `Channels.Server` template for any new stateful runtime process; do not reach for
   `:gen_statem`, `fsmx`, or `Oban`.
4. **Test-first (NON-NEGOTIABLE).** Tests are written before/alongside code. Pyramid:
   many `:unit` (no DB, `<10s`), focused `:integration` (DB), minimal `:liveview` /
   `:liveview_feature`. Tools: ExUnit `async: true`, Mox (behaviours only — no direct
   module mocking), ExMachina, StreamData, Floki; Vitest + jsdom for JS. `mix test` under
   60s. Coverage must not regress.
5. **Contracts and behaviours.** `@callback` behaviours define module contracts. Every
   `/` command is one module implementing the `Commands.Handler` behaviour. Use protocols
   where polymorphic dispatch adds clarity.
6. **Static analysis from day one.** Credo (`--strict`, zero warnings), Dialyzer (`@spec`
   on every public function), `mix format --check-formatted`, ESLint, Prettier — all
   enforced. `make ci` is the gate.
7. **Lean LiveViews & component architecture.** LiveViews are thin and delegate all logic
   to contexts — zero business logic in the web layer. Reusable function components
   encapsulate visual elements. JS hooks are minimal wiring only. Streams for long lists.
8. **Retro design fidelity.** Faithful Windows-98 / mIRC aesthetic: 3D beveled borders,
   pixelated fonts, 16×16 icons, monospace chat fonts (Fixedsys/Consolas/Courier New),
   semantic HTML for accessibility. Emit telemetry at critical interaction points.
9. **Hot/cold data separation.** Runtime state (active channels, online users, rate-limit
   counters) lives in GenServers/ETS. Persistent state (message history, accounts, configs)
   lives in PostgreSQL. Incremental migrations; soft deletes where auditability matters;
   environment-aware config.
10. **Scalable architecture.** Evaluate every decision for future scale (process-per-channel
    scales via distributed Erlang; schemas partitionable; PubSub node-spanning). Simplicity
    is the default, but never a dead-end. Premature optimization is forbidden; premature
    architectural corners are equally forbidden.
11. **User-facing documentation is mandatory.** Every user-facing feature ships help
    topics in `RetroHexChat.Chat.HelpTopics` — undocumented features are incomplete. See §12.

**Quality gates before merge:** `mix format --check-formatted`, `mix credo --strict`,
`mix dialyzer`, `mix test`, `eslint`, `prettier --check`, `vitest run`. Every public
function has an `@spec`. Every `/` command implements `Handler`. PubSub topics follow the
naming convention (§5). LiveViews contain no business logic; contexts contain no web deps.

---

## 2. State: pick the tier by ownership scope

The system has a deliberate four-tier state model. Choose by *who owns the state*, not by
convenience.

- **Per-user, session-scoped → LiveView socket assigns.** Flood tracking, ignore timers,
  auto-respond cooldowns, alias/timer refs, CTCP rate limits. The LiveView process already
  gives per-user isolation and auto-cleanup on disconnect; a GenServer-per-user or ETS
  table would duplicate that for nothing. Any timer whose lifetime equals the session gets
  this for free (`Process.send_after` refs die with the process).
- **Server-enforced global limits → ETS token bucket** (`RateLimit.Limiter`). Reserved for
  limits the *server* imposes on everyone (e.g. 5 msg/s, 2 cmd/s). Do NOT conflate with
  per-user filtering: flood protection is user-configurable filtering and stays in assigns.
- **Shared channel/session runtime → GenServer** (`restart: :transient`, `via_tuple`,
  `Process.send_after` for timed transitions). New stateful runtime processes follow this.
- **Authoritative durable state → PostgreSQL.** GenServers/ETS are a hot cache seeded from
  the DB on boot. On crash, `init/1` reloads from DB; a terminal DB row stops the process
  with `:ignore`, otherwise it resumes with reset timers. Never treat ETS as a recovery
  source — it is lost on node restart. The DB is authoritative for anything a
  crashed-but-not-yet-restarted GenServer could lie about (e.g. duplicate-session checks
  are DB queries, not Registry lookups).

**Timers: one idiom only.** `Process.send_after/3` in the owning process, everywhere
(ignore expiry, scripting timers, session timeouts, periodic cleanup). Repeating timers
re-arm inside their own `handle_info`; periodic cleanup GenServers self-schedule each tick —
no cron, no `:timer.send_interval`. Timer refs are process-level state and must NOT be
stored in domain structs (`Session`, `IgnoreList`); keep domain modules pure and hold refs
in a parallel assigns map.

**Cache + expiry pattern.** A GenServer-owned public ETS table seeded from the DB plus a
periodic `Task` that expires/reconciles rows (BanCache/BanExpiry, RoleCache, WhowasCache,
global mutes). Expired timed entries are filtered on load (`expires_at < now`); survivors
get fresh timers with the *remaining* duration.

---

## 3. Command / dispatch architecture (the spine)

- **Every `/command` is one Handler module** implementing the `Commands.Handler` behaviour
  (`execute/2`, `validate/1`, `help/0`, `category/0`, `syntax_definition/0`), registered in
  a compile-time map in `Commands.Registry`. Metadata is co-located with the command
  (`help/0`, `category/0`) so new commands auto-categorize — a centralized metadata map was
  rejected as fragile. Never inline command logic elsewhere.
- **Handlers stay pure-domain** and return one of three shapes:
  - `{:ok, :system, %{content}}` — ephemeral text back to the user.
  - `{:ok, :ui_action, :atom, payload}` — routed through `UiActionHandlers` to a
    `UiActions.*` submodule. This is the seam between a command and a LiveView effect.
  - `{:error, msg}`.
- **Large command surface → one entry-point handler dispatching to submodules** (e.g.
  `Handlers.Admin` → `admin/server.ex`, `admin/user.ex`). Partition UI-action atoms into
  compile-time lists (`@core_actions`, `@notify_actions`, …) so `UiActionHandlers`
  delegates without a giant `case`.
- **Every UI affordance dispatches through the SAME command pipeline.** A menu item runs
  `CommandDispatch.dispatch_command(..., "motd", [])`; input dialogs synthesize
  `/me ...` / `/notice nick ...`. This preserves handler validation and identical output —
  never invent a parallel send path.
- **A bare command with no args opens its management dialog** via `:ui_action` (mirroring
  `/alias`, `/autorespond`) rather than printing usage, when such a dialog exists.
- **Aliases resolve at the LiveView layer** (`dispatch_command/4`), *before* the stateless
  domain `Dispatcher`, because aliases are per-user Session state and the `Dispatcher` must
  stay a pure function of `(command, args, context)`. Alias expansion re-parses and
  recursively re-dispatches with a depth cap of 5.
- **Variable expansion is one shared pure module** (`Chat.AliasExpander`, zero web deps)
  used by aliases, custom menus, auto-respond, and timers — never duplicated per subsystem.
  Rules: `$1`–`$9`, `$nick`, `$chan`, `$$`→`$`. Command chaining (`|`, `&&`, `;`) is
  rejected at *save* time, not execution time.
- **Orchestration façades** (e.g. `RetroHexChat.Admin`) wrap "do the domain action → write
  audit log → PubSub broadcast → return `{:ok,msg}`/`{:error,msg}`" so handlers call one
  function.

---

## 4. PubSub & permissions

- **Topic conventions are load-bearing and fixed:** `"channel:#{name}"`,
  `"pm:#{sorted_ids}"` (nicknames sorted alphabetically and `:`-joined so both directions
  share one topic), `"user:#{nickname}"`, `"service:nickserv"`, `"service:chanserv"`,
  `"p2p:#{token}"` (per-session, token-based), `"game:#{token}"`, plus server topics
  `"server:announcements"`, `"server:wallops"`, `"server:settings"`. State transitions and
  side effects are enforced server-side and announced via broadcast; observers react in
  `pubsub_handlers/*`.
- **Nicknames are the only durable identity key in chat** (guests have no persistent user
  ID). On nick change, the LiveView unsubscribes/resubscribes PM topics; DB records keep
  the nickname as-sent (immutable), and history queries must union old+new nicknames.
- **Permission checks belong in the domain** (`Channels.Policy`, `Commands.Policy`,
  `Accounts.ServerRoles`). Server roles require `identified: true` (NickServ) and come from
  config/env/RoleCache, not a users table. Channel roles are a single-valued rank
  (owner > operator > half_operator > voiced > regular), not independent flags — test op
  and voice transitions separately.
- **UI event guards must match or exceed the handler's own check** — never let a
  menu/dialog bypass handler semantics. If a handler's gate is looser than the spec intends,
  apply the stricter gate in the UI and record the handler discrepancy rather than silently
  changing command semantics.
- **Structured admin/UI controls dispatch with the viewer's REAL role context**
  (`ServerRoles.admin?/server_operator?` from the session), never an elevated provisioning
  context, so operator-only handlers still gate correctly. Admin-only affordances are fully
  hidden (`:if={@is_admin}`), not merely grayed.
- **Silent receiver-side filtering, never sender notification.** Ignore and flood-duplicate
  blocking drop messages silently; notifying the sender would leak that filtering is active.
  "Sender feedback" means the sender's *own* local rate limiter, nothing else.

---

## 5. Persistence conventions

- **Single-row-per-user settings tables** keyed by `owner_nickname` FK → `registered_nicks`,
  one column per setting (`flood_protection_settings`, `ctcp_settings`, …). Chosen over JSON
  columns (lose DB type safety) and key-value tables (over-engineered). Use this for any new
  fixed-shape per-user config.
- **List-type features** (ignore, notify, highlight words, aliases, favorites, contacts,
  perform) persist via **delete-all-then-reinsert in a transaction** for `save/2`, and
  query-and-convert for `load/1` (lists are capped ≤100). Each such feature = a domain
  module with `new/0` + CRUD + `save/2`/`load/1`, a getter/setter pair on the Session
  struct, and a `position` column for ordering.
- **JSONB `message_settings` is the general-purpose per-user preference store.** New scalar
  preferences (e.g. P2P `turn_only`) go under a nested key here — no migration. Reserve new
  columns/tables for structured data only.
- **Cursor pagination uses `inserted_at` timestamps** (not offsets, not plain UUIDs), with
  composite indexes like `(channel_name, inserted_at)`:
  `WHERE channel = ? AND inserted_at < ? ORDER BY inserted_at DESC LIMIT 50`. Offsets
  rejected (O(n) deep pages); UUIDs rejected (no chronological sort without UUIDv7).
- **Text search uses pg_trgm GIN + ILIKE/`similarity()`**, not tsvector full-text (trigram
  wins for the substring matching Ctrl+F expects) and not an external engine.
- **Fuzzy matching runs server-side** (subsequence + weighted scoring, ~30 LOC Elixir); only
  Tab-cycling and recent-commands (localStorage, capped 5) are client-local for latency.
  Levenshtein and external fuzzy libs rejected as overkill for small datasets.
- Ecto timestamps are `utc_datetime_usec` throughout.

---

## 6. LiveComponent island decomposition

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

---

## 7. Windowed desktop UI (Win98 desktop)

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
  The `handle_info({:feature_summary, ...})` clause must sit above the catch-all (see §6.6); a
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

---

## 8. WebRTC / P2P

**Naming policy — "lobby" is the DOMAIN, not a page.** `RetroHexChat.Lobby` is the
P2P-session bounded context; the PubSub topic `"lobby:#{token}"`, the `lobby_*`
events, the `lobby-*` DOM ids and the `Lobby*` module names all refer to that
domain concept. There is NO standalone lobby page — `/lobby/:token` only
redirects to `/chat`, where P2P sessions live (invite card in the PM, `p2p-*`
desktop windows). Do not invent or search for a lobby LiveView/page.

### 8.1 Session model

- **Session status is a 7-state machine:** `pending → lobby → connecting → active` plus
  terminal `closed / expired / failed`. Enforced as a DB `status` string column with changeset
  validation; `closed_at` and `closed_reason` are required whenever terminal. Any non-terminal
  state can jump to `closed`. Terminal sessions are retained indefinitely for audit (no purge).
- **Duplicate-session prevention is a DB query, not a Registry check**
  (`WHERE (creator=A AND peer=B) OR (creator=B AND peer=A)` filtered to non-terminal). The DB
  is authoritative because a crashed-but-not-yet-restarted GenServer would make a Registry
  check lie.
- **Session tokens are `Phoenix.Token.sign/verify`** (salt `"p2p_session"`, 24h max_age)
  embedding `%{creator_id, peer_id, session_id}` so authorization needs no DB lookup. The domain
  app reads the signing secret from `Application.get_env(:retro_hex_chat, :p2p_token_secret)`
  populated at startup — it must NOT depend on the web endpoint module.
- **`create_session` IS the invite.** No separate invite action; creating a session broadcasts
  `p2p_invite`, delivered by reusing `send_private_message` (persisted, appears in PM history).
  A single session-creation rate limit (5/10min) subsumes the invite limit. P2P rate limiting is
  its own ETS sliding-window (minutes-scale), deliberately NOT the message `RateLimit.Limiter`.
- **Block/ignore reuse:** P2P policy checks blocks by querying the existing
  `ignore_list_entries` table directly (type `:all`) rather than depending on Chat runtime
  state — self-contained, one source of truth.

### 8.2 Signaling & TURN

- **Self-hosted STUN/TURN runs inside the BEAM.** The `elixir-webrtc/rel` TURN server was
  *extracted* into `RetroHexChat.P2P.Turn.*` rather than added as a dep (`rel` is a standalone
  OTP app that collides with Phoenix — own Application, port 4000). Only new dep is `ex_stun`,
  pinned `~> 0.1` (0.2.x has breaking API changes). A Docker sidecar was rejected (violates
  "same BEAM VM"). TURN credentials are RFC 5766 HMAC-SHA1, generated in Phoenix.
- **The server is a blind signaling relay.** Signaling is stateless server-side: JS `pushEvent`
  → LiveView `handle_event` → `PubSub.broadcast("p2p:token")` → peer LiveView → `push_event` →
  peer JS. The server never inspects SDP; the SessionServer only learns of `connecting → active`
  transitions.
- **The session creator is always the offer initiator** — server sends `p2p_start_offer` only to
  the creator on `connecting`, preventing simultaneous-offer glare.
- **TURN-only privacy mode** = pass `{iceTransportPolicy: "relay"}` to the browser
  `RTCPeerConnection`; server sends a `turn_only` flag alongside `ice_servers`.

### 8.3 JS architecture (hook = wiring, lib = logic)

This separation is Principle IV and is enforced.

- **`webrtc.js` owns the single `RTCPeerConnection`** multiplexing all data channels (file
  transfer, game data) — shared by media+file+game, living in the host backbone, **never** in an
  island. It exposes pure functions (createOffer/Answer, ICE, track management) and is the one
  source of PC truth.
- **Sibling hooks never touch the PC directly.** `WebRTCHook` dispatches the PC reference via
  `CustomEvent` (`media_pc_ready`, `ft_channel_ready`); `FileTransferHook`/`MediaHook` listen.
  New media/data logic goes in its own lib module (`media.js`), never bloating `webrtc.js` or a
  hook.
- Audio→video upgrade rides the native `negotiationneeded` event through the existing
  `p2p_signal` channel — no custom upgrade protocol. Device switching uses `replaceTrack()` (no
  renegotiation). Codec ordering via `setCodecPreferences()`, never SDP munging.
- **Single-offerer negotiation** (only the initiator emits offers) is host/backbone logic — an
  island only *requests* media via push_events to its hook. Do not move this into an island.
- **Bidirectional video** (both enable at once, real RTP `track.muted === false`) is the scenario
  that most regresses — always run it after touching media.

### 8.4 File transfer protocol

- **Custom binary protocol over one ordered RTCDataChannel** (`arraybuffer`, named
  `"filetransfer"`, created by the initiator during the offer phase). Byte 0 = message type;
  chunk messages carry a 4-byte big-endian Uint32 index then ≤64 KB payload. JSON-only rejected
  (base64 +33%); multiple channels rejected (lifecycle complexity).
- **Chunk size 64 KB.** Backpressure via `bufferedAmount`: pause above 1 MB, resume below 256 KB.
  ACK-per-chunk rejected — SCTP already guarantees ordered reliable delivery.
- **Resume uses a `have-chunks` index array** (Uint32Array), not a byte offset, because
  disconnection leaves non-contiguous gaps. Receiver stores chunks index-keyed (O(1) out-of-order
  insert), assembles a Blob at the end.
- **SHA-256 integrity is mandatory** (sender hashes before, receiver hashes assembled buffer).
- **File metadata flows over the DataChannel, never PubSub** — consent reuses the existing
  `request_action("file_transfer")` → `respond_action` flow, but nothing about the file touches
  the server. Extension blocklist is env-configurable; MIME checking rejected (browser MIME is
  extension-derived).

---

## 9. UI = component composition (never bespoke per-screen markup)

- Build reusable components under `components/ui/**`; screens/dialogs/menus only pass assigns and
  event names. Never write one-off interface code in a LiveView/template for a single feature.
- **LiveViews are adapters, not visual owners.** A LiveView owns socket assigns, PubSub,
  authorization, verified routes, browser hooks and event dispatch. If a block mostly answers
  "how does this look?", move it to `components/ui/**` and pass data, event names and paths in.
  Accept only thin wrappers in `live/**` when they preserve stream ids, `phx-update`, `@myself`,
  hook roots or `data-*` contracts consumed by JS/tests.
- **Shared screens stay composed after refactors.** Connect, Help, Landing and Chat shell chrome
  follow the same rule as dialogs: desktop shells, taskbars, menu bars, toolbars, empty states,
  cards and rich rows live in UI modules. Adapters such as `LandingHelpers` or
  `HelpLive.HelpHelpers` may remain as import-compatible bridges, but they must delegate visual
  work instead of owning HEEx markup.
- **Keep route verification at the edge.** UI components may render simple fixed paths, but when a
  route depends on caller context or must stay verified, the LiveView passes a prepared path
  (`~p` stays in the adapter). UI components must not reach into socket/session state.
- **Composition refactors need real gates.** Preserve ids, `data-testid`, events and hooks, then run
  focused tests for the touched surface plus `make ci` before merging. If Playwright is needed,
  use the local-only E2E suite deliberately; it is not part of `make ci`.
- **Enhance an existing component; never fork a parallel dialog/menu.** New channel-config and
  ChanServ tabs extend the existing Channel Central dialog; wiring specs just add a menu entry to
  an already-built dialog. **Reuse a whole stateful component across contexts via
  capability/flag toggles** rather than copying it per context — this is how the chat Composer is
  context-agnostic (capabilities map).
- Aggregator dialogs (Options, Admin Console) are built incrementally: ship a tabbed/tree shell
  that preserves a safe default fallback (e.g. the raw Console tab), then fill structured tabs one
  slice per iteration.
- Dialog-backed actions need result-returning helpers (`{:ok, socket}` /
  `{:error, socket, msg}`) so the dialog closes on success and shows inline errors; socket-only
  `handle_ui_action/3` is fine only for fire-and-forget typed commands. After a mutation,
  re-assign the updated struct / re-fetch the snapshot so status labels and buttons don't go
  stale.
- New menu/toolbar actions must be added to BOTH hook lists: `attach_all_hooks/1` (client events)
  and `@event_hook_fns` (internal `toolbar_action` dispatch through `dispatch_to_hooks/3`). Reuse
  an existing v1 event name when a hook already handles it.
- Project a domain "snapshot" for read-heavy UI (founder + viewer role + grouped access lists
  together) so event handlers only refresh assigns. Make sure hot-state projections
  (`Server.get_state/1`) actually expose the fields the UI needs before building the affordance.
- **Reuse existing infrastructure over building parallel systems.** PMs carry P2P invites; the
  notification dispatcher carries P2P toasts; the ignore table backs P2P blocks; the
  action-request flow gates file transfers and calls. New tables/systems are consistently
  rejected as over-engineering when an existing one fits.

---

## 10. SVG / CSS fidelity (enforced by `make ci`)

- **No inline `<svg>` anywhere.** Icons are function components in `Icons.*` submodules (chosen
  by *what the icon depicts*, not where it's used), exposed via the `components/icons.ex` facade;
  complex illustrations go in `components/diagrams.ex`. Reuse from `docs/reference/svg-catalog.md` /
  `/showcase/icons` before adding one. A missing icon is a real prerequisite — add it via
  submodule + facade `defdelegate` + `@spec` first.
- **No hardcoded hex colors or CSS values in Elixir/JS** — Tailwind classes or CSS custom
  properties only. Inline `style=` is allowed only for dynamic `left`/`top` and CSS custom
  properties. `make ci` runs `mix audit.styles --strict` (must show 0 LOW / 0 MEDIUM / 0 HIGH).
- **JS that toggles visual state flips a CSS-owned project class** (e.g.
  `menubar-copy-disabled`), never raw Tailwind utilities, because the CSS lint scans
  `classList.*` strings. Emit boolean-ish `data-*` attributes as explicit `"true"`/`"false"`
  strings — hooks/CSS compare against the string.

---

## 11. Retro / mIRC-parity design rules

- Preserve the Windows-98 / mIRC mental model: administration happens INSIDE the chat via
  commands, with dialogs as a discoverable front-end — not a separate dashboard. Every UI control
  maps to an equivalent slash command (document the control→command mapping).
- Follow mIRC dialog conventions: tree/tabbed Options with Apply/OK/Cancel; two-panel list +
  inline edit form; context menus that only APPEND to (never replace) built-ins;
  keyboard-shortcut hints aligned right; grayed disabled states for unavailable actions.
- Respect standard visibility gates: op-only, admin-only, identified-only, never-on-self,
  disabled-when-disconnected. Admin-only affordances are fully hidden (`:if`), not grayed.

---

## 12. Help documentation is mandatory (Principle XI)

Every user-facing change adds/updates topics in `RetroHexChat.Chat.HelpTopics`
(`apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`):

- New command → a topic in the **Commands** category (syntax, examples, "See Also").
- New feature → a topic in the **Features** category.
- New UI element (window, dialog, toolbar) → a topic in the **User Interface** category.
- New keyboard shortcut → update the **Keyboard Shortcuts** topic.
- Update "See Also" cross-references in related topics.
- Reuse existing topic IDs when a new one already maps to an existing topic
  (`cmd-invite` vs `invite_send`) — update in place, never duplicate.

Accessible via F1, Help menu → Help Topics, and `/help`. Stale/inaccurate help is a defect.

---

## 13. Testing conventions & gotchas

- **`make ci` (complete local guard, 12 checks) is the ONLY final validation and the
  completeness gate, not E2E and not `ci.changed`.** A task isn't done until it's fully
  green. The guard partitions the normal ExUnit suite and the LiveView feature suite by
  default; use `make ci.serial` only to diagnose partition-specific issues. All
  warnings/failures are yours — never "pre-existing" without proof. `make ci.quick` (skips
  dialyzer) and `make ci.changed` (diff-selected checks) are for iteration only.
  Per-feature Playwright alone does NOT catch LiveViewTest/component regressions; when an
  E2E spec and a `make ci` LiveViewTest disagree, `make ci` is authoritative — the spec is
  stale.
- **Use the fast loops deliberately.** `make test.stale`, `make test.domain.stale`,
  `make test.web.stale`, `make test.failed`, `make test.js.changed SINCE=origin/main`,
  `make test.js.related FILES="js/app.js"`, `make e2e.changed`, and
  `make e2e.shard SHARD=1/2` are local feedback tools. They never replace the final
  `make ci` gate.
- **Never assert on async `send_update` / stream messages.** Assert on synchronous state
  (`:sys.get_state`), domain/component unit tests, or persisted data. No `sleep` / render-retry.
  (See §6.3 for the flush rule when a synchronous read is genuinely needed.)
- **Feature tests run concurrently — never mutate shared global state destructively.** Set caches
  to `:unset`/neutral values instead of deleting them (deleting `:motd_cache` forced unrelated
  mounts to query outside their Ecto sandbox owner). Accept BOTH valid values when another test
  may be flipping a global (e.g. TURN listener count).
- **Seed through the real domain context** (`AuditLogs.log/4`, `Chat.Queries`, a real registered
  nick/channel process) over parsing command text. Verify command dispatch by subscribing the
  test process to the PubSub topic, using unique message text, and asserting both inline output
  and the broadcast payload.
- **Don't execute genuinely destructive commands in feature UI tests** (nuke/purge tear down
  shared channel/bot processes) — cover the preview + invalid-confirmation path in LiveView and
  leave destructive execution to isolated command tests. Require typed-confirmation strings
  (matching the channel/server name) before dispatching.
- **Floki text extraction can leak icon text** (e.g. `#`) into label assertions — wrap visible
  labels in explicit `data-testid` spans when exact matches matter. Hidden dialogs still render
  their static markup; assert on target state/content or show-trigger presence, not on absence of
  the dialog's `data-testid`.
- Component test: `use RetroHexChatWeb.ConnCase, async: true` + `@moduletag :unit` (CI splits by
  tag; untagged tests run in the wrong worker). `@moduledoc` explaining the ownership decision
  (passthrough vs owned) + `@spec` on every public function *including* callbacks (`mount/1`,
  `update/2`, `render/1`, `handle_async/3`) and helpers (`id/0`, `open/1`, `close/1`).
- **`phx-change` is a form binding** — it does not fire on a bare `<input>`. Wrap it in a
  `<form phx-change=...>` (this was a real never-worked filter bug), or use `phx-keyup`/`keydown`.
- **State that must appear in a *focused*, value-bound input must be set before the input mounts**
  (same render it becomes visible), not in a later async action — LiveView won't patch the `value`
  of a focused input.
- **Removing dead state: grep by module/function name, not filename** ("0 refs" was false because
  only the filename was grepped). A client→server sync with no server reader is dead.
- **Baseline before blaming your change:** a spec that *passes* on your branch can't be a
  regression, so only re-run *failing* specs against a clean baseline via
  `git stash push -- <file>` → `MIX_ENV=e2e mix compile` → run → `git stash pop`. Fails on both =
  pre-existing; passes on baseline, fails on branch = real regression.
- **Connect-burst first-click race** (recurring, not a regression): `waitUntilConnected()` only
  waits for the WS handshake, which resolves before the join-render settles, so the first
  `phx-click`/menu-open after connect is eaten by the render burst. Fix with an idempotent Page
  Object helper that re-clicks if the target doesn't appear in ~2s, not scattered
  `waitForTimeout`s.
- Playwright E2E requires **`mix assets.build` first**, or it serves a stale bundle without the
  new hook.

---

## 14. Process & tooling discipline

- **Always inspect and pull before committing or pushing to `main`:** run
  `git fetch origin`, `git status --short --branch`, then
  `git pull --ff-only origin main`. If local edits are uncommitted, use
  `git pull --ff-only --autostash origin main`. Push only after confirming the
  local `main` is current.
- **⚠️ Never `git checkout <file>` to undo edits when work is uncommitted** — it reverts to HEAD
  and destroys *other* uncommitted work too. Undo with Edit or a recoverable
  `git stash push -- <file>`. Recover a lost stash via
  `git fsck --no-reflog | grep "dangling commit"`.
- **⚠️ Don't let a pipe mask `make ci`'s exit:** `make ci 2>&1 | tail -20` returns `tail`'s exit
  (0). Run `make ci > log 2>&1; echo $?` or check the `Results: N/12` line.
- **Run `mix format` before `make ci`.** Long `send_update`/pipe lines break format and
  cascade-skip later parallel CI stages, wasting a round-trip.
- **"No silent catch" (JS and Elixir).** Every `try/catch` in connection/media/game JS must log
  or surface — no silent swallow (best-effort audio is the sole exception). Server-side, a
  catch-all `handle_info`/no-op that eats a message you depend on is the same bug class — prefer
  explicit clauses for anything load-bearing; reserve catch-alls for genuine no-ops.
- **Comments describe what the code does, never the change that produced it.** No migration/plan
  references in moduledocs or comments.
- Private helpers added to a `*_events.ex` module go in the helpers section at the end, never
  between `handle_event/3` clauses (else `-W0` "clauses with the same name and arity should be
  grouped"). Credo "Nested modules could be aliased": add an `alias`.
- Keep increments small, self-contained, reviewable (one coherent sub-task per iteration for
  large features).
- **When the spec contradicts the code, trust the code and record the discrepancy** — specs lag
  reality on key bindings (`Ctrl+Shift+F` not `Ctrl+F`), menu names (File/Edit/View/Tools/Help,
  no User menu), and handler permission gates. Don't invent parallel structure for a stale spec.

---

## 15. JS hook loading & bundle standard (CI-enforced)

There is exactly ONE hook registration pattern; do not reintroduce local choice in `app.js`.

- **One registration path.** A LiveSocket entrypoint imports a single `build*Hooks()` function
  from `assets/js/hooks/*_hooks.js` and passes the returned map to `LiveSocket(..., {hooks})`.
  No entrypoint may import individual hook implementations or define an inline hooks object.
  `app.js` → `buildHooks()` (`hooks/registry.js`); `help_live.js` → `buildHelpHooks()`;
  `retrohex_content.js` → `buildShowcaseHooks()`.
- **Critical vs lazy classification is mandatory.** Critical hooks (chat shell input, keyboard,
  autocomplete, scroll, menu/toolbar, conversations, connection/lag, sound/title/notification,
  context-menu base) are imported eagerly in `critical_hooks.js` — **a critical hook must never
  be lazy** and that file contains zero dynamic imports. Lazy feature hooks (P2P WebRTC, media
  audio/video, file transfer, P2P diagram, game WebRTC, game canvas, game engines) are declared
  **only** in the central `lazy_feature_hooks.js` allowlist via
  `lazyFeatureHook({name, loader, serverEvents, readyEvent, reason})`.
- **Readiness protocol for any lazy hook that receives server-pushed startup events.** Dynamic
  `import()` is async, so a facade can mount before its impl loads and miss an early
  `push_event`. The handshake: DOM renders `phx-hook` → facade mounts → impl loads → impl
  registers all `handleEvent` callbacks → client pushes `*_ready` → server (re)sends startup
  state. Rules: `serverEvents.length > 0` **requires** a `readyEvent`; `safeWithoutReady` is
  banned. Server `handle_event("*_ready", …)` resends current state if the feature is already
  active, and all startup pushes must be idempotent (a duplicate start must not create a second
  `RTCPeerConnection`, media/file session, game engine, or timer). Client registers `handleEvent`
  **before** `pushEvent("*_ready")`, guards duplicate starts, queues out-of-order signals, and
  cleans up timers/listeners on `destroyed`.
- **CI guard** (`enforce_hooks_contract.cjs`, run via `make lint.hooks`) fails on: direct hook
  imports or inline hook maps in an entrypoint; `lazyFeatureHook(`/`import(` outside the approved
  registry/facade/i18n/game-engine locations; a `phx-hook="Name"` with no registry entry; a
  critical hook appearing in the lazy allowlist; a lazy hook with `serverEvents` but no
  `readyEvent`; `safeWithoutReady`; a new hook file that isn't classified.
- **Bundle budget** (`npm run bundle:budget`) fails if initial `app.js` exceeds budget, a known
  lazy module is pulled back into the initial chunk, or an async chunk grows past budget without
  an explicit budget update. Keep lazy feature chunks as async chunks. Approved dynamic-import
  sites: `lazy_feature_hooks.js`, the JS i18n catalog loader (`lib/i18n.js`), the game-engine
  loader — anything else must be added to the allowlist with rationale or it fails CI.

---

## 16. i18n & public-page URLs

- **Gettext, English source, small per-domain catalogs.** English is the source language;
  catalogs are kept small per functional domain, not concentrated in one `default.po`. Call
  `Gettext.put_locale/2` in `mount/3` or a shared `on_mount`. Locales are registered in
  `config/i18n_locales.exs` (Gettext dir code, BCP47 tag, Open Graph locale, native name, text
  direction, `Plural-Forms`, rollout wave/status). See `docs/reference/i18n-catalogs.md` for the
  catalog conventions and the locale roster.
- **Refresh Gettext with the standard scoped flow.** Use `make i18n.gettext.extract` to refresh
  `.pot` templates, then `make i18n.gettext.merge DOMAINS=<domain> [APP=web|domain]` to merge the
  affected `.po` files. Do not use the global rebuild for routine feature work; it requires
  `CONFIRM_GLOBAL_REBUILD=1` and is reserved for broad catalog refactors.
- **JS i18n catalogs are lazy-loaded** (dynamic `import()` in `lib/i18n.js`) while `t()`/`jt()`
  stay synchronous at call sites — one of the approved dynamic-import boundaries (§15).
- **Localized public URL model.** Default English is **unprefixed** (`/features`); non-default
  locales use a BCP47 **path segment** (`/pt-BR/features`, `/zh-Hans/features`). Public SEO URLs
  use only the clean path model — `?locale=` query URLs are non-canonical and must never appear
  in `<head>` alternates, footer language links, or the sitemap. Query-locale routes
  (`/locale/:locale?return_to=…`) exist solely for in-app user-initiated language switching.
- **Routes: explicit localized scopes per enabled non-default locale, never a catch-all
  `/:locale`** — a catch-all would capture app routes (`/connect`, `/chat`, `/lobby/:token`,
  `/showcase`). `PutLocale` resolves
  the locale from route params/assigns before the session / Accept-Language fallback.
- **hreflang is reciprocal.** Sitemap and `<head>` alternates list every locale version of a
  page reciprocally; `x-default` points at the English unprefixed URL. Canonical URLs on
  localized pages are self-referencing clean paths.
- **Public pages avoid the full app bundle.** Prefer server-rendered / CSS-first behavior on
  landing and help pages; only actual app pages load `app.js`.
