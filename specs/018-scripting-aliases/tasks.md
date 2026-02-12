# Tasks: Scripting & Aliases (Simplified)

**Input**: Design documents from `/specs/018-scripting-aliases/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/domain-modules.md, quickstart.md

**Tests**: TDD approach per Constitution Principle IV. Tests are written first for all domain modules and command handlers.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story (US1–US5)
- Exact file paths included in all descriptions

## Path Conventions

- **Domain layer**: `apps/retro_hex_chat/lib/retro_hex_chat/`
- **Web layer**: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/`
- **Domain tests**: `apps/retro_hex_chat/test/retro_hex_chat/`
- **Web tests**: `apps/retro_hex_chat_web/test/retro_hex_chat_web/`
- **Migrations**: `apps/retro_hex_chat/priv/repo/migrations/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Database migrations, value objects, and shared modules that all user stories depend on

- [X] T001 [P] Create migration for `aliases` table in `apps/retro_hex_chat/priv/repo/migrations/YYYYMMDDHHMMSS_create_aliases.exs` — FK to `registered_nicks`, fields: `owner_nickname`, `name` (string 30), `expansion` (string 500), `position` (integer), timestamps. Index on `owner_nickname`, unique index on `lower(owner_nickname), lower(name)`. Run `mix ecto.migrate`.
- [X] T002 [P] Create migration for `custom_menu_items` table in `apps/retro_hex_chat/priv/repo/migrations/YYYYMMDDHHMMSS_create_custom_menu_items.exs` — FK to `registered_nicks`, fields: `owner_nickname`, `menu_type` (string 10), `label` (string 50), `command` (string 500), `position` (integer), timestamps. Index on `owner_nickname`, unique index on `lower(owner_nickname), menu_type, lower(label)`. Run `mix ecto.migrate`.
- [X] T003 [P] Create migration for `autorespond_rules` table in `apps/retro_hex_chat/priv/repo/migrations/YYYYMMDDHHMMSS_create_autorespond_rules.exs` — FK to `registered_nicks`, fields: `owner_nickname`, `trigger_event` (string 15), `channel_filter` (string 50, nullable), `command` (string 500), `enabled` (boolean, default true), `position` (integer), timestamps. Index on `owner_nickname`. Run `mix ecto.migrate`.
- [X] T004 [P] Create Ecto schema `RetroHexChat.Chat.Schemas.AliasEntry` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/alias_entry.ex` — table `aliases`, changeset validates required `[:owner_nickname, :name, :expansion, :position]`, length validations for name (max 30) and expansion (max 500).
- [X] T005 [P] Create Ecto schema `RetroHexChat.Chat.Schemas.CustomMenuItem` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/custom_menu_item.ex` — table `custom_menu_items`, changeset validates required fields, inclusion of `menu_type` in `["nicklist", "channel"]`, length validations for label (max 50) and command (max 500).
- [X] T006 [P] Create Ecto schema `RetroHexChat.Chat.Schemas.AutoRespondRule` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/auto_respond_rule.ex` — table `autorespond_rules`, changeset validates required `[:owner_nickname, :trigger_event, :command, :position]`, inclusion of `trigger_event` in `["on_join", "on_part", "on_nick_change"]`, length validations.
- [X] T007 [P] Create value object `RetroHexChat.Chat.AliasEntry` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/alias_entry.ex` — struct with `name`, `expansion`, `position` fields. `new/1` function accepting keyword opts. `@type t` and `@spec` on all public functions.
- [X] T008 [P] Create value object `RetroHexChat.Chat.CustomMenuItem` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/custom_menu_item.ex` — struct with `menu_type`, `label`, `command`, `position` fields. `new/1` accepting keyword opts.
- [X] T009 [P] Create value object `RetroHexChat.Chat.AutoRespondRule` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/auto_respond_rule.ex` — struct with `id`, `trigger_event`, `channel_filter`, `command`, `enabled`, `position` fields. `new/1` accepting keyword opts.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared variable expansion engine and Session struct updates that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [X] T010 Write tests for `AliasExpander` in `apps/retro_hex_chat/test/retro_hex_chat/chat/alias_expander_test.exs` — test `expand/3` with: positional args `$1`–`$9` substitution, `$nick` and `$chan` substitution, missing args replaced with empty string, `$chan` with nil channel → empty string, `$$` escaped to literal `$`, no variable → passthrough. Test `validate_expansion/1`: rejects `|`, `&&`, `;`, newlines; accepts clean expansions. Test `contains_chaining?/1`. Use `@tag :unit`, `async: true`.
- [X] T011 Implement `RetroHexChat.Chat.AliasExpander` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/alias_expander.ex` — pure functions: `expand/3` (template, args, context), `validate_expansion/1`, `contains_chaining?/1`. All with `@spec`. See contracts/domain-modules.md for full API. Make tests from T010 pass.
- [X] T012 Add 3 new fields to `RetroHexChat.Accounts.Session` in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex` — add `aliases: map()`, `custom_menus: map()`, `autorespond_rules: map()` to `@type t`, `defstruct`, and `new/1` (initialize with `AliasList.new()`, `CustomMenus.new()`, `AutoRespondRules.new()`). Add getter/setter pairs: `get_aliases/1`, `set_aliases/2`, `get_custom_menus/1`, `set_custom_menus/2`, `get_autorespond_rules/1`, `set_autorespond_rules/2`. Add required aliases to module imports.

**Checkpoint**: Foundation ready — AliasExpander available, Session struct updated. User story implementation can begin.

---

## Phase 3: User Story 1 — Alias Creation and Expansion (Priority: P1) MVP

**Goal**: Users can create aliases with variable expansion and invoke them from chat input. Aliases intercept commands before built-in registry lookup. Persistence for registered users.

**Independent Test**: Create alias `/hi` → `/me says hello!` via `/alias add`, type `/hi` in channel, verify action message appears.

### Tests for User Story 1

- [X] T013 [P] [US1] Write unit tests for `AliasList` in `apps/retro_hex_chat/test/retro_hex_chat/chat/alias_list_test.exs` — test `new/0`, `add_entry/3` (success, duplicate, invalid name, expansion too long, command chaining rejection, list full at 50), `remove_entry/2` (success, not found), `update_entry/3`, `find_entry/2` (case-insensitive), `entries/1` ordering, `shadows_builtin?/1`. Use `@tag :unit`, `async: true`.
- [X] T014 [P] [US1] Write unit tests for `Alias` command handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/alias_test.exs` — test `execute/2` for: no args → `:ui_action :open_alias_dialog`, `["add", "hi", "/me", "says", "hello"]` → `:ui_action :alias_added`, `["remove", "hi"]` → `:ui_action :alias_removed`, `["list"]` → `:system` message. Test `validate/1` always returns `:ok`. Test `help/0` returns expected map. Use `@tag :unit`, `async: true`.
- [X] T015 [P] [US1] Write integration tests for alias persistence in `apps/retro_hex_chat/test/retro_hex_chat/chat/alias_list_test.exs` (add to same file, separate `describe` block) — test `save/2` persists to DB, `load/1` retrieves correctly, save-then-load round-trip, load with no data returns `{:error, :not_found}`. Use `@tag :integration`, `async: true`, `use RetroHexChat.DataCase`.

