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

These principles are the supreme constraints. Any change that violates one is wrong
until the principle itself is amended.

1. **Elixir & Phoenix exclusive stack.** Backend is Elixir/OTP only. All reactive UI is
   Phoenix LiveView — zero JS UI frameworks (no React/Vue/Svelte/Angular). PostgreSQL is
   the sole relational store; no NoSQL as primary store. The retro CSS design system is
   the aesthetic base.
2. **Umbrella with bounded contexts.** `apps/retro_hex_chat` is the domain and carries no
   web layer — no LiveView, controller, route, component or endpoint. It does use Phoenix
   as a library (PubSub, Token, Presence, HTML escaping). `apps/retro_hex_chat_web` is the
   web layer. The domain contexts are: `Accounts`,
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
11. **User-facing documentation is mandatory.** Every feature that gives the reader
    something to do ships help topics in `RetroHexChat.Chat.HelpTopics` — undocumented
    features are incomplete. Something they cannot act on is not a feature and gets no
    topic. See §12.
12. **Never fork a concept per context.** When two surfaces handle the same thing — a
    message, an attachment, a reaction — the context is a **parameter**, not a second
    implementation. Two implementations do not diverge with a warning: they diverge when
    somebody adds a feature to one of them, and the only signal is a user complaining
    months later. The tell is the adapter: if reusing a rule means renaming a field from
    A's spelling to B's, then A and B are one type with two names.

    **Finding what has already diverged**, when you inherit a fork you cannot yet merge:
    list the functions each twin calls, difference the sets, and for every call that
    exists on one side only, look for the branch that would refuse it on the other. When
    there is no such branch, it is forgetfulness, not a decision. Where the two share a
    handler, suspect the function that decides which of them the message came from.
    `if context do … else <nothing> end` is a feature nobody wrote the second case for.
    Applied to one such fork this found seven defects, none of which anyone had reported
    in months of use.

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

**A read-model answers one question for every kind of thing that asks it.** A channel and
a private conversation are the same idea addressed two ways, and each place that forgets it
forks. `Chat.Roster.of/1` is the single answer to "who is in this conversation" — channel
membership from the channel process, a query's two people from the server-wide presence
topic — and one user-list island renders whatever it returns. `Helpers.Conversation` is the
matching web-side door: one `activate_channel`/`activate_pm` and one `load_roster`, because
a second copy of a conversation switch drifts from the first (the keyboard path had already
stopped resetting the composer and closing the search bar that the click path did).

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
  `"user:#{nickname}"`, `"service:nickserv"`, `"service:chanserv"`,
  `"p2p:#{token}"` (per-session, token-based), `"game:#{token}"`, plus server topics
  `"server:announcements"`, `"server:wallops"`, `"server:settings"`. The two that name a
  conversation are built by `RetroHexChat.Topics`, never interpolated. State transitions and
  side effects are enforced server-side and announced via broadcast; observers react in
  `pubsub_handlers/*`.
- **A private conversation is delivered to inboxes, not to a topic of its own.** A channel
  has a join that precedes every message; a private conversation is *created by* its first
  message, so a topic named after the pair cannot carry the one message that matters most.
  Each message, edit, delete, reply-quote refresh and typing notice is addressed to the
  participants' `user:` topics, which are subscribed once at mount. Anything else observing
  a conversation — the virtual-space runtime, for instance — watches those same inboxes.
- **Nicknames are the only durable identity key in chat** (guests have no persistent user
  ID). On nick change, the LiveView unsubscribes/resubscribes the `user:` inbox; DB records
  keep the nickname as-sent (immutable), and history queries must union old+new nicknames.
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
- **Every paginated `list_*/2` returns `RetroHexChat.Page`, keyed by `id`.** Cursor keyset, never
  offset (O(n) deep pages) — `WHERE channel_name = ? AND id < ? ORDER BY id DESC`, backed by
  composite indexes like `(channel_name, id)`. Read `page.ex`'s moduledoc before writing a new
  paginated query; the rules below are the parts callers keep getting wrong.
- **`has_more` comes from `limit + 1` in the database, never from `length/1` of a filtered list.**
  Ask for one row past the page (`Page.limit_with_lookahead/1`), and build the page *before* any
  presentation filter runs. `Page.filter/2` and `Page.map/2` reshape items and deliberately leave
  pagination state alone, so an ignore list or a visibility cutoff can never truncate paging.
  The cursor is the last **raw** row's id, not the last visible one.
