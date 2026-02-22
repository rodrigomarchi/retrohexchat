# Feature Specification: Log Viewer

**Feature Branch**: `008-log-viewer`
**Created**: 2026-02-11
**Status**: Draft
**Input**: User description: "Logging System for RetroHexChat — Log Viewer with search, filter, and export capabilities for persisted chat history"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Search and Browse Chat History (Priority: P1)

A registered user wants to find a specific conversation from a past channel discussion. They open the Log Viewer from the Tools menu or toolbar. A retro-style dialog appears with filter controls: a date range picker, a channel/PM selector dropdown, a nickname filter field, and a text search box. The user selects a channel, optionally narrows by date and nickname, and types a search term. Matching messages appear in a scrollable, paginated list with timestamps, nicknames, and message content. System events (joins, parts, kicks, topic changes) are visually distinct from regular messages.

**Why this priority**: This is the core value proposition — without search and browse, no other feature (export, configuration) is useful. A functional log viewer with filters delivers immediate value.

**Independent Test**: Can be fully tested by opening the Log Viewer, applying filters (channel, date range, nickname, text), and verifying that matching messages are displayed with correct formatting and pagination.

**Acceptance Scenarios**:

1. **Given** a registered user with message history in #project, **When** they open the Log Viewer and select #project from the channel dropdown, **Then** they see messages from #project in reverse chronological order with timestamps and nicknames.
2. **Given** a user viewing #project logs, **When** they set a date range to a specific day and type a search term, **Then** only messages from that day containing the search term are displayed.
3. **Given** a user searching for text with special characters (e.g., `C++`, `$100`), **When** they type the search term, **Then** the special characters are treated as literal text (not regex), and matching results are shown.
4. **Given** a search that returns many results (100+ messages), **When** results load, **Then** the first page of results appears within 2 seconds, with pagination controls to load more.
5. **Given** a search that returns no results, **When** the query completes, **Then** the viewer shows "No results found" with a suggestion to broaden the search criteria.
6. **Given** a guest user (not registered), **When** they open the Log Viewer, **Then** they can only see messages from their current session, not historical data.

---

### User Story 2 - Export Filtered Logs (Priority: P2)

