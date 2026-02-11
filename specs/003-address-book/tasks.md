# Tasks: Address Book

**Input**: Design documents from `/specs/003-address-book/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/liveview-events.md

**Tests**: Included per Constitution Principle IV (TDD is non-negotiable). Tests are written before/alongside implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Domain**: `apps/retro_hex_chat/lib/retro_hex_chat/`
- **Domain tests**: `apps/retro_hex_chat/test/retro_hex_chat/`
- **Web**: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/`
- **Web tests**: `apps/retro_hex_chat_web/test/retro_hex_chat_web/`
- **Migrations**: `apps/retro_hex_chat/priv/repo/migrations/`
- **JS**: `apps/retro_hex_chat_web/assets/js/`

---

## Phase 1: Setup (Migration)

**Purpose**: Create database tables for contacts and nick color overrides

- [x] T001 Create migration for `contacts` and `nick_color_overrides` tables in `apps/retro_hex_chat/priv/repo/migrations/TIMESTAMP_create_address_book_tables.exs`. Follow the notify_list_entries pattern: FK to registered_nicks with ON DELETE CASCADE, case-insensitive unique indexes using `lower()`, owner index. Contacts table: owner_nickname (FK, varchar 16), contact_nickname (varchar 16, NOT NULL), note (varchar 200, nullable), first_contact_date (utc_datetime_usec, NOT NULL), timestamps. Nick color overrides table: owner_nickname (FK, varchar 16), target_nickname (varchar 16, NOT NULL), color_index (integer, NOT NULL), timestamps. Run migration with `mix ecto.migrate`.

---

## Phase 2: Foundational (Domain Layer)

**Purpose**: Core domain modules that MUST be complete before ANY user story UI work can begin

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Contact Domain

- [x] T002 [P] Create Contact struct with tests in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/contact.ex` and `apps/retro_hex_chat/test/retro_hex_chat/accounts/contact_test.exs`. Struct fields: contact_nickname (required, string), note (string | nil), first_contact_date (required, DateTime). Enforce keys: [:contact_nickname, :first_contact_date]. Implement `new/1` accepting keyword/map with defaults (note: nil, first_contact_date: DateTime.utc_now()). Add `@type t :: %__MODULE__{}` and `@spec` on new/1. Tests: new/1 with all fields, new/1 with defaults, enforce_keys validation. Tag tests `@tag :unit`.

- [x] T003 [P] Create ContactEntry Ecto schema in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/contact_entry.ex`. Schema for `contacts` table with fields: owner_nickname (string, max 16), contact_nickname (string, max 16), note (string, max 200), first_contact_date (utc_datetime_usec). Changeset validates required [:owner_nickname, :contact_nickname, :first_contact_date], validates length of owner_nickname (max 16), contact_nickname (max 16), note (max 200). Add `@type t :: %__MODULE__{}`.

- [x] T004 Create ContactList context module with in-memory CRUD in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/contact_list.ex` and unit tests in `apps/retro_hex_chat/test/retro_hex_chat/accounts/contact_list_test.exs`. Follow the NotifyList pattern exactly. Functions: `new/0` → `%{entries: []}`, `add_entry/3` (contact_list, owner_nickname, contact_nickname, note) → `{:ok, map} | {:error, :self_add | :duplicate | :list_full | :invalid_nickname}`, `remove_entry/2` (contact_list, contact_nickname) → `{:ok, map} | {:error, :not_found}`, `update_note/3` (contact_list, contact_nickname, note) → `{:ok, map} | {:error, :not_found}`, `sorted_entries/1` → sorted alphabetically by contact_nickname (case-insensitive), `count/1`, `full?/1` (max 100). All nickname comparisons case-insensitive via String.downcase. Validate nickname 1-16 chars, note max 200 chars. Tests: new/0, add success, add self error, add duplicate error, add list full (100), add invalid nickname (empty, >16 chars), remove success, remove not found, update_note success, update_note not found, sorted_entries alphabetical, count, full?. Tag unit tests `@tag :unit`.

- [x] T005 Add persistence functions to ContactList in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/contact_list.ex` and integration tests in `apps/retro_hex_chat/test/retro_hex_chat/accounts/contact_list_test.exs`. Functions: `save/2` (owner, contact_list) → delete all + insert all in transaction, `load/1` (owner) → `{:ok, map} | {:error, :not_found}`, `save_entry/2` (owner, Contact) → upsert single entry with case-insensitive lookup, `delete_entry/2` (owner, contact_nickname) → :ok. Follow NotifyList persistence pattern: fragment("lower(?)", field) for case-insensitive queries, Repo.transaction for save/2. Tests: save and load round-trip, save_entry upsert, delete_entry, load not_found, case-insensitive persistence. Tag `@tag :integration`.