- **Filter and search belong in the `WHERE`**, never `Enum.filter` over a full list; and a
  displayed count comes from `page.total`, never from a truncated list.
- **Every long list has five states** — empty, loading, end-of-list, error, truncated — from the
  shared components in `components/ui/layout/list_states.ex`. Auto-load always ships with a
  keyboard-reachable fallback. A list with no domain ceiling paginates; one with a ceiling
  documents the ceiling.
- **Long-list streams carry a negative `limit:`** (about 3× the page) so the DOM stays bounded.
- **Text search uses pg_trgm GIN + ILIKE/`similarity()`**, not tsvector full-text (trigram
  wins for the substring matching Ctrl+F expects) and not an external engine.
- **Fuzzy matching runs server-side** (subsequence + weighted scoring, ~30 LOC Elixir); only
  Tab-cycling and recent-commands (localStorage, capped 5) are client-local for latency.
  Levenshtein and external fuzzy libs rejected as overkill for small datasets.
- Ecto timestamps are `utc_datetime_usec` throughout.
- **Message content is a pair: source + rendered format, plus a cached `plain_content`.** IRC is a
  first-class format, not a legacy one — Markdown was added as an *explicit* mode beside it
  (IRC / MD / TXT), never as a silent replacement. `RetroHexChat.Chat.Content` is the facade;
  `plain_content` is derived by the changeset (`put_plain_content`) and **protected there** — a
  cached visible-text column that callers can set becomes a second source of truth.
- **Anything that reads a message as *text* reads the visible text, not the source.** Search is
  `coalesce(plain_content, content)`; the same holds for highlight, notifications, previews and
  accessibility. Only "Copy Source" reads the source, and it travels through the DOM in a
  representation separate from the visible text so copying can't break rendering or leak
  special-line privacy.
- **Parallel send paths need duplicated contract tests.** `Chat.Service` and `Channels.Server` are
  two ways in; a format that works through one and vanishes through the other passes a suite that
  only covers the first. Test both for as long as both exist.

---

## 6. LiveComponent island decomposition

**→ [`guide/liveview-islands.md`](guide/liveview-islands.md)** — Read when extracting, editing, or debugging a LiveComponent island: ownership, event routing, `send_update` timing, streams, bubbling, modals, async work.


---

## 7. Windowed desktop UI (Win98 desktop)

**→ [`guide/windowed-desktop.md`](guide/windowed-desktop.md)** — Read when adding or changing a window, dialog, taskbar entry, or Start menu item in the Win98 desktop shell.


---

## 8. WebRTC / P2P

**→ [`guide/webrtc-p2p.md`](guide/webrtc-p2p.md)** — Read when touching calls, signaling, TURN, file transfer, or call recovery.


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
  complex illustrations go in `components/diagrams.ex`. Check the submodules or `/showcase/icons`
  (they are the only catalog — a hand-maintained list of icons goes stale immediately) and
  reuse before adding one. A missing icon is a real prerequisite — add it via
  submodule + facade `defdelegate` + `@spec` first.
- **No hardcoded hex colors or CSS values in Elixir/JS** — Tailwind classes or CSS custom
  properties only. Inline `style=` is allowed only for dynamic `left`/`top` and CSS custom
  properties. `make ci` runs `mix audit.styles --strict` (must show 0 LOW / 0 MEDIUM / 0 HIGH).
  The auditor reads **any** `#` followed by digits as a hex colour, including a GitHub issue
  reference in a JS comment — `#3639` broke the build once. Write issue references out in words.
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
- **The composer line belongs to the input.** Mode/format controls compete directly with typing
  space, so they live in the tools menu and as contextual icons — never as permanent text buttons
  on the composition line. A Markdown preview renders through the real message component, or it
  becomes a second visual language for the same content.

---

## 12. Help documentation is mandatory (Principle XI)

Every change that gives the reader something to **do** adds/updates topics in
`RetroHexChat.Chat.HelpTopics`
(`apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`):

