# Chat Desktop Migration — Loop Prompt

Use this prompt on every loop iteration:

---

You are migrating the main chat (`ChatLive`) to the Win98 windowed desktop UI that
already powers the P2P lobby. Work through the plan in `docs/plan/chat-desktop/`.

1. Read `docs/plan/chat-desktop/PROGRESS.md` to find the current phase and what was
   learned so far. Read the current phase file (`phase-N-*.md`).
2. Pick the next unchecked task in the current phase. Do ONE coherent unit of work
   (one task, or one dialog migration end-to-end).
3. Work TDD: write/adjust the test first when practical. Follow the per-dialog
   recipe in PROGRESS.md once Phase 2 has established it.
4. Validate: `make ci.quick` while iterating; the FULL `make ci` must be green
   before checking off a phase-completion criterion. Never skip dialyzer/E2E in the
   full run. For E2E iteration, target specific tests (file:line), never the full
   Playwright suite ad hoc.
5. Commit directly to `main` (never branch) with a focused message.
6. Update PROGRESS.md: check off the task in the phase file, record any new
   learning/gotcha in the Learnings section (these become AGENT-GUIDE material at
   the end). Keep entries short and durable — no session narration.
7. Stop when the current task is committed and PROGRESS.md is updated. If the phase
   is complete (all completion criteria verified), mark it in PROGRESS.md and stop.

Hard rules (from CLAUDE.md / AGENT-GUIDE — non-negotiable):
- LiveViews stay thin; delegate to domain contexts. Compose existing UI components
  (`Components.UI.Desktop`, `Components.UI.Window`, `Components.UI.Dialog`) — never
  fork per-context copies; extend generically with capability flags/attrs.
- No hex colors or inline SVG in Elixir/JS. Icons live in `Icons.*` submodules
  (16×16 title-bar icons use the `icon_dialog_*` naming).
- Comments/moduledocs describe what the code does — never the migration that made it.
- Every new window/UI surface needs Help documentation (`HelpTopics`) — Phase 6
  gates on it, but add topics as you go when natural.
- LiveView tests: never assert on async `send_update`/stream timing. Assert on
  synchronous state (`:sys.get_state`), `render_hook`, `assert_push_event`, or
  component unit tests. No sleeps.
- Generic WM changes (hook or `Desktop`/`Window` components) need Vitest coverage in
  `assets/test/hooks/ui/window_manager_hook.test.js` and must not break the lobby or
  showcase consumers.

---

## Mission summary

The lobby's window manager is already generic: `Components.UI.Desktop` +
`Components.UI.Window` + `WindowManagerHook` (JS owns geometry/z-order/persistence;
server owns lifecycle of `managed` windows only). The chat currently renders ~28
modal dialogs (stateful LiveComponents over `UI.Dialog`) plus ~21 nested sub-form
modals. The migration turns the chat page into a desktop: the chat itself becomes
one pinned window, ~18 mini-app dialogs become floating windows with taskbar
buttons and a start menu, confirmations stay modal.

## Locked design decisions (do not re-litigate)

1. **Scope**: only dialogs become windows. The whole current chat layout (sidebar +
   tabs + viewport + nicklist + composer) becomes ONE `desktop_window id="chat"`,
   `pinned` (no close button), maximized by default, restorable/draggable/resizable.
2. **Confirmations stay modal** (`UI.Dialog`, centered, overlay): DeleteConfirm,
   DisconnectConfirm, PasteConfirm, MuteDuration, KickQueue, InviteQueue,
   KnockRequest, InviteChannelPicker, NickChange, About (client-side `show_modal`).
   EmojiPicker stays a Composer popup. These are transient prompts — Win98
   MessageBoxes were modal.
3. **Nested sub-forms stay modal but scoped to their parent window** (centered over
   the window that opened them, not the whole viewport).
4. **Menu bar and start menu coexist**: the top menu bar (File/Edit/View/Tools/Help)
   keeps working, now opening windows instead of modals; the start menu is a second
   path mirroring the menu-bar categories (Tools / View / Admin / Help). Admin
   category is permission-gated.
5. **Persistence ON**: `persist_key="chat"`, geometry + open-state persisted in
   localStorage (unlike the lobby's clean-slate).
6. **Taskbar**: start button + one button per open window + tray with clock
   (`ClockHook`, like the showcase). Channels/PMs stay as tabs INSIDE the chat
   window — they do NOT get taskbar buttons.
7. **Header chrome**: logo + menu bar + status bar live in the desktop `:header`
   slot (like the lobby), outside/above the chat window.
8. **Mobile**: inherit the WM's built-in stacked mode (<720px) as-is. No new mobile
   UX in this migration — a platform-wide answer comes later.

## Window classification

Become windows (18):

| Category | Windows |
|----------|---------|
| Tools | AddressBook, NotifyList, Alias, CustomMenus, AutoRespond, Perform, SoundSettings, FloodProtection, Timers, Highlight |
| View | UrlCatcher, ChannelList, UserLookup, Cheatsheet |
| Account/Channel | Account, ChannelCentral |
| Admin | AdminConsole, BotManagement |

Stay modal: everything in locked decision #2, plus all nested sub-forms (~21).

## Key files

- WM hook: `apps/retro_hex_chat_web/assets/js/hooks/ui/window_manager_hook.js`
  (+ tests `assets/test/hooks/ui/window_manager_hook.test.js`)
- Desktop components: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/layout/desktop.ex`
- Window chrome: `.../components/ui/layout/window.ex`
- Modal dialog base (stays for modals): `.../components/ui/layout/dialog.ex`
- Reference consumer (the model to follow): `.../components/ui/lobby/universal_lobby.ex`
  + `.../live/app/lobby_live.ex` (managed-window helpers/handlers)
- Second reference: `.../live/showcase_live/layout/desktop.html.heex` (persist + tray clock)
- Target: `.../live/app/chat_live.ex` + `chat_live.html.heex` (dialogs block ~L179–359)
- Event pipeline: `.../live/chat_live/*_events.ex` (attach_hook modules;
  `keyboard_events.ex` owns Escape/`dismiss_topmost`; `menu_toolbar_events.ex` owns
  `toolbar_action`)
- Dialog wrappers (islands): `.../live/chat_live/components/*_dialog.ex`
- Dialog UI layer: `.../components/ui/dialogs/*.ex`
- Guide: `docs/AGENT-GUIDE.md` §6 (islands) and §7 (windowed desktop rules)

## Phases

| Phase | File | Goal |
|-------|------|------|
| 1 | `phase-1-desktop-shell.md` | Desktop shell in ChatLive; chat as pinned maximized window; taskbar/start-menu/tray; WM extensions |
| 2 | `phase-2-pilot-recipe.md` | Migrate 3 representative dialogs; crystallize the per-dialog recipe |
| 3 | `phase-3-tools-settings.md` | Batch: 8 Tools/Settings windows |
| 4 | `phase-4-view-account.md` | Batch: 6 View/Account/Channel windows |
| 5 | `phase-5-admin.md` | Batch: 2 admin windows (permission-gated) |
| 6 | `phase-6-unify-cleanup.md` | Unify open-state, Escape/shortcut rewrite, help docs, cleanup, crystallize learnings |