### NickColor Domain

- [x] T006 [P] Create NickColor struct with tests in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/nick_color.ex` and `apps/retro_hex_chat/test/retro_hex_chat/accounts/nick_color_test.exs`. Struct fields: target_nickname (required, string), color_index (required, non_neg_integer 0..15). Enforce keys: [:target_nickname, :color_index]. Implement `new/1` accepting keyword/map. Add `@type t :: %__MODULE__{}` and `@spec`. Tests: new/1 with valid fields, enforce_keys validation. Tag `@tag :unit`.

- [x] T007 [P] Create NickColorEntry Ecto schema in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/nick_color_entry.ex`. Schema for `nick_color_overrides` table with fields: owner_nickname (string, max 16), target_nickname (string, max 16), color_index (integer). Changeset validates required [:owner_nickname, :target_nickname, :color_index], validates length of owner_nickname (max 16), target_nickname (max 16), validates color_index inclusion in 0..15. Add `@type t :: %__MODULE__{}`.

- [x] T008 Create NickColors context module with in-memory CRUD in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/nick_colors.ex` and unit tests in `apps/retro_hex_chat/test/retro_hex_chat/accounts/nick_colors_test.exs`. Follow the NotifyList pattern. Functions: `new/0` → `%{entries: []}`, `add_entry/3` (nick_colors, target_nickname, color_index) → `{:ok, map} | {:error, :duplicate | :list_full | :invalid_nickname | :invalid_color}`, `remove_entry/2` → `{:ok, map} | {:error, :not_found}`, `update_color/3` (nick_colors, target_nickname, color_index) → `{:ok, map} | {:error, :not_found | :invalid_color}`, `add_or_update/3` (nick_colors, target_nickname, color_index) → `{:ok, map} | {:error, ...}` (upsert for context menu), `color_for/2` (nick_colors, nickname) → hex string | nil (looks up override, returns hex from IRC_COLORS palette or nil), `sorted_entries/1` → sorted alphabetically by target_nickname, `count/1`, `full?/1` (max 50). Define `@irc_colors` module attribute with the 16 IRC color hex values (matching FormattingToolbar palette). Tests: new/0, add success, add duplicate, add list full (50), add invalid nickname, add invalid color (negative, 16+), remove success, remove not found, update_color success, update_color not found, update_color invalid, add_or_update add new, add_or_update update existing, color_for with override, color_for without override (nil), sorted_entries. Tag `@tag :unit`.

- [x] T009 Add persistence functions to NickColors in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/nick_colors.ex` and integration tests in `apps/retro_hex_chat/test/retro_hex_chat/accounts/nick_colors_test.exs`. Functions: `save/2`, `load/1`, `save_entry/2`, `delete_entry/2`. Same pattern as ContactList persistence (T005). Tests: save and load round-trip, save_entry upsert, delete_entry, load not_found, case-insensitive persistence, color_index preserved correctly. Tag `@tag :integration`.

### Session Extension