- New command → a topic in the **Commands** category (syntax, examples, "See Also").
- New feature → a topic in the **Features** category.
- New UI element (window, dialog, toolbar) → a topic in the **User Interface** category.
- New keyboard shortcut → update the **Keyboard Shortcuts** topic.
- Update "See Also" cross-references in related topics.
- Reuse existing topic IDs when a new one already maps to an existing topic
  (`cmd-invite` vs `invite_send`) — update in place, never duplicate.

**A change with no control surface gets no topic.** The test is not "can the reader
see it" — it is "is there anything the reader could type, click, or choose here". A
setting, a command, a window, a shortcut, a behaviour they have to anticipate: those
are help. Styling, a colour, a wallpaper, spacing, an animation — anything they
cannot act on and could not change if they wanted to — is not, and writing a topic
about it makes the help longer without making it more useful. Help answers "how do
I…", never "what am I looking at". The wallpaper shipped with a topic explaining
that it exists; nobody could do anything with that, and it was removed.

Accessible via the Help menu → Help Topics and `/help`. Nothing binds F1 — it is in
`@reserved_fkeys` because the browser owns it. Stale/inaccurate help is a defect.

---

## 13. Testing conventions & gotchas

**→ [`guide/testing.md`](guide/testing.md)** — Read before writing or debugging tests: the flaky-suite rules, what to assert on, and the gotchas that have burned this suite.


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
  (0). Run `make ci > log 2>&1; echo $?` or check the `Results:` line it prints.
- **Run `mix format` before `make ci`.** Long `send_update`/pipe lines break format and
  cascade-skip later parallel CI stages, wasting a round-trip.
- **"No silent catch" (JS and Elixir).** Every `try/catch` in connection/media/game JS must log
  or surface — no silent swallow (best-effort audio is the sole exception). Server-side, a
  catch-all `handle_info`/no-op that eats a message you depend on is the same bug class — prefer
  explicit clauses for anything load-bearing; reserve catch-alls for genuine no-ops.
- **Use the repo's Prettier, not `npx prettier`** — `npx` fetches a different version that disagrees
  with what `make format.check` runs:
  `apps/retro_hex_chat_web/assets/node_modules/.bin/prettier --write <file>`.
- **Programmatic edits need a unique anchor or an explicit `count=1`.** A bare `str.replace` hits
  *every* occurrence; one such edit silently rewrote an unrelated pre-existing assertion
  (`toBe("chat")` → `toBe("call")`) and the breakage read as a production regression.
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
  cleans up timers/listeners on `destroyed`. **The server half is not optional and
  its absence is silent:** `LobbyWebRTCHook` had none, so a page resuming into a
  running session pushed its start while the implementation was still being
  imported, the event went nowhere, and the surface — having recorded that it
  started — never pushed it again. The restart that followed reached a
  connection with no role and no ICE servers and gave up without building
  anything. Nothing logged, and the answerer simply sat there.
- **A registered hook is not a mounted hook, and nothing used to say so.**
  `critical_hooks.js` accepts any name; only a `phx-hook=` in a template puts it
  to work. `SurfacePresenceHook` was registered, imported and bundled for a
  whole wave while no template carried its name — every click asking another tab
  to come forward waited 300 ms for an answer from a hook that had never run.
  The guard now fails on a registered name that appears in no template, which
  found four more dead hooks in the eager bundle and one, `ToolbarGroupHook`,
  whose markup was rendered with nothing bound to it. The override set in the
  guard is empty and an entry costs a written reason.
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

### 15.1 What may live inside a hook (CI-enforced)

§15 governs how a hook is *loaded*; this governs what may live *inside* one. A hook is a thin
binding, nothing more. It may contain exactly four things:

1. binding and unbinding DOM listeners,
2. registering `handleEvent` callbacks,
3. calling `pushEvent` / `pushEventTo`,
4. creating and destroying a controller from `lib/`, handing it `this.el` and ports.

Reading `this.el.dataset` and passing it on counts as part of (4). Everything else — any `if`
over domain state, any calculation, any state machine — belongs in a module under `js/lib/` that
knows nothing about LiveView and can therefore be tested without one. Three shapes cover all of it:

- **Pure module** (`js/lib/<area>/<name>.js`) — decisions, maths, transforms. No DOM, no timers,
  no `this`. Named exports with JSDoc `@param`/`@returns`, the way domain functions carry `@spec`.
