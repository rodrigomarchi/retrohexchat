# Feature Spec: Identity, Account & Presence
**Coverage today:** ❌ command-only / no launcher · **Priority:** P0 · **Commands:** /ns, /nick, /away, /bio, /umode

## 1. Overview

This feature covers a user's entire identity lifecycle: claiming and protecting a nickname (NickServ registration/identification), changing the display nickname, advertising an "about me" bio, signalling temporary unavailability (away), and toggling personal user modes (currently only `+w` wallops). Every chat participant — guests and registered users alike — relies on this journey, and registration/login is the single most foundational action in the product. Today **none of it has a UI launcher**: a brand-new user has no on-screen way to discover that they can register or identify a nickname — they must already know to type `/ns register <password>`. This makes the most important onboarding step effectively invisible, so it is the highest-priority gap to close.

## 2. Commands (grounded in handler source)

All syntax below is quoted verbatim from the handler `Usage:`/`syntax` strings and examples.

| Command | Syntax | What it does | Permission / preconditions |
|---|---|---|---|
| `/ns register` | `/ns register <password>` | Claims the **current** nickname and registers it with the given password via `NickServ.register(context.nickname, password)`. Empty password → `Usage: /ns register <password>`. | Any user; registers whatever nickname you are currently using. |
| `/ns identify` | `/ns identify <password>` | Authenticates the current session for the current nickname via `NickServ.identify(context.nickname, password)`. Empty password → `Usage: /ns identify <password>`. | Nickname must already be registered. |
| `/ns ghost` | `/ns ghost <nickname> <password>` | Disconnects a stale/ghost session holding `<nickname>`, authenticated by that nick's `<password>` (`NickServ.ghost(target, password, requester)`). Missing args → `Usage: /ns ghost <nickname> <password>`. | Requires the registered nickname's password. |
| `/ns info` | `/ns info [nick]` | Shows registration info (`registered_at`, `identified`) for `[nick]`; defaults to your own nickname when omitted. | Any user; read-only. |
| `/ns drop` | `/ns drop <password>` | Deletes the registration for your current nickname (`NickServ.drop(context.nickname, password)`). Empty password → `Usage: /ns drop <password>`. | Must own/identify the nickname; password required. |
| `/ns help` | `/ns help` | Shows NickServ help. | Any user. |
| `/ns` (no args) | `/ns <register\|identify\|ghost\|info\|drop\|help> [args]` | Prints the umbrella usage string. | — |
| `/nick` | `/nick <newnick>` | Changes display nickname. Returns `{:ok, :nick_change, new_nick}`, which triggers the **Nick Change confirmation dialog** (password field appears if the target nick is registered). Rules enforced in handler: 1–16 chars, no spaces, must start with a letter or `[ ] \ ^ _ { \| }`, allowed chars letters/numbers/`[ ] \ ^ _ \` { \| }`/hyphen, cannot equal current nick. | Any user. Examples: `/nick NewNick`, `/nick [Bot]`. |
| `/away` | `/away [message]` | With a message → `:ui_action :set_away` (`Session.set_away`, broadcasts away change, system event "You are now away: …"). With **no args** → `:ui_action :clear_away` ("You are no longer away"). | Any user. Examples: `/away Gone to lunch`, `/away`. |
| `/bio` | `/bio [<text>\|clear]` | No args → `:view_bio`. `clear` → `:clear_bio`. Otherwise sets bio (`:set_bio`); max **200 graphemes**, silently truncated beyond that (`truncated: true`). Visible to others via `/whois`. | Any user. Examples: `/bio Elixir enthusiast from Brazil`, `/bio`, `/bio clear`. |
| `/umode` | `/umode <+/-mode>` | Toggles personal user modes. Only known mode is `w` (wallops): `+w` receive operator broadcasts, `-w` stop. Must start with `+`/`-`. No args → `Usage: /umode <+/-mode>`; unknown flag → `Unknown user mode: <flag>`. Emits `:ui_action :set_user_mode`. | Any user. Examples: `/umode +w`, `/umode -w`. |

**Note (source vs. assumption):** `/ns register` and `/ns drop` always operate on `context.nickname` — there is no way to register a *different* nickname than the one currently in use. Any UI must register/drop the **current** nick, not an arbitrary one.

## 3. Current UI state