- [x] T010 Extend Session struct with contacts and nick_colors fields in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex`. Add fields: `contacts: nil` and `nick_colors: nil` to defstruct. Update `@type t` to include `contacts: map(), nick_colors: map()`. Update `new/1` to initialize `contacts: ContactList.new(), nick_colors: NickColors.new()`. Add accessor functions: `set_contacts/2`, `get_contacts/1`, `set_nick_colors/2`, `get_nick_colors/1`. Add `@spec` to all new functions. Update existing session tests if any break due to new fields.

**Checkpoint**: Domain layer complete — ContactList and NickColors have full CRUD, validation, and persistence. Session holds both in-memory. All domain tests passing.

---

## Phase 3: User Story 1 — Address Book Dialog Shell (Priority: P1) 🎯 MVP

**Goal**: Render the tabbed dialog with 98.css tab controls, Alt+B toggle, toolbar icon, and menu bar item

**Independent Test**: Press Alt+B → dialog opens with 4 tabs → switch tabs → close dialog

### Tests for US1

- [x] T011 [P] [US1] Write LiveView tests for dialog open/close/tab-switch in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/address_book_test.exs`. Tests: (1) Alt+B opens dialog with 4 tab headers visible, (2) clicking tab header switches tab content, (3) clicking close button closes dialog, (4) Alt+B toggles dialog closed, (5) Contacts tab is default when opening, (6) toolbar button toggles dialog, (7) switching tabs while open preserves dialog visibility. Use `render_keydown` for Alt+B simulation. Tag `@tag :liveview`.

### Implementation for US1

- [x] T012 [US1] Create AddressBookDialog component shell in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/address_book_dialog.ex`. Function component with attrs: `visible` (boolean), `active_tab` (string, default "contacts"). Render a centered dialog overlay (z-index 200, fixed position) with 98.css window styling. Implement 4-tab layout using `<menu role="tablist">` with `<li aria-selected={...}>` items for Contacts, Notify, Nick Colors, Control. Each tab header uses `phx-click="address_book_tab"` with `phx-value-tab`. Tab panel area (`<div role="tabpanel">`) shows content based on `@active_tab` using `:if`. Title bar: "Address Book" with close button (`phx-click="toggle_address_book"`). For now, each tab panel shows placeholder text ("Contacts tab", "Notify tab", etc.). Add `@spec` on the public function.

- [x] T013 [US1] Add Address Book assigns and toggle event handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`. Add to assign_defaults: `show_address_book: false`, `address_book_tab: "contacts"`, `contacts_selected: nil`, `nick_colors_selected: nil`, `show_contact_add_dialog: false`, `show_contact_edit_dialog: false`, `show_nick_color_add_dialog: false`, `show_nick_color_edit_dialog: false`, `show_context_color_picker: false`. Add `handle_event("toggle_address_book", ...)` that toggles `show_address_book` and resets `address_book_tab` to "contacts" when closing (also resets all sub-dialog assigns). Add `handle_event("address_book_tab", %{"tab" => tab}, ...)` that sets `address_book_tab` and closes any open sub-dialogs. Render `AddressBookDialog` component in template after the NotifyListWindow, passing `visible={@show_address_book}` and `active_tab={@address_book_tab}`.

- [x] T014 [US1] Add Alt+B handling to window_keydown in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`. In the existing `handle_event("window_keydown", ...)` handler (or create one if it doesn't exist), add a clause: when `key == "b" && altKey == true`, toggle the Address Book dialog. Use pattern matching on params: `%{"key" => "b", "altKey" => true}`. Ensure Alt+B works regardless of which element has focus (it's a window-level event).

- [x] T015 [P] [US1] Add Address Book button to toolbar in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/toolbar.ex`. Add a button labeled "Address Book" (or with an appropriate icon) with `phx-click="toggle_address_book"` and `data-testid="toolbar-address-book"`. Place it after existing toolbar buttons.

- [x] T016 [P] [US1] Add "Tools" menu with Address Book item to menu bar in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/menu_bar.ex`. Add a new "Tools" menu (between View and Help) with a single item: "Address Book" with `phx-click="toggle_address_book"`. Follow the existing menu dropdown pattern.

**Checkpoint**: Address Book dialog opens via Alt+B, toolbar, and menu. Four tabs visible with placeholder content. Dialog toggles on/off. All LiveView tests passing.

---

## Phase 4: User Story 2 — Contacts Tab (Priority: P2)

**Goal**: Full CRUD for contacts within the Address Book Contacts tab

**Independent Test**: Open Address Book → Add contact "Alice" with note → verify in list → edit note → remove → verify empty

### Tests for US2

- [x] T017 [P] [US2] Write LiveView tests for Contacts tab CRUD in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/address_book_test.exs`. Tests: (1) empty contacts shows "No contacts saved", (2) add contact success — appears in list with nickname, note, date, (3) add duplicate shows error, (4) add self shows error, (5) add with empty nickname shows error, (6) select contact enables Edit/Remove buttons, (7) edit note updates in list, (8) remove contact removes from list, (9) add contact full (100) shows error, (10) contacts sorted alphabetically. Tag `@tag :liveview`.

