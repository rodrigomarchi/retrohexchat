# Category H: Logging System

**Priority**: Green (Low impact)
**Dependencies**: None (standalone)
**Existing**: Chat history already persisted in database

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| H1 | Auto-logging of channels | New | Export channel history as user-accessible logs |
| H2 | Auto-logging of PMs | New | Export PM history as downloadable logs |
| H3 | Log viewer dialog | New | Dedicated window to search and view past logs with filters |
| H4 | Configurable log formats | New | Choose timestamp format, include/exclude events |
| H5 | Export logs as file | New | Download log as .txt or .html file |

## Dependencies Detail

- H is fully independent — no dependencies on other categories
- H4 (configurable formats) may integrate with V (Options Dialog) for settings
- Existing chat persistence provides the data source

## Technical Notes (IRC/mIRC Reference)

- mIRC logs to text files in a configurable directory, one file per channel/PM per day
- Log format is customizable: timestamp format, whether to include joins/parts/mode changes
- mIRC supports log viewer with search functionality
- Modern IRC clients (HexChat, TheLounge) also offer HTML export with color preservation

---

## Spec Command

```
/speckit.specify "Logging System for RetroHexChat.

PROBLEM: Although chat messages are persisted, users have no way to browse, search, or export their chat history outside of scrolling up in the chat window. Users who need to find a specific conversation from last week, export a meeting log, or keep records of important discussions have no tools to do so. Classic mIRC provides robust logging with search and export capabilities.

EXISTING CONTEXT: All chat messages (channels and PMs) are already persisted in the database with full history. This feature is about surfacing that data to users through a dedicated interface.

USER JOURNEY: A user needs to find something discussed in #project last Thursday. They open the Log Viewer (via menu or toolbar). A retro-style window appears with filter controls at the top: a date range picker, a channel/PM selector dropdown, a nickname filter field, and a text search box. They select #project, set the date range to last Thursday, and type a search term. The matching messages appear in a scrollable list with timestamps, nicknames, and message content. System events (joins, parts, kicks, topic changes) are shown in a distinct style.

The user can then click 'Export' to download the filtered results as a .txt file (plain text with timestamps) or an .html file (styled to look like the chat with colors and formatting preserved). The export respects the current filter — only the visible results are exported.

Users can also configure what events appear in logs: they can toggle inclusion of joins, parts, kicks, mode changes, and topic changes. They can choose timestamp format: [HH:MM], [HH:MM:SS], or [DD/MM HH:MM].

ACTORS: Any connected registered user can access the Log Viewer to search and export their own message history. Guest users can only access history from their current session.

EDGE CASES: Searching across a very large history (thousands of messages) should not freeze the interface — results should load progressively. Exporting a very large log should provide progress feedback. If no messages match the filter, the viewer should show 'No results found' with a suggestion to broaden the search. Date range must not allow selecting future dates. Searching for special characters (regex metacharacters) should be treated as literal text.

SCOPE: In scope — log viewer with date/channel/nick/text filters, paginated results, export as .txt and .html, configurable event inclusion and timestamp format. Out of scope — automatic periodic log file generation (logs are on-demand), log rotation or deletion policies, log sharing between users."
```