**What exists:**
- **Nick Change dialog** (`components/ui/dialogs/nick_change_dialog.ex`) — appears **only mid-`/nick` flow** (after `/nick <newnick>` returns `:nick_change`). It confirms the change and, when the target nick is `registered`, shows a "NickServ password" field with a `password_error` slot. It is *not* an account launcher — there is no way to open it except by typing `/nick`.
- **Inline help "nickserv" topic** (`HelpTopics.Services`, id `"nickserv"`, lock icon) — a passive help card explaining NickServ; it does not launch anything.

**What is missing (no launcher anywhere):**
- No **Register / Identify** launcher — registration and login are command-only and undiscoverable.
- No **away toggle** — `/away` has no button or indicator; users can't see or clear away state from the UI.
- No **bio editor** — `/bio` view/set/clear is text-command only.
- No **user-mode UI** — `+w` wallops can only be toggled by typing `/umode`.
- No **account/identity indicator** in the status bar showing nick + identified/away state.

## 4. UI specification — what to build

### 4.1 Entry points

1. **Status-bar account widget** (always visible): shows the current nickname plus identity/presence badges.
   - Label format: `<nick> · <state>` where state is one of `Guest`, `Identified`, `Away`.
   - Clicking the widget opens the **Account** dialog (4.2).
   - A small **Away** toggle sits next to it (lamp/icon) as a one-click quick-action (see 4.3).

2. **File menu group** — add a labelled group **"Account"** with items:
   - **"Register Nickname…"** → opens Account dialog on *Register/Login* tab, Register sub-mode.
   - **"Identify…"** → opens Account dialog on *Register/Login* tab, Login sub-mode.
   - **"Change Nickname…"** → opens the existing Nick Change dialog (now reachable without typing `/nick`).
   - **"Edit Profile…"** → Account dialog, *Profile* tab.
   - **"Set Away…"** → Account dialog, *Presence* tab.
   - **"Account Info"** → runs `/ns info` and shows the result (registration date + identified state).

### 4.2 Layout

A single tabbed **Account** dialog (built from existing dialog/button/input primitives, matching the Nick Change dialog style). Tabs: **Register/Login**, **Profile**, **Presence**, **User Modes**.

```
┌─ Account ─────────────────────────────────────[X]┐
│ [Register/Login] [Profile] [Presence] [User Modes]│
├───────────────────────────────────────────────────┤
│  Nickname:  alice            (current)            │
│  Status:    ● Not identified  (Guest)             │
│                                                   │
│  ( ) Register this nickname                       │
│  (•) Identify (log in)                            │
│                                                   │
│  Password:  [••••••••••••••••]                    │
│  (Register only) Confirm: [••••••••••••••]        │
│                                                   │
│  ⚠ <inline error: wrong password / nick taken>    │
│                                                   │
│            [ Identify ]   [ Cancel ]              │
└───────────────────────────────────────────────────┘
```

```
┌─ Account › Profile ───────────────────────────[X]┐
│  Bio (about me) — shown in /whois, max 200 chars  │
│  ┌─────────────────────────────────────────────┐ │
│  │ Elixir enthusiast from Brazil               │ │
│  │                                             │ │
│  └─────────────────────────────────────────────┘ │
│  142 / 200                                        │
│          [ Save Bio ]  [ Clear Bio ]  [ Close ]   │
└───────────────────────────────────────────────────┘
```

```
┌─ Account › Presence ──────────────────────────[X]┐
│  [x] I'm away                                     │
│  Away message: [ Gone to lunch                  ] │
│  (shown to others via /whois)                     │
│          [ Set Away ]  [ Clear Away ]  [ Close ]  │
└───────────────────────────────────────────────────┘
```

```
┌─ Account › User Modes ────────────────────────[X]┐
│  [x] Receive wallops (+w)                         │
│      Operator broadcast messages                  │
│                          [ Apply ]  [ Close ]     │
└───────────────────────────────────────────────────┘
```

### 4.3 Interactions & states

- **Logged-out (guest) vs identified:** the *Register/Login* tab shows current nick + status. If the nick is unregistered, default the radio to **Register** (with Confirm-password field). If registered but not identified, default to **Identify** (single password field). If already identified, show "✓ Identified" and offer **Drop registration…** (confirmation, requires password → `/ns drop <password>`).
- **Password fields:** use `type="password"` inputs (same primitive as Nick Change dialog). Register mode adds a Confirm field; client-side validation requires both to match before enabling **Register**.
- **Nickname validation** (Change Nickname / Register flows): mirror the handler rules — 1–16 chars, no spaces, valid first char, allowed charset. Show inline error; do not submit invalid nicks.
- **Away quick-action:** the status-bar Away toggle flips between "Set Away" and "Back". Toggling **off** runs `/away` (clear). Toggling **on** with no custom message runs `/away` with the last-used or a default message; the Presence tab lets the user set a custom message. The widget badge updates to `Away` when away (state mirrors `Session.set_away`).
- **Bio editor:** live character counter `N / 200`; soft-cap at 200 (handler truncates silently — UI should warn before truncation rather than rely on it). **Save Bio** runs `/bio <text>`, **Clear Bio** runs `/bio clear`.
- **Error feedback:** surface NickServ errors inline in the dialog (the handlers return `{:error, "[NickServ] <message>"}` for wrong password, nick already registered, not registered, etc.). Reuse the `password_error` pattern from the Nick Change dialog. `/umode` unknown-mode and `/away`/`/bio` results surface as the existing system events.