### Implementation for US2

- [x] T018 [US2] Implement Contacts tab content in AddressBookDialog component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/address_book_dialog.ex`. Add attrs: `contacts` (list, default []), `contacts_selected` (string, default nil), `show_contact_add_dialog` (boolean), `show_contact_edit_dialog` (boolean). Render Contacts tab panel with: (1) toolbar row with Add/Edit/Remove buttons (Edit/Remove disabled when no selection), (2) sunken-panel with scrollable table (Nickname | Notes | First Contact Date columns), (3) empty state "No contacts saved" when list empty, (4) row click `phx-click="contact_select"` with `phx-value-nickname`, (5) selected row highlighted in blue. Buttons: Add → `phx-click="contact_add_dialog"`, Edit → `phx-click="contact_edit_dialog"`, Remove → `phx-click="contact_remove"`.

- [x] T019 [US2] Implement add/edit contact dialogs in AddressBookDialog component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/address_book_dialog.ex`. Add dialog (rendered with `:if={@show_contact_add_dialog}`): form with nickname text input (max 16) and note textarea (max 200), OK button (`phx-submit="contact_add"`) and Cancel button (`phx-click="contact_add_cancel"`). Edit dialog (rendered with `:if={@show_contact_edit_dialog}`): form with note textarea only (pre-filled with current note), OK (`phx-submit="contact_edit"`) and Cancel (`phx-click="contact_edit_cancel"`). Both use dialog-overlay pattern matching NotifyListWindow's add/edit dialogs.

- [x] T020 [US2] Implement ChatLive event handlers for contact CRUD in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`. Handlers: `contact_select` → set contacts_selected, `contact_add_dialog` → show dialog, `contact_add_cancel` → hide dialog, `contact_add` → call ContactList.add_entry with session.nickname as owner, update session via Session.set_contacts, close dialog, push_status_message on error, `contact_edit_dialog` → show dialog, `contact_edit_cancel` → hide dialog, `contact_edit` → call ContactList.update_note, update session, close dialog, `contact_remove` → call ContactList.remove_entry, update session, clear contacts_selected. Each mutation calls `maybe_persist_contacts/2` helper (async Task.start save if identified). Pass `contacts={ContactList.sorted_entries(@session.contacts)}`, `contacts_selected={@contacts_selected}`, and dialog assigns to AddressBookDialog.

- [x] T021 [US2] Add ContactList persistence on NickServ identify in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`. In the existing NickServ identify success handler (where notify_list is loaded), add ContactList.load/1 call. On success, update session with Session.set_contacts. Add private `maybe_persist_contacts/2` helper following the `maybe_persist_notify_list/2` pattern: if session.identified, spawn Task.start to ContactList.save.

**Checkpoint**: Contacts tab fully functional — add, edit, remove contacts with validation. Persistence for registered users. All LiveView tests passing.

---

## Phase 5: User Story 3 — Notify Tab (Priority: P2)

**Goal**: Render existing notify list data inside the Address Book as an alternate UI with bidirectional sync

**Independent Test**: Open Address Book → Notify tab → Add buddy → verify in standalone Notify List window

### Tests for US3

