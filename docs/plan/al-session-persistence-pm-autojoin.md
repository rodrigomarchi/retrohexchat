# Category AL: Session Persistence — PM Conversations, Auto-Join & Notifications

**Priority**: Red (Critical — core UX gap affecting daily usability)
**Dependencies**: AC (Notification System) for toast/badge infrastructure, I (Perform/Auto-Commands) for auto-join list, AB (Visual Feedback) for unread indicators
**Existing**: AL1 auto-join list (autojoin_list.ex), AL2 PM helper (helpers/pm.ex), AL3 notification routing (pubsub_handlers/messages.ex), AL4 treebar PM section (treebar.ex)

## Problem

Three critical UX gaps make the chat feel stateless and forgettable:

1. **PM conversations are lost on every page load.** The `pm_conversations` field in Session starts as `[]` on mount. Users must manually `/query <nick>` to resume any previous conversation. If someone sends a PM, the receiver gets no visible indication in the treebar — the conversation simply doesn't appear unless the receiver already has it open. In mIRC, receiving a PM instantly opens a new query window.

2. **PM history is invisible.** The database stores all private messages (`private_messages` table), but there's no query to retrieve the list of people a user has conversed with. The "Private" section in the treebar shows nothing on connect, even if the user has months of PM history. In mIRC, the query window list persists and shows all active conversations.

3. **Channels aren't remembered.** Users must manually configure auto-join or re-join channels every session. When a user joins a new channel, it should automatically be added to their auto-join list (for registered users), so their workspace rebuilds itself on reconnect. In mIRC, the "Rejoin channels on connect" option does exactly this.

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| AL1 | Query PM conversation partners from DB | New | Add `Queries.list_pm_conversation_partners/1` that returns all unique nicknames a user has exchanged PMs with, ordered by most recent message timestamp (DESC). Uses the existing `private_messages` table with a `DISTINCT ON` or equivalent query. Returns `[%{nickname: String.t(), last_message_at: DateTime.t()}]` |
| AL2 | Restore PM conversations on mount | New | On ChatLive mount (for identified users), call AL1 to populate `session.pm_conversations` with all previous PM partners, ordered by most recent first. Subscribe to PubSub topics for each restored conversation. This makes the "Private" treebar section show the full history immediately |
| AL3 | Auto-open PM conversation on incoming message | New | When `apply_new_pm/3` receives a PM from someone NOT in `pm_conversations`, automatically add them to the list AND subscribe to their PM PubSub topic. The treebar updates instantly — no need for `/query`. Also ensure the sender is added when sending via `/msg` |
| AL4 | PM treebar ordering by recency | New | The "Private" section in treebar must display conversations ordered by most recent message (newest on top), not insertion order. When a new PM arrives or is sent, that conversation bubbles to the top. Requires either sorting `pm_conversations` as a list of `{nick, last_at}` tuples or maintaining a separate order index |
| AL5 | Auto-add channel to auto-join on join | New | When a registered user joins ANY channel (via `/join`, invite, or channel list), automatically add it to their `autojoin_list` and persist to DB. If the list is full (20 max), show a system message but don't block the join. If already in the list, no-op. On `/part`, remove from auto-join list |
| AL6 | PM notification for new conversations | New | When a PM arrives from someone NOT already in `pm_conversations` (i.e., a brand new conversation), trigger enhanced notification: toast popup ("Nova mensagem de <nick>"), browser notification if in background, sound, AND treebar flash. Existing notification infra (AC) handles the delivery — this item ensures the routing logic fires for first-contact PMs |
| AL7 | Channel message notification for background channels | Existing/Enhance | Verify and enhance that messages in non-active channels trigger proper notification chain: unread badge increment (already working), treebar flash (already working), toast popup (verify), browser notification if in background (verify). Ensure no regression from AL5 changes |
| AL8 | Help documentation | New | Add help topics: "PM Conversations" (feature), "Auto-Join Channels" (update existing). Update "Treebar" UI topic with PM ordering info. Add cross-references |

## Dependencies Detail

