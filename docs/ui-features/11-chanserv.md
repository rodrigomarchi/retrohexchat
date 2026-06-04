# Feature Spec: ChanServ (channel registration)

**Coverage today:** command-only (no UI for normal users)
**Priority:** P3
**Commands:** /cs

---

## 1. Overview

ChanServ is the channel registration service. It lets a channel operator permanently
"own" a channel by registering it, preventing squatting and enabling persistent access
control that survives server restarts.

Core capabilities:

- **Register** — a channel operator claims the channel; they become its founder.
- **Drop** — the founder relinquishes registration (channel becomes unregistered again).
- **Info** — anyone can query registration metadata (founder, registration date).
- **Access lists** — the founder manages three privilege tiers:
  - **SOP** (super-operator): can add/remove AOP and VOP entries, treated as +o on join.
  - **AOP** (auto-operator): auto-voiced as +o on join.
  - **VOP** (auto-voice): auto-voiced as +v on join.

Registration is identified-only: the requesting nick must be identified with NickServ.

---

## 2. Commands (grounded in handler source)

All commands operate on the currently active channel (`context.active_channel`).
They are dispatched by `RetroHexChat.Commands.Handlers.Cs` and executed via
`RetroHexChat.Services.ChanServ`.

| Subcommand            | Full syntax                  | Required level          | Notes                                   |
|-----------------------|------------------------------|-------------------------|-----------------------------------------|
| register              | `/cs register`               | Channel operator (+o)   | Caller becomes founder                  |
| drop                  | `/cs drop`                   | Founder only            | Removes all access list entries too     |
| info                  | `/cs info`                   | Any (channel member)    | Returns founder + registered_at         |
| sop add \<nick\>      | `/cs sop add <nick>`         | Founder only            | Adds nick to SOP list                   |
| sop del \<nick\>      | `/cs sop del <nick>`         | Founder only            | Removes nick from SOP list              |
| sop list              | `/cs sop list`               | Any (channel member)    | Lists SOP entries with level + added_by |
| aop add \<nick\>      | `/cs aop add <nick>`         | Founder or SOP          | Adds nick to AOP list                   |
| aop del \<nick\>      | `/cs aop del <nick>`         | Founder or SOP          | Removes nick from AOP list              |
| aop list              | `/cs aop list`               | Any (channel member)    | Lists AOP entries                       |
| vop add \<nick\>      | `/cs vop add <nick>`         | Founder or SOP or AOP   | Adds nick to VOP list                   |
| vop del \<nick\>      | `/cs vop del <nick>`         | Founder or SOP or AOP   | Removes nick from VOP list              |
| vop list              | `/cs vop list`               | Any (channel member)    | Lists VOP entries                       |
| help                  | `/cs help`                   | Any                     | Falls through to help system            |

Access list entries expose the fields: `nickname`, `level`, `added_by`
(from `RetroHexChat.Services.Queries.list_access/1`).

---

## 3. Current UI state

- **Normal users:** no UI surface whatsoever. ChanServ functions are command-line only
  via `/cs <subcommand>`. There is no visual registration status, no access list viewer,
  and no way to discover whether a channel is registered without typing `/cs info`.
- **Admins:** indirect access via `/admin cs ...` in the Admin Console, which executes
  the same `ChanServ` service functions but through a privileged admin pathway.
- **Help system:** `RetroHexChat.Chat.HelpTopics.Services` exposes a `chanserv` topic
  (category "Services & Protocols") describing registration and access lists at a high
  level, but without command-specific detail. There is no ChanServ-specific command help
  beyond the `help/0` callback in the handler itself.

---

## 4. UI specification — what to build

### 4.1 Entry points

Add a sixth tab, **"Registration"**, to the existing Channel Central dialog
(`RetroHexChatWeb.Components.UI.ChannelCentralDialog`). This is a pure enhancement:
no new dialog, no parallel window.

Tab label: **"Registration"**
Tab icon: `Icons.icon_tab_registration` (new icon — shield or key, 16x16, to be added
to `Icons.Security` submodule)
Tab value (for `phx-value-tab`): `"registration"`

Visibility rule: the tab is **always visible** to any channel member. Its contents
adapt to the viewer's role (founder vs. access-list member vs. non-member).

The tab is appended after "Invite Exc." in the tabs list.

### 4.2 Layout

Two logical sections inside the tab:

**Section A — Registration status banner** (always visible)