- [x] T022 [P] [US3] Write LiveView tests for Notify tab in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/address_book_test.exs`. Tests: (1) Notify tab shows existing buddies from session.notify_list, (2) add buddy via Notify tab — appears in both Address Book and standalone NotifyListWindow, (3) remove buddy via Notify tab — disappears from both, (4) edit note via Notify tab — updated in both, (5) toggle auto-whois via Notify tab — reflected in both, (6) buddy added via standalone window is visible in Notify tab. Tag `@tag :liveview`.

### Implementation for US3

- [x] T023 [US3] Implement Notify tab content in AddressBookDialog component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/address_book_dialog.ex`. Add attrs: `notify_entries` (list), `notify_selected` (string), `show_notify_add_dialog` (boolean), `show_notify_edit_dialog` (boolean), `auto_whois` (boolean). Render Notify tab panel reusing the same layout pattern as NotifyListWindow: (1) toolbar with Add/Edit/Remove buttons and auto-whois checkbox, (2) sunken-panel with table (Nickname | Status | Notes | Last Seen columns), (3) online/offline status dots (green/grey), (4) empty state when no buddies. Wire all events to the SAME existing event names: `notify_add_dialog`, `notify_add_cancel`, `notify_add`, `notify_edit_dialog`, `notify_edit_cancel`, `notify_edit`, `notify_remove`, `notify_select`, `toggle_auto_whois`. This ensures changes in the Address Book Notify tab use the same handlers as the standalone window.

- [x] T024 [US3] Pass notify list data to AddressBookDialog in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`. Update the AddressBookDialog component call in the template to pass: `notify_entries={NotifyList.sorted_entries(@session.notify_list)}`, `notify_selected={@notify_selected}`, `show_notify_add_dialog={@show_notify_add_dialog}`, `show_notify_edit_dialog={@show_notify_edit_dialog}`, `auto_whois={@session.notify_list.settings.auto_whois}`. Since both Address Book Notify tab and standalone NotifyListWindow read from the same session.notify_list and use the same events, bidirectional sync is automatic.

**Checkpoint**: Notify tab displays same data as standalone window. All CRUD operations sync bidirectionally. All LiveView tests passing.

---

## Phase 6: User Story 4 — Nick Colors Tab + Override Integration (Priority: P3)

**Goal**: Full CRUD for nick color overrides plus propagation to all nickname displays

**Independent Test**: Open Nick Colors tab → Add "Alice" with red → verify Alice's nickname appears red in chat messages, nicklist, and notify list

### Tests for US4

- [x] T025 [P] [US4] Write LiveView tests for Nick Colors tab CRUD in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/address_book_test.exs`. Tests: (1) empty nick colors shows "No custom colors set. Nicknames use automatic colors.", (2) add nick color success — appears in list with nickname and color swatch, (3) add duplicate shows error, (4) add with invalid color shows error, (5) edit color updates in list, (6) remove color override removes from list, (7) color override applies to chat message nickname rendering, (8) removing override reverts to hash-based color. Tag `@tag :liveview`.

### Implementation for US4

- [x] T026 [US4] Implement Nick Colors tab content in AddressBookDialog component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/address_book_dialog.ex`. Add attrs: `nick_color_entries` (list), `nick_colors_selected` (string), `show_nick_color_add_dialog` (boolean), `show_nick_color_edit_dialog` (boolean). Render Nick Colors tab panel: (1) toolbar with Add/Edit/Remove buttons (Edit/Remove disabled when no selection), (2) sunken-panel with table (Nickname | Color columns), (3) color column shows a 16x16 color swatch + color name text, (4) empty state "No custom colors set. Nicknames use automatic colors.", (5) row click `phx-click="nick_color_select"` with `phx-value-nickname`, (6) selected row highlighted. Define `@irc_colors` module attribute (or import from NickColors) for color name/hex lookup.

- [x] T027 [US4] Implement add/edit nick color dialogs in AddressBookDialog component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/address_book_dialog.ex`. Add dialog: form with nickname text input (max 16) + 16-color picker grid (4x4 grid of color swatches, each with `phx-click` or radio input for selection). Use the IRC color palette matching FormattingToolbar. Selected color highlighted with border. OK (`phx-submit="nick_color_add"`) and Cancel (`phx-click="nick_color_add_cancel"`). Edit dialog: 16-color picker grid only (nickname shown as label, not editable), current color pre-selected. OK (`phx-submit="nick_color_edit"`) and Cancel (`phx-click="nick_color_edit_cancel"`).

