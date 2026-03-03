# Category D: Highlight / Mentions

**Priority**: Red (High impact)
**Dependencies**: None (standalone)
**Existing**: None

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| D1 | Highlight own nick | New | When someone mentions your nickname, the message is visually highlighted |
| D2 | Custom highlight words | New | Configurable list of words that trigger highlights |
| D3 | Highlight with sound | New | Notification sound when a highlight triggers |
| D4 | Highlight with taskbar flash | New | Treebar/switchbar item flashes when highlight occurs in non-active channel |
| D5 | Colors per highlight word | New | Each highlight word can have custom foreground + background color |

## Dependencies Detail

- D is fully independent — no dependencies on other categories
- D3 (sound) uses sound infrastructure that O (Sounds & Notifications) may expand
- D4 (flash) relates to O5 (visual flash/blink) for visual attention
- D5 (colors) may integrate with V6 (color options) for persistence

## Technical Notes (IRC/mIRC Reference)

- mIRC highlights the user's own nick by default with a configurable color
- Custom highlight words are configured in Tools > Address Book > Highlight tab (or Options)
- mIRC supports wildcards in highlight patterns (e.g., "elixir*")
- Highlight events can trigger sounds, flashes, and even beeps in mIRC

---

## Spec Command

```
/speckit.specify "Highlight / Mentions for RetroHexChat.

PROBLEM: In a busy channel with many messages flowing quickly, users have no way to know when someone mentions them by name or discusses a topic they care about. Messages mentioning their nickname scroll by unnoticed. This is one of the most impactful UX gaps — every IRC client since the 1990s highlights the user's own nick.

USER JOURNEY: A user named 'Alice' is reading messages in #elixir. Someone types 'hey Alice, check this out'. The message line is rendered with a distinct highlight color (e.g., bright yellow background), a notification sound plays, and if #elixir is not the active channel, the treebar entry for #elixir flashes to draw attention.

Beyond their own nickname (which is highlighted by default with no setup), the user can configure custom highlight words. They open a Highlight configuration dialog and add 'phoenix', 'liveview', and 'deploy'. Now any message containing these words in any channel also triggers highlighting, sound, and flashing.

Each highlight word can optionally have its own custom colors. For example, 'deploy' could have a red background to signal urgency while 'phoenix' has a subtle blue highlight. If no custom color is set, the default highlight color is used.

ACTORS: Any connected user (guest or registered). Highlight preferences are per-user and persist across sessions for registered users.

EDGE CASES: Highlight matching must be case-insensitive and should match whole words only ('Rod' should not highlight 'Alice'). The user's own messages should NOT trigger self-highlights. If a message contains multiple highlight words, the highest-priority color should win (own nick > custom words). Channels where the user has muted notifications should not produce sound or flash, but should still visually highlight the message text. An empty highlight word list (besides own nick) should be the default.

NEGATIVE REQUIREMENTS: Highlights must NOT generate any visible signal to other users — they are purely local. The system must NOT highlight words inside URLs or system messages.

SCOPE: In scope — own-nick highlighting (on by default), custom highlight word list with per-word colors, notification sound on highlight, treebar/switchbar flash on highlight in non-active channels, configuration dialog. Out of scope — regex patterns for highlight matching (keep it simple, whole-word only), highlight logging or history."
```
