# Quickstart: Log Viewer

**Feature Branch**: `008-log-viewer`

## Scenario 1: Search Channel History (US1 — Core MVP)

### Setup
1. Ensure at least one registered user with persisted message history in `messages` table
2. Multiple messages in "#project" channel across several dates
3. Some messages contain specific search terms

### Steps
1. Connect as registered user
2. Open Log Viewer (Alt+L or Tools > Log Viewer)
3. Select "#project" from channel dropdown
4. Set date range to last week
5. Type "meeting" in text search field
6. Verify: paginated results showing matching messages with timestamps and nicknames
7. Click "Next" page button
8. Verify: second page loads with correct messages

### Expected
- First page shows up to 50 messages in chronological order
- Page indicator shows "Page 1 of N"
- System events (joins, parts) are visually distinct
- Empty search shows "No results found" message

---

## Scenario 2: Export as Text (US2)

### Setup
1. Perform a filtered search that returns results (from Scenario 1)

### Steps
1. Click "Export" dropdown
2. Select ".txt"
3. Verify: file downloads with correct name pattern (e.g., `project_2026-02-03_to_2026-02-11.txt`)
4. Open file and verify contents

### Expected
- Each line: `[HH:MM:SS] <NickName> message content`
- System events: `[HH:MM:SS] * User joined #project`
- Only filtered messages appear (same as viewer)
- Filename strips `#` from channel name

---

## Scenario 3: Export as HTML (US2)

### Setup
1. Some messages contain formatting codes (bold, colors)

### Steps
1. Filter to show messages with formatting
2. Click "Export" > ".html"
3. Open HTML file in browser

### Expected
- Standalone HTML page with embedded CSS
- Bold, italic, underline preserved
- IRC colors displayed correctly
- Dark theme styling applied

---

## Scenario 4: Display Preferences (US3)

### Steps
1. Open Log Viewer with results showing join/part events
2. Toggle off "Show Joins" checkbox
3. Verify: join events disappear from results
4. Change timestamp format to [HH:MM]
5. Verify: timestamps update
6. Export as .txt
7. Verify: exported file reflects preferences (no joins, short timestamps)
8. Close and reopen Log Viewer
9. Verify: preferences preserved

---

## Scenario 5: Guest User (Edge Case)

### Steps
1. Connect as guest (no NickServ registration)
2. Send some messages in #lobby
3. Open Log Viewer
4. Verify: only messages from current session shown
5. Verify: no historical messages visible

---

## Scenario 6: Empty History (Edge Case)

### Steps
1. Connect as new user with no history
2. Open Log Viewer
3. Verify: friendly empty state message
4. Export button disabled

---

## Scenario 7: Special Characters in Search (Edge Case)

### Steps
1. Have a message containing "C++" in history
2. Open Log Viewer, search for "C++"
3. Verify: finds the message (no regex interpretation)
4. Search for "$100" — verify literal match