- [x] T028 [US4] Implement ChatLive event handlers for nick color CRUD in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`. Handlers: `nick_color_select`, `nick_color_add_dialog`, `nick_color_add_cancel`, `nick_color_add` (call NickColors.add_entry, update session, rebuild nick_color_fn), `nick_color_edit_dialog`, `nick_color_edit_cancel`, `nick_color_edit` (call NickColors.update_color, update session, rebuild nick_color_fn), `nick_color_remove` (call NickColors.remove_entry, update session, rebuild nick_color_fn). Each mutation calls `maybe_persist_nick_colors/2` helper. Pass `nick_color_entries`, `nick_colors_selected`, and dialog assigns to AddressBookDialog.

- [x] T029 [US4] Implement nick_color_fn assign and rebuild helper in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`. Create private function `build_nick_color_fn/1` that takes session and returns `fn nickname -> NickColors.color_for(session.nick_colors, nickname) || nick_color(nickname) end` where `nick_color/1` is the existing hash-based color function. Call this in assign_defaults to set initial `nick_color_fn` assign. Create private `rebuild_nick_color_fn/1` that recalculates and reassigns nick_color_fn after any nick color change. The nick_color_fn is passed to components via assigns.

- [x] T030 [US4] Propagate nick_color_fn to ChatMessage component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_message.ex`. Add `attr :nick_color_fn, :any, default: nil` to the component. Replace the inline `nick_color(msg.author)` call with `@nick_color_fn.(msg.author)` (or fall back to hash if nil). Update the ChatLive template where ChatMessage is rendered to pass `nick_color_fn={@nick_color_fn}`.

- [x] T031 [P] [US4] Propagate nick_color_fn to Nicklist component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/nicklist.ex`. Add `attr :nick_color_fn, :any, default: nil`. Apply the color function to each nickname in the list. Update ChatLive template to pass `nick_color_fn={@nick_color_fn}`.

- [x] T032 [P] [US4] Propagate nick_color_fn to NotifyListWindow component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/notify_list_window.ex`. Add `attr :nick_color_fn, :any, default: nil`. Apply the color function to buddy nicknames in the table. Update ChatLive template to pass `nick_color_fn={@nick_color_fn}`.

- [x] T033 [P] [US4] Propagate nick_color_fn to ContextMenu component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/context_menu.ex`. Add `attr :nick_color_fn, :any, default: nil`. Apply the color function to `@target_nick` display. Update ChatLive template to pass `nick_color_fn={@nick_color_fn}`.

- [x] T034 [US4] Add NickColors persistence on NickServ identify in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`. In the NickServ identify success handler (alongside ContactList.load and NotifyList.load), add NickColors.load/1 call. On success, update session with Session.set_nick_colors and rebuild nick_color_fn. Add private `maybe_persist_nick_colors/2` helper following the same async Task.start pattern.

**Checkpoint**: Nick Colors tab fully functional. Custom colors override hash-based colors in chat messages, nicklist, notify list, and context menu. Persistence for registered users. All LiveView tests passing.

---

## Phase 7: User Story 5 — Control Tab Placeholder (Priority: P3)

**Goal**: Render placeholder message for the Control tab (awaiting Cat F Ignore System)

**Independent Test**: Open Address Book → Control tab → verify placeholder message

### Tests for US5

- [x] T035 [P] [US5] Write LiveView test for Control tab placeholder in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/address_book_test.exs`. Test: switching to Control tab shows text "Ignore management will be available in a future update." Tag `@tag :liveview`.

### Implementation for US5

- [x] T036 [US5] Implement Control tab placeholder content in AddressBookDialog component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/address_book_dialog.ex`. Render the Control tab panel with a centered paragraph: "Ignore management will be available in a future update." Style with muted text color. No interactive elements.

**Checkpoint**: All four tabs have content — Control tab shows placeholder. LiveView test passing.

---

## Phase 8: Context Menu Integration (FR-025, FR-026)

**Goal**: Add "Add to Contacts" and "Set Nick Color" to the nick right-click context menu

**Independent Test**: Right-click a nickname → "Add to Contacts" adds to contacts list. Right-click → "Set Nick Color" → pick color → nickname color changes.

### Tests for Context Menu

- [x] T037 [P] Write LiveView tests for context menu Address Book actions in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/address_book_test.exs`. Tests: (1) context menu shows "Add to Contacts" and "Set Nick Color" items, (2) "Add to Contacts" adds target nick to contacts — status message confirms, (3) "Add to Contacts" when already a contact — shows error, (4) "Set Nick Color" shows color picker, (5) picking a color assigns override — nickname color changes, (6) picking color when 50 overrides exist — shows error. Tag `@tag :liveview`.