### 4.4 Control → command mapping

| UI control | Command it runs |
|---|---|
| **Register** button (Register sub-mode) | `/ns register <password>` |
| **Identify** button (Login sub-mode) | `/ns identify <password>` |
| **Drop registration…** (confirm + password) | `/ns drop <password>` |
| **Account Info** menu item / Info refresh | `/ns info` (or `/ns info <nick>`) |
| **Ghost session…** (advanced, optional) | `/ns ghost <nickname> <password>` |
| **Change Nickname…** → confirm in Nick Change dialog | `/nick <newnick>` (registered target → password field already in dialog) |
| **Set Away** button / toggle ON | `/away <message>` |
| **Clear Away** button / toggle OFF | `/away` |
| **Save Bio** | `/bio <text>` |
| **Clear Bio** | `/bio clear` |
| **View Bio** (Profile tab open) | `/bio` |
| **Receive wallops (+w)** checkbox ON | `/umode +w` |
| **Receive wallops** checkbox OFF | `/umode -w` |

## 5. Permissions & visibility

- All five commands are usable by **any user** (guest or registered) — none require operator/admin rights.
- **Register/Login tab** adapts to identity state:
  - Unregistered nick → **Register** enabled, Identify/Drop hidden.
  - Registered, not identified → **Identify** enabled; **Drop** available (needs password).
  - Identified → status shows ✓; Identify hidden; **Drop** available.
- **Ghost** requires the *registered nickname's* password, so expose it only as an advanced action (default collapsed) to avoid confusing guests.
- **Profile / Presence / User Modes** tabs are available to everyone (bio, away, and wallops do not require identification). The widget badge reflects `Guest` / `Identified` / `Away` purely as status — it never gates these tabs.

## 6. Help documentation (mandatory)

Per the project's mandatory help-documentation rule, the Account UI must ship with help updates:

- **User Interface category** — add a topic **"Account Dialog"** describing the status-bar widget, the four tabs, the Away toggle, and how each maps to a command. Cross-reference the existing `nickserv` topic and the `/nick`, `/away`, `/bio`, `/umode` command topics.
- **Features category** — add/expand an **"Identity & Presence"** topic covering nickname registration/identification, away status, bio, and user modes as one journey; link out to the per-command topics.
- **Update existing `nickserv` topic** (`HelpTopics.Services`, id `"nickserv"`) — add a "See Also" cross-reference pointing to the new Account Dialog UI topic, and add keywords (`account`, `login`, `identify`, `away`, `bio`).
- **Keyboard Shortcuts topic** — if the Account dialog gets an accelerator (e.g. open from File menu), add the shortcut there.
- **Cross-references:** the new UI topic should "See Also" → `nickserv`, `nick`, `away`, `bio`, `umode`; those command topics should "See Also" back → "Account Dialog".

## 7. Out of scope / open questions

- **Registering a non-current nickname:** the handler only registers `context.nickname`; a flow to register/reserve an arbitrary nick is out of scope (would require backend changes).
- **Auto-away (idle) timer:** the Presence wireframe hints at it, but `/away` has no idle/auto trigger in the handler. Treating auto-away as a *new* client-side feature is **out of scope** for this spec — open question whether to add an idle-detection hook that calls `/away` automatically.
- **Bio truncation UX:** handler silently truncates at 200 graphemes. Open question: should the UI hard-block at 200 (recommended) or allow paste-and-truncate with a warning?
- **Additional user modes:** only `+w` (wallops) exists today. The User Modes tab should be built to accommodate future modes but currently renders a single checkbox.
- **Ghost discoverability:** open question whether Ghost belongs in the main Account dialog at all, or only in an "Advanced" disclosure, given it needs the registered password and targets another session.
- **Password reset / change:** there is no NickServ password-change or reset command in the handlers reviewed — out of scope; flag as a potential backend gap.