```
+----------------------------------------------------------+
|  [shield icon]  #lobby                                   |
|                                                          |
|  Status:    Registered                                   |
|  Founder:   Alice                                        |
|  Since:     2024-03-15 08:22 UTC                         |
|                                                          |
|  [ Register Channel ]   (shown only when unregistered    |
|                           and user is +o; grayed out     |
|                           otherwise)                     |
|  [ Drop Registration ]  (shown only to founder;          |
|                           destructive, requires confirm) |
+----------------------------------------------------------+
```

When unregistered, Status shows "Not registered" and founder/since fields are absent.

**Section B — Access list** (visible when channel is registered)

Three sub-tabs or a single segmented control switching between SOP / AOP / VOP.
Each list renders identically:

```
+----------------------------------------------------------+
|  [ SOP ] [ AOP ] [ VOP ]                                 |
|                                                          |
|  +----------------------------------------------------+  |
|  | Nickname         | Added by    |                   |  |
|  |----------------------------------------------------|  |
|  | BobOp            | Alice       |                   |  |
|  | CharlieOp        | Alice       |                   |  |
|  +----------------------------------------------------+  |
|                                                          |
|  Nick: [______________]  [ Add ]   [ Remove ]           |
|                           (founder/SOP only for SOP)    |
|                           (founder/SOP only for AOP)    |
|                           (founder/SOP/AOP for VOP)     |
+----------------------------------------------------------+
```

- Table: two columns — Nickname, Added By. No pagination needed (typical access lists
  are short; a `max-h-[160px] overflow-y-auto` scroll region suffices).
- Add row: inline text input for the target nick + Add button. No modal sub-form needed
  (keep it simpler than the ban sub-dialogs pattern; the sub-form pattern is overkill for
  a simple nick entry).
- Remove: select a row then click Remove, or type nick in the input and click Remove.
  Remove button is disabled when no row is selected and the input is empty.
- Read-only view: when the viewer lacks permission to add/remove at a given tier, the
  input and buttons are hidden; a note reads "You do not have permission to manage this
  list."

### 4.3 Interactions & states

**Unregistered channel — user is +o (operator):**
- Status banner: "Not registered"
- "Register Channel" button enabled
- Access list section hidden (no registration = no access list)
- Clicking "Register Channel" dispatches `cc_cs_register` event

**Unregistered channel — user is not +o:**
- Status banner: "Not registered"
- "Register Channel" button absent
- Access list section hidden
- Informational note: "Only channel operators can register this channel."

**Registered channel — viewer is founder:**
- Status banner: registered + founder + since date
- "Register Channel" button absent (already registered)
- "Drop Registration" button visible (destructive, styled `variant="destructive"`)
- Clicking "Drop" shows an inline confirmation prompt before dispatching:
  "Are you sure you want to drop #lobby? This cannot be undone."
  Confirm/Cancel buttons inline (no separate dialog).
- Access list: all three tiers visible; Add/Remove controls enabled for all tiers.

**Registered channel — viewer is SOP:**
- Status banner: registered info (no drop button)
- Access list: SOP tab read-only; AOP and VOP tabs editable (Add/Remove enabled).

**Registered channel — viewer is AOP:**
- Status banner: registered info (no controls)
- Access list: SOP and AOP tabs read-only; VOP tab editable.

**Registered channel — viewer is VOP or plain member:**
- Status banner: registered info (no controls)
- Access list: all tiers read-only.

**Error state:**
- ChanServ errors (`{:error, msg}`) surfaced as an inline error banner inside the tab
  (red border box, small text), not as chat system messages. This keeps the dialog
  self-contained.

**Loading state:**
- Add/Remove buttons show a spinner and are disabled while the LiveView event is in
  flight (use `phx-disable-with` on the button).

### 4.4 Control to command mapping

| UI control                        | LiveView event dispatched   | Maps to /cs subcommand             |
|-----------------------------------|-----------------------------|------------------------------------|
| "Register Channel" button         | `cc_cs_register`            | `/cs register`                     |
| "Drop Registration" (confirmed)   | `cc_cs_drop`                | `/cs drop`                         |
| SOP/AOP/VOP tab switch            | `cc_cs_access_tab` (local)  | (read-only, no command; re-fetch)  |
| "Add" button (nick input)         | `cc_cs_access_add`          | `/cs <level> add <nick>`           |
| "Remove" button (selected row)    | `cc_cs_access_remove`       | `/cs <level> del <nick>`           |
| Tab open (registration tab)       | `cc_cs_info` (on mount)     | `/cs info` (populate banner)       |
| Level list load                   | `cc_cs_list`                | `/cs <level> list`                 |

All events carry `phx-value-channel={@channel_name}` and `phx-value-level={active_level}`
where relevant.

---

## 5. Permissions & visibility

The tab is always shown (consistent with how Bans/Ban Exc./Invite Exc. are always shown).
Controls inside adapt to the computed role:

| Role       | Register | Drop | SOP add/del | AOP add/del | VOP add/del |
|------------|----------|------|-------------|-------------|-------------|
| Founder    | N/A      | yes  | yes         | yes         | yes         |
| SOP        | no       | no   | no          | yes         | yes         |
| AOP        | no       | no   | no          | no          | yes         |
| VOP        | no       | no   | no          | no          | no          |
| Op (+o)    | yes*     | no   | no          | no          | no          |
| Non-op     | no       | no   | no          | no          | no          |

*Op can register only if the channel is currently unregistered.

The LiveView event handlers enforce these rules server-side by calling the same
`ChanServ` service functions that the `/cs` command handler uses. The UI controls are
presentational hints only; the service layer is the authority.

**Identified-only constraint:** ChanServ operations require the nick to be identified
with NickServ. If the user is not identified, all write controls (Register, Drop, Add,
Remove) are disabled with the note: "You must be identified with NickServ to use
ChanServ." This state is detected from the existing `identified?` assign already
present in `ChatLive`.

---

## 6. Help documentation (mandatory)

Following the project's mandatory help documentation rule:

**In `RetroHexChat.Chat.HelpTopics.Services`:**

Expand the existing `chanserv` topic to include a `commands` key (or add a linked
subtopic) listing all `/cs` subcommands with their syntax, similar to the NickServ
topic pattern.

**New topics to add:**

1. `"chanserv-register"` — Category: "Commands"
   - Title: "Registering a Channel (/cs register)"
   - Keywords: `["chanserv", "register", "cs register", "channel ownership"]`
   - Describes: what registration means, who can do it, how to drop it.

2. `"chanserv-access"` — Category: "Commands"
   - Title: "Channel Access Lists (/cs sop/aop/vop)"
   - Keywords: `["chanserv", "access list", "sop", "aop", "vop", "cs add", "cs del"]`
   - Describes: the three tiers, what privileges each grants, add/del/list syntax.

3. `"chanserv-ui"` — Category: "User Interface"
   - Title: "Channel Central: Registration Tab"
   - Keywords: `["registration tab", "channel central", "chanserv ui"]`
   - Describes: how to open Channel Central, locate the Registration tab, and use
     the visual controls as an alternative to typing `/cs` commands.

**Update existing cross-references:**

- In `"chanserv"` topic: add "See Also" links to `"chanserv-register"` and
  `"chanserv-access"`.
- In keyboard shortcuts topic: no new shortcuts needed (Channel Central is already
  accessible via its existing entry point).
- In `"channel-central"` UI topic (if it exists): add reference to `"chanserv-ui"`.

---

## 7. Out of scope / open questions

**Out of scope for this feature:**

- ChanServ `ENFORCE` / `GUARD` modes (not implemented in the service layer).
- Automatic privilege application on join (ChanServ auto-op/voice on join) — that
  belongs to the ChanServ service layer, not this UI feature.
- Admin-facing ChanServ controls in the Admin Console (already exists; no changes).
- Bulk access list import/export.
- Access list entry timestamps (`added_at`) — the `Queries.list_access/1` result
  exposes `nickname`, `level`, `added_by` but not a timestamp; adding one would
  require a migration and is deferred.

**Open questions:**

1. **Role detection source:** how does the LiveView know the viewer's ChanServ role
   (founder vs. SOP vs. AOP vs. VOP)? Options: (a) call `ChanServ.info/2` to get the
   founder and compare, then call `Queries.list_access/1` to check tier membership;
   (b) add a dedicated `ChanServ.viewer_role/3` helper. Recommend option (b) for
   clarity, but this is an implementation decision.

2. **Tab data loading strategy:** should Registration tab data load eagerly when the
   dialog opens (add to the existing `cc_open` event), or lazily when the tab is first
   clicked? Lazy is lower overhead (most users never open this tab); eager is simpler
   to implement. Recommend lazy with a loading spinner.

3. **Icon:** `Icons.icon_tab_registration` does not exist yet. Best candidate from
   existing inventory is `Icons.Security` submodule (shields/locks). A new 16x16 icon
   needs to be designed or an existing one repurposed (e.g., `icon_shield` if it exists
   at 16x16).

4. **Inline vs. segmented control for SOP/AOP/VOP:** the wireframe shows a segmented
   control. Alternatively, three rows with headers (like the existing list tab with a
   level column) could show all tiers at once. The three-tier segmented approach is
   preferred to keep the list short and focused.

5. **`channel_central_events.ex` scope:** new event handlers (`cc_cs_*`) belong in
   `channel_central_events.ex`. Confirm this file handles all channel-central event
   routing before implementation.