- **Controller** (`js/lib/<area>/<name>.js`) — DOM, timers, observers or a connection, but still
  no LiveView. A `createX(el, ports)` factory returning `mount`/`reconcile`/`destroy`, whose
  `destroy` is the exact mirror of `mount`. State lives in the closure, never at module scope.
- **Hook** (`js/hooks/<area>/<name>_hook.js`) — `createXHook(deps = {})` + `export default
  createXHook()`, so a test injects a double without mocking a module.

The reference implementation is `hooks/games/retro_game_canvas_hook.js` with
`lib/games/engine_loader.js`; copy that pair when in doubt. When a hook grows past a binding, it
is a signal the logic is trapped in the wrong layer.

**The operational test:** if a test needs `Object.create(Hook)` or reaches for a `hook._private`
method, the logic is in the wrong place. Move it to the `lib/` module it belongs to and test it
there.

**State a hook writes over server markup needs `phx-update="ignore"` and an id.**
The server renders a region, the hook writes a class and a text into it, and the
next LiveView patch of that subtree restores the template over both — through
`setAttribute("class", …)`, so a `classList` spy sees nothing and the write
looks like it worked for the six milliseconds before the patch. Either give the
region the flag and let the browser own it, or push the state to the server and
let it render; there is no third arrangement that survives a patch.

**Enforcement** (`enforce_hooks_contract.cjs`, via `make lint.hooks`), each a ratchet that only
falls: a 200-line hook budget; a forbidden-primitive list in `js/hooks/`
(`new RTCPeerConnection`, canvas `getContext`, `ResizeObserver`, `MutationObserver`,
`navigator.mediaDevices`, `navigator.clipboard` — each is a controller in disguise); a ceiling on
`hook._private` calls in `test/hooks/`; and no mutable module scope (`let`/`var` at top level) in
`js/lib/`. A current violator carries a named override pointing at the package that resolves it,
or — for the WebRTC hooks, whose residual is irreducible live-`RTCPeerConnection` and tile-DOM
plumbing — a standing override with a written reason. `assets/js/SURFACE.txt` +
`scripts/surface_snapshot.sh --check` pins the observable surface (event names, `data-*` keys) so
a move that renames one is caught before commit. The refactor that introduced all this is logged
in `docs/refactor/`.

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
- **Six reserved first segments, and none of them may collide with a locale tag**: `connect`,
  `chat`, `join`, `call`, `space`, `p2p`, `play`. Adding a surface adds one, and the check is
  against `config/i18n_locales.exs`, which is the only list of locale segments.
- **Every *public* route goes inside the locale loop, not only in the unprefixed scope.**
  `/join/:slug` shipped registered once and answered `NoRouteError` on `/pt-BR/join/…`. Sixteen
  tests missed it because they all built the path the way the code did — a test that exercises
  only the path its own code constructs tests nothing. Anything that reads a public path back
  (`App.ReturnTo`, `ShareLinkRef`) strips the prefix using
  `SEO.localized_locale_segments/0`, the same list the router loops over.
- **`/join/:slug` is the only public surface address, and it is `noindex` whenever the slug does
  not resolve to a live room.** The app addresses inherit `SEO.noindex_content/0`: they are one
  person's screen, not a page.
- **hreflang is reciprocal.** Sitemap and `<head>` alternates list every locale version of a
  page reciprocally; `x-default` points at the English unprefixed URL. Canonical URLs on
  localized pages are self-referencing clean paths.
- **Public pages avoid the full app bundle.** Prefer server-rendered / CSS-first behavior on
  landing and help pages; only actual app pages load `app.js`.

---

## 17. Background work is Oban, and Oban is observable

**→ [`guide/background-jobs.md`](guide/background-jobs.md)** — Read when adding or changing an Oban worker, queue, recurrence, or its observability.


---

## 18. Mobile & touch

**→ [`guide/mobile-touch.md`](guide/mobile-touch.md)** — Read when changing viewport behaviour, touch handling, or a dialog on mobile.

---

## 19. Surfaces: an address of their own

**→ [`guide/surfaces.md`](guide/surfaces.md)** — Read when adding a screen that can live in a browser tab of its own, changing how one is reached, or debugging why a surface behaves differently inside the chat than at its own address. The conference and the P2P session have **no** mount inside the chat: the only door each has is the card the chat writes into the conversation when the room is created.


