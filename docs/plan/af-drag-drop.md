# Category AF: Drag & Drop

**Priority**: Green (Medium — convenience feature)
**Dependencies**: None (independent)
**Existing**: None (new category)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| AF1 | Nick drag from nicklist to input | New | Drag a nick from the nicklist and drop onto input to insert the nickname |
| AF2 | Channel reorder in treebar | New | Drag treebar items to reorder channels, persist order in preferences |
| AF3 | URL drag from browser to chat | New | Drag a URL from the browser address bar or another tab into the chat input |
| AF4 | File drag to chat (DCC stub) | New | Drag a file from desktop to chat area — show "File sharing not yet supported" or future DCC hook |

## Dependencies Detail

- AF1 (nick to input) is self-contained — uses HTML5 Drag and Drop API on nicklist items
- AF2 (channel reorder) modifies treebar component — persists order in user preferences
- AF3 (URL drag) uses HTML5 drop event on the input field to extract URL text
- AF4 (file drag) uses HTML5 drop event with file detection — stub for future DCC implementation

## Technical Notes

- HTML5 Drag and Drop API: use draggable="true" on source elements, drop event on targets
- Nick drag: set dataTransfer text to nick name, on drop insert at cursor position in input
- Channel reorder: use drag-over to show insertion indicator, on drop reorder the treebar list
  - Persist order in user preferences (DB for registered, localStorage for guests)
  - Visual feedback during drag: ghost element with 98.css styling, insertion line indicator
- URL drag: listen for drop event on input, extract text/uri-list or text/plain from dataTransfer
- File drag: detect file in dataTransfer.types, show informative message rather than silently failing
- Prevent default browser behavior for drag events to avoid unwanted navigation
- LiveView integration: use JS hooks for drag/drop events, push events to server for persistence

---

## Spec Command

```
/speckit.specify "Drag & Drop for RetroHexChat.

PROBLEM: The application does not support any drag and drop interactions. Users cannot drag nicknames from the nicklist into the input field, cannot reorder channels in the treebar by dragging, cannot drag URLs from other browser tabs into the chat, and dropping files onto the chat area does nothing (or triggers unwanted browser behavior). These are intuitive interactions that users expect in a desktop-like application, especially one with a Windows 98 aesthetic where drag and drop was a standard interaction pattern.

EXISTING CONTEXT: No drag and drop functionality is currently implemented. The treebar renders channels in a fixed order based on join time. The nicklist renders users but they are not draggable. The input field accepts typed and pasted text but not dropped content. DCC (Direct Client-to-Client) file transfer is not yet implemented.

USER JOURNEY — NICK DRAG: A user in a busy channel wants to mention someone. Instead of typing the nick, they grab a name from the nicklist and drag it to the input field. A ghost element shows the nick being dragged. They drop it onto the input — the nick is inserted at the cursor position. If the input was empty and they drop at the start, the nick is followed by ': ' (IRC convention for addressing someone).

USER JOURNEY — CHANNEL REORDER: A user has joined 8 channels and wants to organize them in the treebar. They grab #dev and drag it above #general. An insertion line indicator shows where the channel will be placed. They drop it — the treebar reorders. The new order persists across sessions. They can also drag PM windows to reorder them separately from channels.

USER JOURNEY — URL DRAG: A user is reading a webpage and wants to share the URL in chat. They drag the URL from their browser's address bar and drop it onto the chat input. The URL text is inserted at the cursor position. They add a comment and press Enter to send.

USER JOURNEY — FILE DRAG: A user drags a file from their desktop onto the chat area. Instead of the browser trying to open the file, a friendly message appears: 'Envio de arquivos será suportado em breve via DCC!' — this is a stub for future DCC file transfer implementation.

ACTORS: All drag and drop features are available to any connected user (guest or registered). Channel reorder preferences persist for registered users.

EDGE CASES: Dragging a nick over the chat area (not the input) should not trigger any action. If the user drops a nick onto an empty input, add ': ' after the nick (addressing convention). Channel reorder must handle the case where new channels are joined after reordering (append to end). If the treebar has both channels and PMs, they should be reorderable within their sections but not across sections. URL drop should handle both text/uri-list and text/plain MIME types. File drop must prevent the browser from navigating to the file (preventDefault). Dragging text from the chat area to the input should work as standard browser text drag.

NEGATIVE REQUIREMENTS: Drag and drop must NOT interfere with text selection in the chat area. Dragging must NOT trigger click events on the source element. File drop must NOT attempt to upload or process files — only show a stub message. Channel reorder must NOT change the active channel or trigger any joins/parts. Drag visual feedback must NOT obscure important UI elements.

SCOPE: In scope — nick drag from nicklist to input, channel/PM reorder in treebar with persistence, URL drag from browser to input, file drag stub with friendly message. Out of scope — DCC file transfer implementation, drag between different RetroHexChat windows/tabs, drag and drop in dialogs, custom drag ghost elements (use browser default with 98.css styling hint)."
```
