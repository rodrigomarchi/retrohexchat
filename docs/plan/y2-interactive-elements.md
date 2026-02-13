# Category Y2: Interactive Elements in Chat

**Priority**: Red (Critical — makes chat elements clickable and discoverable)
**Dependencies**: Y (Context Menus) for shared nick/URL/channel detection in DOM
**Existing**: URL auto-detection already renders URLs as visually distinct in chat

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| Y10 | Clickable URLs in chat | New | URLs in messages open in new tab on click, show page title tooltip on hover |
| Y11 | Clickable #channels in chat | New | #channel names in messages are clickable — click to join, hover shows user count tooltip |
| Y12 | Clickable @nicks in chat | New | @nick mentions are clickable — click opens PM, hover shows status tooltip |
| Y13 | Nick hover card | New | Hovering over any nick for 500ms shows mini-card: nick, host, status, channels |
| Y14 | Nick click actions in chat | New | Single-click nick in chat inserts into input, double-click opens PM |

## Dependencies Detail

- Y10 extends existing URL auto-detection (from Category E) with click and hover behavior
- Y11 requires wrapping #channel patterns in chat messages with clickable spans
- Y12 requires wrapping @nick patterns in chat messages with clickable spans
- Y13 (nick hover card) uses Presence for status and whois data to populate the card
- Y14 (nick click) integrates with the input component for nick insertion
- All items share nick/URL/channel DOM detection infrastructure with Y (Context Menus)

## Technical Notes

- URL detection in chat already exists via URL auto-detection — extend with click handler (target="_blank") and hover tooltip
- Channel detection: #channel pattern in messages should be wrapped in clickable spans with data attributes
- Nick detection: nick text in messages should have data-nick attributes for both click and hover handlers
- Hover card: use 500ms delay to avoid accidental triggers, dismiss on mouseout with small grace period
- Hover card content: nick, hostname (if available from whois cache), online duration, shared channels
- Nick click behavior: single-click inserts nick into input (appending ": " if input is empty), double-click opens PM
- Must distinguish between click and text selection — click should only trigger if user did not drag/select

---

## Spec Command

```
/speckit.specify "Interactive Elements in Chat for RetroHexChat.

PROBLEM: Chat messages are currently static text. URLs, channel names, and nicknames mentioned in messages are not clickable or hoverable. To join a channel mentioned in chat, users must type '/join #channel'. To PM someone whose name appears in a message, they must type '/msg nick'. To learn about a user, they must type '/whois nick'. This makes the chat feel like a passive text display rather than an interactive environment. Modern chat applications make all these elements interactive.

EXISTING CONTEXT: URL auto-detection in chat messages is already implemented — URLs are visually distinct (different color). Context menus for nicks, URLs, and channels in the chat area are handled by Category Y (Context Menus), which provides the right-click interaction. This category adds the left-click and hover interactions for the same elements.

USER JOURNEY — CLICKABLE URLS: A user sees 'check https://hexdocs.pm/phoenix' in a chat message. The URL is visually distinct (underlined on hover, pointer cursor). They hover over it — a tooltip shows the page title if available (e.g., 'Phoenix Framework — Overview'). They click — it opens in a new browser tab.

USER JOURNEY — CLICKABLE CHANNELS: A user sees 'join us in #dev for the discussion' in chat. The '#dev' text is visually distinct (colored, underlined on hover). They hover — a tooltip shows '#dev — 5 users — Click to join'. They click — they join #dev (or switch to it if already joined).

USER JOURNEY — CLICKABLE NICKS AND HOVER CARD: A user sees a message from Mario. They hover over 'Mario' in the chat for 500ms — a mini-card appears: 'Mario, mario@host.com, Online for 2h, Channels: #general, #dev'. The card has subtle text: 'Click: insert nick | Double-click: PM | Right-click: menu'. They single-click Mario's name — 'Mario: ' is inserted into the input field. They double-click another nick — a PM window opens.

ACTORS: Any connected user (guest or registered) can interact with clickable elements. No special permissions required.

EDGE CASES: Clicking a #channel the user is already in should switch to that channel, not attempt to re-join. If whois data is not available for a hover card, show a loading state then minimal info (just the nick). The nick hover card must not appear while the user is actively selecting text (only on idle hover after 500ms without mouse movement). If a nick changes while a hover card is showing, the card should dismiss. URLs with special characters must still be clickable. Channel names at the end of sentences followed by punctuation (e.g., '#dev.') must not include the period. Long URLs should be visually truncated but link to the full URL.

NEGATIVE REQUIREMENTS: Clickable elements must NOT interfere with text selection — click should only trigger if the user did not drag/select text. The nick hover card must NOT appear for the user's own nick in their own messages. Clicking elements must NOT trigger if a context menu is open. Hover tooltips must NOT remain stuck if the mouse leaves the viewport.

SCOPE: In scope — clickable URLs with hover title tooltip, clickable #channels with hover user count, clickable @nicks with hover status, nick hover card (mini whois), nick single-click (insert into input) and double-click (open PM). Out of scope — right-click menus (that is Category Y Context Menus), link preview thumbnails/embeds, nick cards with action buttons (keep it simple — tooltip only)."
```