### Implementation for User Story 1

- [X] T016 [US1] Implement `RetroHexChat.Chat.AliasList` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/alias_list.ex` — follow PerformList/Favorites pattern. Functions: `new/0`, `add_entry/3`, `remove_entry/2`, `update_entry/3`, `find_entry/2`, `entries/1`, `shadows_builtin?/1`, `save/2`, `load/1`. Max 50 aliases per user. Case-insensitive name matching. Validate name format `[a-zA-Z0-9_-]`. Validate expansion via `AliasExpander.validate_expansion/1`. Make tests from T013 and T015 pass.
- [X] T017 [US1] Implement `/alias` command handler `RetroHexChat.Commands.Handlers.Alias` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/alias.ex` — implement Handler behaviour. `execute([], _)` → open dialog. `execute(["add", name | parts], _)` → return `:ui_action :alias_added` with name and expansion. `execute(["remove", name], _)` → `:ui_action :alias_removed`. `execute(["list"], _)` → `:system` with formatted list. `help/0` with syntax, description, examples. Make tests from T014 pass.
- [X] T018 [US1] Register `/alias` command in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex` — add `"alias" => RetroHexChat.Commands.Handlers.Alias` to the `@commands` map.
- [X] T019 [US1] Implement alias interception in `dispatch_command/4` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — before calling `Dispatcher.dispatch/3`, check if `command_name` matches a user alias via `AliasList.find_entry/2`. If found: expand variables via `AliasExpander.expand/3`, re-parse via `Parser.parse/1`, and recursively dispatch (tracking depth, max 5). On recursion detection, show error via `stream_insert(:chat_messages, ...)`. If not found: fall through to `Dispatcher.dispatch/3`. Add `alias_depth` parameter (default 0) to the recursive helper.
- [X] T020 [US1] Add alias CRUD event handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — handle `:alias_added` UI action (add to session aliases, check `shadows_builtin?`, show warning if shadowing, persist for registered users), `:alias_removed` (remove from session, persist), dialog events (`open_alias_dialog`, `close_alias_dialog`, `alias_select`, `alias_add`, `alias_edit`, `alias_save`, `alias_delete`). Add `maybe_persist_aliases/2` following existing pattern. Add aliases to `load_persisted_data/2`.
- [X] T021 [US1] Initialize `user_timers` and `autorespond_cooldowns` socket assigns in `mount/3` of `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — add `user_timers: %{}`, `autorespond_cooldowns: %{}`, and all dialog visibility assigns for alias/custom menus/auto-respond dialogs (e.g., `show_alias_dialog: false`, `alias_dialog_selected: nil`, etc.).