A user has filtered their log view to show a specific set of messages (e.g., all messages in #meeting from last Monday). They want to save this as a file for their records. They click the "Export" button and choose between plain text (.txt) or styled HTML (.html). The export contains only the currently filtered/visible results. The .txt format includes timestamps and nicknames in a clean, readable format. The .html format preserves chat styling, colors, and formatting codes. For large exports, a progress indicator is shown.

**Why this priority**: Export is the second most valuable capability — it enables users to save and share logs outside the application. It builds directly on the filter/search from US1.

**Independent Test**: Can be tested by applying a filter in the Log Viewer, clicking Export, choosing a format, and verifying the downloaded file contains exactly the filtered messages in the correct format.

**Acceptance Scenarios**:

1. **Given** a user with filtered log results showing 50 messages, **When** they click Export and choose .txt, **Then** a plain text file downloads containing those 50 messages with timestamps and nicknames.
2. **Given** a user with filtered log results, **When** they click Export and choose .html, **Then** an HTML file downloads preserving message formatting (bold, italic, underline, colors) and chat styling.
3. **Given** a user exporting a large log (500+ messages), **When** the export is processing, **Then** a progress indicator is shown until the file is ready for download.
4. **Given** a user with no results displayed (empty filter), **When** they attempt to export, **Then** the Export button is disabled or shows a message indicating there is nothing to export.

---

### User Story 3 - Configure Log Display Preferences (Priority: P3)

A user wants to customize what information appears in the Log Viewer. They access a settings area within the Log Viewer where they can toggle the inclusion of system events: joins, parts, kicks, mode changes, and topic changes. They can also choose their preferred timestamp format from three options: [HH:MM], [HH:MM:SS], or [DD/MM HH:MM]. These preferences persist for the duration of the session and affect both the viewer display and exports.

**Why this priority**: Configuration enhances usability but is not essential for core functionality. The viewer is fully functional without custom preferences by using sensible defaults.

**Independent Test**: Can be tested by changing event toggles and timestamp format in settings, then verifying the log display and exports reflect those changes.

**Acceptance Scenarios**:

1. **Given** a user viewing logs with joins/parts enabled (default), **When** they disable join/part events in settings, **Then** join and part messages disappear from the current view.
2. **Given** a user with timestamp format set to [HH:MM:SS] (default), **When** they switch to [HH:MM], **Then** all displayed timestamps update to show only hours and minutes.
3. **Given** a user with custom settings (some events hidden, specific timestamp format), **When** they export the log, **Then** the export reflects the same settings (hidden events are excluded, timestamp format matches).
4. **Given** a user who has changed settings, **When** they close and reopen the Log Viewer in the same session, **Then** their settings are preserved.

---

### Edge Cases

- **Empty history**: A new user with no message history opens the Log Viewer and sees a friendly empty state with guidance on how to get started.
- **Very large result set**: Searching across months of history in a busy channel returns thousands of results — the interface remains responsive with paginated loading (50 messages per page).
- **Future date selection**: The date range picker does not allow selecting dates in the future; validation rejects any future date with an inline error.
- **Channel no longer exists**: If a user's history includes a channel that has since been dropped, the channel still appears in the dropdown and its logs are still accessible.
- **Special characters in search**: Regex metacharacters (`*`, `+`, `?`, `.`, `(`, `)`, `[`, `]`, `{`, `}`, `\`, `^`, `$`, `|`) are escaped and treated as literal text.
- **Concurrent session**: If new messages arrive while the Log Viewer is open, the viewer shows a point-in-time snapshot; users can click a "Refresh" button to reload with the current filter.
- **PM history**: Private message history is accessible by selecting a PM conversation from the dropdown; the dropdown lists both channels and PM partners in separate groups.
- **Export filename**: Exported files are named with the channel/PM name and date range, e.g., `project_2026-02-05_to_2026-02-11.txt` (the `#` is stripped from channel names for filesystem compatibility).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a Log Viewer dialog accessible from the Tools menu, a toolbar button, and the keyboard shortcut Alt+L.
- **FR-002**: System MUST display a channel/PM selector dropdown listing all channels and PM conversations the user has participated in, grouped by type (Channels, Private Messages).
- **FR-003**: System MUST provide a date range filter with start and end date inputs; future dates MUST be rejected with an inline validation message.
- **FR-004**: System MUST provide a nickname filter field that restricts results to messages sent by a specific user (case-insensitive partial match).
- **FR-005**: System MUST provide a text search field that performs case-insensitive literal text matching; regex metacharacters MUST be escaped automatically.
- **FR-006**: System MUST display matching messages in a scrollable list with timestamps, nicknames, and message content in chronological order.
- **FR-007**: System MUST paginate results with 50 messages per page, with "Previous" and "Next" buttons and a page indicator (e.g., "Page 2 of 15").
- **FR-008**: System MUST visually distinguish system events (joins, parts, kicks, mode changes, topic changes) from regular messages using a distinct text style.
- **FR-009**: System MUST show "No results found — try broadening your search criteria" when a query returns zero results.
- **FR-010**: System MUST allow exporting filtered results as a .txt file with plain text timestamps, nicknames, and content (one message per line).
- **FR-011**: System MUST allow exporting filtered results as an .html file preserving formatting codes (bold, italic, underline, colors) using the existing Formatter module's output.
- **FR-012**: System MUST disable the Export button when no results are displayed.
- **FR-013**: System MUST show a progress indicator when exporting more than 100 messages.
- **FR-014**: System MUST name exported files using the pattern `{channel_or_pm}_{start_date}_to_{end_date}.{ext}`, stripping `#` from channel names.
- **FR-015**: System MUST allow users to toggle inclusion of each system event type independently: joins, parts, kicks, mode changes, topic changes.
- **FR-016**: System MUST allow users to choose timestamp format from three options: [HH:MM], [HH:MM:SS], or [DD/MM HH:MM].
- **FR-017**: System MUST apply display preferences (event toggles, timestamp format) consistently to both the viewer display and file exports.
- **FR-018**: System MUST persist display preferences for the duration of the user's session (in-memory, not database).
- **FR-019**: Registered users MUST be able to search their full persisted message history across all channels and PMs they have participated in.
- **FR-020**: Guest users MUST only be able to view messages from their current active session in the Log Viewer; no historical database queries are permitted for guests.
- **FR-021**: System MUST allow closing the Log Viewer via the X button or the Escape key.
- **FR-022**: System MUST provide a "Refresh" button to reload results with the current filter criteria.

### Key Entities

- **Log Entry**: A single message or system event with a timestamp, source (channel name or PM partner nickname), author nickname, content, and event type (message, action, join, part, kick, mode_change, topic_change).
- **Log Filter**: A set of filter criteria comprising: channel/PM selection (string), date range start (date), date range end (date), nickname filter (string), and text search term (string). All fields are optional; an empty filter returns the most recent messages.
- **Display Preferences**: User-configurable settings including 5 event type visibility toggles (show_joins, show_parts, show_kicks, show_mode_changes, show_topic_changes) and one timestamp format selection (hh_mm, hh_mm_ss, dd_mm_hh_mm). Defaults: all events visible, timestamp format [HH:MM:SS].
- **Export Job**: A request to export filtered log entries in a specific format (.txt or .html), producing a downloadable file named according to the filter context.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can find a specific message from a known channel and approximate date within 30 seconds of opening the Log Viewer.
- **SC-002**: Search results for the first page (50 messages) appear within 2 seconds for queries spanning up to 30 days of history.
- **SC-003**: Exported .txt files contain correctly formatted timestamps, nicknames, and content for 100% of filtered messages with no data loss.
- **SC-004**: Exported .html files preserve all formatting codes (bold, italic, underline, colors) present in the original messages.
- **SC-005**: All 5 system event toggles correctly show/hide their respective event types in both the viewer display and exports.
- **SC-006**: The Log Viewer renders in the retro visual style (retro design system) consistent with all other dialogs in the application.
- **SC-007**: Guest users see only current-session messages, with zero leakage of historical data from other users or previous sessions.

## Assumptions

- Messages are already persisted in the database with timestamps, channel/PM source, author, content, and event type — no new data capture is needed.
- The existing database schema supports queries by channel, date range, and text content; performance indexes may need to be added during implementation.
- The "current session" for guest users is defined as messages received since their LiveView mount (connection time).
- Default display preferences: all system event types visible, timestamp format [HH:MM:SS].
- The Log Viewer follows the same dialog pattern as Channel Central, Address Book, and other retro windows in the application.
- Export downloads are triggered via the browser (client-side download), not server-side file storage.
- The nickname filter in FR-004 uses case-insensitive partial matching (e.g., "ali" matches "Alice" and "Malice") to be consistent with search UX patterns.

## Scope

### In Scope

- Log Viewer dialog with channel/PM, date range, nickname, and text search filters
- Paginated message display (50 per page) with page navigation
- System event visual distinction and configurable inclusion (5 toggles)
- Configurable timestamp format (3 options)
- Export as .txt (plain text) and .html (styled with formatting preserved)
- Progress indicator for large exports (100+ messages)
- Keyboard shortcut (Alt+L), menu bar item, toolbar button
- Guest user session-only limitation
- Help documentation (feature-log-viewer, feature-log-export topics)

### Out of Scope

- Automatic periodic log file generation (logs are on-demand only)
- Log rotation, deletion, or retention policies
- Log sharing between users
- Real-time streaming of new messages into the viewer (point-in-time snapshot with manual refresh)
- Full-text search indexing beyond what the database natively supports
- Log viewer for non-participants (users can only see logs for channels/PMs they participated in)