### Implementation for Context Menu

- [x] T038 Add "Add to Contacts" and "Set Nick Color" items to ContextMenu component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/context_menu.ex`. Add two new menu items after "Whois" and before the operator separator: "Add to Contacts" with `phx-click="context_add_contact"` and "Set Nick Color" with `phx-click="context_set_nick_color"`. Add a separator line between the new items and the operator section.

- [x] T039 Add context color picker to ContextMenu or as a separate overlay in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/context_menu.ex`. Add `attr :show_color_picker, :boolean, default: false` and `attr :color_picker_target, :string, default: nil`. When `show_color_picker` is true, render a 4x4 color swatch grid (positioned near the context menu) with each swatch having `phx-click="context_pick_color"` and `phx-value-color_index`. Clicking outside closes the picker. Pass `show_context_color_picker` and target nick from ChatLive.

- [x] T040 Implement ChatLive event handlers for context menu actions in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`. Handler `context_add_contact`: get target_nick from context_menu assigns, call ContactList.add_entry with session.nickname as owner and nil note, update session, push_status_message ("Added X to contacts" or error), close context menu. Handler `context_set_nick_color`: set show_context_color_picker: true, keep target_nick. Handler `context_pick_color`: get target_nick and color_index, call NickColors.add_or_update, update session, rebuild nick_color_fn, push_status_message, close picker and context menu. Update `close_context_menu/1` to also close color picker.

**Checkpoint**: Context menu integration complete. Quick-add contacts and set nick colors from right-click. All LiveView tests passing.

---

## Phase 9: Polish, E2E Tests, data-testid Attributes

**Purpose**: End-to-end testing, accessibility attributes, final integration verification

- [x] T041 [P] Add data-testid attributes to all new interactive elements in AddressBookDialog (`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/address_book_dialog.ex`), ContextMenu (`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/context_menu.ex`), and Toolbar (`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/toolbar.ex`). Key testids: `address-book-dialog`, `address-book-tab-contacts`, `address-book-tab-notify`, `address-book-tab-nick-colors`, `address-book-tab-control`, `contact-add-btn`, `contact-edit-btn`, `contact-remove-btn`, `nick-color-add-btn`, `nick-color-edit-btn`, `nick-color-remove-btn`, `context-add-contact`, `context-set-nick-color`, `toolbar-address-book`.

- [x] T042 [P] Write E2E tests for US1 (dialog shell) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/address_book_e2e_test.exs`. Tests: (1) connect → Alt+B opens dialog, (2) four tabs visible, (3) tab switching works, (4) close button works, (5) Alt+B toggle closes, (6) toolbar button opens/closes, (7) Contacts is default tab. Tag `@tag :e2e`. Use data-testid selectors.

- [x] T043 [P] Write E2E tests for US2 (contacts tab) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/address_book_e2e_test.exs`. Tests: (1) add contact end-to-end, (2) edit contact note, (3) remove contact, (4) duplicate error, (5) empty state display. Tag `@tag :e2e`.

- [x] T044 [P] Write E2E tests for US3 (notify tab) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/address_book_e2e_test.exs`. Tests: (1) notify tab shows existing buddies, (2) add buddy via notify tab, (3) bidirectional sync with standalone notify list window. Tag `@tag :e2e`.

- [x] T045 [P] Write E2E tests for US4 (nick colors tab) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/address_book_e2e_test.exs`. Tests: (1) add nick color override, (2) edit color, (3) remove override, (4) color applied to chat messages, (5) color applied to nicklist. Tag `@tag :e2e`.

- [x] T046 [P] Write E2E tests for US5 (control tab) and context menu in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/address_book_e2e_test.exs`. Tests: (1) control tab placeholder message, (2) context menu "Add to Contacts" works, (3) context menu "Set Nick Color" → color picker → color applied. Tag `@tag :e2e`.

- [x] T047 Run full linter and static analysis suite: `mix format --check-formatted`, `mix credo --strict`, `mix dialyzer`. Fix any warnings or errors. Ensure all new public functions have `@spec` annotations. Verify all aliases are alphabetically ordered (Credo strict).