**Checkpoint**: Alias system fully functional — create, expand, persist. MVP complete.

---

## Phase 4: User Story 5 — Alias Editor Dialog UI (Priority: P2)

**Goal**: Windows 98-styled Alias Editor dialog with full CRUD operations, accessible via Tools menu and `/alias` command.

**Independent Test**: Open dialog via Tools > Alias Editor, add/edit/remove aliases visually, verify changes take effect in alias expansion.

### Tests for User Story 5

- [ ] T022 [P] [US5] Write LiveView tests for Alias Editor dialog in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_alias_test.exs` — test dialog opens via event, shows alias list, add alias flow, edit alias flow, delete alias flow, validation errors displayed, builtin shadowing warning displayed, close dialog. Use `@tag :liveview`, Floki for HTML assertions.

### Implementation for User Story 5

- [X] T023 [US5] Create `RetroHexChatWeb.Components.AliasDialog` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/alias_dialog.ex` — 98.css dialog with: title bar "Alias Editor", list of aliases (name + expansion columns), Add/Edit/Remove/Close buttons, inline add/edit form (name field, expansion field, Save/Cancel). Props: `visible`, `aliases`, `selected_alias`, `editing_mode`, `draft_name`, `draft_expansion`, `warning_message`, `error_message`. Follow existing dialog patterns (PerformDialog, FavoriteDialog).
- [X] T024 [US5] Add "Alias Editor" entry to Tools menu in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/menu_bar.ex` — add `<div class="menu-dropdown-item" data-testid="menu-alias-editor" phx-click="open_alias_dialog">Alias Editor</div>` to the Tools dropdown. Position after existing items.
- [X] T025 [US5] Render AliasDialog component in ChatLive template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — add `<RetroHexChatWeb.Components.AliasDialog.alias_dialog ... />` to the template section where other dialogs are rendered. Pass all required assigns. Make LiveView tests from T022 pass.

**Checkpoint**: Alias Editor dialog complete — full visual CRUD for aliases.

---

## Phase 5: User Story 2 — Timer Commands (Priority: P2)

**Goal**: Users can schedule one-shot and repeating commands via `/timer`. Timers are session-only, managed via Process.send_after.

**Independent Test**: Type `/timer test 5 /me timer fired!`, wait 5 seconds, verify action message. Type `/timer list` to see active timers. Type `/timer stop test` to cancel.

### Tests for User Story 2

- [X] T026 [P] [US2] Write unit tests for `TimerManager` in `apps/retro_hex_chat/test/retro_hex_chat/chat/timer_manager_test.exs` — test `parse_timer_args/1` for: one-shot `["remind", "60", "/me", "hi"]`, repeat `["hb", "repeat", "30", "/me", "alive"]`, list `["list"]`, stop `["stop", "hb"]`, invalid args. Test `validate_create/5`: max 5 timers, invalid name, interval bounds (min 1 one-shot, min 10 repeat, max 86400). Test `clamp_interval/2`: repeat below 10 → clamp to 10 with notice. Test `format_timer_list/1` output formatting. Use `@tag :unit`, `async: true`.
- [X] T027 [P] [US2] Write unit tests for `Timer` command handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/timer_test.exs` — test `execute/2`: no args → help system message, `["list"]` → `:ui_action :timer_list`, `["stop", "name"]` → `:ui_action :timer_stop`, `["name", "60", "/me", "hi"]` → `:ui_action :timer_create` with parsed data. Test `help/0`. Use `@tag :unit`, `async: true`.