- AL1 is a pure Ecto query — no dependencies, can be implemented first
- AL2 depends on AL1 for the query function
- AL3 modifies `apply_new_pm/3` in pubsub_handlers/messages.ex — independent of AL1/AL2
- AL4 requires changing how `pm_conversations` is stored in Session (list of nicks → ordered structure)
- AL5 extends the existing `join_channel` flow in helpers.ex — uses existing AutoJoinList module
- AL6 builds on AL3 (detecting new conversations) + existing AC notification infrastructure
- AL7 is mostly verification — existing notification chain should work, may need minor fixes
- AL8 depends on all other items being complete

## Technical Notes

### AL1: PM Partners Query
```sql
-- Conceptual query
SELECT DISTINCT partner, MAX(inserted_at) as last_message_at
FROM (
  SELECT recipient_nickname as partner, inserted_at
  FROM private_messages WHERE sender_nickname = $1
  UNION ALL
  SELECT sender_nickname as partner, inserted_at
  FROM private_messages WHERE recipient_nickname = $1
) sub
GROUP BY partner
ORDER BY last_message_at DESC
```
- Must handle both directions (sent and received)
- Limit to last N partners (e.g., 50) to avoid loading ancient history
- Consider adding a DB index on `(sender_nickname, inserted_at)` and `(recipient_nickname, inserted_at)` if not already present

### AL2: Mount Flow
- Current mount: `mount → assign_defaults → join_channel("#lobby") → maybe_trigger_perform()`
- New flow: After session initialization and identification, call `restore_pm_conversations/1`
- Only for identified users — guests start with empty PM list (they have no DB history)
- Must subscribe to PubSub for each restored conversation: `"pm:#{sorted_pair}"`

### AL3: Auto-Open on Incoming PM
- Current `apply_new_pm/3` assumes the conversation already exists in `pm_conversations`
- New behavior: if `other_nick` not in `pm_conversations`, add it first, THEN process the message
- Must also call `ensure_pm_subscription/2` for the new conversation
- Edge case: ignored users should NOT auto-open conversations (already handled by ignore check before `apply_new_pm`)

### AL4: PM Ordering
- Current: `pm_conversations` is a plain list of nicknames, displayed in insertion order
- Option A: Change to `[{nickname, last_message_at}]` and sort in treebar component
- Option B: Keep as ordered list, move-to-front on any PM activity (simpler, no timestamps needed)
- Recommend Option B: simpler, in-memory only, treebar just renders in list order
- `Session.touch_pm_conversation/2` moves a nick to the front of the list