- [x] T048 Run full test suite: `make test` (unit + integration + liveview) and `make test.all` (including E2E). Verify zero failures, zero warnings. Verify existing tests not broken by Session field additions or component attr changes.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (migration must exist for persistence tests) — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 completion (session fields needed)
- **US2 (Phase 4)**: Depends on Phase 2 (ContactList) + Phase 3 (dialog shell)
- **US3 (Phase 5)**: Depends on Phase 3 (dialog shell)
- **US4 (Phase 6)**: Depends on Phase 2 (NickColors) + Phase 3 (dialog shell)
- **US5 (Phase 7)**: Depends on Phase 3 (dialog shell)
- **Context Menu (Phase 8)**: Depends on Phase 4 (contacts) + Phase 6 (nick colors + nick_color_fn)
- **Polish (Phase 9)**: Depends on all previous phases

### User Story Dependencies

- **US1 (P1)**: Independent after Phase 2 — no other story dependencies
- **US2 (P2)**: Depends on US1 (needs dialog shell to render contacts tab)
- **US3 (P2)**: Depends on US1 (needs dialog shell to render notify tab)
- **US4 (P3)**: Depends on US1 (needs dialog shell to render nick colors tab)
- **US5 (P3)**: Depends on US1 (needs dialog shell to render control tab)
- **Context Menu**: Depends on US2 + US4 (needs ContactList + NickColors + nick_color_fn)

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Structs/schemas before context modules
- Context modules before LiveView event handlers
- Component rendering before ChatLive wiring
- Story complete before moving to next priority

### Parallel Opportunities

- **Phase 2**: T002+T006 (Contact struct ∥ NickColor struct), T003+T007 (ContactEntry ∥ NickColorEntry schemas)
- **Phase 3**: T011 (tests) ∥ T015+T016 (toolbar + menu bar)
- **Phase 5+6+7**: US3, US4, US5 can proceed in parallel after US1 is complete
- **Phase 6**: T031+T032+T033 (propagate nick_color_fn to 3 components in parallel)
- **Phase 9**: All E2E test files can be written in parallel (T042-T046)

---

## Parallel Example: Phase 2 Foundation

```text
# Wave 1 — Structs (parallel, different files):
T002: Contact struct + tests
T006: NickColor struct + tests

# Wave 2 — Schemas (parallel, different files):
T003: ContactEntry Ecto schema
T007: NickColorEntry Ecto schema

# Wave 3 — Context modules (sequential per domain, parallel across):
T004: ContactList CRUD → T005: ContactList persistence
T008: NickColors CRUD → T009: NickColors persistence

# Wave 4 — Session (depends on all above):
T010: Session extension
```

## Parallel Example: Phase 6 Nick Color Propagation

```text
# After T029 (nick_color_fn) and T030 (ChatMessage) complete:
T031: Propagate to Nicklist
T032: Propagate to NotifyListWindow
T033: Propagate to ContextMenu
# All three are different files with no dependencies on each other
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1: Migration
2. Complete Phase 2: Domain foundation
3. Complete Phase 3: Dialog shell (US1)
4. **STOP and VALIDATE**: Alt+B opens tabbed dialog, tabs switch, dialog closes
5. Deployable MVP — Address Book container ready for tab content

### Incremental Delivery

1. Phase 1+2 → Foundation ready
2. Phase 3 (US1) → Dialog shell → Deploy (MVP)
3. Phase 4 (US2) → Contacts tab → Deploy (adds personal contact manager)
4. Phase 5 (US3) → Notify tab → Deploy (adds unified notify management)
5. Phase 6 (US4) → Nick Colors tab → Deploy (adds color personalization)
6. Phase 7 (US5) → Control tab placeholder → Deploy (complete 4-tab Address Book)
7. Phase 8 → Context menu shortcuts → Deploy (quick-add contacts + colors)
8. Phase 9 → E2E tests + polish → Final release

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- TDD is non-negotiable per Constitution Principle IV
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- The Notify tab reuses existing events — no new domain code needed for US3
- The Control tab is a placeholder only — full implementation deferred to Cat F
- Nick color overrides require touching 4+ components for propagation — schedule accordingly