### Implementation for User Story 2

- [X] T028 [US2] Implement `RetroHexChat.Chat.TimerManager` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/timer_manager.ex` — pure functions: `parse_timer_args/1`, `validate_create/5`, `clamp_interval/2`, `format_timer_list/1`. Name validation: `[a-zA-Z0-9_-]`, max 30 chars. Interval: min 1s one-shot, min 10s repeat, max 86400s. Max 5 concurrent timers. Human-readable error strings. Make tests from T026 pass.
- [X] T029 [US2] Implement `/timer` command handler `RetroHexChat.Commands.Handlers.Timer` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/timer.ex` — implement Handler behaviour. Delegates parsing to `TimerManager.parse_timer_args/1`. Returns `:ui_action` for create/list/stop, `:system` for help. Make tests from T027 pass.
- [X] T030 [US2] Register `/timer` command in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex` — add `"timer" => RetroHexChat.Commands.Handlers.Timer`.
- [X] T031 [US2] Implement timer lifecycle in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — handle `:timer_create` UI action: validate via `TimerManager.validate_create/5`, clamp interval, cancel existing timer with same name if present (`Process.cancel_timer`), schedule via `Process.send_after(self(), {:user_timer_fired, name}, interval * 1000)`, store in `socket.assigns.user_timers` map. Handle `:timer_stop`: cancel timer ref, remove from map, show confirmation. Handle `:timer_list`: format via `TimerManager.format_timer_list/1`, show as system messages.
- [X] T032 [US2] Implement `handle_info({:user_timer_fired, name}, socket)` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — when timer fires: look up timer in `user_timers` map, expand command via `AliasExpander.expand/3` with current context, parse via `Parser.parse/1`, dispatch via `dispatch_command`. For `:repeat` type: schedule next fire and update timer ref. For `:once` type: remove from map. Handle case where timer was already cancelled (timer not in map → ignore).

**Checkpoint**: Timer system complete — one-shot, repeat, list, stop all working. Session-only (dies on disconnect).

---

## Phase 6: User Story 3 — Custom Popup Menu Items (Priority: P3)

**Goal**: Users add custom items to nicklist and channel context menus. Items execute commands with variable expansion.

**Independent Test**: Add custom nicklist item "Greet" → `/notice $1 Welcome!`, right-click nick, click "Greet", verify notice sent.

### Tests for User Story 3

- [X] T033 [P] [US3] Write unit tests for `CustomMenus` in `apps/retro_hex_chat/test/retro_hex_chat/chat/custom_menus_test.exs` — test `new/0`, `add_entry/4` (success, duplicate label, menu full at 10, invalid label, command too long), `remove_entry/3`, `update_entry/5`, `entries_for/2` filtering by menu_type with ordering. Test persistence: `save/2` and `load/1` round-trip. Use `@tag :unit` for pure functions, `@tag :integration` for persistence, `async: true`.
- [X] T034 [P] [US3] Write unit tests for `Popups` command handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/popups_test.exs` — test `execute([], _)` → `:ui_action :open_custom_menus_dialog`, `help/0`, `validate/1`. Use `@tag :unit`, `async: true`.