### AL5: Auto-Add to Auto-Join
- Existing `AutoJoinList.add_entry/3` handles validation, duplicates, and max limit
- Hook into `Helpers.join_channel/3` — after successful join, add to autojoin list
- On `/part`, call `AutoJoinList.remove_entry/2` and persist
- Only for identified users — guests have no persistent auto-join
- `#lobby` should be excluded (it's always joined by default)
- Channels joined via auto-join on connect should NOT re-trigger the add (they're already in the list)

### AL6: First-Contact PM Notification
- Detection: in `apply_new_pm/3`, check if `other_nick` was already in `pm_conversations` BEFORE adding
- If new, push enhanced notification with `maybe_push_notification(:new_pm_conversation, ...)`
- Toast content: "Nova mensagem privada de <nick>" with click-to-navigate
- Sound: reuse `:pm` sound event

### Existing Infrastructure Leveraged
- `AutoJoinList` module: full CRUD + persistence already implemented
- `UnreadTracker`: already tracks `"pm:#{nick}"` keys for badges
- `NotificationPreferences`: already has PM notification rules
- `TreebarHook`: already handles PM section rendering with unread badges
- `ensure_pm_subscription/2`: already exists in helpers/pm.ex
- `maybe_push_notification/3`: already routes PM notifications to toast/browser/badge

---

## Spec Command

```
/speckit.specify "Session Persistence — PM Conversations, Auto-Join & Notifications for RetroHexChat.

PROBLEM: The chat feels stateless across sessions. Three critical gaps exist: (1) Private message conversations are lost on every page load — the pm_conversations list starts empty, so the Private section in the treebar shows nothing even though the database has full PM history. Users must manually /query <nick> to resume any conversation. (2) When someone sends a PM to a user who doesn't have that conversation open, the message is stored in the database but the receiver sees NO indication in the treebar — the conversation doesn't auto-appear. In mIRC, receiving a PM instantly opens a query window. (3) Channels are not remembered across sessions — users must manually rejoin or configure auto-join for every channel. Joining a channel should automatically add it to the auto-join list for registered users.

EXISTING CONTEXT: (1) private_messages table stores all PMs with sender_nickname, recipient_nickname, content, inserted_at. (2) Session struct has pm_conversations (list of nicks) and autojoin_list (AutoJoinList module with full CRUD + DB persistence). (3) Treebar component renders Private section from pm_conversations with unread badges via UnreadTracker. (4) apply_new_pm/3 handles incoming PMs — increments unread, plays sound, pushes notification, but does NOT add missing conversations to treebar. (5) AutoJoinList supports add_entry/3, remove_entry/2, save/2, load/1 with max 20 entries. (6) Full notification infrastructure exists: toast popups, browser notifications, sounds, treebar flash, favicon badge (Category AC).

USER JOURNEY — PM PERSISTENCE: A registered user connects. Immediately, the Private section in the treebar shows all people they've ever exchanged PMs with, ordered by most recent conversation first. They see 'Alice' at the top (last PM was 2 minutes ago), then 'Bob' (last PM yesterday), then 'Charlie' (last PM a week ago). They click Alice and see the full conversation history. No /query needed.

USER JOURNEY — INCOMING PM: The user is chatting in #general. A new user 'Dave' (whom they've never spoken to) sends them a PM. Instantly: (1) 'Dave' appears at the TOP of the Private section in the treebar with an unread badge showing '1'. (2) A toast popup appears: 'Nova mensagem de Dave: Hey, can you help me?'. (3) The title bar flashes. (4) A PM notification sound plays. (5) If the tab is in the background, a browser notification appears. The user clicks Dave in the treebar and sees the message. They reply, and the conversation continues naturally.

USER JOURNEY — AUTO-JOIN CHANNELS: A registered user joins #elixir for the first time via /join #elixir. The channel is automatically added to their auto-join list. Next time they connect, #elixir is auto-joined along with #lobby and any other channels they've visited. If they /part #elixir, it's removed from the auto-join list. The auto-join list has a 20-channel limit — if full, the join still works but the channel isn't added to auto-join, and a system message explains why.

USER JOURNEY — CHANNEL NOTIFICATIONS: The user is viewing #general. A message arrives in #elixir (a background channel). The treebar shows an unread badge on #elixir, the tab bar highlights it, and a toast shows the message preview. If someone mentions their nick, it's highlighted with the mention notification sound instead.

ACTORS: Registered (identified) users get full persistence (PM history from DB, auto-join saved to DB). Guest users get in-session PM conversation tracking (lost on disconnect) and no auto-join persistence. All users get real-time PM auto-open and notifications.

EDGE CASES: User has hundreds of PM partners — limit to 50 most recent on mount. PM from an ignored user — do NOT auto-open conversation (ignore check fires before auto-open). Auto-join list at 20 max — join succeeds but auto-add fails gracefully with system message. Channel requires a key (+k) — auto-join stores the key. User parts and rejoins same channel — no duplicate in auto-join list. PM to self — should not create a conversation entry. Nick changes — PM conversations keyed by nick at time of message, no retroactive update needed.

NEGATIVE REQUIREMENTS: Auto-join MUST NOT trigger for guest users (no DB persistence). Restoring PM conversations MUST NOT block mount — load asynchronously if needed. Auto-join MUST NOT add #lobby (always joined by default). PM conversation list MUST NOT show conversations with the user's own nick. Channel auto-add MUST NOT fire during auto-join execution on connect (would be circular).

SCOPE: In scope — DB query for PM partners, PM conversation restore on mount, auto-open PM on incoming message, PM treebar ordering by recency, auto-add channels to auto-join on join/remove on part, enhanced notification for new PM conversations, help documentation. Out of scope — PM conversation deletion/archiving, PM search across all conversations, channel key management UI, PM conversation pinning, offline message queue."
```