### Implementation for User Story 3

- [X] T035 [US3] Implement `RetroHexChat.Chat.CustomMenus` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/custom_menus.ex` — follow AliasList pattern. `new/0`, `add_entry/4`, `remove_entry/3`, `update_entry/5`, `entries_for/2`, `save/2`, `load/1`. Max 10 per menu_type. Case-insensitive label uniqueness per menu_type per owner. Make tests from T033 pass.
- [X] T036 [US3] Implement `/popups` command handler `RetroHexChat.Commands.Handlers.Popups` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/popups.ex` — simple handler: no args → open dialog. Make tests from T034 pass.
- [X] T037 [US3] Register `/popups` command in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex` — add `"popups" => RetroHexChat.Commands.Handlers.Popups`.
- [X] T038 [US3] Create `RetroHexChatWeb.Components.CustomMenusDialog` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/custom_menus_dialog.ex` — 98.css dialog with two tabs (Nicklist, Channel). Each tab shows list of items (label + command), Add/Edit/Remove buttons, inline form (label field, command field). Follow PerformDialog tabbed pattern.
- [X] T039 [US3] Add custom menu items to nicklist context menu in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/context_menu.ex` — after existing menu items, add a `<li class="separator">` divider followed by a `:for` loop rendering custom nicklist items from `@custom_nicklist_items`. Each item: `phx-click="custom_menu_execute"`, `phx-value-command={item.command}`, `phx-value-target={@target_nick}`.
- [X] T040 [US3] Add custom menu items to channel context menu in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/treebar_context_menu.ex` — after existing "Add to Favorites" item, add separator + custom channel items from `@custom_channel_items`. Each item: `phx-click="custom_menu_execute"`, `phx-value-command={item.command}`, `phx-value-target={@channel}`.
- [X] T041 [US3] Add custom menu event handlers and dialog wiring in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — handle `custom_menu_execute` event: expand command via `AliasExpander.expand/3` with `$1` = target, parse and dispatch. Handle dialog CRUD events for custom menus. Add `maybe_persist_custom_menus/2`. Add custom menus to `load_persisted_data/2`. Pass `custom_nicklist_items` and `custom_channel_items` to context menu components via assigns. Add "Custom Menus" to Tools menu in `menu_bar.ex`. Render CustomMenusDialog in template.

**Checkpoint**: Custom popup menus complete — items appear in context menus, execute commands with variable expansion.

---

## Phase 7: User Story 4 — Auto-Respond Rules (Priority: P4)

**Goal**: Users create event-triggered auto-respond rules (on join, on part, on nick change) with channel filtering and rate limiting.

**Independent Test**: Create rule "on join #test → /notice $nick Welcome!", have another user join #test, verify notice sent. Verify own joins don't trigger. Verify rate limit (rejoin within 60s → no response).

### Tests for User Story 4

- [X] T042 [P] [US4] Write unit tests for `AutoRespondRules` in `apps/retro_hex_chat/test/retro_hex_chat/chat/auto_respond_rules_test.exs` — test `new/0`, `add_entry/4` (success, list full at 10, invalid trigger, command too long), `remove_entry/2`, `update_entry/3`, `toggle_entry/2`, `matching_rules/3` (filter by event type, channel filter match, global rules, disabled rules excluded). Test persistence `save/2` and `load/1` round-trip. Use `@tag :unit` / `@tag :integration`, `async: true`.
- [X] T043 [P] [US4] Write unit tests for `AutoRespond` command handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/auto_respond_test.exs` — test `execute/2`: no args → `:ui_action :open_autorespond_dialog`, `["add", "on_join", "#test", "/notice", "$nick", "hi"]` → `:ui_action :autorespond_added`, `["remove", "0"]` → `:ui_action :autorespond_removed`, `["list"]` → `:system` message. Use `@tag :unit`, `async: true`.

### Implementation for User Story 4

- [X] T044 [US4] Implement `RetroHexChat.Chat.AutoRespondRules` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/auto_respond_rules.ex` — follow AliasList pattern. `new/0`, `add_entry/4`, `remove_entry/2`, `update_entry/3`, `toggle_entry/2`, `matching_rules/3`, `entries/1`, `save/2`, `load/1`. Max 10 rules. Trigger validation for `:on_join`, `:on_part`, `:on_nick_change`. Channel filter validation (must start with `#` if present). Make tests from T042 pass.
- [X] T045 [US4] Implement `/autorespond` command handler `RetroHexChat.Commands.Handlers.AutoRespond` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/auto_respond.ex` — Handler behaviour. Subcommands: `add <trigger> [channel] <command>`, `remove <position>`, `list`, no args → open dialog. Make tests from T043 pass.
- [X] T046 [US4] Register `/autorespond` command in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex` — add `"autorespond" => RetroHexChat.Commands.Handlers.AutoRespond`.
- [X] T047 [US4] Create `RetroHexChatWeb.Components.AutoRespondDialog` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/auto_respond_dialog.ex` — 98.css dialog with: list of rules (trigger, channel, command, enabled checkbox), Add/Edit/Remove/Close buttons, add/edit form with trigger event dropdown (on join/on part/on nick change), channel filter field, command field. Follow existing dialog patterns.
- [X] T048 [US4] Implement `maybe_fire_autorespond/4` helper and hook into PubSub event handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — create helper function `maybe_fire_autorespond(socket, event_type, channel, event_data)` that: gets rules from session, calls `AutoRespondRules.matching_rules/3`, skips if triggering nick == own nick (FR-029), checks `autorespond_cooldowns` map for rate limit (60s per rule+nick combo, FR-030), expands command via `AliasExpander.expand/3` with `$nick` = triggering nick and `$chan` = channel, parses and dispatches (marked as auto-generated to prevent cascading, FR-031), updates cooldowns map. Add call to `maybe_fire_autorespond` at end of `handle_info({:user_joined, ...})`, `handle_info({:user_left, ...})`, and `handle_info({:nick_changed, ...})` handlers.
- [X] T049 [US4] Add auto-respond dialog CRUD handlers and persistence in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — handle dialog events (open, close, add, edit, save, delete, toggle). Add `maybe_persist_autorespond_rules/2`. Add auto-respond rules to `load_persisted_data/2`. Add "Auto-Respond" to Tools menu in `menu_bar.ex`. Render AutoRespondDialog in template.

**Checkpoint**: Auto-respond complete — event-triggered rules with rate limiting, channel filtering, and cascading prevention.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, final validation, code quality

- [X] T050 [P] Add help topics for `/alias` command and Aliases feature in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` — command topic with syntax (`/alias`, `/alias add <name> <expansion>`, `/alias remove <name>`, `/alias list`), examples, variable reference ($1–$9, $nick, $chan). Feature topic explaining alias system, variable expansion, recursion detection, builtin shadowing. Add "See Also" cross-references to related topics.
- [X] T051 [P] Add help topics for `/timer` command and Timers feature in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` — command topic with syntax for one-shot, repeat, list, stop. Feature topic explaining timer lifecycle, session-only behavior, limits (5 max, 10s min repeat, 24h max interval).
- [X] T052 [P] Add help topics for `/popups` command and Custom Menus feature in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` — command topic with syntax. Feature topic explaining nicklist/channel menu customization, variable expansion in menu commands, 10-per-type limit.
- [X] T053 [P] Add help topics for `/autorespond` command and Auto-Respond feature in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` — command topic with syntax for add, remove, list. Feature topic explaining trigger events, channel filters, rate limiting (60s cooldown), own-action exclusion, cascading prevention.
- [ ] T054 Run full CI-equivalent validation pipeline: `mix compile --warnings-as-errors`, then in parallel: `mix format --check-formatted`, `mix credo --strict`, `mix test --include e2e`, `mix dialyzer`. Fix any issues found.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — all 9 tasks parallelizable
- **Phase 2 (Foundational)**: Depends on Phase 1 (value objects needed by AliasExpander and Session)
- **Phase 3 (US1 — Aliases)**: Depends on Phase 2 (AliasExpander, Session fields)
- **Phase 4 (US5 — Alias Dialog)**: Depends on Phase 3 (alias event handlers must exist)
- **Phase 5 (US2 — Timers)**: Depends on Phase 2 (AliasExpander for timer command expansion)
- **Phase 6 (US3 — Custom Menus)**: Depends on Phase 2 (AliasExpander for menu command expansion)
- **Phase 7 (US4 — Auto-Respond)**: Depends on Phase 2 (AliasExpander for auto-respond command expansion)
- **Phase 8 (Polish)**: Depends on all user story phases being complete

### User Story Dependencies

- **US1 (Aliases)**: Requires Foundational phase only
- **US5 (Alias Dialog)**: Requires US1 (dialog manages aliases that US1 implements)
- **US2 (Timers)**: Requires Foundational phase only — can run in parallel with US1
- **US3 (Custom Menus)**: Requires Foundational phase only — can run in parallel with US1/US2
- **US4 (Auto-Respond)**: Requires Foundational phase only — can run in parallel with US1/US2/US3

### Within Each User Story

- Tests written FIRST, verified to FAIL
- Domain modules before command handlers
- Command handlers registered before LiveView integration
- LiveView event handlers before UI components
- UI components before template rendering

### Parallel Opportunities

- Phase 1: ALL 9 tasks (T001–T009) can run in parallel (different files)
- Phase 2: T010 and T012 can run in parallel (different files), T011 depends on T010
- Within each user story: test tasks marked [P] can run in parallel
- US1, US2, US3, US4 can all start after Phase 2 (if staffed for parallel development)
- Phase 8: All 4 help topic tasks (T050–T053) can run in parallel

---

## Parallel Example: Phase 1 Setup

```
# All 9 tasks launch simultaneously:
T001: Migration — aliases table
T002: Migration — custom_menu_items table
T003: Migration — autorespond_rules table
T004: Ecto schema — AliasEntry
T005: Ecto schema — CustomMenuItem
T006: Ecto schema — AutoRespondRule
T007: Value object — AliasEntry
T008: Value object — CustomMenuItem
T009: Value object — AutoRespondRule
```

## Parallel Example: User Story 1 Tests

```
# All 3 test tasks launch simultaneously:
T013: Unit tests — AliasList
T014: Unit tests — Alias command handler
T015: Integration tests — alias persistence
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (migrations, schemas, value objects)
2. Complete Phase 2: Foundational (AliasExpander, Session fields)
3. Complete Phase 3: User Story 1 (alias CRUD, expansion, interception, persistence)
4. Complete Phase 4: User Story 5 (Alias Editor dialog)
5. **STOP and VALIDATE**: Create alias, type it, verify expansion works
6. Run CI validation pipeline (T054)

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. US1 + US5 → Aliases working with dialog (MVP!)
3. US2 → Timers working (independent of aliases but can invoke them)
4. US3 → Custom menus working (uses AliasExpander)
5. US4 → Auto-respond working (uses AliasExpander + PubSub events)
6. Polish → Help docs + final validation

### Suggested Execution Order (Single Developer)

Phase 1 → Phase 2 → Phase 3 (US1) → Phase 4 (US5) → Phase 5 (US2) → Phase 6 (US3) → Phase 7 (US4) → Phase 8

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Constitution Principle IV (TDD) enforced: test tasks precede implementation
- All command handlers implement `Handler` behaviour (Principle V)
- All public functions have `@spec` (Principle VI)
- LiveView delegates all logic to domain modules (Principle VII)
- 98.css styling on all dialogs (Principle VIII)
- Help topics for all commands and features (Principle XI)
